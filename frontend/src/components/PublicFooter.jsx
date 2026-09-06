import { Link } from 'react-router-dom';
import { SEO_PAGES, SISTER_PRODUCTS } from '../seo/seoPages';

export default function PublicFooter({ className = '', showSeoLinks = false }) {
  const sister = SISTER_PRODUCTS[0];

  return (
    <footer className={`w-full border-t border-slate-200 bg-white px-4 lg:px-8 py-6 ${className}`}>
      <div className="w-full space-y-6">
        {showSeoLinks && (
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">Solutions</p>
            <div className="flex flex-wrap gap-x-4 gap-y-2 text-sm w-full">
              {SEO_PAGES.map((p) => (
                <Link key={p.path} to={p.path} className="text-slate-600 hover:text-brand-600 transition">
                  {p.h1}
                </Link>
              ))}
            </div>
          </div>
        )}

        {sister && (
          <div>
            <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">Our other popular product</p>
            <a
              href={sister.url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-brand-600 hover:text-brand-700 font-medium"
            >
              {sister.name} — quotationinseconds.com
            </a>
            <p className="text-xs text-slate-500 mt-1 max-w-xl">{sister.tagline}</p>
          </div>
        )}

        <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4 text-sm text-slate-500">
          <p className="shrink-0">© {new Date().getFullYear()} InventoryInOneTap. All rights reserved.</p>
          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 lg:justify-end">
            <Link to="/pricing" className="hover:text-brand-600 transition">Pricing</Link>
            <Link to="/stock-management-software" className="hover:text-brand-600 transition">Stock management</Link>
            <Link to="/inventory-management-software" className="hover:text-brand-600 transition">Solutions</Link>
            <a href={sister?.url || 'https://quotationinseconds.com'} target="_blank" rel="noopener noreferrer" className="hover:text-brand-600 transition">
              QuotationInSeconds
            </a>
            <Link to="/terms" className="hover:text-brand-600 transition">Terms & Conditions</Link>
            <Link to="/privacy" className="hover:text-brand-600 transition">Privacy Policy</Link>
            <Link to="/cookies" className="hover:text-brand-600 transition">Cookie Policy</Link>
          </div>
        </div>
      </div>
    </footer>
  );
}
