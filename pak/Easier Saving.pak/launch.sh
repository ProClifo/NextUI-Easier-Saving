#!/bin/sh
# Everything runs inside main() so sh has read the whole script before an
# update overwrites it.

main() {
	PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
	cd "$PAK_DIR"

	ES_DIR="$SHARED_USERDATA_PATH/.easiersaving"
	BIN_DIR="$PAK_DIR/bin/$PLATFORM"
	LOG="$LOGS_PATH/Easier Saving.txt"
	mkdir -p "$ES_DIR"

	if [ ! -x "$BIN_DIR/easiersaving.elf" ]; then
		echo "Easier Saving has no build for $PLATFORM" >> "$LOG"
		exit 1
	fi

	OS_NAME="NextUI"
	[ "$(cat ./os.txt 2>/dev/null)" = "minui" ] && OS_NAME="MinUI"
	NOTICE=""
	if ! sh ./apply.sh check; then
		NOTICE="Needs $OS_NAME $(cat ./nextui-version.txt)"
	fi

	"$BIN_DIR/easiersaving.elf" "$NOTICE" >> "$LOG" 2>&1
	# 3: an update was downloaded and should be installed
	if [ $? -eq 3 ] && sh ./update.sh install >> "$LOG" 2>&1; then
		# start the new version, which applies its own binaries on exit
		exec sh "$PAK_DIR/launch.sh"
	fi

	# nextui.elf isn't running while a pak is, so swapping binaries now is safe
	# and the launcher comes back up with the new setting
	sh ./apply.sh
}

main "$@"; exit $?
