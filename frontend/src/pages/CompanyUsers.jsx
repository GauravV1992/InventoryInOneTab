import { useEffect, useState } from 'react';
import { UserPlus, Trash2, Shield, CreditCard } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Alert, Table, PageLoading } from '../components/UI';
import { openRazorpayCheckout } from '../utils/razorpay';
import { validatePassword, validateUsername } from '../utils/passwordRules';

const fmtLimit = (value) => (value == null || value >= 999999 ? 'Unlimited' : String(value));
const fmt = (n) => `₹${Number(n).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

export default function CompanyUsers() {
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const [users, setUsers] = useState([]);
  const [subscription, setSubscription] = useState(null);
  const [prorationPreview, setProrationPreview] = useState(null);
  const [form, setForm] = useState({ username: '', password: '', firstName: '', lastName: '', email: '' });
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [payingUserId, setPayingUserId] = useState('');

  const load = () => {
    Promise.all([
      api.get('/company/users'),
      api.get('/billing/limits'),
      api.get('/company/users/proration-preview'),
    ])
      .then(([usersRes, limitsRes, previewRes]) => {
        setUsers(usersRes.data);
        setSubscription(limitsRes.data);
        setProrationPreview(previewRes.data);
      })
      .catch((err) => setError(err.response?.data?.error || 'Failed to load team users'))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  if (user.role !== 'Admin') {
    return (
      <div>
        <PageHeader title="Team Users" subtitle="Manage users in your company" />
        <Alert type="error" message="Only company admin can manage team users." />
      </div>
    );
  }

  const completePayment = async (targetUserId, order) => {
    await openRazorpayCheckout({
      keyId: order.keyId,
      orderId: order.orderId,
      amountPaise: order.amountPaise,
      name: 'InventoryInOneTap',
      description: 'Additional team user (prorated)',
      prefill: { name: user.fullName || user.username },
      onSuccess: async (response) => {
        await api.post('/company/users/verify-payment', {
          razorpay_order_id: response.razorpay_order_id,
          razorpay_payment_id: response.razorpay_payment_id,
          razorpay_signature: response.razorpay_signature,
          userId: targetUserId,
        });
        setSuccess('Payment successful. User can now login until the company subscription end date.');
        load();
      },
    });
  };

  const addUser = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');
    if (subscription?.subscriptionActive === false) {
      setError('Your subscription has expired. Please renew on the Pricing page.');
      return;
    }
    if (subscription?.canAddUser === false) {
      setError('Cannot add users while subscription is inactive.');
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
    setSubmitting(true);
    try {
      const { data } = await api.post('/company/users', form);

      if (data.needsPayment) {
        await completePayment(data.user.UserId, data.order);
        setForm({ username: '', password: '', firstName: '', lastName: '', email: '' });
      } else {
        setSuccess('User added successfully. They can login until the company subscription end date.');
        setForm({ username: '', password: '', firstName: '', lastName: '', email: '' });
        load();
      }
    } catch (err) {
      if (err.message !== 'Payment cancelled') {
        setError(err.response?.data?.error || err.message || 'Failed to add user');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const retryPayment = async (row) => {
    setError('');
    setSuccess('');
    setPayingUserId(row.UserId);
    try {
      const { data: order } = await api.post(`/company/users/${row.UserId}/create-order`);
      await completePayment(row.UserId, order);
    } catch (err) {
      if (err.message !== 'Payment cancelled') {
        setError(err.response?.data?.error || err.message || 'Payment failed');
      }
    } finally {
      setPayingUserId('');
    }
  };

  const removeUser = async (row) => {
    if (!window.confirm(`Remove user "${row.Username}"?`)) return;
    setError('');
    try {
      await api.delete(`/company/users/${row.UserId}`);
      setSuccess(row.PaymentStatus === 'Pending' ? 'Pending user removed' : 'User deactivated');
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to remove user');
    }
  };

  const columns = [
    { key: 'FullName', label: 'Name' },
    { key: 'Username', label: 'Username' },
    { key: 'Email', label: 'Email', render: (r) => r.Email || '—' },
    {
      key: 'Role',
      label: 'Role',
      render: (r) => (
        <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${r.Role === 'Admin' ? 'bg-amber-100 text-amber-800' : 'bg-slate-100 text-slate-700'}`}>
          {r.Role === 'Admin' && <Shield size={12} />}
          {r.Role}
        </span>
      ),
    },
    {
      key: 'SubscriptionEnd',
      label: 'Access till',
      render: (r) => (r.SubscriptionEnd ? new Date(r.SubscriptionEnd).toLocaleDateString('en-IN') : '—'),
    },
    {
      key: 'Status',
      label: 'Status',
      render: (r) => {
        if (r.PaymentStatus === 'Pending') {
          return <span className="text-xs font-medium text-amber-600">Pending payment</span>;
        }
        if (r.IsActive) {
          return <span className="text-xs font-medium text-green-600">Active</span>;
        }
        return <span className="text-xs font-medium text-red-500">Inactive</span>;
      },
    },
    {
      key: 'actions',
      label: '',
      render: (r) => (
        r.UserId !== user.userId && (r.IsActive || r.PaymentStatus === 'Pending') ? (
          <div className="flex gap-2">
            {r.PaymentStatus === 'Pending' && (
              <button
                type="button"
                onClick={() => retryPayment(r)}
                disabled={payingUserId === r.UserId}
                className="p-1.5 rounded-lg text-brand-600 hover:bg-brand-50 border border-brand-200"
                title="Complete payment"
              >
                <CreditCard size={14} />
              </button>
            )}
            <button type="button" onClick={() => removeUser(r)} className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 border border-red-200">
              <Trash2 size={14} />
            </button>
          </div>
        ) : null
      ),
    },
  ];

  const planType = subscription?.planType ?? subscription?.PlanType;
  const maxUsers = subscription?.maxUsers ?? subscription?.MaxUsers;
  const activeUsers = subscription?.activeUsers ?? subscription?.ActiveUsers;
  const subscriptionEnd = subscription?.subscriptionEnd ?? subscription?.SubscriptionEnd;
  const canAddUser = subscription?.canAddUser !== false;
  const needsPayment = subscription?.needsPaymentForUser ?? prorationPreview?.paymentRequired;

  if (loading) return <PageLoading message="Loading team users..." />;

  return (
    <div>
      <PageHeader
        title="Team Users"
        subtitle="Add users with the same subscription end date as your company. Extra users require prorated payment before login."
      />

      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {subscription && (
        <Card className="p-4 mb-6">
          <p className="text-sm text-slate-600">
            Plan: <strong className="capitalize">{planType}</strong>
            {' · '}Users: <strong>{activeUsers}</strong> / {fmtLimit(maxUsers)}
            {subscriptionEnd && (
              <> · Company access till <strong>{new Date(subscriptionEnd).toLocaleDateString('en-IN')}</strong></>
            )}
          </p>
          {subscription.subscriptionActive === false && (
            <p className="text-sm text-red-600 mt-2">Subscription expired — renew on Pricing page before adding users.</p>
          )}
          {needsPayment && prorationPreview?.proration && (
            <p className="text-sm text-amber-700 mt-2">
              Adding another user requires prorated payment of <strong>{fmt(prorationPreview.proration.amountRupees)}</strong>
              {' '}for {prorationPreview.proration.remainingDays} remaining day(s). User can login only after payment.
            </p>
          )}
          {!needsPayment && subscription.subscriptionActive !== false && (
            <p className="text-sm text-green-700 mt-2">
              You have included user slots available — new users can login immediately with the same end date as your company.
            </p>
          )}
        </Card>
      )}

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <Card className="p-4 sm:p-6">
          <h3 className="font-semibold mb-4 flex items-center gap-2"><UserPlus size={18} /> Add User</h3>
          <form onSubmit={addUser} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input label="First Name *" value={form.firstName} onChange={(e) => setForm({ ...form, firstName: e.target.value })} required />
              <Input label="Last Name" value={form.lastName} onChange={(e) => setForm({ ...form, lastName: e.target.value })} />
              <Input label="Username *" value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} required />
              <Input label="Email" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
              <Input label="Password *" type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} required />
            </div>
            <Button type="submit" loading={submitting} disabled={!canAddUser}>
              {submitting
                ? 'Processing...'
                : needsPayment
                  ? 'Add User & Pay Prorated'
                  : 'Add User'}
            </Button>
          </form>
        </Card>

        <Card className="p-4 sm:p-6">
          <h3 className="font-semibold mb-4">Company Users</h3>
          <Table columns={columns} data={users} keyField="UserId" />
        </Card>
      </div>
    </div>
  );
}
