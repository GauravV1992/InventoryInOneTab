const { execProc, query } = require('./db');
const { getPlanLimits, isUnlimited, formatLimit, getPlan, getTrialEndDate } = require('./plans');

const SUBSCRIPTION_CACHE_TTL_MS = 30_000;
const subscriptionCache = new Map();

function getCachedSubscription(companyId) {
  const entry = subscriptionCache.get(companyId);
  if (!entry || Date.now() - entry.ts > SUBSCRIPTION_CACHE_TTL_MS) return null;
  return entry.sub;
}

function setCachedSubscription(companyId, sub) {
  if (sub) subscriptionCache.set(companyId, { sub, ts: Date.now() });
}

function invalidateSubscriptionCache(companyId) {
  if (companyId) subscriptionCache.delete(companyId);
  else subscriptionCache.clear();
}

async function ensureCompanyTrialSubscription(companyId) {
  const trialLimits = getPlanLimits('trial');
  const start = new Date();
  const end = getTrialEndDate();

  await execProc('sp_UpdateCompanySubscription', {
    CompanyId: companyId,
    PlanType: 'Trial',
    BillingCycle: 'monthly',
    SubscriptionStatus: 'Active',
    SubscriptionStart: start,
    SubscriptionEnd: end,
    MaxUsers: trialLimits.maxUsers,
  });

  await query(`
    UPDATE dbo.CompanyMaster
    SET MaxWarehouses = @MaxWarehouses,
        MaxMaterials = @MaxMaterials
    WHERE CompanyId = @CompanyId
      AND (PlanType IS NULL OR SubscriptionEnd IS NULL OR MaxWarehouses IS NULL OR MaxMaterials IS NULL)
  `, {
    CompanyId: companyId,
    MaxWarehouses: trialLimits.maxWarehouses,
    MaxMaterials: trialLimits.maxMaterials,
  });

  invalidateSubscriptionCache(companyId);
}

async function getCompanySubscription(companyId) {
  const cached = getCachedSubscription(companyId);
  if (cached) return cached;

  const result = await execProc('sp_GetCompanySubscription', { CompanyId: companyId });
  let sub = result.recordset[0] || null;
  if (sub && !sub.SubscriptionEnd) {
    await ensureCompanyTrialSubscription(companyId);
    const refreshed = await execProc('sp_GetCompanySubscription', { CompanyId: companyId });
    sub = refreshed.recordset[0] || null;
  }
  if (sub) setCachedSubscription(companyId, sub);
  return sub;
}

function getUpgradeHint(planType, resource) {
  const key = String(planType || 'trial').toLowerCase();
  if (resource === 'user') {
    if (key === 'basic' || key === 'standard' || key === 'trial') {
      return 'Contact Custom plan support via WhatsApp on the Pricing page, or pay prorated for an extra user.';
    }
    return 'User limit reached. Pay prorated amount to add more users on Team Users page.';
  }
  if (key === 'basic') return 'Upgrade to Standard on the Pricing page, or contact us for a Custom plan.';
  if (key === 'standard') return 'Contact us for a Custom plan via WhatsApp on the Pricing page.';
  return 'Upgrade your plan on the Pricing page.';
}

async function getActiveCounts(companyId) {
  const result = await query(`
    SELECT
      (SELECT COUNT(*) FROM dbo.Users
       WHERE CompanyId = @CompanyId AND IsActive = 1 AND ISNULL(PaymentStatus, N'Paid') = N'Paid') AS activeUsers,
      (SELECT COUNT(*) FROM dbo.WarehouseLocation
       WHERE CompanyId = @CompanyId AND IsActive = 1) AS activeWarehouses,
      (SELECT COUNT(*) FROM dbo.MaterialMaster
       WHERE CompanyId = @CompanyId AND IsActive = 1) AS activeMaterials
  `, { CompanyId: companyId });
  const row = result.recordset[0] || {};
  return {
    activeUsers: row.activeUsers ?? 0,
    activeWarehouses: row.activeWarehouses ?? 0,
    activeMaterials: row.activeMaterials ?? 0,
  };
}

