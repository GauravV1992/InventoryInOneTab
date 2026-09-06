import { Link } from 'react-router-dom';
import { ArrowRight, Check, Package, Warehouse, FileText, BarChart3 } from 'lucide-react';
import { useEffect } from 'react';
import PublicFooter from '../components/PublicFooter';
import WhatsAppSupport from '../components/WhatsAppSupport';
import useSeo from '../hooks/useSeo';
import { SITE_NAME, SISTER_PRODUCTS } from '../constants/site';
import { SEO_PAGES } from '../seo/seoPages';
import { buildPageJsonLd } from '../seo/jsonLd';

const FEATURES = [
  { icon: Package, title: 'Material master', text: 'HSN, purchase rate, sales rate, unit and color in one catalog.' },
  { icon: Warehouse, title: 'Multi-warehouse stock', text: 'Opening stock, purchase inward and sales by location.' },
  { icon: FileText, title: 'GST invoice PDF', text: 'Branded tax invoices with logo, terms and customer billing.' },
  { icon: BarChart3, title: 'Live stock reports', text: 'Filter by material or warehouse and avoid stockouts.' },
];

const TOP_SOLUTIONS = [
  '/stock-management-software',
  '/inventory-management-software',
  '/inventory-software-india',
  '/inventory-management-system',
  '/gst-inventory-billing-software',
  '/warehouse-stock-management-system',
  '/best-stock-management-software',
  '/stock-inventory-software',
];

const LANDING_FAQS = [
  {
    q: 'What is InventoryInOneTap?',
    a: 'InventoryInOneTap is cloud inventory and stock management software for Indian businesses — materials, warehouses, purchase, sales and GST invoice PDFs.',
  },
  {
    q: 'Who should use this inventory software India?',
    a: 'Retail shops, wholesalers, distributors and SMEs who need affordable stock control without a heavy ERP.',
  },
  {
    q: 'How much does stock management software cost?',
    a: 'Basic starts at ₹499/month and Standard at ₹999/month. Custom plans are available on WhatsApp. 3-day free trial included.',
  },
];

