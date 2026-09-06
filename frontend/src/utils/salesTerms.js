export const DEFAULT_SALES_TERMS = [
  'Goods once sold will not be taken back or exchanged.',
  'Payment is due as per the agreed credit terms / on delivery.',
  'Interest may be charged on overdue payments as applicable.',
  'Please check goods carefully at the time of delivery; later claims may not be entertained.',
  'All disputes are subject to local jurisdiction only.',
];

/** Parse stored terms JSON (or newline text) into a clean string array. */
export function parseSalesTerms(raw) {
  if (raw == null || raw === '') return [];
  if (Array.isArray(raw)) {
    return raw.map((t) => String(t || '').trim()).filter(Boolean);
  }
  if (typeof raw === 'object' && typeof raw.toString === 'function' && !(raw instanceof String)) {
    // mssql sometimes returns odd types
    try {
      if (Buffer.isBuffer?.(raw)) raw = raw.toString('utf8');
    } catch {
      // ignore
    }
  }
  const text = String(raw).trim();
  if (!text || text === 'null' || text === 'undefined') return [];
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed)) {
      return parsed.map((t) => String(t || '').trim()).filter(Boolean);
    }
    if (typeof parsed === 'string') {
      return parseSalesTerms(parsed);
    }
  } catch {
    // fall through — treat as newline / pipe separated
  }
  return text
    .split(/\r?\n|\|/)
    .map((t) => t.replace(/^\s*\d+[.)]\s*/, '').trim())
    .filter(Boolean);
}

export function serializeSalesTerms(terms = []) {
  const cleaned = (terms || []).map((t) => String(t || '').trim()).filter(Boolean);
  return JSON.stringify(cleaned);
}

/** Terms for invoice PDF — uses saved terms, else defaults when never saved. */
export function resolveInvoiceTerms(sale) {
  const raw = sale?.TermsAndConditions
    ?? sale?.termsAndConditions
    ?? sale?.items?.[0]?.TermsAndConditions
    ?? sale?.items?.[0]?.termsAndConditions;
  if (raw == null || raw === '') {
    return [...DEFAULT_SALES_TERMS];
  }
  return parseSalesTerms(raw);
}
