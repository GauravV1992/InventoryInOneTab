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
        <article className="max-w-3xl mx-auto bg-white rounded-2xl border border-slate-200 p-4 sm:p-6 lg:p-10">
          <h1 className="text-2xl font-bold text-slate-800 mb-2">{title}</h1>
          <p className="text-sm text-slate-500 mb-8">Last updated: September 2026</p>
          {children}
        </article>
      </main>

      <PublicFooter />
    </div>
  );
}

export default function PrivacyPolicy() {
  return (
    <LegalLayout title="Privacy Policy">
      <section className="space-y-4 text-sm text-slate-600 leading-relaxed">
        <h2 className="text-lg font-semibold text-slate-800">1. Information We Collect</h2>
        <p>We collect account information (name, username, email, company details), usage data, and payment references processed through Razorpay. We do not store full card or UPI credentials on our servers.</p>

        <h2 className="text-lg font-semibold text-slate-800">2. How We Use Information</h2>
        <p>Your information is used to provide and improve the service, authenticate users, process subscriptions, generate invoices, and communicate important account updates.</p>

        <h2 className="text-lg font-semibold text-slate-800">3. Data Storage & Security</h2>
        <p>Business data is stored in secure databases with access controls. Passwords are stored using industry-standard hashing. You are responsible for safeguarding your login credentials.</p>

        <h2 className="text-lg font-semibold text-slate-800">4. Sharing of Information</h2>
        <p>We do not sell your personal data. We may share limited information with payment processors (Razorpay) and infrastructure providers strictly to operate the service.</p>

        <h2 className="text-lg font-semibold text-slate-800">5. Cookies & Local Storage</h2>
        <p>We use browser storage for session tokens, optional remembered login preferences, and cached profile data. See our Cookie Policy for details.</p>

        <h2 className="text-lg font-semibold text-slate-800">6. Your Rights</h2>
        <p>You may request access, correction, or deletion of your account data by contacting support. Some data may be retained where required for legal or billing records.</p>

        <h2 className="text-lg font-semibold text-slate-800">7. Children</h2>
        <p>InventoryInOneTap is intended for business use and is not directed at children under 18.</p>

        <h2 className="text-lg font-semibold text-slate-800">8. Contact</h2>
        <p>For privacy-related requests, email {SUPPORT_EMAIL}.</p>
      </section>
    </LegalLayout>
  );
}
