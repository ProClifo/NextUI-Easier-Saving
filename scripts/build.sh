#!/bin/sh
# Builds the patched NextUI binaries plus the settings tool and assembles the
# pak for each platform, each from the NextUI source listed in sources.txt.
#
# usage: scripts/build.sh [platform...]   (default: every platform in sources.txt)
#
# Needs git, docker (or podman) and network access to pull NextUI, its
# dependencies and the ghcr.io/loveretro/<platform>-toolchain images.
# Output: dist/Easier Saving.zip, extract it to the root of the SD card.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES="$ROOT/sources.txt"
PLATFORMS="${*:-$(grep -v '^#' "$SOURCES" | awk 'NF {print $1}' | xargs)}"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
STAGE="$BUILD/stage"
PAK_NAME="Easier Saving.pak"
RUNTIME="${CONTAINER_RUNTIME:-$(command -v docker || command -v podman)}"

[ -n "$RUNTIME" ] || { echo "docker or podman is required" >&2; exit 1; }

rm -rf "$STAGE" "$DIST"
mkdir -p "$BUILD" "$STAGE" "$DIST"

for platform in $PLATFORMS; do
	LINE="$(awk -v p="$platform" '$1==p' "$SOURCES")"
	[ -n "$LINE" ] || { echo "no source for $platform in sources.txt" >&2; exit 1; }
	NEXTUI_REPO="$(echo "$LINE" | awk '{print $2}')"
	NEXTUI_TAG="$(echo "$LINE" | awk '{print $3}')"
	echo "== $platform: $NEXTUI_REPO $NEXTUI_TAG"

	# pristine NextUI checkout at the pinned release
	SRC="$BUILD/src-$(echo "$NEXTUI_REPO" | tr -c 'A-Za-z0-9' '-')$NEXTUI_TAG"
	if [ ! -d "$SRC" ]; then
		git clone --depth 1 --branch "$NEXTUI_TAG" "$NEXTUI_REPO" "$SRC"
	fi
	COMMIT="$(git -C "$SRC" rev-parse HEAD)"

	# one tree per platform, minarch's bundled deps don't rebuild cleanly across toolchains
	WS="$BUILD/$platform"
	rm -rf "$WS"
	cp -R "$SRC" "$WS"
	git -C "$WS" apply "$ROOT/patches/easier-saving.patch"
	cp "$ROOT/src/common/easiersaving.h" "$WS/workspace/all/common/"
	cp -R "$ROOT/src/easiersaving" "$WS/workspace/all/"
	# same short hash stock NextUI reports in minarch's Options > Core
	git -C "$WS" rev-parse --short HEAD > "$WS/workspace/hash.txt"

	"$RUNTIME" run --rm \
		-v "$WS/workspace":/root/workspace \
		-e PLATFORM="$platform" -e UNION_PLATFORM="$platform" \
		"ghcr.io/loveretro/$platform-toolchain:latest" \
		/bin/bash -c ". ~/.bashrc && export PLATFORM=$platform UNION_PLATFORM=$platform && cd /root/workspace \
			&& make -C ./$platform/libmsettings \
			&& make -C ./all/nextui \
			&& make -C ./all/minarch \
			&& make -C ./all/easiersaving"

	PAK="$STAGE/Tools/$platform/$PAK_NAME"
	mkdir -p "$PAK/bin/$platform"
	cp "$ROOT/pak/$PAK_NAME/launch.sh" "$ROOT/pak/$PAK_NAME/apply.sh" "$PAK/"
	echo "$NEXTUI_TAG" > "$PAK/nextui-version.txt"
	echo "$COMMIT" > "$PAK/nextui-commit.txt"
	cp "$WS/workspace/all/minarch/build/$platform/minarch.elf" \
	   "$WS/workspace/all/nextui/build/$platform/nextui.elf" \
	   "$WS/workspace/all/easiersaving/build/$platform/easiersaving.elf" \
	   "$PAK/bin/$platform/"
	chmod +x "$PAK"/*.sh "$PAK/bin/$platform"/*.elf
done

(cd "$STAGE" && zip -r -X "$DIST/Easier Saving.zip" Tools)
echo "built $DIST/Easier Saving.zip"
