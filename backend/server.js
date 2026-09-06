require('dotenv').config();
const express = require('express');
const cors = require('cors');
const compression = require('compression');
const helmet = require('helmet');
const jwt = require('jsonwebtoken');
const Razorpay = require('razorpay');
const { sql, query, execProc } = require('./db');
const { getPlan, getPlanAmountPaise, listPlansForApi, getSubscriptionEndDate, TRIAL_DAYS, isUnlimited } = require('./plans');
const { getCompanyLimits, getCompanySubscription, ensureCompanyTrialSubscription, invalidateSubscriptionCache, getActiveCounts, getEffectiveLimits, assertCanAddUser, assertCanAddWarehouse, assertCanAddMaterial, isSubscriptionActive, assertSubscriptionActive, isLimitError } = require('./planLimits');
const { calculateProratedUserAmount, needsPaymentForNewUser } = require('./userBilling');
const {
  assertSecureConfig,
  getCorsOptions,
  authRateLimiter,
  checkUsernameRateLimiter,
  apiRateLimiter,
  validateUsername,
  validatePassword,
  verifyPassword,
  hashPassword,
  verifyRazorpaySignature,
  safeErrorMessage,
} = require('./security');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'InventoryInOneTap_SecretKey_2026';
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || '';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || '';

const razorpay = RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET
  ? new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET })
  : null;

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
}));
app.use(cors(getCorsOptions()));
app.use(compression());
app.use(express.json({ limit: '3mb' }));
app.use('/api', apiRateLimiter);

async function assertPaymentOrderForCompany(companyId, orderId, paymentType, userId = null) {
  const result = await query(`
    SELECT TOP 1 PaymentHistoryId, UserId
    FROM dbo.PaymentHistory
    WHERE CompanyId = @CompanyId
      AND RazorpayOrderId = @OrderId
      AND PaymentType = @PaymentType
      AND PaymentStatus IN (N'Created', N'Pending')
  `, { CompanyId: companyId, OrderId: orderId, PaymentType: paymentType });
  const row = result.recordset[0];
  if (!row) {
    throw new Error('Payment order not found for this company');
  }
  if (userId != null && row.UserId != null && Number(row.UserId) !== Number(userId)) {
    throw new Error('Payment order does not match this user');
  }
  return row;
}

function auth(req, res, next) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Unauthorized' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    if (!req.user.companyId) {
      return res.status(401).json({ error: 'Session expired. Please login again.' });
    }
    next();
  } catch {
    res.status(401).json({ error: 'Invalid token' });
  }
}

function withCompany(req, params = {}) {
  return { CompanyId: req.user.companyId, ...params };
}

function buildAuthToken(user) {
  return jwt.sign(
    {
      userId: user.UserId,
      username: user.Username,
      companyId: user.CompanyId,
      role: user.Role || 'Admin',
    },
    JWT_SECRET,
    { expiresIn: '8h' }
  );
}

function buildAuthUser(user, extras = {}) {
  const subscriptionActive = extras.subscriptionActive ?? true;
  return {
    userId: user.UserId,
    username: user.Username,
    fullName: user.FullName,
    companyId: user.CompanyId,
    companyName: user.CompanyName,
    role: user.Role || 'Admin',
    planType: extras.planType ?? user.PlanType ?? null,
    subscriptionStatus: extras.subscriptionStatus ?? user.SubscriptionStatus ?? null,
    subscriptionEnd: extras.subscriptionEnd ?? user.CompanySubscriptionEnd ?? user.SubscriptionEnd ?? null,
    subscriptionActive,
    needsPayment: extras.needsPayment ?? !subscriptionActive,
  };
}

function requireActiveSubscription(req, res, next) {
  getCompanySubscription(req.user.companyId)
    .then((sub) => {
      assertSubscriptionActive(sub);
      next();
    })
    .catch((err) => {
      res.status(402).json({
        error: err.message || 'Your subscription has expired. Please renew on the Pricing page.',
        code: 'SUBSCRIPTION_EXPIRED',
      });
    });
}

function adminAuth(req, res, next) {
  if (req.user.role !== 'Admin') {
    return res.status(403).json({ error: 'Only company admin can perform this action' });
  }
  next();
}

// SQL OPENJSON expects PascalCase keys
function toDetailJson(details = []) {
  const rows = details
    .map((d) => ({
      MaterialId: parseInt(d.MaterialId ?? d.materialId, 10),
      Quantity: parseFloat(d.Quantity ?? d.quantity),
      Rate: parseFloat(d.Rate ?? d.rate) || 0,
    }))
    .filter((d) => d.MaterialId && d.Quantity > 0);

  if (rows.length === 0) {
    throw new Error('Add at least one valid item with material and quantity');
  }
  return JSON.stringify(rows);
}

function toSalesDetailJson(details = []) {
  const rows = details
    .map((d) => ({
      MaterialId: parseInt(d.MaterialId ?? d.materialId, 10),
      LocationId: parseInt(d.LocationId ?? d.locationId, 10),
      Quantity: parseFloat(d.Quantity ?? d.quantity),
      Rate: parseFloat(d.Rate ?? d.rate) || 0,
    }))
    .filter((d) => d.MaterialId && d.LocationId && d.Quantity > 0);

  if (rows.length === 0) {
    throw new Error('Add at least one valid item with material, warehouse and quantity');
  }
  return JSON.stringify(rows);
}

async function validateSalesStock(details = [], excludeSalesId = null, companyId) {
  const demand = {};

  for (const d of details) {
    const materialId = parseInt(d.materialId ?? d.MaterialId, 10);
    const locationId = parseInt(d.locationId ?? d.LocationId, 10);
    const quantity = parseFloat(d.quantity ?? d.Quantity);

    if (!materialId || !locationId || !(quantity > 0)) continue;

    const key = `${materialId}-${locationId}`;
    if (!demand[key]) demand[key] = { materialId, locationId, quantity: 0 };
    demand[key].quantity += quantity;
  }

  const entries = Object.values(demand);
  if (entries.length === 0) {
    throw new Error('Add at least one valid item with material, warehouse and quantity');
  }

  const demandJson = JSON.stringify(entries.map((e) => ({
    materialId: e.materialId,
    locationId: e.locationId,
    quantity: e.quantity,
  })));

  const result = await query(`
    WITH demand AS (
      SELECT MaterialId, LocationId, Quantity
      FROM OPENJSON(@DemandJson)
      WITH (
        MaterialId INT '$.materialId',
        LocationId INT '$.locationId',
        Quantity DECIMAL(18, 3) '$.quantity'
      )
    )
    SELECT
      d.MaterialId,
      d.LocationId,
      d.Quantity AS RequiredQty,
      m.MaterialName,
      l.LocationName,
      ISNULL(SUM(sl.QuantityIn - sl.QuantityOut), 0)
        + CASE WHEN @ExcludeSalesId IS NULL THEN 0
          ELSE ISNULL((
            SELECT SUM(sd.Quantity)
            FROM dbo.SalesDetail sd
            INNER JOIN dbo.SalesHeader sh ON sh.SalesId = sd.SalesId AND sh.CompanyId = @CompanyId
            WHERE sd.SalesId = @ExcludeSalesId
              AND sd.MaterialId = d.MaterialId
              AND sd.LocationId = d.LocationId
          ), 0)
        END AS AvailableStock
    FROM demand d
    INNER JOIN dbo.MaterialMaster m
      ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId AND m.IsActive = 1
    INNER JOIN dbo.WarehouseLocation l
      ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId AND l.IsActive = 1
    LEFT JOIN dbo.StockLedger sl
      ON sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
    GROUP BY d.MaterialId, d.LocationId, d.Quantity, m.MaterialName, l.LocationName
  `, {
    DemandJson: demandJson,
    CompanyId: companyId,
    ExcludeSalesId: excludeSalesId || null,
  });

  const stockByKey = new Map(
    result.recordset.map((row) => [`${row.MaterialId}-${row.LocationId}`, row])
  );

  for (const entry of entries) {
    const row = stockByKey.get(`${entry.materialId}-${entry.locationId}`);
    if (!row) {
      throw new Error('Invalid material or warehouse on one or more lines');
    }
    const available = Number(row.AvailableStock || 0);
    if (entry.quantity > available) {
      throw new Error(
        `Insufficient stock: ${row.MaterialName} @ ${row.LocationName} — required ${entry.quantity}, available ${available}`
      );
    }
  }
}

