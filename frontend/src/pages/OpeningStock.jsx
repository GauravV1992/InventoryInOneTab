import { useEffect, useMemo, useState } from 'react';
import { Plus } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, WarehouseSelect, Autocomplete, Textarea, Alert, Table, ListToolbar, Pagination, PageLoading } from '../components/UI';
import { matchSearch, paginate, PAGE_SIZE } from '../utils/listHelpers';
import { fetchMasters } from '../utils/masterCache';
import { matchMaterial, materialLabel } from '../utils/autocompleteHelpers';

const emptyForm = {
  materialId: '',
  locationId: '',
  quantity: '',
  rate: '',
  stockDate: new Date().toISOString().split('T')[0],
  remark: '',
};
const SEARCH_FIELDS = ['MaterialName', 'Color', 'HSNCode', 'LocationName', 'Remark'];
const fmtMoney = (n) => `₹${Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

export default function OpeningStock() {
  const [records, setRecords] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [materialSearch, setMaterialSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [search, setSearch] = useState('');
  const [locationId, setLocationId] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      api.get('/opening-stock'),
      fetchMasters(),
    ]).then(([recordsRes, masters]) => {
      setRecords(recordsRes.data);
      setMaterials(masters.materials);
      setLocations(masters.locations);
    }).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { setPage(1); }, [search, locationId]);

  const filtered = useMemo(
    () => records.filter((r) => {
      if (locationId && String(r.LocationId) !== String(locationId)) return false;
      return matchSearch(r, search, SEARCH_FIELDS);
    }),
    [records, search, locationId]
  );
  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  const lineAmount = (parseFloat(form.quantity) || 0) * (parseFloat(form.rate) || 0);

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    if (!form.materialId) {
      setError('Select a material from suggestions');
      return;
    }
    try {
      setSaving(true);
      await api.post('/opening-stock', {
        materialId: parseInt(form.materialId),
        locationId: parseInt(form.locationId),
        quantity: parseFloat(form.quantity),
        rate: form.rate === '' ? null : parseFloat(form.rate),
        stockDate: form.stockDate,
        remark: form.remark || null,
      });
      setSuccess('Opening stock saved');
      setShowForm(false);
      setForm(emptyForm);
      setMaterialSearch('');
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const columns = [
    { key: 'MaterialName', label: 'Material' },
    { key: 'Color', label: 'Color' },
    { key: 'HSNCode', label: 'HSN' },
    { key: 'LocationName', label: 'Location' },
    { key: 'Quantity', label: 'Qty', render: (r) => `${r.Quantity} ${r.Unit}` },
    { key: 'Rate', label: 'Purchase Rate', render: (r) => fmtMoney(r.Rate) },
    { key: 'Amount', label: 'Amount', render: (r) => fmtMoney(r.Amount ?? (Number(r.Quantity) * Number(r.Rate || 0))) },
    { key: 'StockDate', label: 'Date', render: (r) => new Date(r.StockDate).toLocaleDateString('en-IN') },
    { key: 'Remark', label: 'Remark' },
  ];

  if (loading) return <PageLoading message="Loading opening stock..." />;

  return (
    <div>
      <PageHeader
        title="Opening Stock"
        subtitle="Set initial stock quantity and rate per material and warehouse"
        action={<Button onClick={() => { setShowForm(true); setError(''); setSuccess(''); setMaterialSearch(''); setForm(emptyForm); }}><Plus size={16} /> Add Opening Stock</Button>}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">New Opening Stock</h3>
          <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <Autocomplete
              label="Material"
              value={materialSearch}
              onChange={(v) => {
                setMaterialSearch(v);
                setForm({ ...form, materialId: '', rate: '' });
              }}
              onSelect={(m) => {
                setMaterialSearch(m.MaterialName);
                setForm({
                  ...form,
                  materialId: String(m.MaterialId),
                  rate: m.Rate != null ? String(m.Rate) : '',
                });
              }}
              options={materials}
              getOptionLabel={materialLabel}
              getOptionValue={(m) => m.MaterialId}
              filterOption={matchMaterial}
              placeholder="Type material (min 3 chars)..."
              required
            />
            <WarehouseSelect
              label="Warehouse"
              value={form.locationId}
              onChange={(id) => setForm({ ...form, locationId: id })}
              locations={locations}
              placeholder="Select warehouse"
              required
            />
            <Input label="Quantity *" type="number" step="0.001" value={form.quantity} onChange={(e) => setForm({ ...form, quantity: e.target.value })} required />
            <Input label="Purchase Rate ₹ *" type="number" step="0.01" value={form.rate} onChange={(e) => setForm({ ...form, rate: e.target.value })} required />
            <Input label="Amount ₹" type="text" value={fmtMoney(lineAmount)} readOnly />
            <Input label="Stock Date" type="date" value={form.stockDate} onChange={(e) => setForm({ ...form, stockDate: e.target.value })} />
            <div className="md:col-span-2 lg:col-span-3">
              <Textarea label="Remark" value={form.remark} onChange={(e) => setForm({ ...form, remark: e.target.value })} />
            </div>
            <div className="flex flex-col sm:flex-row gap-3 md:col-span-2 lg:col-span-3">
              <Button type="submit" loading={saving}>{saving ? 'Saving...' : 'Save Opening Stock'}</Button>
              <Button type="button" variant="secondary" onClick={() => setShowForm(false)}>Cancel</Button>
            </div>
          </form>
        </Card>
      )}

      <Card>
        <ListToolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search by material, color, HSN, location, remark..."
        >
          <div className="w-full lg:w-56">
            <WarehouseSelect
              label="Warehouse"
              value={locationId}
              onChange={(id) => setLocationId(id)}
              locations={locations}
              allowEmpty
              emptyLabel="All Warehouses"
            />
          </div>
        </ListToolbar>
        <Table columns={columns} data={items} keyField="OpeningStockId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
