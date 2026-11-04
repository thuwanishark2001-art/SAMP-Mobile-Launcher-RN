#!/usr/bin/env bash
# Upload the GTA SA game files from this Android phone to the Kingmakers RP
# server and import them, using Termux. Run in Termux:
#
#   curl -fsSL https://raw.githubusercontent.com/thuwanishark2001-art/SAMP-Mobile-Launcher-RN/main/scripts/termux-upload.sh | bash
#
# It finds the game's files folder (the one holding texdb/) in shared storage,
# streams it to the server over SSH (you type the server's root password once)
# and runs kingmakers-import there. To pick the source yourself, pass a folder
# or a .zip:
#
#   curl -fsSL .../termux-upload.sh | bash -s -- /sdcard/Download/game.zip
#
# Add --merge to add the files to what the server has instead of replacing it.
#
# Settings: SERVER (default root@65.20.88.67), STORAGE (default /storage/emulated/0)
set -euo pipefail

SERVER="${SERVER:-root@65.20.88.67}"
STORAGE="${STORAGE:-/storage/emulated/0}"
SRC=""
IMPORT_OPTS=""
for arg in "$@"; do
	case "$arg" in
	--merge) IMPORT_OPTS="--merge" ;; # add to the server's files instead of replacing them
	*) SRC="$arg" ;;
	esac
done
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30)

ask() { # prompt from the keyboard even when this script is piped into bash
	local reply
	read -r -p "$1" reply </dev/tty
	printf '%s' "$reply"
}

echo "==> Installing ssh"
command -v ssh >/dev/null || pkg install -y openssh >/dev/null
# pv only draws the progress bar. Some Termux installs ship a pv that cannot
# run ("unexpected e_type"), so fall back to plain cat when it fails.
command -v pv >/dev/null || pkg install -y pv >/dev/null 2>&1 || true
if pv --version >/dev/null 2>&1; then
	HAVE_PV=1
else
	HAVE_PV=0
	echo "    (no progress bar: pv does not run here; the upload still works)"
fi
progress() { # progress <bytes>: copy stdin to stdout, with a bar if possible
	if [ "$HAVE_PV" = 1 ]; then pv -s "$1"; else cat; fi
}

if [ ! -r "$STORAGE" ] || [ -z "$(ls -A "$STORAGE" 2>/dev/null)" ]; then
	echo "==> Termux needs storage access. Tap 'Allow', then run this command again."
	termux-setup-storage
	exit 1
fi

if [ -z "$SRC" ]; then
	echo "==> Looking for GTA SA game files (a folder containing texdb/) in $STORAGE"
	mapfile -t FOUND < <(find "$STORAGE" -maxdepth 7 -type d -name texdb 2>/dev/null |
		xargs -r -n1 dirname | sort -u)
	if [ "${#FOUND[@]}" -eq 0 ]; then
		cat >&2 <<EOF
No game files found. Android hides Android/data from Termux on Android 11+.
Copy the game's "files" folder (the one with texdb/, data/, audio/ ...) into
Download with a file manager that can open Android/data (e.g. ZArchiver),
then run this again, or pass its path:
  curl -fsSL .../termux-upload.sh | bash -s -- /sdcard/Download/files
EOF
		exit 1
	elif [ "${#FOUND[@]}" -eq 1 ]; then
		SRC="${FOUND[0]}"
	else
		echo "Found several:"
		for i in "${!FOUND[@]}"; do echo "  $((i + 1))) ${FOUND[$i]}"; done
		n=$(ask "Which one? [1-${#FOUND[@]}] ")
		SRC="${FOUND[$((n - 1))]}"
	fi
fi

if [ ! -e "$SRC" ]; then
	echo "Not found: $SRC" >&2
	exit 1
fi

SIZE=$(du -sb "$SRC" | cut -f1)
echo "==> Source: $SRC ($(du -sh "$SRC" | cut -f1))"
ACTION="replace the game files there"
[ -n "$IMPORT_OPTS" ] && ACTION="add it to the game files there"
[ "$(ask "Upload this to $SERVER and $ACTION? [y/N] ")" = "y" ] || exit 1
echo "==> Uploading. Enter the server's root password (from the Vultr page) when asked."
[ "$HAVE_PV" = 1 ] || echo "    This can take 10-30 minutes for 1-2 GB and shows nothing until it ends."

if [ -d "$SRC" ]; then
	tar -C "$SRC" -cf - . | progress "$SIZE" |
		ssh "${SSH_OPTS[@]}" "$SERVER" 'set -e
			rm -rf /root/kingmakers-upload && mkdir -p /root/kingmakers-upload
			tar -xf - -C /root/kingmakers-upload
			kingmakers-import /root/kingmakers-upload '"$IMPORT_OPTS"'
			rm -rf /root/kingmakers-upload'
else
	progress "$SIZE" <"$SRC" |
		ssh "${SSH_OPTS[@]}" "$SERVER" 'set -e
			cat > /root/kingmakers-upload.zip
			kingmakers-import /root/kingmakers-upload.zip '"$IMPORT_OPTS"'
			rm -f /root/kingmakers-upload.zip'
fi

echo
echo "Done. Open the Kingmakers RP app; it will download the game files."
