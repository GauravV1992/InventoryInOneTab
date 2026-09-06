#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/inventoryinonetap"

echo "==> Backend install"
cd "$APP_DIR/backend"
npm install --omit=dev

echo "==> Frontend build"
cd "$APP_DIR/frontend"
npm install
npm run build

echo "==> Restart API"
pm2 restart inventory-api || pm2 start "$APP_DIR/deploy/ecosystem.config.cjs"
pm2 save

echo "==> Reload Nginx"
sudo nginx -t
sudo systemctl reload nginx

echo "Done. Open http://13.205.231.60"
