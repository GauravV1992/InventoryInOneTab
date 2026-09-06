import { Link } from 'react-router-dom';
import PublicFooter from '../components/PublicFooter';
import { SUPPORT_EMAIL } from '../constants/site';

function LegalLayout({ title, children }) {
  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="bg-white border-b border-slate-200 px-4 lg:px-8 py-4">
        <div className="max-w-3xl mx-auto flex items-center justify-between gap-3">
          <Link to="/login" className="flex items-center gap-2 min-w-0">
            <div className="w-9 h-9 rounded-xl bg-brand-500 text-white flex items-center justify-center text-sm font-bold shrink-0">I1</div>
            <span className="font-bold text-slate-800 truncate">InventoryInOneTap</span>
          </Link>
          <div className="flex items-center gap-3 sm:gap-4 text-sm shrink-0">
            <Link to="/pricing" className="text-slate-600 hover:text-brand-600 font-medium hidden sm:inline">Pricing</Link>
            <Link to="/login" className="text-brand-600 font-medium hover:text-brand-700">Login</Link>
          </div>
        </div>
      </header>

      <main className="flex-1 px-4 lg:px-8 py-8">
        <article className="max-w-3xl mx-auto bg-white rounded-2xl border border-slate-200 p-4 sm:p-6 lg:p-10 prose prose-slate max-w-none">
          <h1 className="text-2xl font-bold text-slate-800 mb-2">{title}</h1>
          <p className="text-sm text-slate-500 mb-8">Last updated: September 2026</p>
          {children}
        </article>
      </main>

      <PublicFooter />
    </div>
  );
}

export default function TermsAndConditions() {
  return (
    <LegalLayout title="Terms & Conditions">
      <section className="space-y-4 text-sm text-slate-600 leading-relaxed">
        <h2 className="text-lg font-semibold text-slate-800">1. Acceptance of Terms</h2>
        <p>By accessing or using InventoryInOneTap, you agree to these Terms & Conditions. If you do not agree, please do not use the service.</p>

        <h2 className="text-lg font-semibold text-slate-800">2. Service Description</h2>
        <p>InventoryInOneTap provides cloud-based inventory management including materials, warehouses, purchase, sales, stock reports, and subscription billing.</p>

        <h2 className="text-lg font-semibold text-slate-800">3. Accounts & Responsibilities</h2>
        <p>You are responsible for maintaining the confidentiality of your login credentials and for all activity under your company account. Admin users are responsible for team member access and subscription payments.</p>

        <h2 className="text-lg font-semibold text-slate-800">4. Subscription & Payments</h2>
        <p>Plans, pricing, user limits, warehouse limits, and material limits are as described on the Pricing page. Payments are processed securely via Razorpay. Subscription fees are non-refundable except where required by applicable law.</p>

        <h2 className="text-lg font-semibold text-slate-800">5. Free Trial</h2>
        <p>New registrations may receive a limited free trial. After the trial period, continued use requires an active paid subscription.</p>

        <h2 className="text-lg font-semibold text-slate-800">6. Acceptable Use</h2>
        <p>You agree not to misuse the platform, attempt unauthorized access, upload malicious content, or use the service for unlawful purposes.</p>

        <h2 className="text-lg font-semibold text-slate-800">7. Data & Availability</h2>
        <p>We strive to maintain service availability and data integrity but do not guarantee uninterrupted access. You should maintain your own backups of critical business records where required.</p>

        <h2 className="text-lg font-semibold text-slate-800">8. Limitation of Liability</h2>
        <p>To the maximum extent permitted by law, InventoryInOneTap shall not be liable for indirect, incidental, or consequential damages arising from use of the service.</p>

        <h2 className="text-lg font-semibold text-slate-800">9. Changes</h2>
        <p>We may update these terms from time to time. Continued use after changes constitutes acceptance of the revised terms.</p>

        <h2 className="text-lg font-semibold text-slate-800">10. Contact</h2>
        <p>For questions regarding these terms, contact {SUPPORT_EMAIL}.</p>
      </section>
    </LegalLayout>
  );
}
