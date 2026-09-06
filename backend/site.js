/**
 * Public site identity — keep in sync with frontend/src/constants/site.js
 * Override via env when needed (production .env).
 */
const SITE_DOMAIN = process.env.SITE_DOMAIN || 'inventoryinonetap.com';
const SITE_URL = process.env.SITE_URL || `https://${SITE_DOMAIN}`;
const SITE_NAME = process.env.SITE_NAME || 'InventoryInOneTap';
const SUPPORT_EMAIL = process.env.SUPPORT_EMAIL || `support@${SITE_DOMAIN}`;
const SITE_IP = process.env.SITE_IP || '13.205.231.60';

/** Always merged into CORS allowlist (FRONTEND_URL adds extra origins, it does not replace these) */
const DEFAULT_FRONTEND_URLS = [
  SITE_URL,
  `https://www.${SITE_DOMAIN}`,
  `http://${SITE_DOMAIN}`,
  `http://www.${SITE_DOMAIN}`,
  `http://${SITE_IP}`,
  `https://${SITE_IP}`,
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:4173',
  'http://127.0.0.1:4173',
].join(',');

module.exports = {
  SITE_DOMAIN,
  SITE_IP,
  SITE_URL,
  SITE_NAME,
  SUPPORT_EMAIL,
  DEFAULT_FRONTEND_URLS,
};
