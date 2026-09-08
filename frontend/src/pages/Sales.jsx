import { useCallback, useEffect, useMemo, useState } from 'react';
import { Plus, Trash2, FileDown, Mail, Pencil } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Select, WarehouseSelect, Autocomplete, Alert, Table, Pagination, PageLoading } from '../components/UI';
import { WhatsAppIcon } from '../components/WhatsAppIcon';
import { filterByDateRange, paginate, defaultMonthRange, PAGE_SIZE } from '../utils/listHelpers';
import { matchMaterial, matchCustomer, materialLabel, materialDisplayName } from '../utils/autocompleteHelpers';
import { fetchAccountProfile, profileToCompany } from '../utils/accountProfile';
import { calcSalesTotals, calcSalesTotalsFromSale, autoRoundOff } from '../utils/salesTotals';
import { fetchMaterials, fetchLocations } from '../utils/masterCache';
import { DEFAULT_SALES_TERMS, parseSalesTerms, serializeSalesTerms } from '../utils/salesTerms';

async function runInvoiceAction(action, sale) {
  const mod = await import('../utils/generateSalesInvoicePdf');
  // Ensure customer billing fields are on the sale root for PDF
  const item0 = sale?.items?.[0] || {};
  const enriched = {
    ...sale,
    CustomerName: sale.CustomerName || item0.CustomerName || '',
    CustomerAddress1: sale.CustomerAddress1 || item0.CustomerAddress1 || '',
    CustomerAddress2: sale.CustomerAddress2 || item0.CustomerAddress2 || '',
    CustomerGSTNo: sale.CustomerGSTNo || item0.CustomerGSTNo || '',
    TermsAndConditions: sale.TermsAndConditions || item0.TermsAndConditions || null,
  };
  try {
    const profile = await fetchAccountProfile(true);
    await mod[action](enriched, profileToCompany(profile));
  } catch {
    await mod[action](enriched, profileToCompany(null));
  }
}

async function withCompanyProfile(action, sale) {
  await runInvoiceAction(action, sale);
}

const emptyRow = () => ({
  materialId: '',
  materialName: '',
  size: '',
  locationId: '',
  locationName: '',
  available: null,
  stockByLocation: [],
  quantity: '',
  rate: '',
});

const defaultHeader = () => ({
  salesDate: new Date().toISOString().split('T')[0],
  customerName: '',
  customerAddress1: '',
  customerAddress2: '',
  customerGSTNo: '',
  remark: '',
  gstRate: 18,
  discountType: 'percent',
  discountPercent: 0,
  discountAmount: 0,
  roundOff: 0,
});

