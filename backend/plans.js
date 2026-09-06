const TRIAL_DAYS = 3;
const UNLIMITED = 999999;

const PLANS = {
  basic: {
    id: 'basic',
    name: 'Basic',
    monthlyPaise: 49900,
    yearlyPaise: 548900,
    maxUsers: 1,
    maxWarehouses: 10,
    maxMaterials: 200,
    features: [
      '1 user',
      '10 warehouses',
      '200 materials',
      'Purchase & Sales',
      'GST invoice & PDF',
      'Stock reports',
    ],
    popular: false,
  },
  standard: {
    id: 'standard',
    name: 'Standard',
    monthlyPaise: 99900,
    yearlyPaise: 1098900,
    maxUsers: 1,
    maxWarehouses: 20,
    maxMaterials: 400,
    features: [
      '1 user',
      '20 warehouses',
      '400 materials',
      'Purchase & Sales',
      'GST invoice & PDF',
      'Stock reports',
    ],
    popular: true,
  },
  // Legacy — kept for existing PlanType=premium companies; not listed publicly
  premium: {
    id: 'premium',
    name: 'Premium',
    monthlyPaise: 499900,
    yearlyPaise: 5498900,
    maxUsers: 5,
    maxWarehouses: 10,
    maxMaterials: 3000,
    features: [
      '5 users',
      '10 warehouses',
      '3000 materials',
      'All Standard features',
      'Priority support',
    ],
    popular: false,
    listed: false,
  },
};

function getPlan(planId) {
  return PLANS[String(planId || '').toLowerCase()] || null;
}

function getPlanLimits(planType) {
  const key = String(planType || 'trial').toLowerCase();
  if (key === 'trial') return getPlanLimits('basic');
  const plan = getPlan(key);
  if (!plan) return getPlanLimits('basic');
  return {
    maxUsers: plan.maxUsers,
    maxWarehouses: plan.maxWarehouses,
    maxMaterials: plan.maxMaterials,
    planName: plan.name,
  };
}

function isUnlimited(value) {
  return value >= UNLIMITED;
}

function formatLimit(value) {
  return isUnlimited(value) ? 'Unlimited' : String(value);
}

function getPlanAmountPaise(planId, billingCycle) {
  const plan = getPlan(planId);
  if (!plan) return null;
  return billingCycle === 'yearly' ? plan.yearlyPaise : plan.monthlyPaise;
}

function listPlansForApi() {
  return Object.values(PLANS)
    .filter((p) => p.listed !== false)
    .map((p) => ({
      id: p.id,
      name: p.name,
      monthly: p.monthlyPaise / 100,
      yearly: p.yearlyPaise / 100,
      monthlyPaise: p.monthlyPaise,
      yearlyPaise: p.yearlyPaise,
      maxUsers: p.maxUsers,
      maxWarehouses: isUnlimited(p.maxWarehouses) ? null : p.maxWarehouses,
      maxMaterials: isUnlimited(p.maxMaterials) ? null : p.maxMaterials,
      features: p.features,
      popular: !!p.popular,
    }));
}

function getSubscriptionEndDate(billingCycle) {
  const end = new Date();
  if (billingCycle === 'yearly') {
    end.setFullYear(end.getFullYear() + 1);
  } else {
    end.setMonth(end.getMonth() + 1);
  }
  return end;
}

function getTrialEndDate() {
  const end = new Date();
  end.setDate(end.getDate() + TRIAL_DAYS);
  return end;
}

module.exports = {
  PLANS,
  TRIAL_DAYS,
  UNLIMITED,
  getPlan,
  getPlanLimits,
  isUnlimited,
  formatLimit,
  getPlanAmountPaise,
  listPlansForApi,
  getSubscriptionEndDate,
  getTrialEndDate,
};
