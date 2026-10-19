#!/bin/sh

PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PAK_DIR"

ES_DIR="$SHARED_USERDATA_PATH/.easiersaving"
BIN_DIR="$PAK_DIR/bin/$PLATFORM"
mkdir -p "$ES_DIR"

if [ ! -x "$BIN_DIR/easiersaving.elf" ]; then
	echo "Easier Saving has no build for $PLATFORM" >> "$LOGS_PATH/Easier Saving.txt"
	exit 1
fi

NOTICE=""
if ! sh ./apply.sh check; then
	NOTICE="Needs NextUI $(cat ./nextui-version.txt)"
fi

"$BIN_DIR/easiersaving.elf" "$NOTICE" >> "$LOGS_PATH/Easier Saving.txt" 2>&1

# nextui.elf isn't running while a pak is, so swapping binaries now is safe
# and the launcher comes back up with the new setting
sh ./apply.sh
