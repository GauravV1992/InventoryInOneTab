import { lazy, Suspense } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import Layout from './components/Layout';
import PricingRoute, { PricingContent } from './components/PricingRoute';
import { PageLoading } from './components/UI';
import Login from './pages/Login';
import Register from './pages/Register';
import Landing from './pages/Landing';
import { SEO_PAGES } from './seo/seoPages';

const Dashboard = lazy(() => import('./pages/Dashboard'));
const MaterialMaster = lazy(() => import('./pages/MaterialMaster'));
const SupplierMaster = lazy(() => import('./pages/SupplierMaster'));
const Locations = lazy(() => import('./pages/Locations'));
const OpeningStock = lazy(() => import('./pages/OpeningStock'));
const PurchaseInward = lazy(() => import('./pages/PurchaseInward'));
const Sales = lazy(() => import('./pages/Sales'));
const StockReport = lazy(() => import('./pages/StockReport'));
const MyAccount = lazy(() => import('./pages/MyAccount'));
const CompanyUsers = lazy(() => import('./pages/CompanyUsers'));
const TermsAndConditions = lazy(() => import('./pages/TermsAndConditions'));
const PrivacyPolicy = lazy(() => import('./pages/PrivacyPolicy'));
const CookiePolicy = lazy(() => import('./pages/CookiePolicy'));
const SeoPageRoute = lazy(() => import('./pages/SeoPageRoute'));

function AppShell() {
  const token = localStorage.getItem('token');
  const location = useLocation();
  if (!token) {
    if (location.pathname === '/' || location.pathname === '') return <Landing />;
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  return <Layout />;
}

function LazyPage({ children }) {
  return <Suspense fallback={<PageLoading />}>{children}</Suspense>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/register" element={<Register />} />
      <Route path="/pricing" element={<PricingRoute />}>
        <Route index element={<PricingContent />} />
      </Route>
      <Route path="/terms" element={<LazyPage><TermsAndConditions /></LazyPage>} />
      <Route path="/privacy" element={<LazyPage><PrivacyPolicy /></LazyPage>} />
      <Route path="/cookies" element={<LazyPage><CookiePolicy /></LazyPage>} />
      {SEO_PAGES.map((page) => (
        <Route key={page.path} path={page.path} element={<LazyPage><SeoPageRoute /></LazyPage>} />
      ))}
      <Route path="/" element={<AppShell />}>
        <Route index element={<LazyPage><Dashboard /></LazyPage>} />
        <Route path="materials" element={<LazyPage><MaterialMaster /></LazyPage>} />
        <Route path="suppliers" element={<LazyPage><SupplierMaster /></LazyPage>} />
        <Route path="locations" element={<LazyPage><Locations /></LazyPage>} />
        <Route path="opening-stock" element={<LazyPage><OpeningStock /></LazyPage>} />
        <Route path="purchase-inward" element={<LazyPage><PurchaseInward /></LazyPage>} />
        <Route path="sales" element={<LazyPage><Sales /></LazyPage>} />
        <Route path="stock-report" element={<LazyPage><StockReport /></LazyPage>} />
        <Route path="account" element={<LazyPage><MyAccount /></LazyPage>} />
        <Route path="team" element={<LazyPage><CompanyUsers /></LazyPage>} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
