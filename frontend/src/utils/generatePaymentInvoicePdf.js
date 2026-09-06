import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
import { profileToCompany } from './accountProfile';

const DEFAULT_COMPANY = profileToCompany(null);

function formatDate(d) {
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function formatMoney(paise) {
  const rupees = Number(paise || 0) / 100;
  return `Rs. ${rupees.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
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

function resolveCompany(company) {
  return company && company.name ? company : DEFAULT_COMPANY;
}

function getPaymentDescription(payment) {
  const plan = String(payment.PlanType || 'standard').replace(/^\w/, (c) => c.toUpperCase());
  const cycle = payment.BillingCycle === 'yearly' ? 'Yearly' : 'Monthly';

  if (payment.PaymentType === 'AddUser') {
    const name = payment.UserFullName || payment.UserUsername || 'Team user';
    return `Additional team user — ${name} (prorated)`;
  }

  return `${plan} plan subscription (${cycle})`;
}

export function getPaymentInvoiceFilename(payment) {
  return `Payment_Invoice_${payment.PaymentHistoryId}.pdf`;
}

export function buildPaymentInvoicePdf(payment, company) {
  const co = resolveCompany(company);
  const brandRgb = hexToRgb(co.nameColor);
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const leftX = 14;
  let textX = leftX;

  if (co.logo) {
    try {
      doc.addImage(co.logo, getImageFormat(co.logo), leftX, 6, 18, 18);
      textX = leftX + 22;
    } catch {
      textX = leftX;
    }
  }

  doc.setTextColor(...brandRgb);
  doc.setFontSize(18);
  doc.setFont('helvetica', 'bold');
  doc.text(co.name, textX, 14);

  doc.setTextColor(30, 41, 59);
  doc.setFontSize(16);
  doc.text('PAYMENT INVOICE', 210 - leftX, 12, { align: 'right' });
  doc.setFontSize(10);
  doc.setFont('helvetica', 'normal');
  doc.text(`Invoice No: INV-PAY-${payment.PaymentHistoryId}`, 210 - leftX, 18, { align: 'right' });
  doc.text(`Date: ${formatDate(payment.CreatedAt)}`, 210 - leftX, 23, { align: 'right' });

  let y = 28;
  doc.setFontSize(9);
  doc.setTextColor(71, 85, 105);
  if (co.gstNo) {
    doc.text(`GSTIN: ${co.gstNo}`, textX, y);
    y += 5;
  }
  if (co.email) {
    doc.text(`Email: ${co.email}`, textX, y);
    y += 5;
  }
  if (co.address) {
    doc.text(co.address, textX, y, { maxWidth: 90 });
    y += 8;
  }

  doc.setDrawColor(226, 232, 240);
  doc.line(leftX, 42, 210 - leftX, 42);

  doc.setFontSize(10);
  doc.setTextColor(30, 41, 59);
  doc.setFont('helvetica', 'bold');
  doc.text('Bill To', leftX, 50);
  doc.setFont('helvetica', 'normal');
  doc.text(co.name, leftX, 56);
  if (co.gstNo) doc.text(`GSTIN: ${co.gstNo}`, leftX, 61);
  if (co.address) doc.text(co.address, leftX, 66, { maxWidth: 90 });

  const description = getPaymentDescription(payment);
  const amountRupees = Number(payment.AmountPaise || 0) / 100;

  autoTable(doc, {
    startY: 78,
    head: [['#', 'Description', 'Amount (INR)']],
    body: [[
      '1',
      description,
      amountRupees.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }),
    ]],
    theme: 'grid',
    headStyles: { fillColor: brandRgb, textColor: 255 },
    styles: { fontSize: 9, cellPadding: 3 },
    columnStyles: {
      0: { cellWidth: 12 },
      1: { cellWidth: 120 },
      2: { halign: 'right', cellWidth: 40 },
    },
  });

  const finalY = doc.lastAutoTable.finalY + 8;
  doc.setFont('helvetica', 'bold');
  doc.setFontSize(11);
  doc.text('Total Paid:', 130, finalY);
  doc.text(formatMoney(payment.AmountPaise), 210 - leftX, finalY, { align: 'right' });

  doc.setFont('helvetica', 'normal');
  doc.setFontSize(9);
  doc.setTextColor(71, 85, 105);
  doc.text(`Payment ID: ${payment.RazorpayPaymentId || '—'}`, leftX, finalY + 10);
  doc.text(`Order ID: ${payment.RazorpayOrderId || '—'}`, leftX, finalY + 15);
  doc.text(`Status: ${payment.PaymentStatus || 'Paid'}`, leftX, finalY + 20);
  doc.text('This is a computer-generated payment receipt for InventoryInOneTap subscription services.', leftX, finalY + 30, { maxWidth: 180 });

  return doc;
}

export function downloadPaymentInvoicePdf(payment, company) {
  const doc = buildPaymentInvoicePdf(payment, company);
  doc.save(getPaymentInvoiceFilename(payment));
}
