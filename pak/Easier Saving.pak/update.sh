#!/bin/sh
# Easier Saving: self-update from the latest GitHub release.
#
# usage: update.sh check | download | install
#   check:    prints one line, one of
#               none                      up to date (or offline)
#               available <version>       a newer release can be installed
#               incompatible <version>    a newer release exists but needs another NextUI
#               error <message>
#   download: fetches and verifies the newest release for this platform into
#             .update/ inside the pak, prints "ready" or "error <message>"
#   install:  copies a downloaded update over the pak, run by launch.sh once
#             the settings tool has exited
#
# Each release carries latest.txt:
#   version <tag>
#   <platform> <sha256 of easier-saving-<platform>.tar.gz> <NextUI commit it was built from>

PAK_DIR="$(cd "$(dirname "$0")" && pwd)"
ES_DIR="$SHARED_USERDATA_PATH/.easiersaving"
REPO="ProClifo/NextUI-Easier-Saving"
BASE="${ES_UPDATE_BASE:-https://github.com/$REPO/releases/latest/download}" # override for testing
STAGE="$PAK_DIR/.update"
MANIFEST="/tmp/easiersaving-latest.txt"
TARBALL="/tmp/easiersaving-update.tar.gz"

# verify HTTPS against the CA bundle shipped with the pak, never fall back to -k
fetch() { # url out max_secs
	curl -fsSL --connect-timeout 5 -m "$3" --cacert "$PAK_DIR/cacert.pem" -o "$2" "$1"
}

# 1 if version $1 is newer than $2 (v1.2.3 style, anything else counts as 0)
is_newer() {
	awk -v a="$1" -v b="$2" 'function parse(v, out,   n, i) {
		sub(/^v/, "", v)
		if (v !~ /^[0-9]+(\.[0-9]+)*$/) v = "0"
		n = split(v, out, ".")
		for (i = n + 1; i <= 3; i++) out[i] = 0
	}
	BEGIN {
		parse(a, x); parse(b, y)
		for (i = 1; i <= 3; i++) {
			if (x[i] + 0 > y[i] + 0) { print 1; exit }
			if (x[i] + 0 < y[i] + 0) { print 0; exit }
		}
		print 0
	}'
}

# the manifest line for this platform: <platform> <sha256> <commit>
platform_line() {
	awk -v p="$PLATFORM" '$1==p' "$MANIFEST"
}

# whether a release built from NextUI commit $1 runs on the installed NextUI (see apply.sh)
matches_nextui() {
	[ -f "$ES_DIR/skip-version-check" ] && return 0
	actual="$(sed -n 2p "$SDCARD_PATH/.system/version.txt" 2>/dev/null | tr -d '\r\n ')"
	[ -n "$1" ] && [ -n "$actual" ] || return 1
	case "$1" in
		"$actual"*) return 0 ;;
	esac
	return 1
}

check() {
	command -v curl >/dev/null 2>&1 || { echo "error curl not found"; return; }
	fetch "$BASE/latest.txt" "$MANIFEST" 15 || { echo "none"; return; } # most likely offline
	latest="$(awk '$1=="version" {print $2}' "$MANIFEST")"
	installed="$(cat "$PAK_DIR/version.txt" 2>/dev/null)"
	[ -n "$latest" ] || { echo "error bad manifest"; return; }
	[ "$(is_newer "$latest" "$installed")" = 1 ] || { echo "none"; return; }

	line="$(platform_line)"
	[ -n "$line" ] || { echo "error no $PLATFORM build in $latest"; return; }
	if matches_nextui "$(echo "$line" | awk '{print $3}')"; then
		echo "available $latest"
	else
		echo "incompatible $latest"
	fi
}

download() {
	fetch "$BASE/latest.txt" "$MANIFEST" 15 || { echo "error can't reach GitHub"; return; }
	line="$(platform_line)"
	[ -n "$line" ] || { echo "error no $PLATFORM build"; return; }
	sha="$(echo "$line" | awk '{print $2}')"

	rm -f "$TARBALL"
	fetch "$BASE/easier-saving-$PLATFORM.tar.gz" "$TARBALL" 300 || { echo "error download failed"; return; }
	if command -v sha256sum >/dev/null 2>&1; then
		echo "$sha  $TARBALL" | sha256sum -c - >/dev/null 2>&1 || { rm -f "$TARBALL"; echo "error checksum mismatch"; return; }
	fi

	rm -rf "$STAGE"
	mkdir -p "$STAGE"
	if ! tar -xzf "$TARBALL" -C "$STAGE" || [ ! -f "$STAGE/launch.sh" ] || [ ! -f "$STAGE/bin/$PLATFORM/easiersaving.elf" ]; then
		rm -rf "$STAGE" "$TARBALL"
		echo "error bad update archive"
		return
	fi
	rm -f "$TARBALL"
	sync
	echo "ready"
}

install() {
	[ -f "$STAGE/launch.sh" ] || return 1
	# the patched binaries may be bind mounted from this pak, let go of them first
	sh "$PAK_DIR/apply.sh" unmount
	cp -Rf "$STAGE/." "$PAK_DIR/" || return 1
	rm -rf "$STAGE"
	sync
	echo "updated to $(cat "$PAK_DIR/version.txt")"
}

case "$1" in
	check) check ;;
	download) download ;;
	install) install ;;
	*) echo "usage: $0 check | download | install" >&2; exit 2 ;;
esac
