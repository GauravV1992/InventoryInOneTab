import { useCallback, useEffect, useMemo, useState } from 'react';
import { Plus, Trash2, Pencil } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, WarehouseSelect, Autocomplete, Alert, Table, Pagination, PageLoading } from '../components/UI';
import { filterByDateRange, paginate, defaultMonthRange, PAGE_SIZE } from '../utils/listHelpers';
import { matchMaterial, matchSupplier, materialLabel, materialDisplayName } from '../utils/autocompleteHelpers';
import { fetchMasters, invalidateMasterCache } from '../utils/masterCache';

const emptyLine = { materialId: '', materialName: '', color: '', size: '', locationId: '', quantity: '', rate: '' };

export default function PurchaseInward() {
  const [records, setRecords] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [suppliers, setSuppliers] = useState([]);
  const [locations, setLocations] = useState([]);
  const [editId, setEditId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [page, setPage] = useState(1);
  const [filters, setFilters] = useState(defaultMonthRange());
  const [header, setHeader] = useState({
    purchaseDate: new Date().toISOString().split('T')[0],
    supplierName: '',
    remark: '',
  });
  const [details, setDetails] = useState([{ ...emptyLine }]);
  const [materialOptions, setMaterialOptions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      api.get('/purchase-inward'),
      fetchMasters(),
    ]).then(([recordsRes, masters]) => {
      setRecords(recordsRes.data);
      setMaterials(masters.materials);
      setMaterialOptions(masters.materials);
      setSuppliers(masters.suppliers);
      setLocations(masters.locations);
    }).catch(() => {}).finally(() => setLoading(false));
  };

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
      if (!acc[row.PurchaseId]) acc[row.PurchaseId] = { ...row, items: [] };
      if (row.MaterialName) acc[row.PurchaseId].items.push(row);
    });
    return Object.values(acc);
  }, [records]);

  const filtered = useMemo(
    () => filterByDateRange(grouped, 'PurchaseDate', filters.fromDate, filters.toDate),
    [grouped, filters]
  );

  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  useEffect(() => { setPage(1); }, [filters.fromDate, filters.toDate]);

  const resetForm = () => {
    setHeader({
      purchaseDate: new Date().toISOString().split('T')[0],
      supplierName: '',
      remark: '',
    });
    setDetails([{ ...emptyLine }]);
    setEditId(null);
    setMaterialOptions(materials);
  };

  const openAdd = () => {
    resetForm();
    setShowForm(true);
    setError('');
    setSuccess('');
  };

  const openEdit = (record) => {
    setEditId(record.PurchaseId);
    setHeader({
      purchaseDate: new Date(record.PurchaseDate).toISOString().split('T')[0],
      supplierName: record.SupplierName || '',
      remark: record.Remark || '',
    });
    setDetails(
      record.items.length
        ? record.items.map((i) => ({
          materialId: String(i.MaterialId),
          materialName: i.MaterialName || '',
          color: i.Color || '',
          size: i.Size || '',
          locationId: String(i.LocationId || ''),
          quantity: String(i.Quantity),
          rate: String(i.Rate),
        }))
        : [{ ...emptyLine }]
    );
    setMaterialOptions(materials);
    setShowForm(true);
    setError('');
    setSuccess('');
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this purchase? Stock will be reversed if allowed.')) return;
    setError('');
    setSuccess('');
    try {
      await api.delete(`/purchase-inward/${id}`);
      setSuccess('Purchase deleted successfully');
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Cannot delete this purchase';
      setError(msg);
      alert(msg);
    }
  };

  const addRow = () => setDetails([...details, { ...emptyLine }]);
  const removeRow = (i) => setDetails(details.filter((_, idx) => idx !== i));
  const updateRow = (i, field, val) => {
    const updated = [...details];
    updated[i][field] = val;
    if (field === 'materialName') {
      const selected = materials.find((m) => m.MaterialId === parseInt(updated[i].materialId, 10));
      if (!selected || selected.MaterialName !== val) {
        updated[i].materialId = '';
        updated[i].color = '';
        updated[i].size = '';
      }
    }
    setDetails(updated);
  };

  const selectMaterial = async (i, mat) => {
    let selected = mat;
    try {
      const { data } = await api.get(`/materials/${mat.MaterialId}`);
      selected = data;
    } catch {
      // use autocomplete selection if detail fetch fails
    }

    const updated = [...details];
    updated[i] = {
      ...updated[i],
      materialId: String(selected.MaterialId),
      materialName: selected.MaterialName,
      color: selected.Color || '',
      size: selected.Size || '',
      rate: selected.Rate,
    };
    setDetails(updated);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');

    const rawLines = details.filter(
      (d) => (d.materialId || d.materialName?.trim()) && d.quantity
    );

    if (rawLines.length === 0) {
      setError('Add at least one item with material name and quantity');
      return;
    }

    if (rawLines.some((d) => !d.materialName?.trim())) {
      setError('Enter material name for each row');
      return;
    }

    if (rawLines.some((d) => !d.locationId)) {
      setError('Select warehouse for each line item');
      return;
    }

    try {
      setSaving(true);
      let supplierCreated = false;
      const supplierName = header.supplierName?.trim();
      if (supplierName) {
        const exists = suppliers.find(
          (s) => s.SupplierName.toLowerCase() === supplierName.toLowerCase()
        );
        if (!exists) {
          await api.post('/suppliers', {
            supplierName,
            remark: 'Auto-created from Purchase Inward',
          });
          supplierCreated = true;
        }
      }

      let materialsCreated = 0;
      const finalDetails = [];

      for (const d of rawLines) {
        const materialName = d.materialName.trim();
        let materialId = d.materialId ? parseInt(d.materialId, 10) : null;
        const rate = parseFloat(d.rate) || 0;
        const quantity = parseFloat(d.quantity);

        if (!materialId) {
          const found = materials.find(
            (m) => m.MaterialName.toLowerCase() === materialName.toLowerCase()
          );
          if (found) {
            materialId = found.MaterialId;
          } else {
            const { data } = await api.post('/materials', {
              materialName,
              rate,
              unit: 'Pcs',
              remark: 'Auto-created from Purchase Inward',
            });
            materialId = data.MaterialId;
            materialsCreated += 1;
          }
        }

        finalDetails.push({
          materialId,
          locationId: parseInt(d.locationId, 10),
          quantity,
          rate,
        });
      }

      const payload = {
        ...header,
        supplierName: supplierName || '',
        locationId: finalDetails[0].locationId,
        details: finalDetails,
      };

      const { data } = editId
        ? await api.put(`/purchase-inward/${editId}`, payload)
        : await api.post('/purchase-inward', payload);

      const extras = [];
      if (!editId && (supplierCreated || data.createdSupplier)) extras.push('new supplier added to master');
      if (!editId && (materialsCreated > 0 || data.createdMaterials > 0)) {
        extras.push(`${materialsCreated || data.createdMaterials} new material(s) added to master`);
      }

      setSuccess(
        editId
          ? `Purchase updated: ${data.PurchaseNo}`
          : `Purchase saved: ${data.PurchaseNo}${extras.length ? ` (${extras.join(', ')})` : ''}`
      );
      setShowForm(false);
      resetForm();
      if (supplierCreated || materialsCreated > 0) {
        invalidateMasterCache();
      }
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const columns = [
    { key: 'PurchaseNo', label: 'Purchase No' },
    { key: 'PurchaseDate', label: 'Date', render: (r) => new Date(r.PurchaseDate).toLocaleDateString('en-IN') },
    { key: 'SupplierName', label: 'Supplier' },
    {
      key: 'items', label: 'Items',
      render: (r) => r.items.map((i) => {
        const color = i.Color ? ` · ${i.Color}` : '';
        return `${materialDisplayName(i)}${color} @ ${i.LocationName || '—'} (${i.Quantity})`;
      }).join(', ') || '—',
    },
    {
      key: 'actions', label: 'Actions',
      render: (r) => (
        <div className="flex gap-2">
          <button type="button" onClick={() => openEdit(r)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-600"><Pencil size={16} /></button>
          <button type="button" onClick={() => handleDelete(r.PurchaseId)} className="p-1.5 rounded-lg hover:bg-red-50 text-red-500"><Trash2 size={16} /></button>
        </div>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading purchases..." />;

  return (
    <div>
      <PageHeader
        title="Purchase Inward"
        subtitle="Stock IN — new suppliers and materials are auto-added to master on save"
        action={<Button onClick={openAdd}><Plus size={16} /> New Purchase</Button>}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">{editId ? 'Edit Purchase Inward' : 'New Purchase Inward'}</h3>
          <form onSubmit={handleSave}>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
              <Input label="Purchase Date" type="date" value={header.purchaseDate} onChange={(e) => setHeader({ ...header, purchaseDate: e.target.value })} />
              <Autocomplete
                label="Supplier Name"
                value={header.supplierName}
                onChange={(v) => setHeader({ ...header, supplierName: v })}
                onSelect={(s) => setHeader({ ...header, supplierName: s.SupplierName })}
                options={suppliers}
                getOptionLabel={(s) => s.SupplierName}
                getOptionValue={(s) => s.SupplierId}
                filterOption={matchSupplier}
                placeholder="Type supplier name (min 3 chars)..."
              />
              <Input label="Remark" value={header.remark} onChange={(e) => setHeader({ ...header, remark: e.target.value })} />
            </div>

            <div className="border rounded-xl mb-4 overflow-visible">
              <div className="space-y-3 p-3 sm:p-4">
                {details.map((row, i) => (
                  <div key={i} className="border border-slate-200 rounded-xl p-3 sm:p-4 bg-slate-50/50">
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-3 items-end">
                      <Autocomplete
                        label="Material"
                        value={row.materialName || ''}
                        onChange={(v) => updateRow(i, 'materialName', v)}
                        onSelect={(m) => selectMaterial(i, m)}
                        onSearch={searchMaterials}
                        options={materialOptions}
                        getOptionLabel={materialLabel}
                        getOptionValue={(m) => m.MaterialId}
                        filterOption={matchMaterial}
                        placeholder="Type material (min 3 chars)..."
                        inputClassName="px-3 py-2 rounded-lg"
                      />
                      <Input
                        label="Color"
                        value={row.color || ''}
                        readOnly
                        placeholder="—"
                        className="bg-slate-50"
                      />
                      <Input
                        label="Size"
                        value={row.size || ''}
                        readOnly
                        placeholder="—"
                        className="bg-slate-50"
                      />
                      <WarehouseSelect
                        label="Warehouse *"
                        value={row.locationId}
                        onChange={(id) => updateRow(i, 'locationId', id)}
                        locations={locations}
                        placeholder="Select warehouse"
                        required
                        buttonClassName="px-3 py-2 rounded-lg"
                      />
                      <Input
                        label="Quantity"
                        type="number"
                        step="0.001"
                        value={row.quantity}
                        onChange={(e) => updateRow(i, 'quantity', e.target.value)}
                      />
                      <div className="flex gap-2 items-end">
                        <div className="flex-1 min-w-0">
                          <Input
                            label="Purchase Rate"
                            type="number"
                            step="0.01"
                            value={row.rate}
                            onChange={(e) => updateRow(i, 'rate', e.target.value)}
                          />
                        </div>
                        {details.length > 1 && (
                          <button type="button" onClick={() => removeRow(i)} className="p-2.5 mb-0.5 text-red-500 hover:bg-red-50 rounded-lg shrink-0" aria-label="Remove row">
                            <Trash2 size={18} />
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              <Button type="button" variant="outline" onClick={addRow}>+ Add Row</Button>
              <Button type="submit" loading={saving}>{saving ? 'Saving...' : (editId ? 'Update Purchase' : 'Save Purchase (Stock In)')}</Button>
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
        <Table columns={columns} data={items} keyField="PurchaseId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
