#!/bin/sh
# Builds the patched minarch and launcher plus the settings tool and
# assembles the pak for each target in sources.txt (NextUI or MinUI).
#
# usage: scripts/build.sh [target...]
#   target: <os>-<platform> from sources.txt, eg. nextui-tg5040 or minui-miyoomini
#           (default: every target in sources.txt)
#
# PAK_VERSION sets the version the pak reports and compares against releases
# when it checks for updates (default: dev-<commit>, older than any release).
#
# Needs git, docker (or podman) and network access. NextUI targets use the
# ghcr.io/loveretro/<platform>-toolchain images; MinUI targets build their
# toolchain image from github.com/shauninman/union-<platform>-toolchain.
# Output: dist/Easier Saving (NextUI).zip and/or dist/Easier Saving (MinUI).zip,
# extract to the root of the SD card.

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES="$ROOT/sources.txt"
TARGETS="${*:-$(grep -v '^#' "$SOURCES" | awk 'NF {print $1 "-" $2}' | xargs)}"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
STAGE="$BUILD/stage"
PAK_NAME="Easier Saving.pak"
RUNTIME="${CONTAINER_RUNTIME:-$(command -v docker || command -v podman)}"

[ -n "$RUNTIME" ] || { echo "docker or podman is required" >&2; exit 1; }

rm -rf "$STAGE" "$DIST"
mkdir -p "$BUILD" "$STAGE" "$DIST"

PAK_VERSION="${PAK_VERSION:-dev-$(git -C "$ROOT" rev-parse --short HEAD)}"

# Mozilla's CA list, so update checks can verify HTTPS on devices that ship without one
if [ ! -f "$BUILD/cacert.pem" ]; then
	curl -fsSL https://curl.se/ca/cacert.pem -o "$BUILD/cacert.pem"
fi

for target in $TARGETS; do
	os="${target%%-*}"
	platform="${target#*-}"
	LINE="$(awk -v o="$os" -v p="$platform" '$1==o && $2==p' "$SOURCES")"
	[ -n "$LINE" ] || { echo "no $target in sources.txt" >&2; exit 1; }
	REPO="$(echo "$LINE" | awk '{print $3}')"
	TAG="$(echo "$LINE" | awk '{print $4}')"
	echo "== $target: $REPO $TAG"

	# pristine checkout at the pinned release
	SRC="$BUILD/src-$(echo "$REPO" | tr -c 'A-Za-z0-9' '-')$TAG"
	if [ ! -d "$SRC" ]; then
		git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
	fi
	COMMIT="$(git -C "$SRC" rev-parse HEAD)"

	# one tree per target, minarch's bundled deps don't rebuild cleanly across toolchains
	WS="$BUILD/$target"
	rm -rf "$WS"
	cp -R "$SRC" "$WS"
	git -C "$WS" apply "$ROOT/patches/$os.patch"
	cp "$ROOT/src/common/easiersaving.h" "$WS/workspace/all/common/"
	cp -R "$ROOT/src/easiersaving" "$WS/workspace/all/"
	# same short hash the stock build reports in minarch's Options
	git -C "$WS" rev-parse --short HEAD > "$WS/workspace/hash.txt"

	if [ "$os" = "nextui" ]; then
		IMAGE="ghcr.io/loveretro/$platform-toolchain:latest"
		LAUNCHER=nextui
		MAKE_LIBS="make -C ./$platform/libmsettings"
		MAKE_TOOL="make -C ./all/easiersaving"
	else
		IMAGE="minui-$platform-toolchain"
		LAUNCHER=minui
		# every platform lib, some platform.c need more than libmsettings (eg. my282's libmstick)
		MAKE_LIBS="for lib in ./$platform/lib*/; do make -C \$lib || exit 1; done"
		MAKE_TOOL="make -C ./all/easiersaving -f makefile.minui"
		if ! "$RUNTIME" image inspect "$IMAGE" >/dev/null 2>&1; then
			TC="$BUILD/toolchains/$platform"
			[ -d "$TC" ] || git clone --depth 1 "https://github.com/shauninman/union-$platform-toolchain.git" "$TC"
			"$RUNTIME" build -t "$IMAGE" "$TC"
		fi
	fi

	"$RUNTIME" run --rm \
		-v "$WS/workspace":/root/workspace \
		-e PLATFORM="$platform" -e UNION_PLATFORM="$platform" \
		"$IMAGE" \
		/bin/bash -c ". ~/.bashrc && export PLATFORM=$platform UNION_PLATFORM=$platform && cd /root/workspace \
			&& $MAKE_LIBS \
			&& make -C ./all/$LAUNCHER \
			&& make -C ./all/minarch \
			&& $MAKE_TOOL"

	PAK="$STAGE/$os/Tools/$platform/$PAK_NAME"
	mkdir -p "$PAK/bin/$platform"
	cp "$ROOT/pak/$PAK_NAME/launch.sh" "$ROOT/pak/$PAK_NAME/apply.sh" "$ROOT/pak/$PAK_NAME/update.sh" "$BUILD/cacert.pem" "$PAK/"
	echo "$os" > "$PAK/os.txt"
	echo "$PAK_VERSION" > "$PAK/version.txt"
	echo "$TAG" > "$PAK/nextui-version.txt"
	echo "$COMMIT" > "$PAK/nextui-commit.txt"
	cp "$WS/workspace/all/minarch/build/$platform/minarch.elf" \
	   "$WS/workspace/all/$LAUNCHER/build/$platform/$LAUNCHER.elf" \
	   "$WS/workspace/all/easiersaving/build/$platform/easiersaving.elf" \
	   "$PAK/bin/$platform/"
	chmod +x "$PAK"/*.sh "$PAK/bin/$platform"/*.elf
done

for os in nextui minui; do
	[ -d "$STAGE/$os" ] || continue
	name="NextUI"; [ "$os" = "minui" ] && name="MinUI"
	(cd "$STAGE/$os" && zip -r -X "$DIST/Easier Saving ($name).zip" Tools)
	echo "built $DIST/Easier Saving ($name).zip"
done
