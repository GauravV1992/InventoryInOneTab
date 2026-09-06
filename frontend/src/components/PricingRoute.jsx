import { lazy, Suspense } from 'react';
import { Navigate } from 'react-router-dom';
import Layout from './Layout';
import { PageLoading } from './UI';

const Pricing = lazy(() => import('../pages/Pricing'));

function PrivateRoute({ children }) {
  const token = localStorage.getItem('token');
  return token ? children : <Navigate to="/login" replace />;
}

/** Public: standalone pricing page. Logged-in: sidebar layout + pricing content. */
export default function PricingRoute() {
  const loggedIn = !!localStorage.getItem('token');

  if (loggedIn) {
    return (
      <PrivateRoute>
        <Layout />
      </PrivateRoute>
    );
  }

  return (
    <Suspense fallback={<PageLoading message="Loading plans..." />}>
      <Pricing standalone />
    </Suspense>
  );
}

export function PricingContent() {
  return (
    <Suspense fallback={<PageLoading message="Loading plans..." />}>
      <Pricing standalone={false} />
    </Suspense>
  );
}