function getEffectiveLimits(sub, activeCounts = null) {
  const fromPlan = getPlanLimits(sub.PlanType);
  const planType = sub.PlanType || 'Trial';

  return {
    planType,
    planName: fromPlan.planName,
    maxUsers: Math.max(fromPlan.maxUsers, sub.MaxUsers ?? 0),
    maxWarehouses: fromPlan.maxWarehouses,
    maxMaterials: fromPlan.maxMaterials,
    activeUsers: activeCounts?.activeUsers ?? sub.ActiveUsers ?? 0,
    activeWarehouses: activeCounts?.activeWarehouses ?? sub.ActiveWarehouses ?? 0,
    activeMaterials: activeCounts?.activeMaterials ?? sub.ActiveMaterials ?? 0,
  };
}

async function getCompanyLimits(companyId, existingSub = null) {
  const sub = existingSub || await getCompanySubscription(companyId);
  if (!sub) throw new Error('Company not found');
  const activeCounts = await getActiveCounts(companyId);
  return getEffectiveLimits(sub, activeCounts);
}

function isSubscriptionActive(sub) {
  if (!sub) return false;
  if (sub.SubscriptionStatus && sub.SubscriptionStatus !== 'Active') return false;
  if (sub.SubscriptionEnd && new Date(sub.SubscriptionEnd) < new Date()) return false;
  return true;
}

function assertSubscriptionActive(sub) {
  if (isSubscriptionActive(sub)) return;
  const expired = sub?.SubscriptionEnd && new Date(sub.SubscriptionEnd) < new Date();
  throw new Error(expired
    ? 'Your subscription has expired. Please renew on the Pricing page.'
    : 'Your subscription is not active. Please renew on the Pricing page.');
}

async function assertCanAddUser(companyId) {
  const sub = await getCompanySubscription(companyId);
  if (!sub) throw new Error('Company not found');
  assertSubscriptionActive(sub);

  const limits = getEffectiveLimits(sub);
  if (limits.activeUsers >= limits.maxUsers) {
    throw new Error(
      `User limit reached (${limits.activeUsers}/${formatLimit(limits.maxUsers)}) on ${limits.planName} plan. ${getUpgradeHint(limits.planType, 'user')}`
    );
  }
}

async function assertCanAddWarehouse(companyId) {
  const sub = await getCompanySubscription(companyId);
  if (!sub) throw new Error('Company not found');
  assertSubscriptionActive(sub);

  const limits = getEffectiveLimits(sub);
  if (!isUnlimited(limits.maxWarehouses) && limits.activeWarehouses >= limits.maxWarehouses) {
    throw new Error(
      `Warehouse limit reached (${limits.activeWarehouses}/${limits.maxWarehouses}) on ${limits.planName} plan. ${getUpgradeHint(limits.planType, 'warehouse')}`
    );
  }
}

async function assertCanAddMaterial(companyId) {
  const sub = await getCompanySubscription(companyId);
  if (!sub) throw new Error('Company not found');
  assertSubscriptionActive(sub);

  const activeCounts = await getActiveCounts(companyId);
  const limits = getEffectiveLimits(sub, activeCounts);
  if (!isUnlimited(limits.maxMaterials) && limits.activeMaterials >= limits.maxMaterials) {
    throw new Error(
      `Material limit reached (${limits.activeMaterials}/${limits.maxMaterials}) on ${limits.planName} plan. ${getUpgradeHint(limits.planType, 'material')}`
    );
  }
}

function isLimitError(message) {
  return /limit reached|subscription has expired|subscription is not active/i.test(String(message || ''));
}

module.exports = {
  getCompanySubscription,
  ensureCompanyTrialSubscription,
  invalidateSubscriptionCache,
  getActiveCounts,
  getCompanyLimits,
  getEffectiveLimits,
  assertCanAddUser,
  assertCanAddWarehouse,
  assertCanAddMaterial,
  isSubscriptionActive,
  assertSubscriptionActive,
  isLimitError,
  getUpgradeHint,
};