async function validatePurchaseDelete(purchaseId, companyId) {
  const header = await query(`
    SELECT PurchaseId FROM dbo.PurchaseInwardHeader
    WHERE PurchaseId = @PurchaseId AND CompanyId = @CompanyId
  `, { PurchaseId: purchaseId, CompanyId: companyId });

  if (!header.recordset[0]) {
    throw new Error('Purchase record not found');
  }

  const lines = await query(`
    SELECT d.MaterialId, d.LocationId, SUM(d.Quantity) AS TotalQty, m.MaterialName, l.LocationName,
           ISNULL((
             SELECT SUM(sl.QuantityIn - sl.QuantityOut)
             FROM dbo.StockLedger sl
             WHERE sl.MaterialId = d.MaterialId AND sl.LocationId = d.LocationId AND sl.CompanyId = @CompanyId
           ), 0) AS AvailableStock
    FROM dbo.PurchaseInwardDetail d
    INNER JOIN dbo.MaterialMaster m ON m.MaterialId = d.MaterialId AND m.CompanyId = @CompanyId
    INNER JOIN dbo.WarehouseLocation l ON l.LocationId = d.LocationId AND l.CompanyId = @CompanyId
    WHERE d.PurchaseId = @PurchaseId
    GROUP BY d.MaterialId, d.LocationId, m.MaterialName, l.LocationName
  `, { PurchaseId: purchaseId, CompanyId: companyId });

  for (const row of lines.recordset) {
    const after = Number(row.AvailableStock) - Number(row.TotalQty);
    if (after < 0) {
      throw new Error(
        `Cannot delete/update: ${row.MaterialName} @ ${row.LocationName} — stock would become ${after} (quantity already used in sales)`
      );
    }
  }
}

async function processPurchaseSave(reqBody, companyId) {
  const { purchaseDate, supplierName, remark, details } = reqBody;

  let createdSupplier = false;
  if (supplierName?.trim()) {
    const before = await findSupplierByName(supplierName.trim(), companyId);
    await ensureSupplierMaster(supplierName.trim(), companyId);
    createdSupplier = !before;
  }

  const { resolved, createdMaterials } = await resolvePurchaseDetails(details || [], companyId);
  const locationId = resolved[0]?.locationId || null;
  return {
    purchaseDate,
    locationId,
    supplierName: supplierName?.trim() || null,
    remark: remark || null,
    detailsJson: buildPurchaseDetailJson(resolved),
    createdSupplier,
    createdMaterials,
  };
}

function stockErrorStatus(err) {
  const msg = err.message || 'Operation failed';
  if (isLimitError(msg)) return { msg, status: 400 };
  const isStock = /insufficient stock|stock|warehouse|cannot delete|cannot update/i.test(msg);
  return { msg, status: isStock ? 400 : 500 };
}

async function findSupplierByName(supplierName, companyId) {
  const result = await query(`
    SELECT SupplierId, SupplierName
    FROM dbo.SupplierMaster
    WHERE IsActive = 1 AND CompanyId = @CompanyId
      AND LOWER(LTRIM(RTRIM(SupplierName))) = LOWER(LTRIM(RTRIM(@SupplierName)))
  `, { SupplierName: supplierName, CompanyId: companyId });
  return result.recordset[0] || null;
}

async function ensureSupplierMaster(supplierName, companyId) {
  const trimmed = supplierName.trim();
  if (!trimmed) return null;

  const existing = await findSupplierByName(trimmed, companyId);
  if (existing) return existing;

  await execProc('sp_SaveSupplier', {
    CompanyId: companyId,
    SupplierId: null,
    SupplierName: trimmed,
    GSTNo: null,
    MobileNo: null,
    Address1: null,
    Address2: null,
    Remark: 'Auto-created from Purchase Inward',
    Email: null,
  });
  return findSupplierByName(trimmed, companyId);
}

async function findMaterialByName(materialName, companyId) {
  const result = await query(`
    SELECT MaterialId, MaterialName, Rate, ISNULL(SalesRate, 0) AS SalesRate
    FROM dbo.MaterialMaster
    WHERE IsActive = 1 AND CompanyId = @CompanyId
      AND LOWER(LTRIM(RTRIM(MaterialName))) = LOWER(LTRIM(RTRIM(@MaterialName)))
  `, { MaterialName: materialName, CompanyId: companyId });
  return result.recordset[0] || null;
}

async function ensureMaterialMaster(materialName, companyId, rate = 0) {
  const trimmed = materialName.trim();
  if (!trimmed) return null;

  const existing = await findMaterialByName(trimmed, companyId);
  if (existing) {
    const parsedRate = parseFloat(rate) || 0;
    if (parsedRate > 0 && Number(existing.Rate) !== parsedRate) {
      // Update purchase rate only — do not wipe Color/HSN/SalesRate via full save
      await query(`
        UPDATE dbo.MaterialMaster
        SET Rate = @Rate, UpdatedAt = SYSUTCDATETIME()
        WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId
      `, { Rate: parsedRate, MaterialId: existing.MaterialId, CompanyId: companyId });
    }
    return existing;
  }

  await assertCanAddMaterial(companyId);
  await execProc('sp_SaveMaterial', {
    CompanyId: companyId,
    MaterialId: null,
    MaterialName: trimmed,
    Color: null,
    HSNCode: null,
    Rate: parseFloat(rate) || 0,
    SalesRate: 0,
    Unit: 'Pcs',
    Remark: 'Auto-created from Purchase Inward',
  });
  return findMaterialByName(trimmed, companyId);
}

