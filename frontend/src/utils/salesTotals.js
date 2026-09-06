export function calcSalesTotals(lineItems = [], options = {}) {
  const {
    gstRate = 0,
    discountType = 'percent',
    discountPercent = 0,
    discountAmount = 0,
    roundOff = 0,
  } = options;

  const subTotal = lineItems.reduce(
    (sum, item) => sum + Number(item.quantity || 0) * Number(item.rate || 0),
    0
  );

  let discount = 0;
  if (discountType === 'percent') {
    discount = subTotal * (Number(discountPercent) || 0) / 100;
  } else if (discountType === 'amount') {
    discount = Number(discountAmount) || 0;
  }
  discount = Math.min(Math.max(discount, 0), subTotal);

  const taxable = subTotal - discount;
  const gstAmount = taxable * (Number(gstRate) || 0) / 100;
  const grandTotal = taxable + gstAmount + (Number(roundOff) || 0);

  return {
    subTotal: round2(subTotal),
    discount: round2(discount),
    taxable: round2(taxable),
    gstAmount: round2(gstAmount),
    roundOff: round2(Number(roundOff) || 0),
    grandTotal: round2(grandTotal),
  };
}

export function calcSalesTotalsFromSale(sale) {
  const items = sale.items || [];
  const lineItems = items.map((i) => ({
    quantity: i.Quantity,
    rate: i.Rate,
  }));

  if (sale.GrandTotal != null && sale.SubTotal != null) {
    return {
      subTotal: Number(sale.SubTotal),
      discount: Number(sale.DiscountValue || 0),
      taxable: Number(sale.SubTotal) - Number(sale.DiscountValue || 0),
      gstAmount: Number(sale.GSTAmount || 0),
      roundOff: Number(sale.RoundOff || 0),
      grandTotal: Number(sale.GrandTotal),
      gstRate: Number(sale.GSTRate || 0),
      discountType: sale.DiscountType,
      discountPercent: Number(sale.DiscountPercent || 0),
      discountAmount: Number(sale.DiscountAmount || 0),
    };
  }

  return calcSalesTotals(lineItems, {
    gstRate: sale.GSTRate || 0,
    discountType: (sale.DiscountType || 'percent').toLowerCase(),
    discountPercent: sale.DiscountPercent || 0,
    discountAmount: sale.DiscountAmount || 0,
    roundOff: sale.RoundOff || 0,
  });
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

export function autoRoundOff(taxable, gstAmount) {
  const before = taxable + gstAmount;
  const rounded = Math.round(before);
  return round2(rounded - before);
}
