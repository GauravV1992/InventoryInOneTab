import { SEO_PAGES, SITE_URL } from '../src/seo/seoPages.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, '../public');

const today = new Date().toISOString().slice(0, 10);

/** Public marketing / legal pages always in sitemap */
const STATIC_PAGES = [
  { path: '/', changefreq: 'weekly', priority: '1.0' },
  { path: '/login', changefreq: 'monthly', priority: '0.7' },
  { path: '/register', changefreq: 'monthly', priority: '0.8' },
  { path: '/pricing', changefreq: 'weekly', priority: '0.9' },
  { path: '/terms', changefreq: 'yearly', priority: '0.3' },
  { path: '/privacy', changefreq: 'yearly', priority: '0.3' },
  { path: '/cookies', changefreq: 'yearly', priority: '0.3' },
];

/** Private app routes — exact match ($ = end of URL for Googlebot; avoids blocking SEO pages) */
const DISALLOW_PATHS = [
  '/api/',
  '/materials$',
  '/suppliers$',
  '/locations$',
  '/opening-stock$',
  '/purchase-inward$',
  '/sales$',
  '/stock-report$',
  '/account$',
  '/team$',
];

const PRIMARY_SEO = new Set([
  '/stock-management-software',
  '/stock-management-software-india',
  '/inventory-management-software',
  '/inventory-software-india',
  '/inventory-management-system',
  '/best-stock-management-software',
  '/stock-inventory-software',
]);

function seoPriority(pagePath) {
  if (PRIMARY_SEO.has(pagePath)) return '1.0';
  return '0.85';
}

function escapeXml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function buildSitemap() {
  const urls = [
    ...STATIC_PAGES,
    ...SEO_PAGES.map((p) => ({
      path: p.path,
      changefreq: 'weekly',
      priority: seoPriority(p.path),
    })),
  ];

  // Dedupe by path (static wins order first)
  const seen = new Set();
  const unique = urls.filter((u) => {
    if (seen.has(u.path)) return false;
    seen.add(u.path);
    return true;
  });

  const lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  ];

  for (const u of unique) {
    const loc = escapeXml(`${SITE_URL}${u.path}`);
    lines.push('  <url>');
    lines.push(`    <loc>${loc}</loc>`);
    lines.push(`    <lastmod>${today}</lastmod>`);
    lines.push(`    <changefreq>${u.changefreq}</changefreq>`);
    lines.push(`    <priority>${u.priority}</priority>`);
    lines.push('  </url>');
  }

  lines.push('</urlset>');
  lines.push('');
  return { xml: lines.join('\n'), count: unique.length };
}

function buildRobots() {
  const lines = [
    '# InventoryInOneTap - https://inventoryinonetap.com',
    'User-agent: *',
    'Allow: /',
    '',
    '# Block API and authenticated app areas',
    ...DISALLOW_PATHS.map((p) => `Disallow: ${p}`),
    '',
    `# Public SEO landing pages (${SEO_PAGES.length})`,
    ...SEO_PAGES.map((p) => `Allow: ${p.path}`),
    '',
    'Allow: /login',
    'Allow: /register',
    'Allow: /pricing',
    'Allow: /terms',
    'Allow: /privacy',
    'Allow: /cookies',
    '',
    `Sitemap: ${SITE_URL}/sitemap.xml`,
    `Host: ${SITE_URL.replace(/^https?:\/\//, '')}`,
    '',
  ];
  return lines.join('\n');
}

const { xml, count } = buildSitemap();
fs.writeFileSync(path.join(publicDir, 'sitemap.xml'), xml);
fs.writeFileSync(path.join(publicDir, 'robots.txt'), buildRobots());

console.log(`Wrote public/sitemap.xml (${count} URLs, lastmod ${today})`);
console.log(`Wrote public/robots.txt (${SEO_PAGES.length} SEO Allows, ${DISALLOW_PATHS.length} Disallows)`);
