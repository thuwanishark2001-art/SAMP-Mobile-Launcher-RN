#!/usr/bin/env bash
# Download the launcher's game cache (the README's Google Drive "Game cache"
# folders) file by file, using the list in distribution/manifests/.
# Works on the server and in Termux:
#
#   curl -fsSL https://raw.githubusercontent.com/thuwanishark2001-art/SAMP-Mobile-Launcher-RN/main/scripts/fetch-game-cache.sh | bash -s -- /root/km-cache
#   ... | bash -s -- /root/km-cache-snow snow        # winter-map files
#
# Files already downloaded are skipped, so it is safe to run again after an
# error. Exits non-zero if any file failed.
set -uo pipefail

DEST="${1:?Usage: fetch-game-cache.sh <destination folder> [snow]}"
NAME="cache"
[ "${2:-}" = "snow" ] && NAME="cache_snow"
MANIFEST_URL="${MANIFEST_URL:-https://raw.githubusercontent.com/thuwanishark2001-art/SAMP-Mobile-Launcher-RN/main/distribution/manifests/$NAME.tsv}"

mkdir -p "$DEST"
MANIFEST=$(mktemp)
trap 'rm -f "$MANIFEST" "$MANIFEST.part"' EXIT
if [ -f "$MANIFEST_URL" ]; then
	cp "$MANIFEST_URL" "$MANIFEST"
else
	curl -fsSL "$MANIFEST_URL" -o "$MANIFEST"
fi

TOTAL=$(grep -cv '^#' "$MANIFEST")
n=0
failed=0
while IFS=$'\t' read -r path id; do
	case "$path" in '#'* | '') continue ;; esac
	n=$((n + 1))
	out="$DEST/$path"
	if [ -s "$out" ]; then
		continue
	fi
	mkdir -p "$(dirname "$out")"
	ok=0
	for attempt in 1 2 3; do
		if curl -fsSL -A "Mozilla/5.0" --retry 2 -o "$out.part" \
			"https://drive.usercontent.google.com/download?id=$id&export=download&confirm=t" &&
			! head -c 512 "$out.part" | grep -qi '<!doctype html\|<html'; then
			mv "$out.part" "$out"
			ok=1
			break
		fi
		sleep $((attempt * 5))
	done
	rm -f "$out.part"
	if [ "$ok" = 1 ]; then
		echo "[$n/$TOTAL] $path"
	else
		echo "[$n/$TOTAL] FAILED $path" >&2
		failed=$((failed + 1))
	fi
done <"$MANIFEST"

echo
if [ "$failed" -gt 0 ]; then
	echo "$failed file(s) failed. If Google blocks this machine, run it from the phone (Termux) instead." >&2
	exit 1
fi
echo "All $TOTAL files are in $DEST ($(du -sh "$DEST" | cut -f1))."
