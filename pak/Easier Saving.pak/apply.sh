#!/bin/sh
# Easier Saving: puts the patched minarch.elf/nextui.elf in place (or takes
# them away) without touching .system itself. The patched binaries are bind
# mounted over the stock ones, so nothing on the SD card is overwritten and a
# reboot with the pak switched off (or deleted) always gets stock NextUI back.
#
# usage: apply.sh [check]
#   check: exit 0 if the installed NextUI matches the version this pak was
#          built against, 1 otherwise
#   (none): mount/unmount to match the master switch and keep the boot hook in sync
#
# Runs from launch.sh after the settings tool closes, and at boot from the
# boot.d hook this script installs.

PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
ES_DIR="$SHARED_USERDATA_PATH/.easiersaving"
BIN_DIR="$PAK_DIR/bin/$PLATFORM"
HOOK_PATH="$USERDATA_PATH/.hooks/boot.d/easier-saving.sync.sh" # .sync so it finishes before nextui.elf starts
LOG_PATH="$LOGS_PATH/Easier Saving.txt"
BINARIES="minarch.elf nextui.elf"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_PATH"
}

is_compatible() {
	[ -f "$ES_DIR/skip-version-check" ] && return 0
	expected="$(cat "$PAK_DIR/nextui-commit.txt" 2>/dev/null)"
	# line 2 of version.txt is the short commit hash NextUI was built from
	actual="$(sed -n 2p "$SDCARD_PATH/.system/version.txt" 2>/dev/null | tr -d '\r\n ')"
	[ -n "$expected" ] && [ -n "$actual" ] || return 1
	case "$expected" in
		"$actual"*) return 0 ;;
	esac
	return 1
}

is_mounted() {
	grep -q " $1 " /proc/mounts
}

mount_all() {
	for bin in $BINARIES; do
		target="$SYSTEM_PATH/bin/$bin"
		is_mounted "$target" && continue
		if [ ! -f "$BIN_DIR/$bin" ] || [ ! -f "$target" ]; then
			log "missing $BIN_DIR/$bin or $target, not mounting"
			continue
		fi
		if mount -o bind "$BIN_DIR/$bin" "$target"; then
			log "mounted $bin"
		else
			log "failed to mount $bin"
		fi
	done
}

unmount_all() {
	for bin in $BINARIES; do
		target="$SYSTEM_PATH/bin/$bin"
		is_mounted "$target" || continue
		if umount "$target"; then
			log "unmounted $bin"
		else
			log "failed to unmount $bin"
		fi
	done
}

install_hook() {
	mkdir -p "$(dirname "$HOOK_PATH")"
	# the pak path can contain spaces but never a single quote (NextUI can't launch those)
	cat > "$HOOK_PATH" <<-EOF
		#!/bin/sh
		# installed by Easier Saving.pak, remove the pak or switch it off to uninstall
		APPLY='$PAK_DIR/apply.sh'
		[ -f "\$APPLY" ] && sh "\$APPLY"
	EOF
	chmod +x "$HOOK_PATH"
}

if [ "$1" = "check" ]; then
	is_compatible
	exit $?
fi

if [ -f "$ES_DIR/enabled" ] && [ -d "$BIN_DIR" ]; then
	install_hook
	if is_compatible; then
		mount_all
	else
		log "NextUI version mismatch (built for $(cat "$PAK_DIR/nextui-version.txt" 2>/dev/null)), using stock binaries"
		unmount_all
	fi
else
	rm -f "$HOOK_PATH"
	unmount_all
fi
sync
