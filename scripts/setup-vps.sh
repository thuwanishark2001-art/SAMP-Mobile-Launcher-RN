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
apt-get install -y -qq nginx nodejs npm git >/dev/null

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

echo "==> Generating distribution.json"
"$UPDATE_CMD"

echo "==> Checking the launcher can fetch it"
curl -fsS -o /dev/null "http://127.0.0.1/mobile/distribution.json"

cat <<EOF

Done. The launcher reads:  http://$PUBLIC_IP/mobile/distribution.json
SA-MP server it shows:     $SERVER_ADDRESS

Next:
  1. Put the GTA SA game files in $DIST_DIR/cache
     (winter-map versions, if any, in $DIST_DIR/cache_snow)
  2. Run: kingmakers-update
EOF
