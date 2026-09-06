export const PAGE_SIZE = 10;

export function matchSearch(row, search, fields) {
  if (!search?.trim()) return true;
  const q = search.trim().toLowerCase();
  return fields.some((f) => String(row[f] ?? '').toLowerCase().includes(q));
}

export function filterByDateRange(rows, dateField, fromDate, toDate) {
  return rows.filter((row) => {
    const d = new Date(row[dateField]);
    if (Number.isNaN(d.getTime())) return false;
    if (fromDate) {
      const from = new Date(fromDate);
      from.setHours(0, 0, 0, 0);
      if (d < from) return false;
    }
    if (toDate) {
      const to = new Date(toDate);
      to.setHours(23, 59, 59, 999);
      if (d > to) return false;
    }
    return true;
  });
}

export function paginate(rows, page, pageSize = PAGE_SIZE) {
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(Math.max(1, page), totalPages);
  const start = (currentPage - 1) * pageSize;
  return {
    items: rows.slice(start, start + pageSize),
    total,
    totalPages,
    currentPage,
    pageSize,
  };
}

export function defaultMonthRange() {
  const to = new Date();
  const from = new Date();
  from.setMonth(from.getMonth() - 1);
  return {
    fromDate: from.toISOString().split('T')[0],
    toDate: to.toISOString().split('T')[0],
  };
}
