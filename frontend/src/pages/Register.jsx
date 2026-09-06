import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UserPlus } from 'lucide-react';
import api from '../api';
import { fetchAccountProfile } from '../utils/accountProfile';
import { validatePassword, validateUsername } from '../utils/passwordRules';
import { Loader } from '../components/UI';
import PublicFooter from '../components/PublicFooter';
import useSeo from '../hooks/useSeo';

export default function Register() {
  useSeo({
    title: 'Start Free Trial | Inventory Software India | InventoryInOneTap',
    description:
      'Register for InventoryInOneTap — 3-day free trial of inventory & stock management software for Indian businesses. GST invoices, warehouses, purchase & sales.',
    keywords: 'inventory software free trial India, register stock management software, InventoryInOneTap signup',
    path: '/register',
  });

  const navigate = useNavigate();
  const [form, setForm] = useState({
    username: '',
    password: '',
    confirmPassword: '',
    firstName: '',
    lastName: '',
    email: '',
    companyName: '',
    companyGSTNo: '',
    companyAddress1: '',
    companyAddress2: '',
    companyDescription: '',
  });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [usernameStatus, setUsernameStatus] = useState('idle'); // idle | checking | available | taken
  const [usernameMessage, setUsernameMessage] = useState('');

  const set = (key, value) => setForm({ ...form, [key]: value });

  useEffect(() => {
    const username = form.username.trim();
    if (username.length < 3) {
      setUsernameStatus('idle');
      setUsernameMessage(username.length > 0 ? 'Username must be at least 3 characters' : '');
      return undefined;
    }

    setUsernameStatus('checking');
    setUsernameMessage('Checking availability...');

    const timer = setTimeout(async () => {
      try {
        const { data } = await api.get('/auth/check-username', { params: { username } });
        if (data.available) {
          setUsernameStatus('available');
          setUsernameMessage('Username is available');
        } else {
          setUsernameStatus('taken');
          setUsernameMessage('Username already exists');
        }
      } catch {
        setUsernameStatus('idle');
        setUsernameMessage('');
      }
    }, 400);

    return () => clearTimeout(timer);
  }, [form.username]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (form.password !== form.confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    const usernameError = validateUsername(form.username);
    if (usernameError) {
      setError(usernameError);
      return;
    }

    const passwordError = validatePassword(form.password);
    if (passwordError) {
      setError(passwordError);
      return;
    }

    if (usernameStatus === 'taken') {
      setError('Username already exists. Please choose another.');
      return;
    }

    if (usernameStatus === 'checking') {
      setError('Please wait while username availability is checked');
      return;
    }

    setLoading(true);
    try {
      const { data } = await api.post('/auth/register', {
        username: form.username.trim(),
        password: form.password,
        firstName: form.firstName,
        lastName: form.lastName,
        email: form.email,
        companyName: form.companyName,
        companyGSTNo: form.companyGSTNo,
        companyAddress1: form.companyAddress1,
        companyAddress2: form.companyAddress2,
        companyDescription: form.companyDescription,
      });

      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data.user));
      localStorage.removeItem('companyProfile');

      try {
        await fetchAccountProfile(true);
      } catch {
        /* profile loads later */
      }

      navigate('/');
    } catch (err) {
      const msg = err.response?.data?.error;
      if (err.response?.status === 404) {
        setError('Registration API not found. Restart the backend server and try again.');
      } else {
        setError(msg || err.message || 'Registration failed');
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <div className="flex flex-1 items-center justify-center p-6">
      <div className="w-full max-w-2xl">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-brand-500 text-white flex items-center justify-center text-lg font-bold mx-auto mb-3">I1</div>
          <h1 className="text-2xl font-bold text-slate-800">Create Account</h1>
          <p className="text-slate-500 mt-1">Register your company — 3-day free trial included</p>
        </div>

        {error && (
          <div className="mb-4 px-4 py-3 rounded-xl bg-red-50 text-red-700 border border-red-200 text-sm">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-6 shadow-sm space-y-5">
          <div>
            <h2 className="font-semibold text-slate-800 mb-3">Company Details</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Company Name *</label>
                <input value={form.companyName} onChange={(e) => set('companyName', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" required />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Company GST No</label>
                <input value={form.companyGSTNo} onChange={(e) => set('companyGSTNo', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Company Email</label>
                <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Address 1</label>
                <input value={form.companyAddress1} onChange={(e) => set('companyAddress1', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Address 2</label>
                <input value={form.companyAddress2} onChange={(e) => set('companyAddress2', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Company Description</label>
                <textarea value={form.companyDescription} onChange={(e) => set('companyDescription', e.target.value)} rows={2} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
            </div>
          </div>

          <div>
            <h2 className="font-semibold text-slate-800 mb-3">Login Details</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">First Name *</label>
                <input value={form.firstName} onChange={(e) => set('firstName', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" required />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Last Name</label>
                <input value={form.lastName} onChange={(e) => set('lastName', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Username *</label>
                <input
                  value={form.username}
                  onChange={(e) => set('username', e.target.value)}
                  className={`w-full px-4 py-2.5 rounded-xl border ${
                    usernameStatus === 'taken' ? 'border-red-300' : usernameStatus === 'available' ? 'border-green-300' : 'border-slate-200'
                  }`}
                  required
                  autoComplete="username"
                />
                {usernameMessage && (
                  <p className={`text-xs mt-1 flex items-center gap-2 ${
                    usernameStatus === 'taken' ? 'text-red-600' : usernameStatus === 'available' ? 'text-green-600' : 'text-slate-500'
                  }`}>
                    {usernameStatus === 'checking' && <Loader size="sm" />}
                    {usernameMessage}
                  </p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Password *</label>
                <input type="password" value={form.password} onChange={(e) => set('password', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" required />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Confirm Password *</label>
                <input type="password" value={form.confirmPassword} onChange={(e) => set('confirmPassword', e.target.value)} className="w-full px-4 py-2.5 rounded-xl border border-slate-200" required />
              </div>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading || usernameStatus === 'taken' || usernameStatus === 'checking'}
            className="w-full flex items-center justify-center gap-2 py-3 rounded-xl bg-brand-500 hover:bg-brand-600 text-white font-medium shadow-lg shadow-brand-500/25 transition disabled:opacity-50"
          >
            {loading ? <Loader size="sm" className="border-white border-t-transparent" /> : <UserPlus size={18} />}
            {loading ? 'Creating account...' : 'Create Account'}
          </button>
        </form>

        <p className="text-center text-sm text-slate-500 mt-6">
          Already have an account?{' '}
          <Link to="/login" className="text-brand-600 hover:text-brand-700 font-medium">Sign in</Link>
          {' · '}
          <Link to="/pricing" className="text-brand-600 hover:text-brand-700 font-medium">View pricing</Link>
        </p>
      </div>
      </div>
      <PublicFooter showSeoLinks />
    </div>
  );
}