async function resolvePurchaseDetails(details = [], companyId) {
  const resolved = [];
  let createdMaterials = 0;

  for (const d of details) {
    const quantity = parseFloat(d.quantity ?? d.Quantity);
    const rate = parseFloat(d.rate ?? d.Rate) || 0;
    let materialId = parseInt(d.materialId ?? d.MaterialId, 10) || null;
    const locationId = parseInt(d.locationId ?? d.LocationId, 10) || null;
    const materialName = (d.materialName ?? d.MaterialName ?? '').trim();

    if (!locationId) {
      throw new Error('Each row needs a warehouse location');
    }

    const locCheck = await query(`
      SELECT LocationId FROM dbo.WarehouseLocation
      WHERE LocationId = @LocationId AND CompanyId = @CompanyId AND IsActive = 1
    `, { LocationId: locationId, CompanyId: companyId });
    if (!locCheck.recordset[0]) {
      throw new Error(`Invalid or inactive warehouse for location ID ${locationId}`);
    }

    if (!materialId && materialName) {
      const before = await findMaterialByName(materialName, companyId);
      const material = await ensureMaterialMaster(materialName, companyId, rate);
      if (!before && material) createdMaterials += 1;
      materialId = material?.MaterialId;
    } else if (materialId && materialName) {
      const material = await ensureMaterialMaster(materialName, companyId, rate);
      materialId = material?.MaterialId || materialId;
    } else if (materialId) {
      const result = await query(`
        SELECT MaterialId FROM dbo.MaterialMaster
        WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1
      `, { MaterialId: materialId, CompanyId: companyId });
      if (!result.recordset[0]) {
        throw new Error(`Material not found for ID ${materialId}`);
      }
    }

    if (!materialId || !(quantity > 0)) {
      throw new Error('Each row needs material name, warehouse and quantity');
    }

    resolved.push({ materialId, locationId, quantity, rate });
  }

  if (resolved.length === 0) {
    throw new Error('Add at least one item with material name, warehouse and quantity');
  }

  return { resolved, createdMaterials };
}

function buildPurchaseDetailJson(resolved = []) {
  const rows = resolved
    .map((d) => ({
      MaterialId: parseInt(d.materialId ?? d.MaterialId, 10),
      LocationId: parseInt(d.locationId ?? d.LocationId, 10),
      Quantity: parseFloat(d.quantity ?? d.Quantity),
      Rate: parseFloat(d.rate ?? d.Rate) || 0,
    }))
    .filter((d) =>
      Number.isFinite(d.MaterialId) && d.MaterialId > 0
      && Number.isFinite(d.LocationId) && d.LocationId > 0
      && d.Quantity > 0
    );

  if (rows.length === 0) {
    throw new Error('Add at least one valid item with material, warehouse and quantity');
  }
  return JSON.stringify(rows);
}

async function isUsernameTaken(username) {
  const trimmed = String(username || '').trim();
  if (!trimmed) return false;
  const result = await query(`
    SELECT TOP 1 UserId FROM dbo.Users WHERE LOWER(Username) = LOWER(@Username)
  `, { Username: trimmed });
  return !!result.recordset[0];
}

/* ========== AUTH ========== */
app.post('/api/auth/login', authRateLimiter, async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username?.trim() || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const result = await execProc('sp_GetUserByUsername', { Username: String(username).trim() });
    const user = result.recordset[0];
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const valid = await verifyPassword(user.PasswordHash, password);
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });
    if (!user.IsActive) {
      return res.status(401).json({ error: 'Your account is not active. Contact your company admin.' });
    }
    if (user.PaymentStatus === 'Pending') {
      return res.status(401).json({ error: 'Payment pending. Your admin must complete payment before you can login.' });
    }

    let sub = null;
    try {
      sub = await getCompanySubscription(user.CompanyId);
    } catch {
      /* still allow login; paywall is decided from whatever we have */
    }
    const subscriptionActive = isSubscriptionActive(sub);
    const companyEnd = sub?.SubscriptionEnd || user.CompanySubscriptionEnd || null;

    // Team user's own access window ended, but the company plan is still active
    if (
      subscriptionActive
      && user.CompanySubscriptionEnd
      && user.SubscriptionEnd
      && new Date(user.SubscriptionEnd) < new Date()
    ) {
      return res.status(401).json({ error: 'Your access has expired. Contact your company admin.' });
    }

    const token = buildAuthToken(user);
    res.json({
      token,
      user: buildAuthUser(user, {
        planType: sub?.PlanType || user.PlanType,
        subscriptionStatus: sub?.SubscriptionStatus || user.SubscriptionStatus,
        subscriptionEnd: companyEnd,
        subscriptionActive,
        needsPayment: !subscriptionActive,
      }),
    });
  } catch (err) {
    res.status(500).json({ error: safeErrorMessage(err) });
  }
});

