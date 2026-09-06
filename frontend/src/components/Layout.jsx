import { NavLink, Outlet, Navigate, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Package, Truck, MapPin, Warehouse,
  ShoppingCart, TrendingUp, BarChart3, LogOut, Menu, X, CreditCard, Users
} from 'lucide-react';
import { useEffect, useState } from 'react';
import api from '../api';
import { getStoredProfile } from '../utils/accountProfile';

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/materials', icon: Package, label: 'Material Master' },
  { to: '/suppliers', icon: Truck, label: 'Supplier Master' },
  { to: '/locations', icon: MapPin, label: 'Warehouse Locations' },
  { to: '/opening-stock', icon: Warehouse, label: 'Opening Stock' },
  { to: '/purchase-inward', icon: ShoppingCart, label: 'Purchase Inward' },
  { to: '/sales', icon: TrendingUp, label: 'Sales' },
  { to: '/stock-report', icon: BarChart3, label: 'Stock Report' },
];

function readPaywallFromUser() {
  try {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    return user.subscriptionActive === false || user.needsPayment === true;
  } catch {
    return false;
  }
}

function persistSubscriptionFlags(subscriptionActive, subscriptionEnd) {
  try {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    localStorage.setItem('user', JSON.stringify({
      ...user,
      subscriptionActive,
      needsPayment: !subscriptionActive,
      subscriptionEnd: subscriptionEnd ?? user.subscriptionEnd ?? null,
    }));
  } catch {
    /* ignore */
  }
}

export default function Layout() {
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [paywall, setPaywall] = useState(readPaywallFromUser);
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const companyName = getStoredProfile()?.CompanyName || user.companyName || 'My Company';
  const isAdmin = user.role === 'Admin';

  useEffect(() => {
    const refresh = () => {
      api.get('/billing/limits')
        .then(({ data }) => {
          const active = data.subscriptionActive !== false;
          setPaywall(!active);
          persistSubscriptionFlags(active, data.subscriptionEnd);
        })
        .catch(() => {});
    };

    refresh();
    window.addEventListener('subscription-updated', refresh);
    return () => window.removeEventListener('subscription-updated', refresh);
  }, []);

  const adminNavItems = isAdmin
    ? [
        { to: '/team', icon: Users, label: 'Team Users' },
        { to: '/pricing', icon: CreditCard, label: 'Pricing' },
      ]
    : [];

  const visibleNav = paywall ? [] : navItems;
  const extraNav = paywall
    ? [{ to: '/pricing', icon: CreditCard, label: isAdmin ? 'Renew plan' : 'Pricing' }]
    : adminNavItems;

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('companyProfile');
    navigate('/login');
  };

  if (paywall && location.pathname !== '/pricing') {
    return <Navigate to="/pricing" replace />;
  }

  return (
    <div className="flex min-h-screen bg-slate-50 overflow-x-hidden">
      {/* Sidebar */}
      <aside className={`fixed inset-y-0 left-0 z-40 w-64 bg-surface text-white transform transition-transform lg:translate-x-0 flex flex-col ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="shrink-0 flex items-center gap-3 px-6 py-5 border-b border-white/10">
          <NavLink to={paywall ? '/pricing' : '/'} end className="flex items-center gap-3 min-w-0 flex-1" onClick={() => setSidebarOpen(false)}>
            <div className="w-10 h-10 rounded-xl bg-brand-700 flex items-center justify-center font-bold text-sm shrink-0">I1</div>
            <div className="min-w-0">
              <h1 className="font-bold text-base leading-tight truncate">InventoryInOneTap</h1>
              <p className="text-xs text-slate-400 truncate">{companyName}</p>
            </div>
          </NavLink>
          <button className="lg:hidden shrink-0" onClick={() => setSidebarOpen(false)}>
            <X size={20} />
          </button>
        </div>

        <nav className="flex-1 min-h-0 overflow-y-auto p-4 space-y-1">
          {visibleNav.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/30'
                    : 'text-slate-300 hover:bg-white/10 hover:text-white'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
          {extraNav.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-brand-500 text-white shadow-lg shadow-brand-500/30'
                    : 'text-slate-300 hover:bg-white/10 hover:text-white'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {sidebarOpen && (
        <div className="fixed inset-y-0 left-0 right-0 bg-black/50 z-30 lg:hidden" onClick={() => setSidebarOpen(false)} />
      )}

      {/* Main content */}
      <div className="flex-1 min-w-0 lg:ml-64">
        {paywall && (
          <div className="bg-amber-500 text-white text-sm text-center py-2.5 px-4 font-medium">
            {isAdmin
              ? 'Your trial or subscription has expired. Pay below to restore access.'
              : 'Your trial or subscription has expired. Ask your company admin to renew the plan.'}
          </div>
        )}
        <header className="sticky top-0 z-20 bg-white/80 backdrop-blur border-b border-slate-200 px-4 lg:px-8 py-3 sm:py-4 flex items-center gap-2 sm:gap-3 min-w-0">
          <button type="button" className="lg:hidden p-2 rounded-lg hover:bg-slate-100 shrink-0" onClick={() => setSidebarOpen(true)} aria-label="Open menu">
            <Menu size={22} />
          </button>
          <div className="flex-1 min-w-0" />
          {!paywall && (
            <NavLink
              to="/account"
              title="My Account"
              className={({ isActive }) =>
                `text-sm font-medium truncate max-w-[40vw] sm:max-w-none underline underline-offset-2 shrink-0 transition ${
                  isActive ? 'text-brand-700' : 'text-slate-700 hover:text-brand-600'
                }`
              }
            >
              {user.username || 'User'}
            </NavLink>
          )}
          {paywall && (
            <span className="text-sm font-medium truncate max-w-[40vw] sm:max-w-none text-slate-700 shrink-0">
              {user.username || 'User'}
            </span>
          )}
          <button
            onClick={logout}
            className="flex items-center gap-1.5 px-2 sm:px-3 py-2 rounded-xl text-sm font-medium text-red-600 hover:bg-red-50 transition shrink-0"
          >
            <LogOut size={18} />
            <span className="hidden sm:inline">Logout</span>
          </button>
        </header>
        <main className="p-3 sm:p-4 lg:p-8 pb-28 min-w-0 overflow-x-hidden">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
