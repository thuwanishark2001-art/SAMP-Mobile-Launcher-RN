#!/usr/bin/env bash
# Set up an Ubuntu server (e.g. a Vultr VPS) to host the Kingmakers RP
# launcher files: distribution.json, game files and launcher updates.
#
# Run as root on the server:
#   curl -fsSL https://raw.githubusercontent.com/thuwanishark2001-art/SAMP-Mobile-Launcher-RN/main/scripts/setup-vps.sh | bash
#
# Optional settings (put them before "bash", e.g. "| SERVER_PORT=7778 bash"):
#   PUBLIC_IP       address players reach this server on (auto-detected)
#   SERVER_ADDRESS  SA-MP server shown in the launcher (default: PUBLIC_IP:7777)
#
# Safe to run again: it updates the code and regenerates distribution.json.
set -euo pipefail

REPO_URL="https://github.com/thuwanishark2001-art/SAMP-Mobile-Launcher-RN.git"
APP_DIR="/opt/kingmakers-launcher"
WEB_ROOT="/var/www/kingmakers"
DIST_DIR="$WEB_ROOT/mobile"
CONFIG_FILE="/etc/kingmakers-launcher.env"
UPDATE_CMD="/usr/local/bin/kingmakers-update"
IMPORT_CMD="/usr/local/bin/kingmakers-import"

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run as root (or with sudo)." >&2
	exit 1
fi

PUBLIC_IP="${PUBLIC_IP:-$(hostname -I | awk '{print $1}')}"
SERVER_PORT="${SERVER_PORT:-7777}"
SERVER_ADDRESS="${SERVER_ADDRESS:-$PUBLIC_IP:$SERVER_PORT}"

echo "==> Installing nginx, Node.js and git"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx nodejs npm git unzip >/dev/null

echo "==> Fetching launcher code into $APP_DIR"
if [ -d "$APP_DIR/.git" ]; then
	git -C "$APP_DIR" pull -q --ff-only
else
	git clone -q --depth 1 "$REPO_URL" "$APP_DIR"
fi
(cd "$APP_DIR/distribution" && npm install --omit=dev --no-audit --no-fund --silent)

echo "==> Creating $DIST_DIR"
mkdir -p "$DIST_DIR"/{cache,cache_snow,launcher,image}
cp "$APP_DIR/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" "$DIST_DIR/image/server_icon.png"

echo "==> Configuring nginx"
cat >/etc/nginx/sites-available/kingmakers <<EOF
server {
	listen 80 default_server;
	listen [::]:80 default_server;
	server_name _;
	root $WEB_ROOT;

	types {
		application/json json;
		application/vnd.android.package-archive apk;
		image/png png;
	}
	default_type application/octet-stream;
	sendfile on;
	autoindex off;

	location = /mobile/distribution.json {
		add_header Cache-Control "no-cache";
	}
	location /mobile/ {
		try_files \$uri =404;
	}
	location / {
		return 404;
	}
}
EOF
ln -sf /etc/nginx/sites-available/kingmakers /etc/nginx/sites-enabled/kingmakers
rm -f /etc/nginx/sites-enabled/default
nginx -t -q
systemctl enable -q nginx
systemctl reload nginx || systemctl restart nginx

if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
	echo "==> Opening firewall ports 80/tcp (launcher files) and $SERVER_PORT/udp (SA-MP)"
	ufw allow 80/tcp >/dev/null
	ufw allow "$SERVER_PORT/udp" >/dev/null
fi

echo "==> Saving settings to $CONFIG_FILE"
cat >"$CONFIG_FILE" <<EOF
DIST_DIR=$DIST_DIR
CDN_BASE=http://$PUBLIC_IP/mobile
SERVER_ADDRESS=$SERVER_ADDRESS
EOF

cat >"$UPDATE_CMD" <<EOF
#!/usr/bin/env bash
# Regenerate distribution.json after adding or changing files in
# $DIST_DIR/cache, cache_snow or launcher.
set -euo pipefail
set -a; . $CONFIG_FILE; set +a
cd $APP_DIR/distribution
node src/index.js
chmod -R a+rX "\$DIST_DIR"
EOF
chmod +x "$UPDATE_CMD"

