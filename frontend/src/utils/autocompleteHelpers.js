export function matchMaterial(m, q) {
  return [m.MaterialName, m.Color, m.Size, m.HSNCode]
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
  if (m.Size) parts.push(m.Size);
  if (m.Unit) parts.push(m.Unit);
  return parts.join(' · ');
}

/** Format material line for lists / PDF: "Name (Size)" when size is set */
export function materialDisplayName(m) {
  const name = m?.MaterialName || m?.materialName || '—';
  const size = m?.Size || m?.size;
  return size ? `${name} (${size})` : name;
}
