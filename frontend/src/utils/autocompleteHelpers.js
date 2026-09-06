export function matchMaterial(m, q) {
  return [m.MaterialName, m.Color, m.HSNCode]
    .some((f) => (f || '').toLowerCase().includes(q));
}

export function matchSupplier(s, q) {
  return [s.SupplierName, s.GSTNo, s.MobileNo, s.Email]
    .some((f) => (f || '').toLowerCase().includes(q));
}

export function matchCustomer(c, q) {
  return (c.CustomerName || '').toLowerCase().includes(q);
}

export function materialLabel(m) {
  const parts = [m.MaterialName];
  if (m.Color) parts.push(m.Color);
  if (m.Unit) parts.push(m.Unit);
  return parts.join(' · ');
}
