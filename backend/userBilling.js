const { getPlan } = require('./plans');

function getExtraUserCyclePaise(subscription) {
  const cycle = subscription.BillingCycle === 'yearly' ? 'yearly' : 'monthly';
  // Both public paid plans are 1-user; price extra seats at Standard full cycle rate
  const standard = getPlan('standard');
  return cycle === 'yearly' ? standard.yearlyPaise : standard.monthlyPaise;
}

function calculateProratedUserAmount(subscription) {
  const fullSeatPaise = getExtraUserCyclePaise(subscription);
  const end = new Date(subscription.SubscriptionEnd);
  const start = new Date(subscription.SubscriptionStart || subscription.SubscriptionEnd);
  const now = new Date();

  const totalMs = Math.max(86400000, end.getTime() - start.getTime());
  const remainingMs = Math.max(0, end.getTime() - now.getTime());
  const ratio = remainingMs / totalMs;
  const amountPaise = Math.max(100, Math.round(fullSeatPaise * ratio));

  return {
    amountPaise,
    amountRupees: amountPaise / 100,
    fullSeatPaise,
    fullSeatRupees: fullSeatPaise / 100,
    remainingDays: Math.max(1, Math.ceil(remainingMs / 86400000)),
    totalDays: Math.max(1, Math.ceil(totalMs / 86400000)),
    subscriptionEnd: end.toISOString(),
    billingCycle: subscription.BillingCycle || 'monthly',
    planType: subscription.PlanType || 'Trial',
  };
}

function needsPaymentForNewUser(limits) {
  return limits.activeUsers >= limits.maxUsers;
}

module.exports = {
  getExtraUserCyclePaise,
  calculateProratedUserAmount,
  needsPaymentForNewUser,
};