export default function Landing() {
  useSeo({
    title: `${SITE_NAME} - Inventory Software India | Stock Management Software`,
    description:
      'Inventory software India & stock management software for shops, traders and distributors. Materials, warehouses, purchase, sales, GST invoice PDF. 3-day free trial from ₹499/mo.',
    keywords:
      'inventory software India, stock management software, inventory management software India, GST inventory software, warehouse stock software, best stock management software, InventoryInOneTap',
    path: '/',
  });

  const sister = SISTER_PRODUCTS[0];
  const solutionPages = TOP_SOLUTIONS.map((path) => SEO_PAGES.find((p) => p.path === path)).filter(Boolean);

  useEffect(() => {
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.textContent = JSON.stringify(
      buildPageJsonLd({
        description: 'Cloud inventory and stock management software for Indian businesses.',
        path: '/',
        faqs: LANDING_FAQS,
        h1: 'Stock management software for Indian businesses',
      }),
    );
    document.head.appendChild(script);
    return () => { script.remove(); };
  }, []);

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <header className="bg-white border-b border-slate-200 px-4 lg:px-8 py-4 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto flex items-center justify-between gap-4">
          <Link to="/" className="flex items-center gap-2 shrink-0">
            <div className="w-9 h-9 rounded-xl bg-brand-700 text-white flex items-center justify-center text-sm font-bold" aria-hidden="true">
              I1
            </div>
            <span className="font-bold text-slate-900 truncate max-w-[40vw] sm:max-w-none">{SITE_NAME}</span>
          </Link>
          <div className="flex items-center gap-2 sm:gap-3 text-sm min-w-0">
            <Link to="/pricing" className="text-slate-600 hover:text-brand-700 hidden sm:inline">Pricing</Link>
            <Link to="/inventory-software-india" className="text-slate-600 hover:text-brand-700 hidden md:inline">Solutions</Link>
            <Link to="/login" className="text-slate-700 hover:text-brand-700 font-medium underline underline-offset-2 shrink-0">Login</Link>
            <Link to="/register" className="px-3 sm:px-4 py-2 rounded-xl bg-brand-700 text-white font-medium hover:bg-brand-800 whitespace-nowrap text-xs sm:text-sm">
              Start free trial
            </Link>
          </div>
        </div>
      </header>

      <main className="flex-1">
        <section className="relative overflow-hidden border-b border-slate-200 bg-gradient-to-br from-brand-50 via-orange-50 to-slate-100">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,rgba(234,88,12,0.12),transparent_55%)] pointer-events-none" />
          <div className="relative max-w-5xl mx-auto px-4 lg:px-8 py-16 lg:py-24">
            <p className="text-sm font-semibold text-brand-800 mb-3 tracking-wide">{SITE_NAME}</p>
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold text-slate-900 max-w-3xl leading-tight mb-4">
              Inventory software India — stock management in one tap
            </h1>
            <p className="text-lg text-slate-700 max-w-2xl mb-8 leading-relaxed">
              Cloud stock management software for Indian businesses. Track materials, warehouses, purchase and sales. Generate GST invoice PDFs with your logo — no heavy ERP.
            </p>
            <div className="flex flex-col sm:flex-row flex-wrap gap-3">
              <Link
                to="/register"
                className="inline-flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-brand-700 text-white font-medium hover:bg-brand-800"
              >
                Start 3-day free trial <ArrowRight size={16} />
              </Link>
              <Link
                to="/pricing"
                className="inline-flex items-center justify-center gap-2 px-5 py-3 rounded-xl border border-slate-300 bg-white text-slate-800 font-medium hover:bg-slate-50"
              >
                View pricing
              </Link>
            </div>
            <ul className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-700">
              {['Plans from ₹499/mo', 'Multi-warehouse stock', 'GST invoice PDF', 'WhatsApp support'].map((t) => (
                <li key={t} className="flex items-center gap-2">
                  <Check size={14} className="text-brand-700 shrink-0" />
                  {t}
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-4 lg:px-8 py-14">
          <h2 className="text-2xl font-bold text-slate-900 mb-3">Everything you need for daily stock</h2>
          <p className="text-slate-600 mb-6 max-w-2xl">
            {SITE_NAME} is inventory management software built for shops and traders — material master, godown stock, purchase inward, sales outward and live reports.
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
            {FEATURES.map(({ icon: Icon, title, text }) => (
              <div key={title} className="rounded-2xl border border-slate-200 bg-white p-5">
                <div className="w-10 h-10 rounded-xl bg-brand-100 text-brand-800 flex items-center justify-center mb-3">
                  <Icon size={18} aria-hidden="true" />
                </div>
                <h3 className="font-semibold text-slate-900 mb-1">{title}</h3>
                <p className="text-sm text-slate-600 leading-relaxed">{text}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-4 lg:px-8 pb-14">
          <h2 className="text-2xl font-bold text-slate-900 mb-3">Popular stock &amp; inventory solutions</h2>
          <p className="text-slate-600 mb-6">Explore keyword pages for the stock management software features teams search for most.</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {solutionPages.map((p) => (
              <Link
                key={p.path}
                to={p.path}
                className="rounded-xl border border-slate-200 bg-white px-4 py-3 text-sm font-medium text-slate-800 hover:border-brand-300 hover:text-brand-800"
              >
                {p.h1}
              </Link>
            ))}
          </div>
        </section>

        <section className="max-w-5xl mx-auto px-4 lg:px-8 pb-14">
          <h2 className="text-2xl font-bold text-slate-900 mb-6">Frequently asked questions</h2>
          <div className="space-y-5">
            {LANDING_FAQS.map((f) => (
              <div key={f.q} className="rounded-2xl border border-slate-200 bg-white p-5">
                <h3 className="font-semibold text-slate-900 mb-1">{f.q}</h3>
                <p className="text-sm text-slate-600 leading-relaxed">{f.a}</p>
              </div>
            ))}
          </div>
        </section>

        {sister && (
          <section className="max-w-5xl mx-auto px-4 lg:px-8 pb-14">
            <div className="rounded-2xl border border-slate-200 bg-white p-6 lg:p-8">
              <h2 className="text-xl font-bold text-slate-900 mb-2">Our other popular product</h2>
              <p className="text-sm text-slate-600 mb-4">
                <a href={sister.url} className="font-semibold text-brand-800 hover:underline" target="_blank" rel="noopener noreferrer">
                  {sister.name}
                </a>
                {' — '}
                {sister.tagline}
              </p>
              <a
                href={sister.url}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex text-sm font-medium text-brand-800 underline underline-offset-2"
              >
                Visit {new URL(sister.url).hostname}
              </a>
            </div>
          </section>
        )}
      </main>

      <PublicFooter showSeoLinks />
      <WhatsAppSupport />
    </div>
  );
}