cat >"$IMPORT_CMD" <<'EOF'
#!/usr/bin/env bash
# Replace the game files players download with the contents of a zip.
#   kingmakers-import /root/game.zip          # main game files -> cache/
#   kingmakers-import /root/winter.zip snow   # winter-map files -> cache_snow/
#   kingmakers-import /root/patch --merge     # add/overwrite files, keep the rest
# The zip should hold what goes inside the phone's
# Android/data/<package>/files/ folder (texdb/, data/, audio/, ...).
# Extra wrapper folders inside the zip are fine; they are detected.
set -euo pipefail
set -a; . /etc/kingmakers-launcher.env; set +a

SRC=""
TARGET="$DIST_DIR/cache"
MERGE=0
for arg in "$@"; do
	case "$arg" in
	snow) TARGET="$DIST_DIR/cache_snow" ;;
	--merge) MERGE=1 ;;
	*) SRC="$arg" ;;
	esac
done

if [ -z "$SRC" ]; then
	echo "Usage: kingmakers-import <file.zip or folder> [snow] [--merge]" >&2
	exit 1
fi
if [ ! -e "$SRC" ]; then
	echo "Not found: $SRC" >&2
	echo "Upload the game files zip first. To see what is in /root, run: ls -lh /root" >&2
	exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [ -d "$SRC" ]; then
	ROOT="$SRC"
else
	echo "==> Unzipping $SRC"
	unzip -q "$SRC" -d "$WORK"
	ROOT="$WORK"
fi

# Find the folder that holds texdb/ (the game's files/ folder); otherwise
# step through single wrapper folders.
TEXDB=$(find "$ROOT" -maxdepth 6 -type d -name texdb -print -quit)
if [ -n "$TEXDB" ]; then
	ROOT=$(dirname "$TEXDB")
else
	while [ "$(find "$ROOT" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 ] &&
		[ -d "$(find "$ROOT" -mindepth 1 -maxdepth 1)" ]; do
		ROOT=$(find "$ROOT" -mindepth 1 -maxdepth 1)
	done
	echo "Warning: no texdb/ folder found; using $ROOT as-is." >&2
fi

if [ "$MERGE" = 1 ]; then
	echo "==> Merging game files from $ROOT into $TARGET (existing files kept, same names overwritten)"
else
	echo "==> Copying game files from $ROOT into $TARGET"
	rm -rf "$TARGET"
fi
mkdir -p "$TARGET"
EXCLUDES=()
if [ "$MERGE" = 1 ] && [ -d "$ROOT/texdb" ]; then
	# A texture set's .toc/.tmb index its .dat. If the new files have no .dat
	# for a set the server already has complete, keep the server's set as is.
	for set_dir in "$ROOT"/texdb/*/; do
		set_name=$(basename "$set_dir")
		if ! ls "$set_dir"*.dat >/dev/null 2>&1 &&
			ls "$TARGET/texdb/$set_name/"*.dat >/dev/null 2>&1; then
			echo "    keeping existing texdb/$set_name (new files have no .dat for it)"
			EXCLUDES+=(--exclude="./texdb/$set_name")
		fi
	done
fi
tar -C "$ROOT" -cf - "${EXCLUDES[@]}" . | tar -C "$TARGET" -xf -

echo "==> $(find "$TARGET" -type f | wc -l) files, $(du -sh "$TARGET" | cut -f1) in $TARGET"
kingmakers-update
EOF
chmod +x "$IMPORT_CMD"

echo "==> Generating distribution.json"
"$UPDATE_CMD"

echo "==> Checking the launcher can fetch it"
curl -fsS -o /dev/null "http://127.0.0.1/mobile/distribution.json"

cat <<EOF

Done. The launcher reads:  http://$PUBLIC_IP/mobile/distribution.json
SA-MP server it shows:     $SERVER_ADDRESS

Next: upload a zip of the GTA SA game files (the contents of the phone's
Android/data/<package>/files folder) to this server, e.g. /root/game.zip,
then run:
  kingmakers-import /root/game.zip
EOF
