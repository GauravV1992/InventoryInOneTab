const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const { DEFAULT_FRONTEND_URLS, SITE_DOMAIN } = require('./site');

const DEFAULT_JWT_SECRET = 'InventoryInOneTap_SecretKey_2026';
const USERNAME_RE = /^[a-zA-Z0-9_]{3,50}$/;

function assertSecureConfig() {
  const secret = process.env.JWT_SECRET || DEFAULT_JWT_SECRET;
  if (process.env.NODE_ENV === 'production') {
    if (!process.env.JWT_SECRET || secret === DEFAULT_JWT_SECRET || secret.length < 32) {
      throw new Error('Set a strong JWT_SECRET (32+ chars) in production.');
    }
  } else if (!process.env.JWT_SECRET) {
    console.warn('WARNING: Using default JWT_SECRET. Set JWT_SECRET in backend/.env for production.');
  }
}

function splitUrls(value) {
  return String(value || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function addOrigin(origins, hostnames, value) {
  if (!value) return;
  const cleaned = value.replace(/\/$/, '');
  origins.add(cleaned);
  try {
    hostnames.add(new URL(cleaned).hostname.toLowerCase());
  } catch {
    // Keep non-URL values as exact origin matches only.
  }
}

function expandAllowedOrigins(urlList) {
  const origins = new Set();
  const hostnames = new Set();

  for (const raw of urlList) {
    if (!raw) continue;
    addOrigin(origins, hostnames, raw);

    try {
      const parsed = new URL(raw);
      const hostname = parsed.hostname;
      const portPart = parsed.port ? `:${parsed.port}` : '';
      const host = `${hostname}${portPart}`;
      const isIp = /^\d{1,3}(\.\d{1,3}){3}$/.test(hostname);
      const withProtocol = (protocol, value) => `${protocol}//${value}`;

      addOrigin(origins, hostnames, withProtocol(parsed.protocol, host));
      addOrigin(origins, hostnames, withProtocol(parsed.protocol === 'https:' ? 'http:' : 'https:', host));

      if (!isIp) {
        if (hostname.startsWith('www.')) {
          const bare = hostname.slice(4) + portPart;
          addOrigin(origins, hostnames, withProtocol(parsed.protocol, bare));
          addOrigin(origins, hostnames, withProtocol(parsed.protocol === 'https:' ? 'http:' : 'https:', bare));
        } else {
          addOrigin(origins, hostnames, withProtocol(parsed.protocol, `www.${host}`));
          addOrigin(origins, hostnames, withProtocol(parsed.protocol === 'https:' ? 'http:' : 'https:', `www.${host}`));
        }
      }
    } catch {
      // Keep the raw value only when it is not a valid URL.
    }
  }

  return { origins, hostnames };
}

function isLoopbackHost(hostname) {
  return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1' || hostname === '[::1]';
}

function isOriginAllowed(origin, allowedOrigins, allowedHostnames) {
  if (!origin) return true;
  const normalized = String(origin).replace(/\/$/, '');
  if (allowedOrigins.has(normalized)) return true;

  try {
    const hostname = new URL(normalized).hostname.toLowerCase();
    if (isLoopbackHost(hostname)) return true;
    if (allowedHostnames.has(hostname)) return true;
  } catch {
    return false;
  }
  return false;
}

function getCorsOptions() {
  const configured = [
    ...splitUrls(process.env.FRONTEND_URL),
    ...splitUrls(DEFAULT_FRONTEND_URLS),
  ];
  const { origins, hostnames } = expandAllowedOrigins(configured);

  if (SITE_DOMAIN) {
    hostnames.add(SITE_DOMAIN.toLowerCase());
    hostnames.add(`www.${SITE_DOMAIN.toLowerCase()}`);
  }

  return {
    origin(origin, callback) {
      if (isOriginAllowed(origin, origins, hostnames)) {
        callback(null, true);
        return;
      }
      console.warn(`CORS blocked origin: ${origin}`);
      callback(new Error('Not allowed by CORS'));
    },
    credentials: true,
  };
}

const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts. Please try again later.' },
});

const checkUsernameRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many username checks. Please wait a moment.' },
});

const apiRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests. Please slow down.' },
});

function validateUsername(username) {
  const value = String(username || '').trim();
  if (!USERNAME_RE.test(value)) {
    throw new Error('Username must be 3-50 characters and use letters, numbers, or underscore only.');
  }
  return value;
}

function validatePassword(password, label = 'Password') {
  const value = String(password || '');
  if (value.length < 8) {
    throw new Error(`${label} must be at least 8 characters.`);
  }
  if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) {
    throw new Error(`${label} must include at least one letter and one number.`);
  }
  return value;
}

async function verifyPassword(storedPassword, password) {
  if (storedPassword == null || password == null) return false;
  const stored = String(storedPassword);
  const plain = String(password);
  // Plain-text passwords (no hashing)
  if (!stored.startsWith('$2')) {
    return stored === plain;
  }
  // Legacy bcrypt hashes still accepted for older accounts
  const bcrypt = require('bcryptjs');
  return bcrypt.compare(plain, stored);
}

function hashPassword(password) {
  // Store password as plain text — no hashing
  return Promise.resolve(String(password));
}

function verifyRazorpaySignature(orderId, paymentId, signature, secret) {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');

  const expectedBuf = Buffer.from(expected, 'utf8');
  const signatureBuf = Buffer.from(String(signature || ''), 'utf8');
  if (expectedBuf.length !== signatureBuf.length) {
    throw new Error('Payment verification failed');
  }
  if (!crypto.timingSafeEqual(expectedBuf, signatureBuf)) {
    throw new Error('Payment verification failed');
  }
}

function safeErrorMessage(err, fallback = 'Something went wrong') {
  if (process.env.NODE_ENV === 'production') {
    return fallback;
  }
  return err?.message || fallback;
}

module.exports = {
  assertSecureConfig,
  getCorsOptions,
  authRateLimiter,
  checkUsernameRateLimiter,
  apiRateLimiter,
  validateUsername,
  validatePassword,
  verifyPassword,
  hashPassword,
  verifyRazorpaySignature,
  safeErrorMessage,
  USERNAME_RE,
};
