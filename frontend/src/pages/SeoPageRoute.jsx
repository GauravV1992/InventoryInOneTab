import { useLocation, Navigate } from 'react-router-dom';
import SeoPage from './SeoPage';
import { getSeoPageByPath } from '../seo/seoPages';

export default function SeoPageRoute() {
  const { pathname } = useLocation();
  const page = getSeoPageByPath(pathname);
  if (!page) return <Navigate to="/login" replace />;
  return <SeoPage page={page} />;
}
