import { useEffect, useState } from 'react';
import { FileText, Download, ImagePlus, Trash2 } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Textarea, Alert, Table, PageLoading } from '../components/UI';
import { fetchAccountProfile, storeProfile, getStoredProfile, profileToCompany } from '../utils/accountProfile';
import { validatePassword } from '../utils/passwordRules';
import { fileToLogoDataUrl } from '../utils/logoImage';

const emptyProfile = {
  firstName: '',
  lastName: '',
  email: '',
  companyName: '',
  companyGSTNo: '',
  companyAddress1: '',
  companyAddress2: '',
  companyLogo: '',
  companyDescription: '',
  companyNameColor: '#f97316',
};

const fmt = (paise) => `₹${(Number(paise || 0) / 100).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function paymentLabel(row) {
  if (row.PaymentType === 'AddUser') {
    const name = row.UserFullName || row.UserUsername || 'Team user';
    return `Additional user — ${name}`;
  }
  const plan = String(row.PlanType || 'standard').replace(/^\w/, (c) => c.toUpperCase());
  const cycle = row.BillingCycle === 'yearly' ? 'Yearly' : 'Monthly';
  return `${plan} subscription (${cycle})`;
}

export default function MyAccount() {
  const [profile, setProfile] = useState(emptyProfile);
  const [invoices, setInvoices] = useState([]);
  const [passwords, setPasswords] = useState({ currentPassword: '', newPassword: '', confirmPassword: '' });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(true);
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingPassword, setSavingPassword] = useState(false);
  const [logoBusy, setLogoBusy] = useState(false);

  useEffect(() => {
    Promise.all([
      fetchAccountProfile(true),
      api.get('/account/invoices').then(({ data }) => data).catch(() => []),
    ])
      .then(([data, invoiceRows]) => {
        setProfile({
          firstName: data.FirstName || '',
          lastName: data.LastName || '',
          email: data.Email || '',
          companyName: data.CompanyName || '',
          companyGSTNo: data.CompanyGSTNo || '',
          companyAddress1: data.CompanyAddress1 || '',
          companyAddress2: data.CompanyAddress2 || '',
          companyLogo: data.CompanyLogo || '',
          companyDescription: data.CompanyDescription || '',
          companyNameColor: data.CompanyNameColor || '#f97316',
        });
        setInvoices(invoiceRows || []);
      })
      .catch((err) => setError(err.response?.data?.error || err.message || 'Failed to load profile'))
      .finally(() => setLoading(false));
  }, []);

  const onLogoChange = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setError('');
    setLogoBusy(true);
    try {
      const dataUrl = await fileToLogoDataUrl(file);
      setProfile((prev) => ({ ...prev, companyLogo: dataUrl }));
      setSuccess('Logo ready — click Save Profile to use it on sales invoice PDFs.');
    } catch (err) {
      setError(err.message || 'Failed to process logo');
    } finally {
      setLogoBusy(false);
    }
  };

  const removeLogo = () => {
    setProfile((prev) => ({ ...prev, companyLogo: '' }));
    setSuccess('Logo removed — click Save Profile to update invoices.');
  };

  const saveProfile = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    try {
      setSavingProfile(true);
      const { data } = await api.put('/account/profile', profile);
      storeProfile(data);
      setProfile((prev) => ({
        ...prev,
        companyLogo: data.CompanyLogo || '',
        companyName: data.CompanyName || prev.companyName,
        companyGSTNo: data.CompanyGSTNo || prev.companyGSTNo,
        companyAddress1: data.CompanyAddress1 || prev.companyAddress1,
        companyAddress2: data.CompanyAddress2 || prev.companyAddress2,
        companyDescription: data.CompanyDescription || prev.companyDescription,
        companyNameColor: data.CompanyNameColor || prev.companyNameColor,
      }));
      const user = JSON.parse(localStorage.getItem('user') || '{}');
      localStorage.setItem('user', JSON.stringify({
        ...user,
        fullName: [profile.firstName, profile.lastName].filter(Boolean).join(' ') || user.fullName,
        companyName: profile.companyName || user.companyName,
      }));
      setSuccess('Profile saved. Your logo will appear on sales invoice PDFs.');
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSavingProfile(false);
    }
  };

  const changePassword = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    if (passwords.newPassword !== passwords.confirmPassword) {
      setError('New passwords do not match');
      return;
    }
    const passwordError = validatePassword(passwords.newPassword, 'New password');
    if (passwordError) {
      setError(passwordError);
      return;
    }
    try {
      setSavingPassword(true);
      await api.put('/account/password', {
        currentPassword: passwords.currentPassword,
        newPassword: passwords.newPassword,
      });
      setSuccess('Password changed successfully');
      setPasswords({ currentPassword: '', newPassword: '', confirmPassword: '' });
    } catch (err) {
      setError(err.response?.data?.error || 'Password change failed');
    } finally {
      setSavingPassword(false);
    }
  };

  const downloadInvoice = async (row) => {
    const { downloadPaymentInvoicePdf } = await import('../utils/generatePaymentInvoicePdf');
    const stored = getStoredProfile();
    const company = profileToCompany(stored || {
      CompanyName: profile.companyName,
      CompanyGSTNo: profile.companyGSTNo,
      CompanyAddress1: profile.companyAddress1,
      CompanyAddress2: profile.companyAddress2,
      CompanyLogo: profile.companyLogo,
      CompanyDescription: profile.companyDescription,
      CompanyNameColor: profile.companyNameColor,
      Email: profile.email,
    });
    downloadPaymentInvoicePdf(row, company);
  };

  const invoiceColumns = [
    {
      key: 'PaymentHistoryId',
      label: 'Invoice No',
      render: (r) => `INV-PAY-${r.PaymentHistoryId}`,
    },
    {
      key: 'CreatedAt',
      label: 'Date',
      render: (r) => new Date(r.CreatedAt).toLocaleDateString('en-IN'),
    },
    {
      key: 'Description',
      label: 'Description',
      render: (r) => paymentLabel(r),
    },
    {
      key: 'AmountPaise',
      label: 'Amount',
      render: (r) => fmt(r.AmountPaise),
    },
    {
      key: 'RazorpayPaymentId',
      label: 'Payment ID',
      render: (r) => (
        <span className="text-xs text-slate-500 font-mono">{r.RazorpayPaymentId || '—'}</span>
      ),
    },
    {
      key: 'actions',
      label: '',
      render: (r) => (
        <button
          type="button"
          onClick={() => downloadInvoice(r)}
          className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-sm text-brand-600 hover:bg-brand-50 border border-brand-200"
        >
          <Download size={14} /> PDF
        </button>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading account..." />;

  return (
    <div>
      <PageHeader title="My Account" subtitle="Manage your profile, company logo, payment invoices, and password" />

      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 mb-6">
        <Card className="p-4 sm:p-6">
          <h3 className="font-semibold mb-4">Personal & Company Details</h3>
          <form onSubmit={saveProfile} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="First Name" value={profile.firstName} onChange={(e) => setProfile({ ...profile, firstName: e.target.value })} />
              <Input label="Last Name" value={profile.lastName} onChange={(e) => setProfile({ ...profile, lastName: e.target.value })} />
              <Input label="Email" type="email" value={profile.email} onChange={(e) => setProfile({ ...profile, email: e.target.value })} />
              <Input label="Company Name" value={profile.companyName} onChange={(e) => setProfile({ ...profile, companyName: e.target.value })} />
              <Input label="Company GST No" value={profile.companyGSTNo} onChange={(e) => setProfile({ ...profile, companyGSTNo: e.target.value })} />
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">Company Name Color (PDF)</label>
                <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 min-w-0">
                  <input type="color" value={profile.companyNameColor} onChange={(e) => setProfile({ ...profile, companyNameColor: e.target.value })} className="h-10 w-14 rounded-lg border border-slate-200 cursor-pointer shrink-0" />
                  <div className="flex-1 min-w-0">
                    <Input value={profile.companyNameColor} onChange={(e) => setProfile({ ...profile, companyNameColor: e.target.value })} />
                  </div>
                </div>
              </div>
              <Input label="Company Address 1" value={profile.companyAddress1} onChange={(e) => setProfile({ ...profile, companyAddress1: e.target.value })} />
              <Input label="Company Address 2" value={profile.companyAddress2} onChange={(e) => setProfile({ ...profile, companyAddress2: e.target.value })} />
            </div>

            <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">
              <div className="flex items-center gap-2 mb-1">
                <ImagePlus size={16} className="text-brand-600" />
                <label className="text-sm font-semibold text-slate-700">Company Logo (Sales Invoice PDF)</label>
              </div>
              <p className="text-xs text-slate-500 mb-3">
                Upload PNG/JPG/WEBP. Image is resized automatically and shown on the top-left of sales invoice PDFs after you save.
              </p>
              <input
                type="file"
                accept="image/png,image/jpeg,image/jpg,image/webp"
                onChange={onLogoChange}
                disabled={logoBusy}
                className="block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:bg-brand-50 file:text-brand-700"
              />
              {logoBusy && <p className="text-xs text-slate-500 mt-2">Processing logo…</p>}
              {profile.companyLogo ? (
                <div className="mt-3 flex items-end gap-4">
                  <div className="h-20 w-20 rounded-xl border border-slate-200 bg-white p-2 flex items-center justify-center overflow-hidden">
                    <img src={profile.companyLogo} alt="Company logo" className="max-h-full max-w-full object-contain" />
                  </div>
                  <button
                    type="button"
                    onClick={removeLogo}
                    className="inline-flex items-center gap-1.5 text-sm text-red-600 hover:text-red-700 px-3 py-1.5 rounded-lg border border-red-200 hover:bg-red-50"
                  >
                    <Trash2 size={14} /> Remove logo
                  </button>
                </div>
              ) : (
                <p className="text-xs text-slate-400 mt-2">No logo uploaded yet.</p>
              )}
            </div>

            <Textarea label="Company Description (shown on invoice PDF under company name)" value={profile.companyDescription} onChange={(e) => setProfile({ ...profile, companyDescription: e.target.value })} rows={3} />

            <Button type="submit" loading={savingProfile}>{savingProfile ? 'Saving...' : 'Save Profile'}</Button>
          </form>
        </Card>

        <Card className="p-4 sm:p-6">
          <h3 className="font-semibold mb-4">Change Password</h3>
          <form onSubmit={changePassword} className="space-y-4">
            <Input label="Current Password" type="password" value={passwords.currentPassword} onChange={(e) => setPasswords({ ...passwords, currentPassword: e.target.value })} required />
            <Input label="New Password" type="password" value={passwords.newPassword} onChange={(e) => setPasswords({ ...passwords, newPassword: e.target.value })} required />
            <Input label="Confirm New Password" type="password" value={passwords.confirmPassword} onChange={(e) => setPasswords({ ...passwords, confirmPassword: e.target.value })} required />
            <Button type="submit" variant="secondary" loading={savingPassword}>{savingPassword ? 'Updating...' : 'Update Password'}</Button>
          </form>

          <div className="mt-6 p-4 rounded-xl bg-slate-50 border border-slate-200 text-sm text-slate-600">
            <p className="font-medium text-slate-700 mb-2">Invoice PDF preview info</p>
            <p>Company name, GST, email, address, logo and description appear on sales and payment invoice PDFs using your selected company name color.</p>
          </div>
        </Card>
      </div>

      <Card className="p-4 sm:p-6">
        <h3 className="font-semibold mb-4 flex items-center gap-2">
          <FileText size={18} /> Payment Invoices
        </h3>
        <p className="text-sm text-slate-500 mb-4">
          Download PDF invoices for subscription and team user payments made via Razorpay.
        </p>
        {invoices.length === 0 ? (
          <p className="text-sm text-slate-500 py-6 text-center">No payment invoices yet.</p>
        ) : (
          <Table columns={invoiceColumns} data={invoices} keyField="PaymentHistoryId" />
        )}
      </Card>
    </div>
  );
}
