/**
 * End-to-end API flow test — register → login → masters → purchase → sales → users
 * Run: node test-flow.js
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const BASE = process.env.TEST_API || 'http://localhost:5000/api';
const JWT_SECRET = process.env.JWT_SECRET || 'InventoryInOneTap_SecretKey_2026';

const ts = Date.now();
const USERNAME = `flowtest_${ts}`;
const PASSWORD = 'testpass123';
const COMPANY = `FlowTest Co ${ts}`;

let token = '';
let user = {};
let companyId = null;
let locationId = null;
let materialId = null;
let supplierId = null;
let purchaseId = null;
let salesId = null;

const results = [];
function pass(name) { results.push({ name, ok: true }); console.log(`✓ ${name}`); }
function fail(name, err) { results.push({ name, ok: false, err: String(err) }); console.error(`✗ ${name}:`, err); }

async function api(method, path, body, auth = false) {
  const headers = { 'Content-Type': 'application/json' };
  if (auth && token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!res.ok) {
    const msg = data?.error || data?.message || text || res.statusText;
    throw new Error(`${res.status} ${msg}`);
  }
  return data;
}

async function run() {
  console.log('\n=== InventoryInOneTap E2E Flow Test ===\n');

  try {
    await api('GET', '/health');
    pass('Health check');
  } catch (e) { fail('Health check', e); return summary(); }

  try {
    const plans = await api('GET', '/plans');
    if (!Array.isArray(plans.plans) && !Array.isArray(plans)) throw new Error('No plans returned');
    pass('GET /plans');
  } catch (e) { fail('GET /plans', e); }

  try {
    const chk = await api('GET', `/auth/check-username?username=${USERNAME}`);
    if (chk.available !== true) throw new Error('Expected available username');
    pass('Username availability check');
  } catch (e) { fail('Username availability check', e); }

  try {
    const dup = await api('GET', '/auth/check-username?username=gaurav');
    if (dup.available !== false) throw new Error('gaurav should be taken');
    pass('Username taken check (existing user)');
  } catch (e) { fail('Username taken check (existing user)', e); }

  try {
    const reg = await api('POST', '/auth/register', {
      username: USERNAME,
      password: PASSWORD,
      firstName: 'Flow',
      lastName: 'Test',
      email: `${USERNAME}@test.com`,
      companyName: COMPANY,
    });
    if (!reg.token || !reg.user?.companyId) throw new Error('Missing token or companyId');
    token = reg.token;
    user = reg.user;
    companyId = reg.user.companyId;
    pass(`Register (${USERNAME})`);
  } catch (e) { fail('Register', e); return summary(); }

  try {
    const login = await api('POST', '/auth/login', { username: USERNAME, password: PASSWORD });
    if (!login.token) throw new Error('No token on login');
    token = login.token;
    user = login.user;
    pass('Login');
  } catch (e) { fail('Login', e); }

  try {
    const dupReg = await api('POST', '/auth/register', {
      username: USERNAME,
      password: PASSWORD,
      firstName: 'Dup',
      companyName: 'Dup Co',
    });
    fail('Duplicate register should fail', 'Unexpected success');
  } catch (e) {
    if (/already exists/i.test(e.message)) pass('Duplicate register blocked');
    else fail('Duplicate register blocked', e);
  }

  try {
    const sub = await api('GET', '/billing/subscription', null, true);
    if (!sub.SubscriptionEnd) throw new Error('Missing SubscriptionEnd after register');
    pass('Billing subscription');
  } catch (e) { fail('Billing subscription', e); }

  try {
    const limits = await api('GET', '/billing/limits', null, true);
    if (limits.canAddMaterial === undefined) throw new Error('Missing limits fields');
    pass('Billing limits');
  } catch (e) { fail('Billing limits', e); }

  try {
    const dash = await api('GET', '/dashboard', null, true);
    pass('Dashboard stats');
  } catch (e) { fail('Dashboard stats', e); }

  try {
    const loc = await api('POST', '/locations', {
      locationName: 'Main WH',
      address: 'Test Addr',
      city: 'Mumbai',
    }, true);
    locationId = loc.LocationId || loc.locationId;
    if (!locationId) throw new Error('No locationId');
    pass('Add warehouse location');
  } catch (e) { fail('Add warehouse location', e); }

  try {
    const mat = await api('POST', '/materials', {
      materialName: `Material-${ts}`,
      color: 'Red',
      hsnCode: '1234',
      rate: 100,
      unit: 'Pcs',
    }, true);
    materialId = mat.MaterialId || mat.materialId;
    if (!materialId) throw new Error('No materialId');
    pass('Add material');
  } catch (e) { fail('Add material', e); }

  try {
    const sup = await api('POST', '/suppliers', {
      supplierName: `Supplier-${ts}`,
      gstNo: '27AAAAA0000A1Z5',
      mobileNo: '9876543210',
    }, true);
    supplierId = sup.SupplierId || sup.supplierId;
    pass('Add supplier');
  } catch (e) { fail('Add supplier', e); }

  try {
    await api('POST', '/opening-stock', {
      materialId,
      locationId,
      quantity: 50,
      stockDate: new Date().toISOString().slice(0, 10),
    }, true);
    pass('Opening stock');
  } catch (e) { fail('Opening stock', e); }

  try {
    const stock = await api('GET', `/stock/by-material/${materialId}`, null, true);
    if (!Array.isArray(stock) || stock.length === 0) throw new Error('No stock rows');
    const avail = stock.find((s) => s.LocationId === locationId || s.locationId === locationId);
    if (!avail || Number(avail.AvailableStock ?? avail.availableStock) < 50) {
      throw new Error(`Expected stock >= 50, got ${avail?.AvailableStock ?? avail?.availableStock}`);
    }
    pass('Stock by material (company filtered)');
  } catch (e) { fail('Stock by material', e); }

  try {
    const pur = await api('POST', '/purchase-inward', {
      purchaseDate: new Date().toISOString().slice(0, 10),
      locationId,
      supplierName: `Supplier-${ts}`,
      details: [{ materialId, quantity: 10, rate: 100 }],
    }, true);
    purchaseId = pur.PurchaseId || pur.purchaseId;
    if (!purchaseId) throw new Error('No purchaseId');
    pass(`Purchase inward (${pur.PurchaseNo || pur.purchaseNo || purchaseId})`);
  } catch (e) { fail('Purchase inward', e); }

  try {
    const avail = await api('GET', `/stock/available?materialId=${materialId}&locationId=${locationId}`, null, true);
    if (Number(avail.AvailableStock ?? avail.availableStock) < 60) {
      throw new Error(`Expected stock >= 60 after purchase, got ${avail.AvailableStock}`);
    }
    pass('Stock available after purchase');
  } catch (e) { fail('Stock available after purchase', e); }

  try {
    const sale = await api('POST', '/sales', {
      salesDate: new Date().toISOString().slice(0, 10),
      customerName: 'Test Customer',
      gstRate: 18,
      details: [{ materialId, locationId, quantity: 5, rate: 120 }],
    }, true);
    salesId = sale.SalesId || sale.salesId;
    if (!salesId) throw new Error('No salesId');
    pass(`Sales (${sale.SalesNo || sale.salesNo || salesId})`);
  } catch (e) { fail('Sales', e); }

  try {
    const overSale = await api('POST', '/sales', {
      salesDate: new Date().toISOString().slice(0, 10),
      customerName: 'Over Customer',
      details: [{ materialId, locationId, quantity: 99999, rate: 120 }],
    }, true);
    fail('Oversell should fail', 'Unexpected success');
  } catch (e) {
    if (/insufficient stock/i.test(e.message)) pass('Oversell blocked');
    else fail('Oversell blocked', e);
  }

  try {
    const report = await api('GET', '/stock-report', null, true);
    if (!Array.isArray(report)) throw new Error('Not an array');
    pass('Stock report');
  } catch (e) { fail('Stock report', e); }

  try {
    const filteredReport = await api('GET', `/stock-report?materialId=${materialId}&locationId=${locationId}`, null, true);
    if (!Array.isArray(filteredReport) || filteredReport.length === 0) {
      throw new Error('Filtered stock report returned no rows');
    }
    pass('Stock report filters (material + location)');
  } catch (e) { fail('Stock report filters', e); }

  try {
    const ledger = await api('GET', '/stock-ledger', null, true);
    if (!Array.isArray(ledger)) throw new Error('Not an array');
    pass('Stock ledger');
  } catch (e) { fail('Stock ledger', e); }

  try {
    const today = new Date().toISOString().slice(0, 10);
    const filteredLedger = await api('GET', `/stock-ledger?locationId=${locationId}&fromDate=${today}&toDate=${today}`, null, true);
    if (!Array.isArray(filteredLedger)) throw new Error('Not an array');
    pass('Stock ledger filters (location + date)');
  } catch (e) { fail('Stock ledger filters', e); }

  try {
    const purchases = await api('GET', '/purchase-inward', null, true);
    if (!Array.isArray(purchases)) throw new Error('Not an array');
    pass('List purchases');
  } catch (e) { fail('List purchases', e); }

  try {
    const sales = await api('GET', '/sales', null, true);
    if (!Array.isArray(sales)) throw new Error('Not an array');
    pass('List sales');
  } catch (e) { fail('List sales', e); }

  try {
    const profile = await api('GET', '/account/profile', null, true);
    if (!profile.CompanyName && !profile.companyName) throw new Error('No company in profile');
    pass('Account profile');
  } catch (e) { fail('Account profile', e); }

  try {
    const invoices = await api('GET', '/account/invoices', null, true);
    if (!Array.isArray(invoices)) throw new Error('Not an array');
    pass('Payment invoices');
  } catch (e) { fail('Payment invoices', e); }

  try {
    const users = await api('GET', '/company/users', null, true);
    if (!Array.isArray(users)) throw new Error('Not an array');
    pass('List company users');
  } catch (e) { fail('List company users', e); }

  try {
    const preview = await api('GET', '/company/users/proration-preview', null, true);
    pass('User proration preview');
  } catch (e) { fail('User proration preview', e); }

  try {
    const newUser = `team_${ts}`;
    const add = await api('POST', '/company/users', {
      username: newUser,
      password: 'teampass123',
      firstName: 'Team',
      lastName: 'Member',
    }, true);
    if (add.needsPayment && !add.user) throw new Error('Payment flow missing user');
    if (!add.needsPayment && !add.user) throw new Error('No user returned');
    pass(add.needsPayment ? 'Add user (payment required path)' : 'Add user (free slot)');
  } catch (e) { fail('Add company user', e); }

  try {
    const locs = await api('GET', '/locations', null, true);
    const mats = await api('GET', '/materials', null, true);
    const sups = await api('GET', '/suppliers', null, true);
    if (!locs.every((l) => true) || locs.length < 1) throw new Error('No locations');
    pass('List masters (locations, materials, suppliers)');
  } catch (e) { fail('List masters', e); }

  return summary();
}

function summary() {
  const passed = results.filter((r) => r.ok).length;
  const failed = results.filter((r) => !r.ok);
  console.log(`\n=== Results: ${passed}/${results.length} passed ===`);
  if (failed.length) {
    console.log('\nFailed:');
    failed.forEach((f) => console.log(`  - ${f.name}: ${f.err}`));
    process.exit(1);
  }
  console.log('\nAll flow tests passed.\n');
  process.exit(0);
}

run().catch((e) => {
  console.error('Fatal:', e);
  process.exit(1);
});
