import { useEffect } from 'react';
import { SITE_NAME, SITE_URL } from '../seo/seoPages';

const DEFAULT_KEYWORDS =
  'inventory software India, stock management software, inventory management software India, GST inventory software, warehouse stock software, InventoryInOneTap';

function upsertMeta(attr, key, content) {
  if (!content) return;
  let el = document.querySelector(`meta[${attr}="${key}"]`);
  if (!el) {
    el = document.createElement('meta');
    el.setAttribute(attr, key);
    document.head.appendChild(el);
  }
  el.setAttribute('content', content);
}

function upsertCanonical(href) {
  if (!href) return;
  let el = document.querySelector('link[rel="canonical"]');
  if (!el) {
    el = document.createElement('link');
    el.setAttribute('rel', 'canonical');
    document.head.appendChild(el);
  }
  el.setAttribute('href', href);
}

export default function useSeo({ title, description, keywords, path, noindex = false }) {
  useEffect(() => {
    const pageTitle = title || `${SITE_NAME} - Stock Management Software India`;
    const kw = keywords || DEFAULT_KEYWORDS;
    const absUrl = path ? `${SITE_URL}${path === '/' ? '/' : path}` : SITE_URL;
    document.title = pageTitle;

    upsertMeta('name', 'description', description);
    upsertMeta('name', 'keywords', kw);
    upsertMeta('name', 'robots', noindex ? 'noindex, nofollow' : 'index, follow, max-snippet:-1, max-image-preview:large');
    upsertMeta('name', 'geo.region', 'IN');
    upsertMeta('name', 'language', 'English');
    upsertMeta('property', 'og:title', pageTitle);
    upsertMeta('property', 'og:description', description);
    upsertMeta('property', 'og:type', 'website');
    upsertMeta('property', 'og:site_name', SITE_NAME);
    upsertMeta('property', 'og:locale', 'en_IN');
    upsertMeta('property', 'og:image', `${SITE_URL}/favicon.svg`);
    upsertMeta('name', 'twitter:card', 'summary');
    upsertMeta('name', 'twitter:title', pageTitle);
    upsertMeta('name', 'twitter:description', description);
    upsertMeta('name', 'twitter:image', `${SITE_URL}/favicon.svg`);

    if (path) {
      upsertCanonical(absUrl);
      upsertMeta('property', 'og:url', absUrl);
    }
  }, [title, description, keywords, path, noindex]);
}
