#!/bin/sh
# Easier Saving: puts the patched minarch.elf and launcher (nextui.elf or
# minui.elf) in place, or takes them away, without touching .system itself.
# The patched binaries are bind mounted over the stock ones, so nothing on the
# SD card is overwritten and a reboot with the pak switched off (or deleted)
# always gets the stock binaries back.
#
# usage: apply.sh [check | unmount]
#   check: exit 0 if the installed NextUI/MinUI matches the version this pak
#          was built against, 1 otherwise
#   unmount: put the stock binaries back for now (used before an update)
#   (none): mount/unmount to match the master switch and keep the boot step in sync
#
# Runs from launch.sh after the settings tool closes, and at boot: from a
# boot.d hook on NextUI, from a marked block in auto.sh on MinUI.

PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
ES_DIR="$SHARED_USERDATA_PATH/.easiersaving"
BIN_DIR="$PAK_DIR/bin/$PLATFORM"
LOG_PATH="$LOGS_PATH/Easier Saving.txt"

OS="$(cat "$PAK_DIR/os.txt" 2>/dev/null)"
if [ "$OS" = "minui" ]; then
	OS_NAME="MinUI"
	BINARIES="minarch.elf minui.elf"
else
	OS_NAME="NextUI"
	BINARIES="minarch.elf nextui.elf"
fi

HOOK_PATH="$USERDATA_PATH/.hooks/boot.d/easier-saving.sync.sh" # NextUI, .sync so it finishes before nextui.elf starts
AUTO_PATH="$USERDATA_PATH/auto.sh" # MinUI
AUTO_START="# >>> Easier Saving"
AUTO_END="# <<< Easier Saving"

log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_PATH"
}

is_compatible() {
	[ -f "$ES_DIR/skip-version-check" ] && return 0
	expected="$(cat "$PAK_DIR/nextui-commit.txt" 2>/dev/null)"
	# line 2 of version.txt is the short commit hash the OS was built from
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

# the pak path can contain spaces but never a single quote (the launchers can't open those)
boot_lines() {
	echo "APPLY='$PAK_DIR/apply.sh'"
	echo '[ -f "$APPLY" ] && sh "$APPLY"'
}

remove_auto_block() {
	[ -f "$AUTO_PATH" ] || return 0
	grep -q "^$AUTO_START" "$AUTO_PATH" || return 0
	sed -i "/^$AUTO_START/,/^$AUTO_END/d" "$AUTO_PATH"
}

install_boot() {
	if [ "$OS" = "minui" ]; then
		# already there (this also runs from auto.sh itself at boot)
		[ -f "$AUTO_PATH" ] && grep -qF "APPLY='$PAK_DIR/apply.sh'" "$AUTO_PATH" && return 0
		# right after the shebang, so it runs even if the rest of auto.sh exits early
		remove_auto_block
		tmp="$AUTO_PATH.tmp"
		{
			if [ -f "$AUTO_PATH" ] && head -n 1 "$AUTO_PATH" | grep -q '^#!'; then
				head -n 1 "$AUTO_PATH"
			else
				echo "#!/bin/sh"
			fi
			echo "$AUTO_START (added by Easier Saving.pak, switch it off in the pak to remove)"
			boot_lines
			echo "$AUTO_END"
			if [ -f "$AUTO_PATH" ]; then
				if head -n 1 "$AUTO_PATH" | grep -q '^#!'; then tail -n +2 "$AUTO_PATH"; else cat "$AUTO_PATH"; fi
			fi
		} > "$tmp" && mv "$tmp" "$AUTO_PATH"
		chmod +x "$AUTO_PATH"
	else
		mkdir -p "$(dirname "$HOOK_PATH")"
		{
			echo "#!/bin/sh"
			echo "# installed by Easier Saving.pak, remove the pak or switch it off to uninstall"
			boot_lines
		} > "$HOOK_PATH"
		chmod +x "$HOOK_PATH"
	fi
}

remove_boot() {
	if [ "$OS" = "minui" ]; then remove_auto_block
	else rm -f "$HOOK_PATH"
	fi
}

if [ "$1" = "check" ]; then
	is_compatible
	exit $?
fi
if [ "$1" = "unmount" ]; then
	unmount_all
	exit 0
fi

if [ -f "$ES_DIR/enabled" ] && [ -d "$BIN_DIR" ]; then
	install_boot
	if is_compatible; then
		mount_all
	else
		log "$OS_NAME version mismatch (built for $(cat "$PAK_DIR/nextui-version.txt" 2>/dev/null)), using stock binaries"
		unmount_all
	fi
else
	remove_boot
	unmount_all
fi
sync
