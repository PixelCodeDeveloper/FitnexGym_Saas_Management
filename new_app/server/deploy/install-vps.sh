#!/usr/bin/env bash
# Run on a new Ubuntu/Debian VPS as root:
#   sudo bash deploy/install-vps.sh api.example.com admin@example.com
set -euo pipefail

DOMAIN="${1:-}"
EMAIL="${2:-}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR=/opt/gym-owner

if [[ $EUID -ne 0 ]]; then echo 'Run as root with sudo.' >&2; exit 1; fi
if [[ ! "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || [[ "$DOMAIN" != *.* ]]; then echo 'Pass a valid API domain.' >&2; exit 1; fi
if [[ ! "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then echo 'Pass a valid Lets Encrypt email.' >&2; exit 1; fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl rsync nginx certbot python3-certbot-nginx ufw docker.io
if ! apt-get install -y docker-compose-plugin; then
  apt-get install -y docker-compose
fi
systemctl enable --now docker nginx

compose() {
  if docker compose version >/dev/null 2>&1; then docker compose "$@"; else docker-compose "$@"; fi
}

# Keep SSH reachable before activating the firewall. Restrict SSH to your own IP later if possible.
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

install -d -m 0750 "$APP_DIR"
rsync -a --delete --exclude '.env' --exclude 'node_modules' "$SOURCE_DIR/" "$APP_DIR/"
chown -R root:root "$APP_DIR"
chmod -R go-w "$APP_DIR"
chmod 750 "$APP_DIR/sql/00-create-api-role.sh" "$APP_DIR/deploy/install-vps.sh"

POSTGRES_ADMIN_PASSWORD="$(openssl rand -hex 32)"
POSTGRES_APP_PASSWORD="$(openssl rand -hex 32)"
JWT_SECRET="$(openssl rand -hex 64)"
umask 077
cat > "$APP_DIR/.env" <<EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://gym_api:${POSTGRES_APP_PASSWORD}@db:5432/gym_owner
DATABASE_SSL=false
JWT_SECRET=${JWT_SECRET}
JWT_ISSUER=gym-owner-api
JWT_AUDIENCE=gym-owner-app
ALLOWED_ORIGINS=https://${DOMAIN}
POSTGRES_ADMIN_PASSWORD=${POSTGRES_ADMIN_PASSWORD}
POSTGRES_APP_PASSWORD=${POSTGRES_APP_PASSWORD}
# Set this only when Google sign-in is configured; otherwise leave blank.
GOOGLE_CLIENT_ID=
EOF
chmod 600 "$APP_DIR/.env"

sed "s/__DOMAIN__/${DOMAIN}/g" "$APP_DIR/deploy/nginx-api.conf.template" > "/etc/nginx/sites-available/gym-owner-api"
ln -sfn /etc/nginx/sites-available/gym-owner-api /etc/nginx/sites-enabled/gym-owner-api
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

cd "$APP_DIR"
compose up -d --build
for _ in $(seq 1 30); do
  if curl --fail --silent http://127.0.0.1:3000/health >/dev/null; then break; fi
  sleep 2
done
curl --fail http://127.0.0.1:3000/health

certbot --nginx --non-interactive --agree-tos --redirect -m "$EMAIL" -d "$DOMAIN"
echo "Deployment complete: https://${DOMAIN}/health"
echo "Important: configure encrypted off-VPS PostgreSQL backups before accepting real customer data."
