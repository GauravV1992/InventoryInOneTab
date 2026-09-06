import axios from 'axios';

const api = axios.create({ baseURL: '/api' });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    const url = String(err.config?.url || '');
    const isAuthAttempt = url.includes('/auth/login') || url.includes('/auth/register');
    if (err.response?.status === 402) {
      try {
        const user = JSON.parse(localStorage.getItem('user') || '{}');
        localStorage.setItem('user', JSON.stringify({
          ...user,
          subscriptionActive: false,
          needsPayment: true,
        }));
      } catch {
        /* ignore */
      }
      if (!window.location.pathname.startsWith('/pricing')) {
        window.location.href = '/pricing';
      }
      return Promise.reject(err);
    }
    if (err.response?.status === 401 && !isAuthAttempt) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      localStorage.removeItem('companyProfile');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default api;
