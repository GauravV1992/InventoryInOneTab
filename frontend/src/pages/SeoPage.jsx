import { Link } from 'react-router-dom';
import { Check, ArrowRight, ExternalLink } from 'lucide-react';
import { useEffect } from 'react';
import PublicFooter from '../components/PublicFooter';
import useSeo from '../hooks/useSeo';
import { SEO_PAGES, SISTER_PRODUCTS } from '../seo/seoPages';
import { buildPageJsonLd } from '../seo/jsonLd';

export default function SeoPage({ page }) {
  useSeo({
    title: page.title,
    description: page.description,
    keywords: page.keywords,
    path: page.path,
  });

  useEffect(() => {
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.textContent = JSON.stringify(
      buildPageJsonLd({
        description: page.description,
        path: page.path,
        faqs: page.faqs,
        h1: page.h1,
      }),
    );
    document.head.appendChild(script);
    return () => { script.remove(); };
  }, [page]);

  const idx = SEO_PAGES.findIndex((p) => p.path === page.path);
  const related = [...SEO_PAGES.slice(idx + 1), ...SEO_PAGES.slice(0, Math.max(idx, 0))]
    .filter((p) => p.path !== page.path)
    .slice(0, 12);
  const sister = SISTER_PRODUCTS[0];

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="bg-white border-b border-slate-200 px-4 lg:px-8 py-4 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto flex items-center justify-between gap-4">
          <Link to="/" className="flex items-center gap-2 shrink-0">
            <div className="w-9 h-9 rounded-xl bg-brand-700 text-white flex items-center justify-center text-sm font-bold" aria-hidden="true">I1</div>
            <span className="font-bold text-slate-800 hidden sm:inline">InventoryInOneTap</span>
          </Link>
          <div className="flex items-center gap-2 sm:gap-3 text-sm shrink-0">
            <Link to="/pricing" className="text-slate-600 hover:text-brand-700 hidden sm:inline">Pricing</Link>
            <Link to="/login" className="text-slate-600 hover:text-brand-700">Login</Link>
            <Link to="/register" className="px-3 sm:px-4 py-2 rounded-xl bg-brand-700 text-white font-medium hover:bg-brand-800 whitespace-nowrap text-xs sm:text-sm">Start free trial</Link>
          </div>
        </div>
      </header>

      <main className="flex-1 px-4 lg:px-8 py-10">
        <article className="max-w-5xl mx-auto">
          <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-6 lg:p-10 mb-8">
            <p className="text-sm font-medium text-brand-800 mb-3">InventoryInOneTap — Inventory &amp; stock software India</p>
            <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900 mb-4">{page.h1}</h1>
            <p className="text-lg text-slate-600 leading-relaxed mb-6">{page.intro}</p>
            {page.whoFor && (
              <p className="text-sm text-slate-500 mb-8 border-l-2 border-brand-300 pl-3">
                <span className="font-semibold text-slate-700">Who it&apos;s for: </span>
                {page.whoFor}
              </p>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 mb-8">
              {page.features.map((f) => (
                <div key={f} className="flex items-start gap-2 text-sm text-slate-700">
                  <Check size={16} className="text-brand-700 mt-0.5 shrink-0" />
                  {f}
                </div>
              ))}
            </div>

            <div className="flex flex-wrap gap-3">
              <Link to="/register" className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-brand-700 text-white font-medium hover:bg-brand-800">
                Start 3-day free trial <ArrowRight size={16} />
              </Link>
              <Link to="/pricing" className="inline-flex items-center gap-2 px-5 py-3 rounded-xl border border-slate-200 text-slate-700 font-medium hover:bg-slate-50">
                View pricing
              </Link>
              <Link to="/inventory-software-india" className="inline-flex items-center gap-2 px-5 py-3 rounded-xl border border-slate-200 text-slate-700 font-medium hover:bg-slate-50">
                Inventory software India
              </Link>
            </div>
          </div>

          {Array.isArray(page.benefits) && page.benefits.length > 0 && (
            <section className="bg-white rounded-2xl border border-slate-200 p-6 lg:p-8 mb-8">
              <h2 className="text-xl font-bold text-slate-800 mb-4">Key benefits</h2>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-sm text-slate-600">
                {page.benefits.map((b) => (
                  <div key={b.title}>
                    <h3 className="font-semibold text-slate-800 mb-2">{b.title}</h3>
                    <p>{b.text}</p>
                  </div>
                ))}
              </div>
            </section>
          )}

          <section className="bg-white rounded-2xl border border-slate-200 p-6 lg:p-8 mb-8">
            <h2 className="text-xl font-bold text-slate-800 mb-4">Why choose InventoryInOneTap?</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 text-sm text-slate-600">
              <div>
                <h3 className="font-semibold text-slate-800 mb-2">Built for India</h3>
                <p>GST fields, HSN on materials, rupee pricing, and invoice PDFs formatted for Indian businesses.</p>
              </div>
              <div>
                <h3 className="font-semibold text-slate-800 mb-2">Simple &amp; fast</h3>
                <p>No heavy ERP setup. Register online, add materials, record purchase and sales in minutes.</p>
              </div>
              <div>
                <h3 className="font-semibold text-slate-800 mb-2">Secure cloud</h3>
                <p>Company-wise data, admin roles, Razorpay billing, and payment invoices in your account.</p>
              </div>
            </div>
          </section>

          {Array.isArray(page.faqs) && page.faqs.length > 0 && (
            <section className="bg-white rounded-2xl border border-slate-200 p-6 lg:p-8 mb-8">
              <h2 className="text-xl font-bold text-slate-800 mb-4">Frequently asked questions</h2>
              <div className="space-y-5">
                {page.faqs.map((f) => (
                  <div key={f.q}>
                    <h3 className="font-semibold text-slate-800 mb-1">{f.q}</h3>
                    <p className="text-sm text-slate-600 leading-relaxed">{f.a}</p>
                  </div>
                ))}
              </div>
            </section>
          )}

          {sister && (
            <section className="bg-white rounded-2xl border border-slate-200 p-6 lg:p-8 mb-8">
              <h2 className="text-xl font-bold text-slate-800 mb-2">Our other popular product</h2>
              <p className="text-sm text-slate-600 mb-4">
                Need quotations as fast as stock? Try{' '}
                <a
                  href={sister.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="font-semibold text-brand-700 hover:text-brand-800"
                >
                  {sister.name}
                </a>
                {' '}— {sister.tagline}
              </p>
              <a
                href={sister.url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-slate-900 text-white text-sm font-medium hover:bg-slate-800"
              >
                Visit quotationinseconds.com <ExternalLink size={14} />
              </a>
            </section>
          )}

          <section className="mb-8">
            <h2 className="text-lg font-semibold text-slate-800 mb-4">Explore more inventory &amp; stock solutions</h2>
            <div className="flex flex-wrap gap-2">
              {related.map((p) => (
                <Link
                  key={p.path}
                  to={p.path}
                  className="px-3 py-1.5 rounded-full text-sm bg-white border border-slate-200 text-slate-600 hover:border-brand-300 hover:text-brand-800 transition"
                >
                  {p.h1}
                </Link>
              ))}
            </div>
          </section>
        </article>
      </main>

      <PublicFooter showSeoLinks />
    </div>
  );
}