const fmt = (n) => `₹${Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;

export default function Sales() {
  const [records, setRecords] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [locations, setLocations] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [editId, setEditId] = useState(null);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState(defaultMonthRange());
  const [header, setHeader] = useState(defaultHeader());
  const [details, setDetails] = useState([emptyRow()]);
  const [terms, setTerms] = useState([...DEFAULT_SALES_TERMS]);
  const [customerOptions, setCustomerOptions] = useState([]);
  const [materialOptions, setMaterialOptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      api.get('/sales'),
      fetchMaterials(),
      fetchLocations(),
      api.get('/customers'),
    ]).then(([salesRes, materials, locations, customersRes]) => {
      setRecords(salesRes.data);
      setMaterials(materials);
      setMaterialOptions(materials);
      setLocations(locations);
      setCustomerOptions(customersRes.data);
    }).catch(() => {}).finally(() => setLoading(false));
  };

  const searchCustomers = useCallback(async (q) => {
    try {
      const { data } = await api.get('/customers', { params: { search: q } });
      setCustomerOptions(data);
    } catch {
      setCustomerOptions([]);
    }
  }, []);

  const searchMaterials = useCallback(async (q) => {
    try {
      const { data } = await api.get('/materials', { params: { search: q } });
      setMaterialOptions(data);
    } catch {
      setMaterialOptions([]);
    }
  }, []);

  useEffect(() => { load(); }, []);

  const grouped = useMemo(() => {
    const acc = {};
    records.forEach((row) => {
      if (!acc[row.SalesId]) {
        acc[row.SalesId] = { ...row, items: [] };
      } else {
        // Keep latest non-empty customer billing fields from any detail row
        const cur = acc[row.SalesId];
        if (!cur.CustomerAddress1 && row.CustomerAddress1) cur.CustomerAddress1 = row.CustomerAddress1;
        if (!cur.CustomerAddress2 && row.CustomerAddress2) cur.CustomerAddress2 = row.CustomerAddress2;
        if (!cur.CustomerGSTNo && row.CustomerGSTNo) cur.CustomerGSTNo = row.CustomerGSTNo;
        if (!cur.CustomerName && row.CustomerName) cur.CustomerName = row.CustomerName;
        if (!cur.TermsAndConditions && row.TermsAndConditions) cur.TermsAndConditions = row.TermsAndConditions;
      }
      if (row.MaterialName) {
        acc[row.SalesId].items.push({
          ...row,
          LocationName: row.DetailLocationName || row.LocationName,
        });
      }
    });
    return Object.values(acc);
  }, [records]);

  const filtered = useMemo(
    () => filterByDateRange(grouped, 'SalesDate', filters.fromDate, filters.toDate),
    [grouped, filters]
  );

  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  useEffect(() => { setPage(1); }, [filters.fromDate, filters.toDate]);

  const lineItemsForCalc = useMemo(
    () => details.filter((d) => d.materialId && d.quantity).map((d) => ({
      quantity: parseFloat(d.quantity),
      rate: parseFloat(d.rate) || 0,
    })),
    [details]
  );

  const totals = useMemo(
    () => calcSalesTotals(lineItemsForCalc, header),
    [lineItemsForCalc, header]
  );

  const resetForm = () => {
    setHeader(defaultHeader());
    setDetails([emptyRow()]);
    setTerms([...DEFAULT_SALES_TERMS]);
    setEditId(null);
    setMaterialOptions(materials);
  };

  const openAdd = () => {
    resetForm();
    setShowForm(true);
    setError('');
    setSuccess('');
    api.get('/customers').then(({ data }) => setCustomerOptions(data)).catch(() => {});
  };

  const openEdit = async (record) => {
    setEditId(record.SalesId);
    setHeader({
      salesDate: new Date(record.SalesDate).toISOString().split('T')[0],
      customerName: record.CustomerName || '',
      customerAddress1: record.CustomerAddress1 || '',
      customerAddress2: record.CustomerAddress2 || '',
      customerGSTNo: record.CustomerGSTNo || '',
      remark: record.Remark || '',
      gstRate: record.GSTRate ?? 18,
      discountType: (record.DiscountType || 'percent').toLowerCase(),
      discountPercent: record.DiscountPercent ?? 0,
      discountAmount: record.DiscountAmount ?? 0,
      roundOff: record.RoundOff ?? 0,
    });
    const loadedTerms = parseSalesTerms(record.TermsAndConditions);
    setTerms(loadedTerms.length ? loadedTerms : [...DEFAULT_SALES_TERMS]);

    const rows = await Promise.all(
      (record.items || []).map(async (item) => {
        const row = {
          materialId: String(item.MaterialId),
          materialName: item.MaterialName || '',
          size: item.Size || '',
          locationId: String(item.DetailLocationId || item.LocationId || ''),
          locationName: item.DetailLocationName || item.LocationName || '',
          available: null,
          stockByLocation: [],
          quantity: String(item.Quantity),
          rate: String(item.Rate),
        };
        try {
          const { data } = await api.get(`/stock/by-material/${item.MaterialId}`);
          row.stockByLocation = data || [];
          const loc = row.stockByLocation.find(
            (l) => String(l.LocationId) === String(row.locationId)
          );
          if (loc) row.available = loc.AvailableStock;
        } catch {
          row.stockByLocation = [];
        }
        return row;
      })
    );

    setDetails(rows.length ? rows : [emptyRow()]);
    setMaterialOptions(materials);
    setShowForm(true);
    setError('');
    setSuccess('');
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this sale? Stock will be restored.')) return;
    setError('');
    setSuccess('');
    try {
      await api.delete(`/sales/${id}`);
      setSuccess('Sale deleted successfully');
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Cannot delete this sale';
      setError(msg);
      alert(msg);
    }
  };

  const addRow = () => setDetails([...details, emptyRow()]);
  const removeRow = (i) => setDetails(details.filter((_, idx) => idx !== i));

  const onMaterialSelect = async (i, mat) => {
    let selected = mat;
    try {
      const { data } = await api.get(`/materials/${mat.MaterialId}`);
      selected = data;
    } catch {
      // use autocomplete selection if detail fetch fails
    }

    const updated = [...details];
    updated[i] = {
      ...emptyRow(),
      materialId: String(selected.MaterialId),
      materialName: selected.MaterialName,
      size: selected.Size || '',
      rate: selected.SalesRate != null && selected.SalesRate !== ''
        ? selected.SalesRate
        : selected.Rate,
    };

    try {
      const { data } = await api.get(`/stock/by-material/${selected.MaterialId}`);
      updated[i].stockByLocation = data || [];
    } catch {
      updated[i].stockByLocation = [];
    }

    setDetails(updated);
  };

  const onMaterialSearchChange = (i, val) => {
    const updated = [...details];
    const selected = materials.find((m) => m.MaterialId === parseInt(updated[i].materialId, 10));
    if (!selected || selected.MaterialName !== val) {
      updated[i] = { ...emptyRow(), materialName: val };
    } else {
      updated[i].materialName = val;
    }
    setDetails(updated);
  };

  const selectWarehouse = (i, loc) => {
    if (!loc) {
      const updated = [...details];
      updated[i] = { ...updated[i], locationId: '', locationName: '', available: null };
      setDetails(updated);
      return;
    }
    const stock = details[i].stockByLocation?.find(
      (s) => String(s.LocationId) === String(loc.LocationId)
    );
    const updated = [...details];
    updated[i] = {
      ...updated[i],
      locationId: String(loc.LocationId),
      locationName: loc.LocationName,
      available: stock != null ? stock.AvailableStock : 0,
    };
    setDetails(updated);
  };

  const updateRow = (i, field, val) => {
    const updated = [...details];
    updated[i][field] = val;
    setDetails(updated);
  };

  const applyAutoRoundOff = () => {
    const ro = autoRoundOff(totals.taxable, totals.gstAmount);
    setHeader({ ...header, roundOff: ro });
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');

    const validDetails = details
      .filter((d) => d.materialId && d.locationId && d.quantity)
      .map((d) => ({
        materialId: parseInt(d.materialId, 10),
        locationId: parseInt(d.locationId, 10),
        quantity: parseFloat(d.quantity),
        rate: parseFloat(d.rate) || 0,
      }));

    if (validDetails.length === 0) {
      setError('Add at least one item with material, warehouse and quantity');
      return;
    }

    if (details.some((d) => d.materialId && !d.locationId)) {
      const msg = 'Please select warehouse for each material';
      setError(msg);
      alert(msg);
      return;
    }

    try {
      setSaving(true);
      const payload = {
        salesDate: header.salesDate,
        customerName: header.customerName,
        customerAddress1: header.customerAddress1,
        customerAddress2: header.customerAddress2,
        customerGSTNo: header.customerGSTNo,
        remark: header.remark,
        termsAndConditions: serializeSalesTerms(terms),
        gstRate: header.gstRate,
        discountType: header.discountType,
        discountPercent: header.discountPercent,
        discountAmount: header.discountAmount,
        roundOff: header.roundOff,
        details: validDetails,
      };

      const { data } = editId
        ? await api.put(`/sales/${editId}`, payload)
        : await api.post('/sales', payload);

      setSuccess(
        editId
          ? `Sales updated: ${data.SalesNo} — Total ${fmt(data.GrandTotal ?? totals.grandTotal)}`
          : `Sales saved: ${data.SalesNo} — Total ${fmt(data.GrandTotal ?? totals.grandTotal)}`
      );
      setShowForm(false);
      resetForm();
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Save failed — check stock availability';
      setError(msg);
      alert(msg);
    } finally {
      setSaving(false);
    }
  };

  const columns = [
    { key: 'SalesNo', label: 'Sales No' },
    { key: 'SalesDate', label: 'Date', render: (r) => new Date(r.SalesDate).toLocaleDateString('en-IN') },
    { key: 'CustomerName', label: 'Customer' },
    {
      key: 'items', label: 'Items',
      render: (r) => r.items.map((i) =>
        `${materialDisplayName(i)} @ ${i.LocationName || '—'} (${i.Quantity})`
      ).join(', ') || '—',
    },
    {
      key: 'total', label: 'Grand Total',
      render: (r) => fmt(calcSalesTotalsFromSale(r).grandTotal),
    },
    {
      key: 'invoice',
      label: 'Invoice',
      mobileRole: 'actions',
      render: (r) => (
        <div className="flex items-center gap-1.5 flex-wrap">
          <button type="button" onClick={() => openEdit(r)} title="Edit" className="inline-flex items-center justify-center p-2 min-h-10 min-w-10 rounded-lg text-slate-600 hover:bg-slate-100 border border-slate-200 transition">
            <Pencil size={16} />
          </button>
          <button type="button" onClick={() => handleDelete(r.SalesId)} title="Delete" className="inline-flex items-center justify-center p-2 min-h-10 min-w-10 rounded-lg text-red-500 hover:bg-red-50 border border-red-200 transition">
            <Trash2 size={16} />
          </button>
          <button
            type="button"
            onClick={() => withCompanyProfile('downloadSalesInvoicePdf', r)}
            title="Download PDF"
            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-xs font-medium bg-brand-50 text-brand-700 border border-brand-200 hover:bg-brand-100 transition"
          >
            <FileDown size={14} />
            PDF
          </button>
          <button
            type="button"
            onClick={() => withCompanyProfile('shareSalesInvoiceWhatsApp', r)}
            title="Send via WhatsApp"
            className="inline-flex items-center justify-center p-1.5 rounded-lg text-white bg-[#25D366] hover:bg-[#1da851] border border-[#1da851] transition"
          >
            <WhatsAppIcon size={15} />
          </button>
          <button
            type="button"
            onClick={() => withCompanyProfile('shareSalesInvoiceEmail', r)}
            title="Send via Email"
            className="inline-flex items-center justify-center p-1.5 rounded-lg text-white bg-sky-600 hover:bg-sky-700 border border-sky-700 transition"
          >
            <Mail size={15} />
          </button>
        </div>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading sales..." />;

  return (
    <div>
      <PageHeader
        title="Sales"
        subtitle="Stock OUT with GST, discount and round off"
        action={<Button onClick={openAdd}><Plus size={16} /> New Sale</Button>}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">{editId ? 'Edit Sales (Stock Out)' : 'New Sales (Stock Out)'}</h3>
          <form onSubmit={handleSave}>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
              <Input label="Sales Date" type="date" value={header.salesDate} onChange={(e) => setHeader({ ...header, salesDate: e.target.value })} />
              <Autocomplete
                label="Customer Name"
                value={header.customerName}
                onChange={(v) => setHeader({ ...header, customerName: v })}
                onSelect={(c) => setHeader({
                  ...header,
                  customerName: c.CustomerName,
                  customerAddress1: c.CustomerAddress1 || header.customerAddress1,
                  customerAddress2: c.CustomerAddress2 || header.customerAddress2,
                  customerGSTNo: c.CustomerGSTNo || header.customerGSTNo,
                })}
                onSearch={searchCustomers}
                options={customerOptions}
                getOptionLabel={(c) => c.CustomerName}
                getOptionValue={(c) => c.CustomerName}
                filterOption={matchCustomer}
                placeholder="Type customer name (min 3 chars)..."
              />
              <Input
                label="Customer GST No"
                value={header.customerGSTNo}
                onChange={(e) => setHeader({ ...header, customerGSTNo: e.target.value })}
                placeholder="Optional"
              />
              <Input
                label="Customer Address 1"
                value={header.customerAddress1}
                onChange={(e) => setHeader({ ...header, customerAddress1: e.target.value })}
                placeholder="Optional"
              />
              <Input
                label="Customer Address 2"
                value={header.customerAddress2}
                onChange={(e) => setHeader({ ...header, customerAddress2: e.target.value })}
                placeholder="Optional"
              />
              <Input label="Remark" value={header.remark} onChange={(e) => setHeader({ ...header, remark: e.target.value })} />
            </div>

            <div className="space-y-4 mb-4 relative isolate">
              {details.map((row, i) => (
                <div key={i} className="border border-slate-200 rounded-xl p-4 bg-slate-50/50 relative">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-3 items-end">
                    <div className="lg:col-span-2 relative">
                      <Autocomplete
                        label="Material"
                        value={row.materialName || ''}
                        onChange={(v) => onMaterialSearchChange(i, v)}
                        onSelect={(m) => onMaterialSelect(i, m)}
                        onSearch={searchMaterials}
                        options={materialOptions}
                        getOptionLabel={materialLabel}
                        getOptionValue={(m) => m.MaterialId}
                        filterOption={matchMaterial}
                        placeholder="Type material (min 3 chars)..."
                        inputClassName="px-3 py-2 rounded-lg"
                        required
                      />
                    </div>
                    <div>
                      <Input
                        label="Size"
                        value={row.size || ''}
                        readOnly
                        placeholder="—"
                        className="bg-slate-50"
                      />
                    </div>
                    <div className="relative">
                      <WarehouseSelect
                        label="Warehouse"
                        value={row.locationId}
                        onChange={(id, loc) => selectWarehouse(i, loc)}
                        locations={locations}
                        placeholder="Select warehouse"
                        required
                        buttonClassName="px-3 py-2 rounded-lg"
                        getOptionMeta={(loc) => {
                          const stock = row.stockByLocation?.find(
                            (s) => String(s.LocationId) === String(loc.LocationId)
                          );
                          if (!row.materialId) return null;
                          return `Stock: ${stock != null ? stock.AvailableStock : 0}`;
                        }}
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-slate-600 mb-1.5">Available</label>
                      <input readOnly className="w-full px-3 py-2 rounded-lg border bg-white text-sm text-slate-600" value={row.available ?? '—'} />
                    </div>
                    <div className="flex flex-col sm:flex-row gap-2">
                      <div className="flex-1">
                        <label className="block text-sm font-medium text-slate-600 mb-1.5">Qty *</label>
                        <input type="number" step="0.001" className="w-full px-3 py-2 rounded-lg border bg-white text-base md:text-sm" value={row.quantity} onChange={(e) => updateRow(i, 'quantity', e.target.value)} />
                      </div>
                      <div className="flex-1">
                        <label className="block text-sm font-medium text-slate-600 mb-1.5">Sales Rate</label>
                        <input type="number" step="0.01" className="w-full px-3 py-2 rounded-lg border bg-white text-base md:text-sm" value={row.rate} onChange={(e) => updateRow(i, 'rate', e.target.value)} />
                      </div>
                      {details.length > 1 && (
                        <button type="button" onClick={() => removeRow(i)} className="self-end p-2.5 text-red-500 hover:bg-red-50 rounded-lg mb-0.5 shrink-0" aria-label="Remove row">
                          <Trash2 size={18} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="mb-4">
              <Button type="button" variant="outline" onClick={addRow}>+ Add Row</Button>
            </div>

            <div className="border border-slate-200 rounded-xl p-4 bg-white mb-4">
              <div className="flex flex-wrap items-center justify-between gap-2 mb-3">
                <h4 className="font-medium text-slate-700">Terms &amp; Conditions</h4>
                <div className="flex gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    className="text-xs px-2.5 py-1.5"
                    onClick={() => setTerms((prev) => [...prev, ''])}
                  >
                    + Add Term
                  </Button>
                  <Button
                    type="button"
                    variant="secondary"
                    className="text-xs px-2.5 py-1.5"
                    onClick={() => setTerms([...DEFAULT_SALES_TERMS])}
                  >
                    Reset Defaults
                  </Button>
                </div>
              </div>
              <div className="space-y-2">
                {terms.length === 0 ? (
                  <p className="text-sm text-slate-400">No terms. Add a term or reset defaults.</p>
                ) : (
                  terms.map((term, i) => (
                    <div key={i} className="flex gap-2 items-start">
                      <span className="mt-2.5 text-xs font-medium text-slate-400 w-5 shrink-0">{i + 1}.</span>
                      <textarea
                        rows={2}
                        className="flex-1 px-3 py-2 rounded-lg border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500/30 focus:border-brand-500"
                        value={term}
                        onChange={(e) => {
                          const next = [...terms];
                          next[i] = e.target.value;
                          setTerms(next);
                        }}
                        placeholder="Enter term..."
                      />
                      <button
                        type="button"
                        onClick={() => setTerms(terms.filter((_, idx) => idx !== i))}
                        className="mt-1 p-2 text-red-500 hover:bg-red-50 rounded-lg"
                        title="Remove term"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  ))
                )}
              </div>
            </div>

            {/* GST, Discount, Round Off */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
              <div className="border border-slate-200 rounded-xl p-4 bg-white">
                <h4 className="font-medium text-slate-700 mb-3">GST & Discount</h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <Input label="GST Rate (%)" type="number" step="0.01" value={header.gstRate} onChange={(e) => setHeader({ ...header, gstRate: e.target.value })} />
                  <Select label="Discount Type" value={header.discountType} onChange={(e) => setHeader({ ...header, discountType: e.target.value })}>
                    <option value="percent">Discount (%)</option>
                    <option value="amount">Discount Amount (₹)</option>
                  </Select>
                  {header.discountType === 'percent' ? (
                    <Input label="Discount (%)" type="number" step="0.01" value={header.discountPercent} onChange={(e) => setHeader({ ...header, discountPercent: e.target.value })} />
                  ) : (
                    <Input label="Discount Amount (₹)" type="number" step="0.01" value={header.discountAmount} onChange={(e) => setHeader({ ...header, discountAmount: e.target.value })} />
                  )}
                  <div>
                    <Input label="Round Off (₹)" type="number" step="0.01" value={header.roundOff} onChange={(e) => setHeader({ ...header, roundOff: e.target.value })} />
                    <button type="button" onClick={applyAutoRoundOff} className="mt-1 text-xs text-brand-600 hover:underline">
                      Auto round to nearest ₹
                    </button>
                  </div>
                </div>
              </div>

              <div className="border border-brand-200 rounded-xl p-4 bg-brand-50/30">
                <h4 className="font-medium text-slate-700 mb-3">Amount Summary</h4>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between"><span className="text-slate-600">Sub Total</span><span>{fmt(totals.subTotal)}</span></div>
                  <div className="flex justify-between"><span className="text-slate-600">Discount</span><span className="text-red-600">- {fmt(totals.discount)}</span></div>
                  <div className="flex justify-between"><span className="text-slate-600">Taxable Amount</span><span>{fmt(totals.taxable)}</span></div>
                  <div className="flex justify-between"><span className="text-slate-600">GST ({header.gstRate || 0}%)</span><span>{fmt(totals.gstAmount)}</span></div>
                  <div className="flex justify-between"><span className="text-slate-600">Round Off</span><span>{fmt(totals.roundOff)}</span></div>
                  <div className="flex justify-between pt-2 border-t border-brand-200 font-bold text-base">
                    <span>Grand Total</span><span className="text-brand-700">{fmt(totals.grandTotal)}</span>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              <Button type="submit" loading={saving}>{saving ? 'Saving...' : (editId ? 'Update Sale' : 'Save Sale (Stock Out)')}</Button>
              <Button type="button" variant="secondary" onClick={() => { setShowForm(false); resetForm(); }}>Cancel</Button>
            </div>
          </form>
        </Card>
      )}

      <Card>
        <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row gap-3 sm:items-end">
          <Input label="From Date" type="date" value={filters.fromDate} onChange={(e) => setFilters({ ...filters, fromDate: e.target.value })} />
          <Input label="To Date" type="date" value={filters.toDate} onChange={(e) => setFilters({ ...filters, toDate: e.target.value })} />
          <Button variant="secondary" className="w-full sm:w-auto" onClick={() => setFilters(defaultMonthRange())}>Last 1 Month</Button>
        </div>
        <Table columns={columns} data={items} keyField="SalesId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
