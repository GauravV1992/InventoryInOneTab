require('dotenv').config();
const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_DATABASE || 'PawanPutra',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: parseInt(process.env.DB_PORT || '1433', 10),
  options: {
    encrypt: false,
    trustServerCertificate: true,
  },
  connectionTimeout: 30000,
  requestTimeout: 60000,
  pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
};

let pool;

async function getPool() {
  if (!pool) {
    try {
      pool = await sql.connect(config);
    } catch (err) {
      const target = `${config.server}:${config.port}/${config.database}`;
      throw new Error(`Database connection failed (${target}): ${err.message}`);
    }
  }
  return pool;
}

/** mssql defaults long strings to NVARCHAR(4000) — logos need NVARCHAR(MAX). */
function bindInput(request, key, value) {
  if (value === null || value === undefined) {
    request.input(key, value);
    return;
  }
  if (typeof value === 'string' && value.length > 4000) {
    request.input(key, sql.NVarChar(sql.MAX), value);
    return;
  }
  if (Buffer.isBuffer(value)) {
    request.input(key, sql.VarBinary(sql.MAX), value);
    return;
  }
  request.input(key, value);
}

async function query(text, params = {}) {
  const p = await getPool();
  const request = p.request();
  Object.entries(params).forEach(([key, value]) => {
    bindInput(request, key, value);
  });
  const result = await request.query(text);
  return result;
}

async function execProc(procName, params = {}) {
  const p = await getPool();
  const request = p.request();
  Object.entries(params).forEach(([key, value]) => {
    bindInput(request, key, value);
  });
  const result = await request.execute(procName);
  return result;
}

module.exports = { sql, getPool, query, execProc, config };
