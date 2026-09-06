import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Check, Building2, MessageCircle } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Alert, PageLoading } from '../components/UI';
import { openRazorpayCheckout } from '../utils/razorpay';
import { normalizePlans, PRICING_PLANS } from '../constants/plans';
import { CUSTOM_FEATURES, SUPPORT_WHATSAPP, whatsappSupportUrl } from '../constants/support';
import PublicFooter from '../components/PublicFooter';
import useSeo from '../hooks/useSeo';

const fmt = (n) => `₹${Number(n).toLocaleString('en-IN')}`;
const fmtLimit = (value) => (value == null || value >= 999999 ? 'Unlimited' : String(value));

export default function Pricing({ standalone = false }) {
  useSeo({
    title: 'Pricing — Inventory Software India Plans from ₹499 | InventoryInOneTap',
    description:
      'InventoryInOneTap pricing: Basic ₹499/mo and Standard ₹999/mo. Stock management software with warehouses, materials, GST invoices. 3-day free trial.',
    keywords:
      'inventory software pricing India, stock management software price, cheap inventory software India, InventoryInOneTap plans',
    path: '/pricing',
  });

  const token = localStorage.getItem('token');
  const loggedIn = !!token;
  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const isAdmin = loggedIn && user.role === 'Admin';
  const [plans, setPlans] = useState([]);
  const [trialDays, setTrialDays] = useState(3);
  const [subscription, setSubscription] = useState(null);
  const [billingCycle, setBillingCycle] = useState('monthly');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loadingPlan, setLoadingPlan] = useState('');
  const [loadingPage, setLoadingPage] = useState(true);

  useEffect(() => {
    Promise.all([
      api.get('/plans').then(({ data }) => {
        setPlans(normalizePlans(data.plans || data));
        if (data.trialDays) setTrialDays(data.trialDays);
      }).catch(() => {
        setPlans(PRICING_PLANS);
      }),
      loggedIn
        ? api.get('/billing/subscription').then(({ data }) => setSubscription(data)).catch(() => {})
        : Promise.resolve(),
    ]).finally(() => setLoadingPage(false));
  }, [loggedIn]);

  const subscribe = async (plan) => {
    if (!isAdmin) {
      setError('Only company admin can purchase or upgrade a plan');
      return;
    }

    setError('');
    setSuccess('');
    setLoadingPlan(plan.id);

    try {
      const { data: order } = await api.post('/billing/create-order', {
        planId: plan.id,
        billingCycle,
      });

      await openRazorpayCheckout({
        keyId: order.keyId,
        orderId: order.orderId,
        amountPaise: order.amountPaise,
        name: 'InventoryInOneTap',
        description: `${plan.name} plan (${billingCycle})`,
        prefill: { name: user.fullName || user.username },
        onSuccess: async (response) => {
          const { data } = await api.post('/billing/verify', {
            razorpay_order_id: response.razorpay_order_id,
            razorpay_payment_id: response.razorpay_payment_id,
            razorpay_signature: response.razorpay_signature,
            planId: plan.id,
            billingCycle,
          });

          localStorage.setItem('token', data.token);
          localStorage.setItem('user', JSON.stringify({
            ...user,
            planType: data.planType,
            subscriptionActive: true,
            needsPayment: false,
            subscriptionEnd: data.subscription?.SubscriptionEnd || user.subscriptionEnd,
          }));

          setSubscription({
            ...data.subscription,
            subscriptionActive: true,
          });
          setSuccess(`Successfully subscribed to ${plan.name} plan! You can now use the dashboard.`);
          window.dispatchEvent(new Event('subscription-updated'));
        },
      });
    } catch (err) {
      if (err.message !== 'Payment cancelled') {
        setError(err.response?.data?.error || err.message || 'Payment failed');
      }
    } finally {
      setLoadingPlan('');
    }
  };

  const subscriptionExpired = loggedIn && !!subscription && (
    subscription.subscriptionActive === false
    || (
      subscription.subscriptionActive !== true
      && (
        (subscription.SubscriptionEnd && new Date(subscription.SubscriptionEnd) < new Date())
        || (subscription.SubscriptionStatus && subscription.SubscriptionStatus !== 'Active')
      )
    )
  );
  const isTrial = subscription?.PlanType?.toLowerCase() === 'trial';
  const trialDaysLeft = subscription?.SubscriptionEnd
    ? Math.ceil((new Date(subscription.SubscriptionEnd) - new Date()) / 86400000)
    : 0;
  const trialActive = isTrial && !subscriptionExpired && trialDaysLeft > 0;

  if (loadingPage) {
    return standalone ? (
      <div className="min-h-screen bg-slate-50 flex items-center justify-center">
        <PageLoading message="Loading plans..." />
      </div>
    ) : <PageLoading message="Loading plans..." />;
  }

  return (
    <div className={standalone ? 'min-h-screen bg-slate-50 flex flex-col' : ''}>
      {standalone && (
        <header className="bg-white border-b border-slate-200 px-4 lg:px-8 py-4 flex items-center justify-between gap-3">
          <Link to="/login" className="flex items-center gap-2 min-w-0">
            <div className="w-9 h-9 rounded-xl bg-brand-500 text-white flex items-center justify-center text-sm font-bold shrink-0">I1</div>
            <span className="font-bold text-slate-800 truncate">InventoryInOneTap</span>
          </Link>
          <div className="flex items-center gap-2 sm:gap-3 text-sm shrink-0">
            <Link to="/pricing" className="text-brand-600 font-medium hidden sm:inline">Pricing</Link>
            {loggedIn ? (
              <Link to="/" className="px-3 sm:px-4 py-2 rounded-xl bg-brand-500 text-white font-medium">Dashboard</Link>
            ) : (
              <>
                <Link to="/login" className="text-slate-600 hover:text-slate-800">Login</Link>
                <Link to="/register" className="px-3 sm:px-4 py-2 rounded-xl bg-brand-500 text-white font-medium whitespace-nowrap text-xs sm:text-sm">Start free trial</Link>
              </>
            )}
          </div>
        </header>
      )}

      <div className={standalone ? 'p-4 lg:p-8 max-w-7xl mx-auto' : ''}>
      <PageHeader
        title="Pricing Plans"
        subtitle={
          subscriptionExpired
            ? 'Your access has expired. Choose a plan and pay to continue using InventoryInOneTap.'
            : `Start with a ${trialDays}-day free trial (Basic limits). Pay securely via Razorpay when you upgrade.`
        }
      />

      <Alert type="error" message={error} />
      <Alert type="success" message={success} />
      {success && !subscriptionExpired && (
        <p className="mb-6 text-sm">
          <Link to="/" className="text-brand-600 font-medium">Go to dashboard</Link>
        </p>
      )}

      {subscriptionExpired && (
        <Card className="p-4 mb-6 border-red-200 bg-red-50">
          <p className="text-sm text-red-800 font-medium">
            {isTrial ? 'Your free trial has ended.' : 'Your subscription has expired.'}
            {subscription?.SubscriptionEnd && (
              <> Ended on {new Date(subscription.SubscriptionEnd).toLocaleDateString('en-IN')}.</>
            )}
            {' '}
            {isAdmin
              ? 'Pay below to restore inventory, purchase, and sales access.'
              : 'Ask your company admin to renew the plan.'}
          </p>
        </Card>
      )}

      {trialActive && (
        <Card className="p-4 mb-6 border-amber-200 bg-amber-50">
          <p className="text-sm text-amber-900">
            Free trial active — {trialDaysLeft} day(s) left.
            Trial includes 1 user, 10 warehouses, 200 materials. Subscribe below before trial ends.
          </p>
        </Card>
      )}

      {subscription && (
        <Card className={`p-4 mb-6 ${subscriptionExpired ? 'border-red-200 bg-red-50' : 'border-brand-200 bg-brand-50'}`}>
          <p className={`text-sm ${subscriptionExpired ? 'text-red-800' : 'text-brand-800'}`}>
            Current plan: <strong className="capitalize">{subscription.PlanType || 'Trial'}</strong>
            {subscriptionExpired && <> · <strong>Expired</strong></>}
            {subscription.BillingCycle && subscription.PlanType?.toLowerCase() !== 'trial' && (
              <> · {subscription.BillingCycle}</>
            )}
            {' · '}Users: {subscription.ActiveUsers}/{fmtLimit(subscription.MaxUsers)}
            {' · '}Warehouses: {subscription.ActiveWarehouses ?? '—'}/{fmtLimit(subscription.MaxWarehouses)}
            {' · '}Materials: {subscription.ActiveMaterials ?? '—'}/{fmtLimit(subscription.MaxMaterials)}
            {subscription.SubscriptionEnd && (
              <> · {subscriptionExpired ? 'Ended' : 'Valid till'} {new Date(subscription.SubscriptionEnd).toLocaleDateString('en-IN')}</>
            )}
          </p>
        </Card>
      )}

      <div className="flex justify-center mb-8 overflow-x-auto">
        <div className="inline-flex rounded-xl border border-slate-200 bg-white p-1">
          <button
            type="button"
            onClick={() => setBillingCycle('monthly')}
            className={`px-3 sm:px-4 py-2 rounded-lg text-sm font-medium transition whitespace-nowrap ${billingCycle === 'monthly' ? 'bg-brand-500 text-white' : 'text-slate-600'}`}
          >
            Monthly
          </button>
          <button
            type="button"
            onClick={() => setBillingCycle('yearly')}
            className={`px-3 sm:px-4 py-2 rounded-lg text-sm font-medium transition whitespace-nowrap ${billingCycle === 'yearly' ? 'bg-brand-500 text-white' : 'text-slate-600'}`}
          >
            Yearly (1 month free)
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-6 max-w-5xl mx-auto">
        {plans.map((plan) => {
          const price = billingCycle === 'yearly' ? plan.yearly : plan.monthly;
          const isCurrent = !subscriptionExpired && subscription?.PlanType?.toLowerCase() === plan.id;
          const ctaLabel = subscriptionExpired
            ? (isAdmin ? 'Pay now' : 'Admin only')
            : (isAdmin ? 'Subscribe' : 'Admin only');
          return (
            <Card
              key={plan.id}
              className={`p-6 flex flex-col relative ${plan.popular ? 'ring-2 ring-brand-500 shadow-lg' : ''}`}
            >
              {plan.popular && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-brand-500 text-white text-xs font-medium">
                  Most Popular
                </span>
              )}
              <h3 className="text-xl font-bold text-slate-800 mb-2">{plan.name}</h3>
              <div className="mb-4">
                <span className="text-3xl font-bold text-slate-900">{fmt(price)}</span>
                <span className="text-slate-500 text-sm">/{billingCycle === 'yearly' ? 'year' : 'month'}</span>
              </div>
              <ul className="space-y-2 mb-6 flex-1">
                {plan.features.map((f) => (
                  <li key={f} className="flex items-start gap-2 text-sm text-slate-600">
                    <Check size={16} className="text-brand-500 mt-0.5 shrink-0" />
                    {f}
                  </li>
                ))}
              </ul>
              {isCurrent ? (
                <Button variant="secondary" disabled className="w-full justify-center">Current Plan</Button>
              ) : !loggedIn ? (
                <Link to="/register" className="block">
                  <Button className="w-full justify-center">Start {trialDays}-day free trial</Button>
                </Link>
              ) : (
                <Button
                  className="w-full justify-center"
                  disabled={!isAdmin}
                  loading={loadingPlan === plan.id}
                  onClick={() => subscribe(plan)}
                >
                  {loadingPlan === plan.id ? 'Processing...' : ctaLabel}
                </Button>
              )}
            </Card>
          );
        })}

        <Card className="p-6 flex flex-col border-slate-200 bg-gradient-to-b from-slate-50 to-white">
          <div className="flex items-center gap-2 mb-2">
            <Building2 size={20} className="text-brand-600 shrink-0" />
            <h3 className="text-xl font-bold text-slate-800">Custom</h3>
          </div>
          <div className="mb-4">
            <span className="text-3xl font-bold text-slate-900">Contact</span>
            <span className="text-slate-500 text-sm block mt-1">Tailored for your business</span>
          </div>
          <ul className="space-y-2 mb-6 flex-1">
            {CUSTOM_FEATURES.map((f) => (
              <li key={f} className="flex items-start gap-2 text-sm text-slate-600">
                <Check size={16} className="text-brand-500 mt-0.5 shrink-0" />
                {f}
              </li>
            ))}
          </ul>
          <p className="text-xs text-slate-500 mb-3 text-center">
            WhatsApp <strong>{SUPPORT_WHATSAPP}</strong>
          </p>
          <a
            href={whatsappSupportUrl('Hi, I am interested in the Custom plan for InventoryInOneTap.')}
            target="_blank"
            rel="noopener noreferrer"
            className="block mt-auto"
          >
            <Button variant="secondary" className="w-full justify-center gap-2">
              <MessageCircle size={18} />
              Contact Support
            </Button>
          </a>
        </Card>
      </div>

      {!loggedIn && (
        <p className="text-center text-sm text-slate-500 mt-6">
          <Link to="/register" className="text-brand-600 font-medium">Create account</Link>
          {' '}to start your {trialDays}-day free trial, or{' '}
          <Link to="/login" className="text-brand-600 font-medium">login</Link>
          {' '}to subscribe.
        </p>
      )}

      {loggedIn && !isAdmin && (
        <p className="text-center text-sm text-slate-500 mt-6">
          {subscriptionExpired
            ? 'Only your company admin can pay and restore access.'
            : 'Ask your company admin to upgrade the subscription plan.'}
        </p>
      )}
      </div>
      {standalone && <PublicFooter showSeoLinks />}
    </div>
  );
}