app.get('/api/auth/check-username', checkUsernameRateLimiter, async (req, res) => {
  try {
    const username = String(req.query.username || '').trim();
    if (!username) {
      return res.status(400).json({ error: 'Username is required' });
    }
    if (username.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }
    const taken = await isUsernameTaken(username);
    res.json({ available: !taken, username });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/auth/register', authRateLimiter, async (req, res) => {
  try {
    const {
      username, password, firstName, lastName, email,
      companyName, companyGSTNo, companyAddress1, companyAddress2, companyDescription,
    } = req.body;

    if (!username?.trim() || !password || !firstName?.trim() || !companyName?.trim()) {
      return res.status(400).json({ error: 'Username, password, first name and company name are required' });
    }

    const trimmedUsername = validateUsername(username);
    validatePassword(password);

    if (await isUsernameTaken(trimmedUsername)) {
      return res.status(400).json({ error: 'Username already exists. Please choose another.' });
    }

    const hash = await hashPassword(password);
    const result = await execProc('sp_RegisterAccount', {
      Username: trimmedUsername,
      PasswordHash: hash,
      FirstName: firstName.trim(),
      LastName: lastName?.trim() || null,
      Email: email?.trim() || null,
      CompanyName: companyName.trim(),
      CompanyGSTNo: companyGSTNo?.trim() || null,
      CompanyAddress1: companyAddress1?.trim() || null,
      CompanyAddress2: companyAddress2?.trim() || null,
      CompanyDescription: companyDescription?.trim() || null,
      CompanyNameColor: '#f97316',
    });

    const account = result.recordset[0];
    account.Role = account.Role || 'Admin';
    account.PlanType = 'Trial';
    account.SubscriptionStatus = 'Active';
    await ensureCompanyTrialSubscription(account.CompanyId);
    const token = buildAuthToken(account);

    res.status(201).json({
      token,
      user: buildAuthUser(account),
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

/* ========== PLANS & BILLING ========== */
app.get('/api/plans', (req, res) => {
  res.set('Cache-Control', 'public, max-age=300');
  res.json({ trialDays: TRIAL_DAYS, plans: listPlansForApi() });
});

app.get('/api/billing/config', auth, (req, res) => {
  res.json({ keyId: RAZORPAY_KEY_ID, configured: !!razorpay });
});

app.get('/api/billing/subscription', auth, async (req, res) => {
  try {
    const sub = await getCompanySubscription(req.user.companyId);
    if (!sub) return res.json({});
    const counts = await getActiveCounts(req.user.companyId);
    res.json({
      ...sub,
      ActiveUsers: counts.activeUsers,
      ActiveWarehouses: counts.activeWarehouses,
      ActiveMaterials: counts.activeMaterials,
      subscriptionActive: isSubscriptionActive(sub),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/billing/limits', auth, async (req, res) => {
  try {
    const sub = await getCompanySubscription(req.user.companyId);
    if (!sub) return res.status(404).json({ error: 'Company not found' });
    const activeCounts = await getActiveCounts(req.user.companyId);
    const limits = getEffectiveLimits(sub, activeCounts);
    const subscriptionActive = isSubscriptionActive(sub);
    res.json({
      ...limits,
      subscriptionEnd: sub.SubscriptionEnd,
      subscriptionStatus: sub.SubscriptionStatus,
      subscriptionActive,
      canAddUserFree: limits.activeUsers < limits.maxUsers,
      needsPaymentForUser: limits.activeUsers >= limits.maxUsers,
      canAddUser: subscriptionActive,
      canAddWarehouse: subscriptionActive && (isUnlimited(limits.maxWarehouses) || limits.activeWarehouses < limits.maxWarehouses),
      canAddMaterial: subscriptionActive && (isUnlimited(limits.maxMaterials) || limits.activeMaterials < limits.maxMaterials),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/billing/create-order', auth, adminAuth, async (req, res) => {
  try {
    if (!razorpay) return res.status(503).json({ error: 'Payment gateway not configured' });

    const { planId, billingCycle } = req.body;
    const plan = getPlan(planId);
    if (!plan || plan.listed === false) return res.status(400).json({ error: 'Invalid plan selected' });
    const cycle = billingCycle === 'yearly' ? 'yearly' : 'monthly';
    const amountPaise = getPlanAmountPaise(planId, cycle);
    if (!amountPaise) return res.status(400).json({ error: 'Invalid billing cycle' });

    const order = await razorpay.orders.create({
      amount: amountPaise,
      currency: 'INR',
      receipt: `sub_${req.user.companyId}_${Date.now()}`,
      notes: {
        companyId: String(req.user.companyId),
        planId,
        billingCycle: cycle,
        userId: String(req.user.userId),
      },
    });

    await execProc('sp_SavePaymentHistory', {
      CompanyId: req.user.companyId,
      PlanType: plan.id,
      BillingCycle: cycle,
      AmountPaise: amountPaise,
      RazorpayOrderId: order.id,
      RazorpayPaymentId: null,
      PaymentStatus: 'Created',
      UserId: null,
      PaymentType: 'Subscription',
    });

    res.json({
      orderId: order.id,
      amountPaise,
      currency: 'INR',
      keyId: RAZORPAY_KEY_ID,
      planId: plan.id,
      billingCycle: cycle,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/billing/verify', auth, adminAuth, async (req, res) => {
  try {
    if (!RAZORPAY_KEY_SECRET) return res.status(503).json({ error: 'Payment gateway not configured' });

    const {
      razorpay_order_id: orderId,
      razorpay_payment_id: paymentId,
      razorpay_signature: signature,
      planId,
      billingCycle,
    } = req.body;

    if (!orderId || !paymentId || !signature || !planId) {
      return res.status(400).json({ error: 'Payment verification data is incomplete' });
    }

    verifyRazorpaySignature(orderId, paymentId, signature, RAZORPAY_KEY_SECRET);
    await assertPaymentOrderForCompany(req.user.companyId, orderId, 'Subscription');

    const plan = getPlan(planId);
    if (!plan || plan.listed === false) return res.status(400).json({ error: 'Invalid plan' });

    const cycle = billingCycle === 'yearly' ? 'yearly' : 'monthly';
    const amountPaise = getPlanAmountPaise(planId, cycle);
    const start = new Date();
    const end = getSubscriptionEndDate(cycle);

    const subResult = await execProc('sp_UpdateCompanySubscription', {
      CompanyId: req.user.companyId,
      PlanType: plan.id,
      BillingCycle: cycle,
      SubscriptionStatus: 'Active',
      SubscriptionStart: start,
      SubscriptionEnd: end,
      MaxUsers: plan.maxUsers,
      MaxWarehouses: plan.maxWarehouses,
      MaxMaterials: plan.maxMaterials,
      RazorpayOrderId: orderId,
      RazorpayPaymentId: paymentId,
    });
    invalidateSubscriptionCache(req.user.companyId);

    await execProc('sp_SavePaymentHistory', {
      CompanyId: req.user.companyId,
      PlanType: plan.id,
      BillingCycle: cycle,
      AmountPaise: amountPaise,
      RazorpayOrderId: orderId,
      RazorpayPaymentId: paymentId,
      PaymentStatus: 'Paid',
      UserId: null,
      PaymentType: 'Subscription',
    });

    const user = JSON.parse(JSON.stringify(req.user));
    user.planType = plan.id;
    const token = jwt.sign(user, JWT_SECRET, { expiresIn: '8h' });

    res.json({
      success: true,
      token,
      subscription: subResult.recordset[0],
      planType: plan.id,
      subscriptionActive: true,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ========== COMPANY USERS ========== */
app.get('/api/company/users/proration-preview', auth, adminAuth, async (req, res) => {
  try {
    const subscription = await getCompanySubscription(req.user.companyId);
    if (!subscription) return res.status(404).json({ error: 'Company not found' });
    const limits = getEffectiveLimits(subscription);
    const paymentRequired = needsPaymentForNewUser(limits);
    const proration = paymentRequired ? calculateProratedUserAmount(subscription) : null;
    res.json({ paymentRequired, proration, limits, subscriptionEnd: subscription.SubscriptionEnd });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/company/users', auth, adminAuth, async (req, res) => {
  try {
    const result = await execProc('sp_GetCompanyUsers', { CompanyId: req.user.companyId });
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/company/users', auth, adminAuth, requireActiveSubscription, async (req, res) => {
  try {
    const { username, password, firstName, lastName, email } = req.body;
    if (!username?.trim() || !password || !firstName?.trim()) {
      return res.status(400).json({ error: 'Username, password and first name are required' });
    }

    const trimmedUsername = validateUsername(username);
    validatePassword(password);

    const subscription = await getCompanySubscription(req.user.companyId);
    if (!subscription?.SubscriptionEnd) {
      return res.status(400).json({ error: 'Company subscription end date not found' });
    }
    assertSubscriptionActive(subscription);

    const limits = getEffectiveLimits(subscription);
    const paymentRequired = needsPaymentForNewUser(limits);
    if (!paymentRequired) {
      await assertCanAddUser(req.user.companyId);
    }
    const proration = paymentRequired ? calculateProratedUserAmount(subscription) : null;

    const hash = await hashPassword(password);
    const result = await execProc('sp_AddCompanyUser', {
      CompanyId: req.user.companyId,
      RequestedBy: req.user.userId,
      Username: trimmedUsername,
      PasswordHash: hash,
      FirstName: firstName.trim(),
      LastName: lastName?.trim() || null,
      Email: email?.trim() || null,
      IsActive: paymentRequired ? 0 : 1,
      PaymentStatus: paymentRequired ? 'Pending' : 'Paid',
      SubscriptionEnd: subscription.SubscriptionEnd,
      AllowOverLimit: paymentRequired ? 1 : 0,
    });

    const newUser = result.recordset[0];
    invalidateSubscriptionCache(req.user.companyId);

    if (!paymentRequired) {
      return res.status(201).json({ needsPayment: false, user: newUser });
    }

    if (!razorpay) {
      return res.status(503).json({ error: 'Payment gateway not configured' });
    }

    const order = await razorpay.orders.create({
      amount: proration.amountPaise,
      currency: 'INR',
      receipt: `user_${newUser.UserId}_${Date.now()}`,
      notes: {
        companyId: String(req.user.companyId),
        userId: String(newUser.UserId),
        paymentType: 'AddUser',
        requestedBy: String(req.user.userId),
      },
    });

    await execProc('sp_SavePaymentHistory', {
      CompanyId: req.user.companyId,
      PlanType: subscription.PlanType || 'standard',
      BillingCycle: subscription.BillingCycle || 'monthly',
      AmountPaise: proration.amountPaise,
      RazorpayOrderId: order.id,
      RazorpayPaymentId: null,
      PaymentStatus: 'Created',
      UserId: newUser.UserId,
      PaymentType: 'AddUser',
    });

    res.status(201).json({
      needsPayment: true,
      user: newUser,
      proration,
      order: {
        orderId: order.id,
        amountPaise: proration.amountPaise,
        keyId: RAZORPAY_KEY_ID,
      },
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/company/users/:id/create-order', auth, adminAuth, requireActiveSubscription, async (req, res) => {
  try {
    if (!razorpay) return res.status(503).json({ error: 'Payment gateway not configured' });

    const userId = parseInt(req.params.id, 10);
    const pending = await query(`
      SELECT UserId, Username, PaymentStatus, IsActive
      FROM dbo.Users
      WHERE UserId = @UserId AND CompanyId = @CompanyId AND PaymentStatus = N'Pending'
    `, { UserId: userId, CompanyId: req.user.companyId });

    if (!pending.recordset[0]) {
      return res.status(404).json({ error: 'Pending user not found' });
    }

    const subscription = await getCompanySubscription(req.user.companyId);
    const proration = calculateProratedUserAmount(subscription);

    const order = await razorpay.orders.create({
      amount: proration.amountPaise,
      currency: 'INR',
      receipt: `user_${userId}_${Date.now()}`,
      notes: {
        companyId: String(req.user.companyId),
        userId: String(userId),
        paymentType: 'AddUser',
        requestedBy: String(req.user.userId),
      },
    });

    await execProc('sp_SavePaymentHistory', {
      CompanyId: req.user.companyId,
      PlanType: subscription.PlanType || 'standard',
      BillingCycle: subscription.BillingCycle || 'monthly',
      AmountPaise: proration.amountPaise,
      RazorpayOrderId: order.id,
      RazorpayPaymentId: null,
      PaymentStatus: 'Created',
      UserId: userId,
      PaymentType: 'AddUser',
    });

    res.json({
      orderId: order.id,
      amountPaise: proration.amountPaise,
      keyId: RAZORPAY_KEY_ID,
      proration,
      username: pending.recordset[0].Username,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/company/users/verify-payment', auth, adminAuth, async (req, res) => {
  try {
    if (!RAZORPAY_KEY_SECRET) return res.status(503).json({ error: 'Payment gateway not configured' });

    const {
      razorpay_order_id: orderId,
      razorpay_payment_id: paymentId,
      razorpay_signature: signature,
      userId,
    } = req.body;

    if (!orderId || !paymentId || !signature || !userId) {
      return res.status(400).json({ error: 'Payment verification data is incomplete' });
    }

    verifyRazorpaySignature(orderId, paymentId, signature, RAZORPAY_KEY_SECRET);
    await assertPaymentOrderForCompany(req.user.companyId, orderId, 'AddUser', parseInt(userId, 10));

    const subscription = await getCompanySubscription(req.user.companyId);
    const proration = calculateProratedUserAmount(subscription);

    const activateResult = await execProc('sp_ActivateCompanyUser', {
      CompanyId: req.user.companyId,
      RequestedBy: req.user.userId,
      UserId: parseInt(userId, 10),
      RazorpayOrderId: orderId,
      RazorpayPaymentId: paymentId,
    });

    await execProc('sp_SavePaymentHistory', {
      CompanyId: req.user.companyId,
      PlanType: subscription.PlanType || 'standard',
      BillingCycle: subscription.BillingCycle || 'monthly',
      AmountPaise: proration.amountPaise,
      RazorpayOrderId: orderId,
      RazorpayPaymentId: paymentId,
      PaymentStatus: 'Paid',
      UserId: parseInt(userId, 10),
      PaymentType: 'AddUser',
    });

    res.json({
      success: true,
      user: activateResult.recordset[0],
      message: 'User activated. They can now login until the company subscription end date.',
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete('/api/company/users/:id', auth, adminAuth, requireActiveSubscription, async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    if (userId === req.user.userId) {
      return res.status(400).json({ error: 'You cannot deactivate your own account.' });
    }
    await execProc('sp_DeactivateCompanyUser', {
      CompanyId: req.user.companyId,
      RequestedBy: req.user.userId,
      UserId: userId,
    });
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

/* ========== MY ACCOUNT ========== */
app.get('/api/account/profile', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetUserProfile', { UserId: req.user.userId });
    const profile = result.recordset[0];
    if (!profile) return res.status(404).json({ error: 'Profile not found' });
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/account/profile', auth, async (req, res) => {
  try {
    const {
      firstName, lastName, email, companyName, companyGSTNo,
      companyAddress1, companyAddress2, companyLogo, companyDescription, companyNameColor,
    } = req.body;
    const logo = typeof companyLogo === 'string' && companyLogo.startsWith('data:image/')
      ? companyLogo
      : (companyLogo ? String(companyLogo) : null);
    if (logo && logo.length > 2_500_000) {
      return res.status(400).json({ error: 'Logo is too large. Please upload a smaller image.' });
    }
    const result = await execProc('sp_SaveUserProfile', {
      UserId: req.user.userId,
      FirstName: firstName || null,
      LastName: lastName || null,
      Email: email || null,
      CompanyName: companyName || null,
      CompanyGSTNo: companyGSTNo || null,
      CompanyAddress1: companyAddress1 || null,
      CompanyAddress2: companyAddress2 || null,
      CompanyLogo: logo,
      CompanyDescription: companyDescription || null,
      CompanyNameColor: companyNameColor || '#f97316',
    });
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/account/password', auth, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current and new password are required' });
    }
    validatePassword(newPassword, 'New password');

    const userResult = await execProc('sp_GetUserByUsername', { Username: req.user.username });
    const user = userResult.recordset[0];
    if (!user) return res.status(404).json({ error: 'User not found' });

    const valid = await verifyPassword(user.PasswordHash, currentPassword);
    if (!valid) return res.status(400).json({ error: 'Current password is incorrect' });

    const hash = await hashPassword(newPassword);
    await execProc('sp_UpdateUserPassword', { UserId: req.user.userId, PasswordHash: hash });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/account/invoices', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetCompanyPaymentHistory', { CompanyId: req.user.companyId });
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ========== DASHBOARD ========== */
app.get('/api/dashboard', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetDashboardStats', withCompany(req));
    res.json(result.recordset[0] || {});
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ========== LOCATIONS ========== */
app.get('/api/locations', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetLocations', withCompany(req));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/locations', auth, requireActiveSubscription, async (req, res) => {
  try {
    const { locationId, locationName, address, city } = req.body;
    const id = parseInt(locationId, 10);
    if (!id) {
      await assertCanAddWarehouse(req.user.companyId);
    }
    const result = await execProc('sp_SaveLocation', withCompany(req, {
      LocationId: id || null,
      LocationName: locationName,
      Address: address || null,
      City: city || null,
    }));
    if (!id) invalidateSubscriptionCache(req.user.companyId);
    res.json(result.recordset[0]);
  } catch (err) {
    const status = isLimitError(err.message) ? 400 : 500;
    res.status(status).json({ error: err.message });
  }
});

app.delete('/api/locations/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const locationId = parseInt(req.params.id, 10);
    const check = await query(`
      SELECT
        (SELECT COUNT(*) FROM OpeningStock WHERE LocationId = @LocationId AND CompanyId = @CompanyId) AS OpeningCount,
        (SELECT COUNT(*) FROM PurchaseInwardHeader WHERE LocationId = @LocationId AND CompanyId = @CompanyId) AS PurchaseCount,
        (SELECT COUNT(*) FROM SalesHeader WHERE LocationId = @LocationId AND CompanyId = @CompanyId) AS SalesCount,
        (SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0) FROM StockLedger WHERE LocationId = @LocationId AND CompanyId = @CompanyId) AS CurrentStock
    `, { LocationId: locationId, CompanyId: req.user.companyId });
    const row = check.recordset[0] || {};
    if (row.OpeningCount > 0 || row.PurchaseCount > 0 || row.SalesCount > 0 || row.CurrentStock > 0) {
      return res.status(400).json({
        error: 'Cannot delete this warehouse. It is used in opening stock, purchase, sales, or stock is still present.',
      });
    }
    await query(
      'UPDATE dbo.WarehouseLocation SET IsActive = 0 WHERE LocationId = @LocationId AND CompanyId = @CompanyId',
      { LocationId: locationId, CompanyId: req.user.companyId }
    );
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

/* ========== MATERIALS ========== */
app.get('/api/materials', auth, async (req, res) => {
  try {
    const { search } = req.query;
    const result = await execProc('sp_GetMaterials', withCompany(req));
    let rows = result.recordset;
    if (search && String(search).length >= 3) {
      const q = String(search).toLowerCase();
      rows = rows.filter((m) =>
        [m.MaterialName, m.Color, m.HSNCode].some((f) => (f || '').toLowerCase().includes(q))
      );
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/materials/:id', auth, async (req, res) => {
  try {
    const materialId = parseInt(req.params.id, 10);
    const result = await query(`
      SELECT MaterialId, MaterialName, Color, HSNCode, Rate, ISNULL(SalesRate, 0) AS SalesRate,
             Unit, Remark, IsActive, CreatedAt, UpdatedAt
      FROM dbo.MaterialMaster
      WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1
    `, { MaterialId: materialId, CompanyId: req.user.companyId });
    if (!result.recordset[0]) return res.status(404).json({ error: 'Material not found' });
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/materials', auth, requireActiveSubscription, async (req, res) => {
  try {
    const { materialId, materialName, color, hsnCode, rate, salesRate, unit, remark } = req.body;
    const id = parseInt(materialId, 10);
    if (!id) {
      await assertCanAddMaterial(req.user.companyId);
    }
    const result = await execProc('sp_SaveMaterial', withCompany(req, {
      MaterialId: id || null,
      MaterialName: materialName,
      Color: color || null,
      HSNCode: hsnCode || null,
      Rate: rate != null && rate !== '' ? parseFloat(rate) : 0,
      SalesRate: salesRate != null && salesRate !== '' ? parseFloat(salesRate) : 0,
      Unit: unit || 'Pcs',
      Remark: remark || null,
    }));
    if (!id) invalidateSubscriptionCache(req.user.companyId);
    res.json(result.recordset[0]);
  } catch (err) {
    const status = isLimitError(err.message) ? 400 : 500;
    res.status(status).json({ error: err.message });
  }
});

app.delete('/api/materials/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const materialId = parseInt(req.params.id, 10);
    const check = await query(`
      SELECT
        (SELECT COUNT(*) FROM OpeningStock WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId) AS OpeningCount,
        (SELECT COUNT(*) FROM dbo.PurchaseInwardDetail d INNER JOIN dbo.PurchaseInwardHeader h ON h.PurchaseId = d.PurchaseId WHERE d.MaterialId = @MaterialId AND h.CompanyId = @CompanyId) AS PurchaseCount,
        (SELECT COUNT(*) FROM dbo.SalesDetail d INNER JOIN dbo.SalesHeader h ON h.SalesId = d.SalesId WHERE d.MaterialId = @MaterialId AND h.CompanyId = @CompanyId) AS SalesCount,
        (SELECT ISNULL(SUM(QuantityIn - QuantityOut), 0) FROM StockLedger WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId) AS CurrentStock
    `, { MaterialId: materialId, CompanyId: req.user.companyId });
    const row = check.recordset[0] || {};
    if (row.OpeningCount > 0 || row.PurchaseCount > 0 || row.SalesCount > 0 || row.CurrentStock > 0) {
      return res.status(400).json({
        error: 'Cannot delete this material. It is used in opening stock, purchase, sales, or stock is still present.',
      });
    }
    await execProc('sp_DeleteMaterial', withCompany(req, { MaterialId: materialId }));
    invalidateSubscriptionCache(req.user.companyId);
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

/* ========== SUPPLIERS ========== */
app.get('/api/suppliers', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetSuppliers', withCompany(req));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/suppliers', auth, requireActiveSubscription, async (req, res) => {
  try {
    const {
      supplierId, supplierName, gstNo, mobileNo, address1, address2, remark, email,
    } = req.body;
    const result = await execProc('sp_SaveSupplier', withCompany(req, {
      SupplierId: supplierId || null,
      SupplierName: supplierName,
      GSTNo: gstNo || null,
      MobileNo: mobileNo || null,
      Address1: address1 || null,
      Address2: address2 || null,
      Remark: remark || null,
      Email: email || null,
    }));
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.delete('/api/suppliers/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    await execProc('sp_DeleteSupplier', withCompany(req, { SupplierId: parseInt(req.params.id, 10) }));
    res.json({ success: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

/* ========== OPENING STOCK ========== */
app.get('/api/opening-stock', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetOpeningStock', withCompany(req));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/opening-stock', auth, requireActiveSubscription, async (req, res) => {
  try {
    const { materialId, locationId, quantity, rate, stockDate, remark } = req.body;
    const result = await execProc('sp_SaveOpeningStock', withCompany(req, {
      MaterialId: materialId,
      LocationId: locationId,
      Quantity: quantity,
      Rate: rate != null && rate !== '' ? parseFloat(rate) : null,
      StockDate: stockDate || null,
      Remark: remark || null,
    }));
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ========== PURCHASE INWARD ========== */
app.get('/api/purchase-inward', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetPurchaseInward', withCompany(req));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/purchase-inward', auth, requireActiveSubscription, async (req, res) => {
  try {
    const processed = await processPurchaseSave(req.body, req.user.companyId);
    const result = await execProc('sp_SavePurchaseInward', withCompany(req, {
      PurchaseDate: processed.purchaseDate,
      LocationId: processed.locationId,
      SupplierName: processed.supplierName,
      Remark: processed.remark,
      DetailsJson: processed.detailsJson,
    }));
    res.json({
      ...result.recordset[0],
      createdSupplier: processed.createdSupplier,
      createdMaterials: processed.createdMaterials,
    });
  } catch (err) {
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

app.put('/api/purchase-inward/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const purchaseId = parseInt(req.params.id, 10);
    await validatePurchaseDelete(purchaseId, req.user.companyId);
    const processed = await processPurchaseSave(req.body, req.user.companyId);
    const result = await execProc('sp_UpdatePurchaseInward', withCompany(req, {
      PurchaseId: purchaseId,
      PurchaseDate: processed.purchaseDate,
      LocationId: processed.locationId,
      SupplierName: processed.supplierName,
      Remark: processed.remark,
      DetailsJson: processed.detailsJson,
    }));
    res.json({
      ...result.recordset[0],
      createdSupplier: processed.createdSupplier,
      createdMaterials: processed.createdMaterials,
    });
  } catch (err) {
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

app.delete('/api/purchase-inward/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const purchaseId = parseInt(req.params.id, 10);
    await validatePurchaseDelete(purchaseId, req.user.companyId);
    await execProc('sp_DeletePurchaseInward', withCompany(req, { PurchaseId: purchaseId }));
    res.json({ success: true });
  } catch (err) {
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

/* ========== CUSTOMERS (from sales history) ========== */
app.get('/api/customers', auth, async (req, res) => {
  try {
    const { search } = req.query;
    const result = await query(`
      SELECT DISTINCT CustomerName
      FROM dbo.SalesHeader
      WHERE CompanyId = @CompanyId
        AND CustomerName IS NOT NULL AND LTRIM(RTRIM(CustomerName)) <> ''
      ORDER BY CustomerName
    `, { CompanyId: req.user.companyId });
    let rows = result.recordset.map((r) => ({ CustomerName: r.CustomerName }));
    if (search && String(search).length >= 3) {
      const q = String(search).toLowerCase();
      rows = rows.filter((r) => r.CustomerName.toLowerCase().includes(q));
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/* ========== SALES ========== */
app.get('/api/sales', auth, async (req, res) => {
  try {
    const result = await execProc('sp_GetSales', withCompany(req));
    const rows = result.recordset || [];

    const applyExtras = (map) => {
      rows.forEach((r) => {
        const extra = map.get(Number(r.SalesId));
        if (!extra) return;
        if ('TermsAndConditions' in extra) r.TermsAndConditions = extra.TermsAndConditions;
        if ('CustomerAddress1' in extra) r.CustomerAddress1 = extra.CustomerAddress1;
        if ('CustomerAddress2' in extra) r.CustomerAddress2 = extra.CustomerAddress2;
        if ('CustomerGSTNo' in extra) r.CustomerGSTNo = extra.CustomerGSTNo;
      });
    };

    try {
      const extraRes = await query(`
        SELECT SalesId, TermsAndConditions, CustomerAddress1, CustomerAddress2, CustomerGSTNo
        FROM dbo.SalesHeader
        WHERE CompanyId = @CompanyId
      `, { CompanyId: req.user.companyId });
      applyExtras(new Map((extraRes.recordset || []).map((t) => [Number(t.SalesId), t])));
    } catch {
      // Partial migrations: load available columns separately
      try {
        const termsRes = await query(`
          SELECT SalesId, TermsAndConditions FROM dbo.SalesHeader WHERE CompanyId = @CompanyId
        `, { CompanyId: req.user.companyId });
        applyExtras(new Map((termsRes.recordset || []).map((t) => [Number(t.SalesId), {
          TermsAndConditions: t.TermsAndConditions,
        }])));
      } catch { /* ignore */ }
      try {
        const billRes = await query(`
          SELECT SalesId, CustomerAddress1, CustomerAddress2, CustomerGSTNo
          FROM dbo.SalesHeader WHERE CompanyId = @CompanyId
        `, { CompanyId: req.user.companyId });
        applyExtras(new Map((billRes.recordset || []).map((t) => [Number(t.SalesId), {
          CustomerAddress1: t.CustomerAddress1,
          CustomerAddress2: t.CustomerAddress2,
          CustomerGSTNo: t.CustomerGSTNo,
        }])));
      } catch { /* ignore */ }
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function saveSalesHeaderExtras(salesId, companyId, extras = {}) {
  if (!salesId || !companyId) return;
  const {
    termsAndConditions = null,
    customerAddress1 = null,
    customerAddress2 = null,
    customerGSTNo = null,
  } = extras;

  const id = Number(salesId);
  const termsVal = termsAndConditions == null ? null : String(termsAndConditions);
  const addr1 = customerAddress1 ? String(customerAddress1).trim() : null;
  const addr2 = customerAddress2 ? String(customerAddress2).trim() : null;
  const gst = customerGSTNo ? String(customerGSTNo).trim() : null;

  try {
    await query(`
      UPDATE dbo.SalesHeader
      SET TermsAndConditions = @TermsAndConditions,
          CustomerAddress1 = @CustomerAddress1,
          CustomerAddress2 = @CustomerAddress2,
          CustomerGSTNo = @CustomerGSTNo
      WHERE SalesId = @SalesId AND CompanyId = @CompanyId
    `, {
      SalesId: id,
      CompanyId: companyId,
      TermsAndConditions: termsVal,
      CustomerAddress1: addr1,
      CustomerAddress2: addr2,
      CustomerGSTNo: gst,
    });
    return;
  } catch (err) {
    // Continue with partial updates when some columns are missing
  }

  try {
    await query(`
      UPDATE dbo.SalesHeader
      SET TermsAndConditions = @TermsAndConditions
      WHERE SalesId = @SalesId AND CompanyId = @CompanyId
    `, { SalesId: id, CompanyId: companyId, TermsAndConditions: termsVal });
  } catch { /* ignore */ }

  try {
    await query(`
      UPDATE dbo.SalesHeader
      SET CustomerAddress1 = @CustomerAddress1,
          CustomerAddress2 = @CustomerAddress2,
          CustomerGSTNo = @CustomerGSTNo
      WHERE SalesId = @SalesId AND CompanyId = @CompanyId
    `, {
      SalesId: id,
      CompanyId: companyId,
      CustomerAddress1: addr1,
      CustomerAddress2: addr2,
      CustomerGSTNo: gst,
    });
  } catch { /* columns may not exist until fix_sales_customer_billing.sql */ }
}

app.get('/api/stock/available', auth, async (req, res) => {
  try {
    const materialId = parseInt(req.query.materialId, 10);
    const locationId = parseInt(req.query.locationId, 10);
    if (!materialId || !locationId) {
      return res.status(400).json({ error: 'materialId and locationId are required' });
    }
    const result = await execProc('sp_GetAvailableStock', withCompany(req, {
      MaterialId: materialId,
      LocationId: locationId,
    }));
    res.json(result.recordset[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/stock/by-material/:materialId', auth, async (req, res) => {
  try {
    const materialId = parseInt(req.params.materialId, 10);
    const owned = await query(`
      SELECT 1 FROM dbo.MaterialMaster
      WHERE MaterialId = @MaterialId AND CompanyId = @CompanyId AND IsActive = 1
    `, { MaterialId: materialId, CompanyId: req.user.companyId });
    if (!owned.recordset[0]) {
      return res.status(404).json({ error: 'Material not found' });
    }

    const result = await execProc('sp_GetStockByMaterial', withCompany(req, { MaterialId: materialId }));
    return res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/sales', auth, requireActiveSubscription, async (req, res) => {
  try {
    const {
      salesDate, customerName, customerAddress1, customerAddress2, customerGSTNo,
      remark, termsAndConditions, details,
      gstRate, discountType, discountPercent, discountAmount, roundOff,
    } = req.body;

    await validateSalesStock(details, null, req.user.companyId);

    const result = await execProc('sp_SaveSales', withCompany(req, {
      SalesDate: salesDate,
      CustomerName: customerName || null,
      Remark: remark || null,
      TermsAndConditions: termsAndConditions || null,
      DetailsJson: toSalesDetailJson(details),
      GSTRate: parseFloat(gstRate) || 0,
      DiscountType: discountType ? discountType.toUpperCase() : null,
      DiscountPercent: parseFloat(discountPercent) || 0,
      DiscountAmount: parseFloat(discountAmount) || 0,
      RoundOff: parseFloat(roundOff) || 0,
    }));
    const saved = result.recordset[0];
    await saveSalesHeaderExtras(saved?.SalesId, req.user.companyId, {
      termsAndConditions: termsAndConditions ?? null,
      customerAddress1,
      customerAddress2,
      customerGSTNo,
    });
    res.json(saved);
  } catch (err) {
    // Older SP without @TermsAndConditions — retry without it, then patch column
    if (/too many arguments|TermsAndConditions/i.test(err.message || '')) {
      try {
        const {
          salesDate, customerName, customerAddress1, customerAddress2, customerGSTNo,
          remark, termsAndConditions, details,
          gstRate, discountType, discountPercent, discountAmount, roundOff,
        } = req.body;
        const result = await execProc('sp_SaveSales', withCompany(req, {
          SalesDate: salesDate,
          CustomerName: customerName || null,
          Remark: remark || null,
          DetailsJson: toSalesDetailJson(details),
          GSTRate: parseFloat(gstRate) || 0,
          DiscountType: discountType ? discountType.toUpperCase() : null,
          DiscountPercent: parseFloat(discountPercent) || 0,
          DiscountAmount: parseFloat(discountAmount) || 0,
          RoundOff: parseFloat(roundOff) || 0,
        }));
        const saved = result.recordset[0];
        await saveSalesHeaderExtras(saved?.SalesId, req.user.companyId, {
          termsAndConditions: termsAndConditions ?? null,
          customerAddress1,
          customerAddress2,
          customerGSTNo,
        });
        return res.json(saved);
      } catch (err2) {
        const { msg, status } = stockErrorStatus(err2);
        return res.status(status).json({ error: msg });
      }
    }
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

app.put('/api/sales/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const salesId = parseInt(req.params.id, 10);
    const {
      salesDate, customerName, customerAddress1, customerAddress2, customerGSTNo,
      remark, termsAndConditions, details,
      gstRate, discountType, discountPercent, discountAmount, roundOff,
    } = req.body;

    await validateSalesStock(details, salesId, req.user.companyId);

    const result = await execProc('sp_UpdateSales', withCompany(req, {
      SalesId: salesId,
      SalesDate: salesDate,
      CustomerName: customerName || null,
      Remark: remark || null,
      TermsAndConditions: termsAndConditions || null,
      DetailsJson: toSalesDetailJson(details),
      GSTRate: parseFloat(gstRate) || 0,
      DiscountType: discountType ? discountType.toUpperCase() : null,
      DiscountPercent: parseFloat(discountPercent) || 0,
      DiscountAmount: parseFloat(discountAmount) || 0,
      RoundOff: parseFloat(roundOff) || 0,
    }));
    await saveSalesHeaderExtras(salesId, req.user.companyId, {
      termsAndConditions: termsAndConditions ?? null,
      customerAddress1,
      customerAddress2,
      customerGSTNo,
    });
    res.json(result.recordset[0]);
  } catch (err) {
    if (/too many arguments|TermsAndConditions/i.test(err.message || '')) {
      try {
        const salesId = parseInt(req.params.id, 10);
        const {
          salesDate, customerName, customerAddress1, customerAddress2, customerGSTNo,
          remark, termsAndConditions, details,
          gstRate, discountType, discountPercent, discountAmount, roundOff,
        } = req.body;
        const result = await execProc('sp_UpdateSales', withCompany(req, {
          SalesId: salesId,
          SalesDate: salesDate,
          CustomerName: customerName || null,
          Remark: remark || null,
          DetailsJson: toSalesDetailJson(details),
          GSTRate: parseFloat(gstRate) || 0,
          DiscountType: discountType ? discountType.toUpperCase() : null,
          DiscountPercent: parseFloat(discountPercent) || 0,
          DiscountAmount: parseFloat(discountAmount) || 0,
          RoundOff: parseFloat(roundOff) || 0,
        }));
        await saveSalesHeaderExtras(salesId, req.user.companyId, {
          termsAndConditions: termsAndConditions ?? null,
          customerAddress1,
          customerAddress2,
          customerGSTNo,
        });
        return res.json(result.recordset[0]);
      } catch (err2) {
        const { msg, status } = stockErrorStatus(err2);
        return res.status(status).json({ error: msg });
      }
    }
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

app.delete('/api/sales/:id', auth, requireActiveSubscription, async (req, res) => {
  try {
    const salesId = parseInt(req.params.id, 10);
    await execProc('sp_DeleteSales', withCompany(req, { SalesId: salesId }));
    res.json({ success: true });
  } catch (err) {
    const { msg, status } = stockErrorStatus(err);
    res.status(status).json({ error: msg });
  }
});

/* ========== STOCK REPORT ========== */
app.get('/api/stock-report', auth, async (req, res) => {
  try {
    const { locationId, materialId } = req.query;
    const result = await execProc('sp_GetStockReport', withCompany(req, {
      LocationId: locationId ? parseInt(locationId) : null,
      MaterialId: materialId ? parseInt(materialId) : null,
    }));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/stock-ledger', auth, async (req, res) => {
  try {
    const { locationId, fromDate, toDate } = req.query;
    const result = await execProc('sp_GetStockLedgerReport', withCompany(req, {
      LocationId: locationId ? parseInt(locationId) : null,
      FromDate: fromDate || null,
      ToDate: toDate || null,
    }));
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const { getPool, config } = require('./db');

app.get('/api/health', (req, res) => res.json({ status: 'ok', app: 'InventoryInOneTap API' }));

app.use((err, req, res, next) => {
  if (res.headersSent) {
    next(err);
    return;
  }
  if (err?.message === 'Not allowed by CORS') {
    res.status(403).json({ error: 'Origin not allowed' });
    return;
  }
  res.status(500).json({ error: safeErrorMessage(err) });
});

async function startServer() {
  try {
    assertSecureConfig();
    await getPool();
    console.log(`Database connected: ${config.server}:${config.port} / ${config.database}`);
  } catch (err) {
    console.error('WARNING: Database not connected on startup.');
    console.error(err.message);
    console.error('Check backend/.env and restart the server after any change.');
  }

  app.listen(PORT, () => {
    console.log(`InventoryInOneTap API running on http://localhost:${PORT}`);
  });
}

startServer();
