#!/usr/bin/env bash
# Install HTTPS (Let's Encrypt) for inventoryinonetap.com on Amazon Linux / nginx
# Run on EC2 as ec2-user:
#   cd /opt/inventoryinonetap && bash deploy/install-https.sh
set -euo pipefail

DOMAIN="inventoryinonetap.com"
WWW="www.inventoryinonetap.com"
EMAIL="${CERTBOT_EMAIL:-support@inventoryinonetap.com}"
NGINX_SRC="/opt/inventoryinonetap/deploy/nginx-inventoryinonetap.conf"
NGINX_DST="/etc/nginx/conf.d/inventoryinonetap.conf"
ENV_FILE="/opt/inventoryinonetap/backend/.env"

echo "==> Checking DNS..."
getent hosts "$DOMAIN" || true
getent hosts "$WWW" || true

echo "==> Ensuring nginx site config is installed..."
if [[ -f "$NGINX_SRC" ]]; then
  sudo cp "$NGINX_SRC" "$NGINX_DST"
fi
sudo nginx -t
sudo systemctl reload nginx

echo "==> Installing certbot (Amazon Linux)..."
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y certbot python3-certbot-nginx
elif command -v yum >/dev/null 2>&1; then
  sudo yum install -y certbot python3-certbot-nginx
else
  echo "Install certbot manually for your OS, then re-run."
  exit 1
fi

echo "==> Opening HTTPS in firewalld (if present)..."
if command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-service=https || true
  sudo firewall-cmd --permanent --add-service=http || true
  sudo firewall-cmd --reload || true
fi

echo "==> Requesting certificate for $DOMAIN and $WWW..."
sudo certbot --nginx \
  -d "$DOMAIN" \
  -d "$WWW" \
  --non-interactive \
  --agree-tos \
  -m "$EMAIL" \
  --redirect

echo "==> Updating backend .env for HTTPS CORS..."
if [[ -f "$ENV_FILE" ]]; then
  sudo -u ec2-user bash -c "
    set -e
    touch '$ENV_FILE'
    grep -q '^SITE_DOMAIN=' '$ENV_FILE' && sed -i 's|^SITE_DOMAIN=.*|SITE_DOMAIN=$DOMAIN|' '$ENV_FILE' || echo 'SITE_DOMAIN=$DOMAIN' >> '$ENV_FILE'
    grep -q '^SITE_URL=' '$ENV_FILE' && sed -i 's|^SITE_URL=.*|SITE_URL=https://$DOMAIN|' '$ENV_FILE' || echo 'SITE_URL=https://$DOMAIN' >> '$ENV_FILE'
    grep -q '^SUPPORT_EMAIL=' '$ENV_FILE' && sed -i 's|^SUPPORT_EMAIL=.*|SUPPORT_EMAIL=support@$DOMAIN|' '$ENV_FILE' || echo 'SUPPORT_EMAIL=support@$DOMAIN' >> '$ENV_FILE'
    if grep -q '^FRONTEND_URL=' '$ENV_FILE'; then
      sed -i 's|^FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN,https://$WWW,http://$DOMAIN,http://$WWW,http://13.205.231.60,https://13.205.231.60,http://localhost:5173,http://127.0.0.1:5173|' '$ENV_FILE'
    else
      echo 'FRONTEND_URL=https://$DOMAIN,https://$WWW,http://$DOMAIN,http://$WWW,http://13.205.231.60,https://13.205.231.60,http://localhost:5173,http://127.0.0.1:5173' >> '$ENV_FILE'
    fi
  "
  if command -v pm2 >/dev/null 2>&1; then
    pm2 restart inventory-api || pm2 restart all || true
  fi
else
  echo "WARN: $ENV_FILE not found — set FRONTEND_URL manually, then: pm2 restart inventory-api"
fi

echo ""
echo "Done. Test:"
echo "  https://$DOMAIN"
echo "  https://$WWW"
echo "Certbot renews automatically via systemd timer."
