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

export default function CookiePolicy() {
  return (
    <LegalLayout title="Cookie Policy">
      <section className="space-y-4 text-sm text-slate-600 leading-relaxed">
        <h2 className="text-lg font-semibold text-slate-800">1. What We Store</h2>
        <p>InventoryInOneTap uses browser local storage and session storage rather than traditional marketing cookies. These help the application function correctly when you sign in and navigate the app.</p>

        <h2 className="text-lg font-semibold text-slate-800">2. Types of Storage Used</h2>
        <ul className="list-disc pl-5 space-y-2">
          <li><strong>Authentication token</strong> — keeps you signed in during your session.</li>
          <li><strong>User profile cache</strong> — stores company details for faster invoice and PDF generation.</li>
          <li><strong>Remember me</strong> — if enabled on the login page, saves your username and password locally on your device for convenience.</li>
        </ul>

        <h2 className="text-lg font-semibold text-slate-800">3. Third-Party Services</h2>
        <p>When you make a payment, Razorpay may use its own cookies or storage as part of the checkout process. Please refer to Razorpay&apos;s privacy policy for details.</p>

        <h2 className="text-lg font-semibold text-slate-800">4. Managing Preferences</h2>
        <p>You can clear stored data at any time through your browser settings. Disabling storage may prevent you from staying logged in or using remembered login.</p>

        <h2 className="text-lg font-semibold text-slate-800">5. Contact</h2>
        <p>Questions about this policy can be sent to {SUPPORT_EMAIL}.</p>
      </section>
    </LegalLayout>
  );
}
