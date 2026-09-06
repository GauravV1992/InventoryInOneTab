import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { LogIn, Check, Package, Warehouse, FileText, BarChart3 } from 'lucide-react';
import api from '../api';
import PublicFooter from '../components/PublicFooter';
import WhatsAppSupport from '../components/WhatsAppSupport';
import { Loader } from '../components/UI';
import useSeo from '../hooks/useSeo';

const REMEMBER_KEY = 'i1t_rememberLogin';
const USERNAME_KEY = 'i1t_savedUsername';

const HIGHLIGHTS = [
  { icon: Package, text: 'Material master with HSN, rate, unit & color' },
  { icon: Warehouse, text: 'Multi-warehouse stock — opening, purchase & sales' },
  { icon: FileText, text: 'GST sales invoice PDF for your customers' },
  { icon: BarChart3, text: 'Real-time stock report across all locations' },
];

const QUICK_FEATURES = [
  'Supplier master & purchase inward',
  'Sales with warehouse-wise lines',
  'Low stock alerts on dashboard',
  'Team users & Custom plan via WhatsApp',
];

export default function Login() {
  useSeo({
    title: 'Login | InventoryInOneTap Stock Management Software',
    description: 'Login to InventoryInOneTap — cloud inventory and stock management software for Indian businesses.',
    keywords: 'InventoryInOneTap login, inventory software login, stock management login',
    path: '/login',
  });

  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (localStorage.getItem(REMEMBER_KEY) === 'true') {
      setUsername(localStorage.getItem(USERNAME_KEY) || '');
      setRemember(true);
    }
    localStorage.removeItem('i1t_savedPassword');
  }, []);

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const { data } = await api.post('/auth/login', { username, password });
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data.user));
      localStorage.removeItem('companyProfile');

      if (remember) {
        localStorage.setItem(REMEMBER_KEY, 'true');
        localStorage.setItem(USERNAME_KEY, username);
      } else {
        localStorage.removeItem(REMEMBER_KEY);
        localStorage.removeItem(USERNAME_KEY);
      }

      try {
        const { fetchAccountProfile } = await import('../utils/accountProfile');
        await fetchAccountProfile(true);
      } catch {
        /* profile loads later from My Account */
      }
      navigate(data.user?.subscriptionActive === false ? '/pricing' : '/');
    } catch (err) {
      setError(err.response?.data?.error || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-white">
      <div className="flex flex-1 flex-col lg:flex-row">
        {/* Left panel — warm light background, high-contrast text */}
        <div className="hidden lg:flex lg:w-1/2 lg:sticky lg:top-0 lg:h-screen lg:shrink-0 relative overflow-hidden border-r border-brand-100 bg-gradient-to-br from-brand-50 via-orange-50 to-slate-100">
          <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_left,rgba(249,115,22,0.18),transparent_55%)] pointer-events-none" />
          <div className="absolute bottom-0 right-0 w-80 h-80 rounded-full bg-brand-200/30 blur-3xl pointer-events-none" />
          <div className="relative z-10 flex flex-col px-10 xl:px-14 py-10 overflow-y-auto w-full">
            <div className="w-14 h-14 rounded-2xl bg-brand-700 flex items-center justify-center text-lg font-bold text-white mb-5 shrink-0 shadow-lg shadow-brand-500/30">I1</div>
            <h1 className="text-3xl xl:text-4xl font-bold text-slate-900 mb-2">InventoryInOneTap</h1>
            <p className="text-lg text-brand-700 font-medium mb-3">Inventory in One Tap</p>
            <p className="text-slate-600 max-w-lg leading-relaxed mb-6 text-sm xl:text-base">
              Cloud inventory software built for Indian retailers and wholesalers. Track materials,
              warehouses, purchase inward, sales outward, and stock reports — from one simple dashboard.
            </p>

            <div className="space-y-2.5 mb-6 max-w-lg">
              {HIGHLIGHTS.map(({ icon: Icon, text }) => (
                <div key={text} className="flex items-start gap-3">
                  <div className="w-7 h-7 rounded-lg bg-brand-700 flex items-center justify-center shrink-0 mt-0.5 shadow-sm">
                    <Icon size={14} className="text-white" />
                  </div>
                  <p className="text-sm text-slate-700 leading-snug font-medium">{text}</p>
                </div>
              ))}
            </div>

            <div className="grid grid-cols-2 gap-2 max-w-lg mb-6">
              {QUICK_FEATURES.map((f) => (
                <div key={f} className="flex items-start gap-2 px-2.5 py-2 rounded-lg bg-white/90 border border-brand-100 text-xs text-slate-700 shadow-sm">
                  <Check size={12} className="text-brand-600 shrink-0 mt-0.5" />
                  <span>{f}</span>
                </div>
              ))}
            </div>

            <div className="mt-auto pt-4 max-w-lg border-t border-brand-100/80">
              <p className="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-1">Our other popular product</p>
              <a
                href="https://quotationinseconds.com"
                target="_blank"
                rel="noopener noreferrer"
                className="text-sm font-semibold text-brand-700 hover:text-brand-800"
              >
                QuotationInSeconds
              </a>
              <p className="text-xs text-slate-500 mt-1">
                Create professional quotations in seconds at{' '}
                <a href="https://quotationinseconds.com" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-brand-700">
                  quotationinseconds.com
                </a>
              </p>
            </div>
          </div>
        </div>

        {/* Right panel - login form */}
        <div className="flex-1 flex items-center justify-center p-4 sm:p-6 lg:p-8 lg:min-h-screen">
          <div className="w-full max-w-md">
            <div className="lg:hidden mb-8 text-center">
              <div className="w-14 h-14 rounded-2xl bg-brand-700 text-white flex items-center justify-center text-lg font-bold mx-auto mb-3" aria-hidden="true">I1</div>
              <h1 className="text-2xl font-bold">InventoryInOneTap</h1>
            </div>

            <h2 className="text-2xl font-bold text-slate-800 mb-2">Welcome back</h2>
            <p className="text-slate-500 mb-8">Sign in to your account · New users get a 3-day free trial</p>

            {error && (
              <div className="mb-4 px-4 py-3 rounded-xl bg-red-50 text-red-700 border border-red-200 text-sm">{error}</div>
            )}

            <form onSubmit={handleLogin} className="space-y-5">
              <div>
                <label htmlFor="login-username" className="block text-sm font-medium text-slate-700 mb-1.5">Username</label>
                <input
                  id="login-username"
                  name="username"
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  autoComplete="username"
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-brand-600/30 focus:border-brand-600"
                  required
                />
              </div>
              <div>
                <label htmlFor="login-password" className="block text-sm font-medium text-slate-700 mb-1.5">Password</label>
                <input
                  id="login-password"
                  name="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  autoComplete={remember ? 'current-password' : 'off'}
                  className="w-full px-4 py-3 rounded-xl border border-slate-300 focus:outline-none focus:ring-2 focus:ring-brand-600/30 focus:border-brand-600"
                  required
                />
              </div>

              <label htmlFor="login-remember" className="flex items-center gap-2 text-sm text-slate-700 cursor-pointer select-none">
                <input
                  id="login-remember"
                  name="remember"
                  type="checkbox"
                  checked={remember}
                  onChange={(e) => setRemember(e.target.checked)}
                  className="rounded border-slate-400 text-brand-700 focus:ring-brand-600"
                />
                Remember username
              </label>

              <button
                type="submit"
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-brand-700 hover:bg-brand-800 text-white font-medium shadow-lg shadow-brand-700/25 transition disabled:opacity-50"
              >
                {loading ? <Loader size="sm" className="border-white border-t-transparent" /> : <LogIn size={18} />}
                {loading ? 'Signing in...' : 'Sign In'}
              </button>
            </form>

            <p className="text-center text-sm text-slate-500 mt-6">
              New company?{' '}
              <Link to="/register" className="text-brand-800 hover:text-brand-900 font-medium underline underline-offset-2">Create account</Link>
              {' · '}
              <Link to="/pricing" className="text-brand-800 hover:text-brand-900 font-medium underline underline-offset-2">View pricing</Link>
            </p>
          </div>
        </div>
      </div>

      <PublicFooter showSeoLinks />
      <WhatsAppSupport />
    </div>
  );
}
