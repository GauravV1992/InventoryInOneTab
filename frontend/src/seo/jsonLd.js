import { SITE_NAME, SITE_URL, SUPPORT_EMAIL } from '../constants/site';

/** Build SoftwareApplication + optional FAQ + Breadcrumb JSON-LD graphs */
export function buildPageJsonLd({ description, path, faqs, h1 }) {
  const url = `${SITE_URL}${path || '/'}`;
  const graph = [
    {
      '@type': 'Organization',
      '@id': `${SITE_URL}/#organization`,
      name: SITE_NAME,
      url: SITE_URL,
      email: SUPPORT_EMAIL,
      logo: `${SITE_URL}/favicon.svg`,
      areaServed: 'IN',
      sameAs: ['https://quotationinseconds.com'],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}/#website`,
      name: SITE_NAME,
      url: SITE_URL,
      publisher: { '@id': `${SITE_URL}/#organization` },
      inLanguage: 'en-IN',
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${url}#app`,
      name: SITE_NAME,
      applicationCategory: 'BusinessApplication',
      operatingSystem: 'Web',
      url,
      description: description || `${SITE_NAME} stock and inventory software for Indian businesses.`,
      offers: {
        '@type': 'Offer',
        priceCurrency: 'INR',
        price: '499',
        availability: 'https://schema.org/InStock',
      },
      publisher: { '@id': `${SITE_URL}/#organization` },
    },
    {
      '@type': 'WebPage',
      '@id': `${url}#webpage`,
      url,
      name: h1 || SITE_NAME,
      description,
      isPartOf: { '@id': `${SITE_URL}/#website` },
      about: { '@id': `${url}#app` },
      inLanguage: 'en-IN',
    },
  ];

  if (path && path !== '/') {
    graph.push({
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_URL },
        { '@type': 'ListItem', position: 2, name: h1 || path.slice(1), item: url },
      ],
    });
  }

  if (Array.isArray(faqs) && faqs.length > 0) {
    graph.push({
      '@type': 'FAQPage',
      mainEntity: faqs.map((f) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a },
      })),
    });
  }

  return {
    '@context': 'https://schema.org',
    '@graph': graph,
  };
}
