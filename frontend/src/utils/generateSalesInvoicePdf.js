import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import { calcSalesTotalsFromSale } from './salesTotals';
import { profileToCompany } from './accountProfile';
import { resolveInvoiceTerms } from './salesTerms';

const DEFAULT_COMPANY = profileToCompany(null);

function formatDate(d) {
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function formatMoney(n) {
  return `Rs. ${Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function hexToRgb(hex) {
  if (!hex) return [249, 115, 22];
  const h = String(hex).replace('#', '');
  if (h.length === 3) {
    return [
      parseInt(h[0] + h[0], 16),
      parseInt(h[1] + h[1], 16),
      parseInt(h[2] + h[2], 16),
    ];
  }
  if (h.length >= 6) {
    return [
      parseInt(h.slice(0, 2), 16),
      parseInt(h.slice(2, 4), 16),
      parseInt(h.slice(4, 6), 16),
    ];
  }
  return [249, 115, 22];
}

function getImageFormat(dataUrl) {
  if (!dataUrl) return 'PNG';
  if (dataUrl.includes('image/jpeg') || dataUrl.includes('image/jpg')) return 'JPEG';
  return 'PNG';
}

function pickSaleField(sale, ...keys) {
  for (const key of keys) {
    const v = sale?.[key];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  }
  const item = sale?.items?.[0];
  if (item) {
    for (const key of keys) {
      const v = item?.[key];
      if (v != null && String(v).trim() !== '') return String(v).trim();
    }
  }
  return '';
}

function getSaleBillTo(sale) {
  return {
    name: pickSaleField(sale, 'CustomerName', 'customerName') || 'Walk-in Customer',
    gstNo: pickSaleField(sale, 'CustomerGSTNo', 'customerGSTNo', 'CustomerGstNo'),
    address1: pickSaleField(sale, 'CustomerAddress1', 'customerAddress1'),
    address2: pickSaleField(sale, 'CustomerAddress2', 'customerAddress2'),
  };
}

function resolveCompany(company) {
  return company && company.name ? company : DEFAULT_COMPANY;
}

export function getSalesInvoiceFilename(sale) {
  return `Invoice_${sale.SalesNo || sale.SalesId}.pdf`;
}

export function buildSalesInvoicePdf(sale, company) {
  const co = resolveCompany(company);
  const brandRgb = hexToRgb(co.nameColor);
  const softBrand = brandRgb.map((c) => Math.min(255, Math.round(c + (255 - c) * 0.88)));
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const pageW = 210;
  const pageH = 297;
  const leftX = 14;
  const rightX = pageW - 14;
  const contentW = rightX - leftX;
  const items = sale.items || [];
  const t = calcSalesTotalsFromSale(sale);

  // Top brand bar
  doc.setFillColor(...brandRgb);
  doc.rect(0, 0, pageW, 3.5, 'F');

  let textX = leftX;
  const hasLogo = Boolean(co.logo);

  // Measure header text block first (name → description → address)
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(18);
  const nameLines = doc.splitTextToSize(co.name, contentW - (hasLogo ? 26 : 0) - 55);
  doc.setFont('helvetica', 'italic');
  doc.setFontSize(8);
  const descLines = co.description
    ? doc.splitTextToSize(co.description, contentW - (hasLogo ? 26 : 0) - 55)
    : [];
  const detailLines = [];
  if (co.address1) detailLines.push(co.address1);
  if (co.address2) detailLines.push(co.address2);
  if (co.gstNo) detailLines.push(`GSTIN: ${co.gstNo}`);
  if (co.email) detailLines.push(co.email);

  let measuredY = 14 + (nameLines.length - 1) * 6.5;
  if (descLines.length) {
    measuredY += 3.8 + descLines.length * 3.6 + 1.2;
  } else {
    measuredY += 6.5;
  }
  measuredY += detailLines.length * 3.8;
  const headerBottom = Math.max(measuredY + 4, hasLogo ? 34 : 28, 40);

  // Soft header band (dynamic height)
  doc.setFillColor(...softBrand);
  doc.rect(0, 3.5, pageW, headerBottom - 3.5, 'F');

  if (co.logo) {
    try {
      doc.setFillColor(255, 255, 255);
      doc.roundedRect(leftX - 1, 8, 22, 22, 2, 2, 'F');
      doc.addImage(co.logo, getImageFormat(co.logo), leftX, 9, 20, 20);
      textX = leftX + 26;
    } catch {
      textX = leftX;
    }
  }

  // Company name
  let y = 14;
  doc.setTextColor(...brandRgb);
  doc.setFontSize(18);
  doc.setFont('helvetica', 'bold');
  doc.text(nameLines, textX, y);
  // Keep description tight under company name (no large gap)
  if (descLines.length) {
    y += (nameLines.length - 1) * 6.5 + 3.8;
    doc.setFont('helvetica', 'italic');
    doc.setFontSize(8);
    doc.setTextColor(71, 85, 105);
    doc.text(descLines, textX, y);
    y += descLines.length * 3.6 + 1.2;
  } else {
    y += nameLines.length * 6.5;
  }

  // Address / GST / email under description
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(71, 85, 105);
  detailLines.forEach((line) => {
    doc.text(line, textX, y);
    y += 3.8;
  });

  // Invoice badge (top right)
  const badgeX = 148;
  const badgeY = 9;
  doc.setFillColor(255, 255, 255);
  doc.roundedRect(badgeX, badgeY, 48, 28, 2.5, 2.5, 'F');
  doc.setDrawColor(...brandRgb);
  doc.setLineWidth(0.4);
  doc.roundedRect(badgeX, badgeY, 48, 28, 2.5, 2.5, 'S');

  doc.setTextColor(...brandRgb);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text('TAX INVOICE', badgeX + 24, badgeY + 9, { align: 'center' });

  doc.setTextColor(30, 41, 59);
  doc.setFontSize(9);
  doc.text(sale.SalesNo || '—', badgeX + 24, badgeY + 16, { align: 'center' });
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(100, 116, 139);
  doc.text(formatDate(sale.SalesDate), badgeX + 24, badgeY + 22, { align: 'center' });

  // Accent line under header
  doc.setDrawColor(...brandRgb);
  doc.setLineWidth(0.8);
  doc.line(leftX, headerBottom, rightX, headerBottom);

  y = headerBottom + 8;

  // Bill To + Invoice meta cards
  const cardGap = 4;
  const cardW = (contentW - cardGap) / 2;
  const textW = cardW - 10;
  const MAX_ADDR_LINES = 5;
  const billTo = getSaleBillTo(sale);
  const billLines = [
    { text: billTo.name, kind: 'name' },
    billTo.gstNo ? { text: `GSTIN: ${billTo.gstNo}`, kind: 'meta' } : null,
    billTo.address1 ? { text: billTo.address1, kind: 'addr' } : null,
    billTo.address2 ? { text: billTo.address2, kind: 'addr' } : null,
  ].filter(Boolean);

  const wrapBillLine = (entry) => {
    if (entry.kind === 'name') {
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(10);
    } else {
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
    }
    let wrapped = doc.splitTextToSize(String(entry.text || ''), textW);
    if (entry.kind === 'addr' && wrapped.length > MAX_ADDR_LINES) {
      wrapped = wrapped.slice(0, MAX_ADDR_LINES);
      const last = wrapped[MAX_ADDR_LINES - 1];
      wrapped[MAX_ADDR_LINES - 1] = last.length > 3 ? `${last.slice(0, -3)}...` : `${last}...`;
    }
    const lineH = entry.kind === 'name' ? 4.8 : 3.5;
    const gapAfter = entry.kind === 'name' ? 1 : 0.5;
    return { wrapped, lineH, gapAfter, kind: entry.kind };
  };

  const measured = billLines.map(wrapBillLine);
  let billContentH = 10; // label + top padding
  measured.forEach(({ wrapped, lineH, gapAfter }) => {
    billContentH += wrapped.length * lineH + gapAfter;
  });
  billContentH += 3; // bottom padding

  let metaContentH = 18;
  if (sale.Remark) {
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8.5);
    const remarkLines = doc.splitTextToSize(`Remark: ${sale.Remark}`, textW).slice(0, 2);
    metaContentH = 18 + remarkLines.length * 4;
  }
  const cardH = Math.max(22, billContentH, metaContentH);

  doc.setFillColor(248, 250, 252);
  doc.roundedRect(leftX, y, cardW, cardH, 2, 2, 'F');
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(leftX, y, cardW, cardH, 2, 2, 'S');

  doc.setFillColor(248, 250, 252);
  doc.roundedRect(leftX + cardW + cardGap, y, cardW, cardH, 2, 2, 'F');
  doc.roundedRect(leftX + cardW + cardGap, y, cardW, cardH, 2, 2, 'S');

  // Left accent on Bill To
  doc.setFillColor(...brandRgb);
  doc.rect(leftX, y + 2, 1.2, cardH - 4, 'F');

  doc.setTextColor(...brandRgb);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.text('BILL TO', leftX + 5, y + 6);

  let billY = y + 12;
  measured.forEach(({ wrapped, lineH, gapAfter, kind }) => {
    if (kind === 'name') {
      doc.setTextColor(30, 41, 59);
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(10);
    } else {
      doc.setTextColor(71, 85, 105);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.5);
    }
    doc.text(wrapped, leftX + 5, billY);
    billY += wrapped.length * lineH + gapAfter;
  });

  const metaX = leftX + cardW + cardGap + 5;
  doc.setTextColor(...brandRgb);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(8);
  doc.text('INVOICE DETAILS', metaX, y + 6);

  doc.setTextColor(51, 65, 85);
  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8.5);
  doc.text(`Date: ${formatDate(sale.SalesDate)}`, metaX, y + 13);
  doc.text(`Invoice No: ${sale.SalesNo || '—'}`, metaX, y + 18);
  if (sale.Remark) {
    const remarkLines = doc.splitTextToSize(`Remark: ${sale.Remark}`, textW).slice(0, 2);
    doc.text(remarkLines, metaX, y + 23);
  }

  y += cardH + 8;

  autoTable(doc, {
    startY: y,
    head: [['#', 'Material', 'Size', 'HSN', 'Warehouse', 'Qty', 'Rate', 'Amount']],
    body: items.map((item, idx) => [
      idx + 1,
      item.MaterialName || '—',
      item.Size || '—',
      item.HSNCode || '—',
      item.LocationName || item.DetailLocationName || '—',
      Number(item.Quantity).toFixed(2),
      formatMoney(item.Rate),
      formatMoney(item.Amount ?? item.Quantity * item.Rate),
    ]),
    theme: 'plain',
    headStyles: {
      fillColor: brandRgb,
      textColor: 255,
      fontStyle: 'bold',
      fontSize: 8,
      cellPadding: { top: 3, bottom: 3, left: 2, right: 2 },
    },
    bodyStyles: {
      fontSize: 8,
      textColor: [30, 41, 59],
      cellPadding: { top: 2.5, bottom: 2.5, left: 2, right: 2 },
    },
    alternateRowStyles: { fillColor: softBrand },
    styles: { lineColor: [226, 232, 240], lineWidth: 0.2 },
    columnStyles: {
      0: { cellWidth: 8,halign: 'center' },
      2: { cellWidth: 16 },
      5: {halign: 'right' },
      6: {halign: 'right' },
      7: {halign: 'right', fontStyle: 'bold' },
    },
    margin: { left: leftX, right: leftX },
    tableLineColor: [226, 232, 240],
    tableLineWidth: 0.2,
  });

  let finalY = doc.lastAutoTable.finalY + 8;

  // Totals panel
  const boxW = 72;
  const boxX = rightX - boxW;
  const summaryRows = [
    ['Sub Total', formatMoney(t.subTotal)],
    ['Discount', `- ${formatMoney(t.discount)}`],
    ['Taxable Amount', formatMoney(t.taxable)],
    [`GST (${t.gstRate ?? sale.GSTRate ?? 0}%)`, formatMoney(t.gstAmount)],
    ['Round Off', formatMoney(t.roundOff)],
  ];

  const boxH = 8 + summaryRows.length * 5.5 + 12;
  doc.setFillColor(248, 250, 252);
  doc.roundedRect(boxX, finalY - 2, boxW, boxH, 2, 2, 'F');
  doc.setDrawColor(226, 232, 240);
  doc.setLineWidth(0.3);
  doc.roundedRect(boxX, finalY - 2, boxW, boxH, 2, 2, 'S');

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(8.5);
  doc.setTextColor(71, 85, 105);
  let sy = finalY + 4;
  summaryRows.forEach(([label, val]) => {
    doc.text(label, boxX + 4, sy);
    doc.text(val, boxX + boxW - 4, sy, { align: 'right' });
    sy += 5.5;
  });

  doc.setFillColor(...brandRgb);
  doc.roundedRect(boxX + 2, sy - 1, boxW - 4, 10, 1.5, 1.5, 'F');
  doc.setTextColor(255, 255, 255);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  doc.text('Grand Total', boxX + 5, sy + 5.5);
  doc.text(formatMoney(t.grandTotal), boxX + boxW - 5, sy + 5.5, { align: 'right' });

  let cursorY = Math.max(sy + 14, finalY + 16);

  // Terms & Conditions
  const terms = resolveInvoiceTerms(sale);
  if (terms.length > 0) {
    const ensureSpace = (needed) => {
      if (cursorY + needed > pageH - 20) {
        doc.addPage();
        doc.setFillColor(...brandRgb);
        doc.rect(0, 0, pageW, 3.5, 'F');
        cursorY = 16;
      }
    };

    ensureSpace(20);
    doc.setTextColor(...brandRgb);
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(9);
    doc.text('Terms & Conditions', leftX, cursorY);
    cursorY += 2;
    doc.setDrawColor(...brandRgb);
    doc.setLineWidth(0.4);
    doc.line(leftX, cursorY, leftX + 42, cursorY);
    cursorY += 5;

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(71, 85, 105);
    terms.forEach((term, idx) => {
      const lines = doc.splitTextToSize(`${idx + 1}. ${term}`, contentW);
      ensureSpace(lines.length * 3.4 + 2);
      doc.text(lines, leftX, cursorY);
      cursorY += lines.length * 3.4 + 1.2;
    });
    cursorY += 4;
  }

  const thanksY = cursorY;
  doc.setTextColor(...brandRgb);
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(10);
  if (thanksY > pageH - 24) {
    doc.addPage();
    doc.setFillColor(...brandRgb);
    doc.rect(0, 0, pageW, 3.5, 'F');
    doc.setTextColor(...brandRgb);
    doc.text('Thank you for your business!', leftX, 16);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(148, 163, 184);
    doc.text('This is a computer-generated tax invoice.', leftX, 21);
  } else {
    doc.text('Thank you for your business!', leftX, thanksY);
    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(148, 163, 184);
    doc.text('This is a computer-generated tax invoice.', leftX, thanksY + 5);
  }

  // Footer bar on all pages
  const pageCount = doc.getNumberOfPages();
  for (let p = 1; p <= pageCount; p += 1) {
    doc.setPage(p);
    doc.setFillColor(...brandRgb);
    doc.rect(0, pageH - 12, pageW, 12, 'F');
    doc.setTextColor(255, 255, 255);
    doc.setFontSize(7.5);
    const footerParts = [co.name];
    if (co.gstNo) footerParts.push(`GSTIN: ${co.gstNo}`);
    if (co.email) footerParts.push(co.email);
    const footerText = footerParts.filter(Boolean).join('  ·  ');
    doc.text(footerText, pageW / 2, pageH - 5, { align: 'center' });
  }

  return doc;
}

export function getSalesInvoicePdfBlob(sale, company) {
  const doc = buildSalesInvoicePdf(sale, company);
  return doc.output('blob');
}

function downloadPdfBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function buildInvoiceShareText(sale, company) {
  const co = resolveCompany(company);
  const items = sale.items || [];
  const t = calcSalesTotalsFromSale(sale);
  const billTo = getSaleBillTo(sale);
  const invoiceTerms = resolveInvoiceTerms(sale);
  const itemLines = items.map((item, idx) =>
    `${idx + 1}. ${item.MaterialName || '—'}${item.Size ? ` (${item.Size})` : ''} | Qty: ${Number(item.Quantity).toFixed(2)} | ${formatMoney(item.Amount ?? item.Quantity * item.Rate)}`
  ).join('\n');

  return [
    `*${co.name} - Tax Invoice*`,
    co.gstNo ? `GSTIN: ${co.gstNo}` : null,
    co.email ? `Email: ${co.email}` : null,
    co.address ? co.address : null,
    '',
    `Invoice No: ${sale.SalesNo || '—'}`,
    `Date: ${formatDate(sale.SalesDate)}`,
    `Customer: ${billTo.name}`,
    billTo.gstNo ? `Customer GSTIN: ${billTo.gstNo}` : null,
    billTo.address1 || null,
    billTo.address2 || null,
    '',
    '*Items:*',
    itemLines || '—',
    '',
    `Sub Total: ${formatMoney(t.subTotal)}`,
    `Discount: ${formatMoney(t.discount)}`,
    `GST (${t.gstRate ?? sale.GSTRate ?? 0}%): ${formatMoney(t.gstAmount)}`,
    `Round Off: ${formatMoney(t.roundOff)}`,
    `*Grand Total: ${formatMoney(t.grandTotal)}*`,
    '',
    ...(invoiceTerms.length
      ? [
        '*Terms & Conditions:*',
        ...invoiceTerms.map((term, i) => `${i + 1}. ${term}`),
        '',
      ]
      : []),
    'Thank you for your business!',
    [co.name, co.gstNo ? `GSTIN: ${co.gstNo}` : null, co.address].filter(Boolean).join(' | '),
  ].filter((line) => line !== null).join('\n');
}

export function downloadSalesInvoicePdf(sale, company) {
  const doc = buildSalesInvoicePdf(sale, company);
  doc.save(getSalesInvoiceFilename(sale));
}

export async function shareSalesInvoiceWhatsApp(sale, company) {
  const blob = getSalesInvoicePdfBlob(sale, company);
  const filename = getSalesInvoiceFilename(sale);
  const text = buildInvoiceShareText(sale, company);
  const file = new File([blob], filename, { type: 'application/pdf' });

  if (navigator.share && navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({
        title: `Invoice ${sale.SalesNo}`,
        text,
        files: [file],
      });
      return;
    } catch (err) {
      if (err?.name === 'AbortError') return;
    }
  }

  const phoneInput = window.prompt(
    'Enter WhatsApp number with country code (e.g. 919876543210).\nLeave blank to choose contact in WhatsApp.',
    ''
  );
  if (phoneInput === null) return;

  downloadPdfBlob(blob, filename);

  const phone = phoneInput.replace(/\D/g, '');
  const message = `${text}\n\nPDF invoice downloaded. Please attach *${filename}* in WhatsApp.`;
  const url = phone
    ? `https://wa.me/${phone}?text=${encodeURIComponent(message)}`
    : `https://wa.me/?text=${encodeURIComponent(message)}`;

  window.open(url, '_blank', 'noopener,noreferrer');
}

export function shareSalesInvoiceEmail(sale, company) {
  const co = resolveCompany(company);
  const text = buildInvoiceShareText(sale, company);
  const filename = getSalesInvoiceFilename(sale);
  const emailInput = window.prompt('Enter customer email (optional):', '');
  if (emailInput === null) return;

  downloadSalesInvoicePdf(sale, company);

  const subject = `Tax Invoice ${sale.SalesNo} - ${co.name}`;
  const body = [
    text.replace(/\*/g, ''),
    '',
    `PDF invoice "${filename}" has been downloaded to your device.`,
    'Please attach it to this email before sending.',
  ].join('\n');

  const to = emailInput.trim();
  const mailto = to
    ? `mailto:${encodeURIComponent(to)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
    : `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;

  window.location.href = mailto;
}
