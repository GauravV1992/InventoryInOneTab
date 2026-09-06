export const PRICING_PLANS = [
  {
    id: 'basic',
    name: 'Basic',
    monthly: 499,
    yearly: 5489,
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
  {
    id: 'standard',
    name: 'Standard',
    monthly: 999,
    yearly: 10989,
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
];

export const ALLOWED_PLAN_IDS = PRICING_PLANS.map((p) => p.id);

export function normalizePlans(apiPlans) {
  const list = Array.isArray(apiPlans) ? apiPlans : [];
  const byId = Object.fromEntries(list.map((p) => [p.id, p]));
  // Frontend constants win over API so plan limits/features update without backend restart
  return PRICING_PLANS.map((fallback) => ({
    ...(byId[fallback.id] || {}),
    ...fallback,
  }));
}
