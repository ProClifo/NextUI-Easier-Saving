#!/bin/sh
# Packages the paks staged by build.sh for one OS, used by the release workflow.
#
# usage: scripts/package.sh <os> <stage dir> <dist dir>
#   os: nextui or minui
#
# Writes to <dist dir>:
#   Easier Saving (<OS>).zip                extract to the root of the SD card
#   easier-saving-<os>-<platform>.tar.gz    what update.sh on the device downloads
#   latest-<os>.txt                         this OS's latest.txt lines (see update.sh)

set -e

os="$1"
stage="$2/$os"
dist="$3"
name="NextUI"; [ "$os" = "minui" ] && name="MinUI"

mkdir -p "$dist"
[ -d "$stage" ] || { echo "nothing staged for $os"; exit 0; }
dist="$(cd "$dist" && pwd)"

find "$stage" -name '*.sh' -o -name '*.elf' | xargs -d '\n' chmod +x
(cd "$stage" && zip -r -X "$dist/Easier Saving ($name).zip" Tools)

: > "$dist/latest-$os.txt"
for pak in "$stage"/Tools/*/"Easier Saving.pak"; do
	platform="$(basename "$(dirname "$pak")")"
	tar -czf "$dist/easier-saving-$os-$platform.tar.gz" -C "$pak" .
	sha="$(sha256sum "$dist/easier-saving-$os-$platform.tar.gz" | cut -d' ' -f1)"
	commit="$(cat "$pak/nextui-commit.txt")"
	echo "$os-$platform $sha $commit" >> "$dist/latest-$os.txt"
	# paks from before MinUI support look for plain <platform> entries
	if [ "$os" = "nextui" ]; then
		cp "$dist/easier-saving-$os-$platform.tar.gz" "$dist/easier-saving-$platform.tar.gz"
		echo "$platform $sha $commit" >> "$dist/latest-$os.txt"
	fi
done
cat "$dist/latest-$os.txt"
ls -la "$dist"
