import { useEffect, useMemo, useState } from 'react';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Select, Textarea, Alert, Table, ListToolbar, Pagination, PageLoading } from '../components/UI';
import { matchSearch, paginate, PAGE_SIZE } from '../utils/listHelpers';
import { fetchMaterials, invalidateMasterCache } from '../utils/masterCache';

const emptyForm = {
  materialName: '',
  color: '',
  hsnCode: '',
  rate: '',
  salesRate: '',
  unit: 'Pcs',
  remark: '',
};
const SEARCH_FIELDS = ['MaterialName', 'Color', 'HSNCode', 'Remark'];

const fmtLimit = (value) => (value == null || value >= 999999 ? 'Unlimited' : String(value));
const fmtMoney = (n) => `₹${Number(n || 0).toFixed(2)}`;

export default function MaterialMaster() {
  const [materials, setMaterials] = useState([]);
  const [subscription, setSubscription] = useState(null);
  const [form, setForm] = useState(emptyForm);
  const [editId, setEditId] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  const load = () => {
    setLoading(true);
    Promise.all([
      fetchMaterials(true),
      api.get('/billing/limits'),
    ]).then(([materials, limitsRes]) => {
      setMaterials(materials);
      setSubscription(limitsRes.data);
    }).catch(() => {
      fetchMaterials(true).then((materials) => setMaterials(materials)).catch(() => {});
      api.get('/billing/subscription').then(({ data: sub }) => setSubscription(sub)).catch(() => {});
    }).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { setPage(1); }, [search]);

  const filtered = useMemo(
    () => materials.filter((m) => matchSearch(m, search, SEARCH_FIELDS)),
    [materials, search]
  );
  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  const planType = subscription?.planType ?? subscription?.PlanType;
  const maxMaterials = subscription?.maxMaterials ?? subscription?.MaxMaterials;
  const apiActive = subscription?.activeMaterials ?? subscription?.ActiveMaterials;
  const activeMaterials = apiActive != null
    ? Math.max(Number(apiActive) || 0, materials.length)
    : materials.length;
  const canAddMaterial = subscription?.canAddMaterial ?? (maxMaterials == null || maxMaterials >= 999999 || activeMaterials < maxMaterials);

  const openAdd = () => {
    if (subscription && !canAddMaterial) {
      if (subscription.subscriptionActive === false) {
        setError('Your subscription has expired. Please renew on the Pricing page.');
      } else {
        setError(`Material limit reached (${activeMaterials}/${fmtLimit(maxMaterials)}). Upgrade your plan on Pricing page.`);
      }
      return;
    }
    setForm(emptyForm);
    setEditId(null);
    setShowForm(true);
    setError('');
    setSuccess('');
  };
  const openEdit = (m) => {
    setForm({
      materialName: m.MaterialName,
      color: m.Color || '',
      hsnCode: m.HSNCode || '',
      rate: m.Rate != null ? String(m.Rate) : '',
      salesRate: m.SalesRate != null ? String(m.SalesRate) : '',
      unit: m.Unit,
      remark: m.Remark || '',
    });
    setEditId(m.MaterialId);
    setShowForm(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    if (!editId && subscription && !canAddMaterial) {
      setError('Material limit reached. Upgrade your plan on Pricing page.');
      return;
    }
    try {
      setSaving(true);
      await api.post('/materials', {
        materialId: editId,
        ...form,
        rate: parseFloat(form.rate) || 0,
        salesRate: parseFloat(form.salesRate) || 0,
      });
      invalidateMasterCache('materials');
      setSuccess(editId ? 'Material updated' : 'Material added');
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this material?')) return;
    setError('');
    setSuccess('');
    try {
      await api.delete(`/materials/${id}`);
      invalidateMasterCache('materials');
      setSuccess('Material deleted successfully');
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Cannot delete this material';
      setError(msg);
      alert(msg);
    }
  };

  const columns = [
    { key: 'MaterialName', label: 'Material Name' },
    { key: 'Color', label: 'Color' },
    { key: 'HSNCode', label: 'HSN Code' },
    { key: 'Rate', label: 'Purchase Rate', render: (r) => fmtMoney(r.Rate) },
    { key: 'SalesRate', label: 'Sales Rate', render: (r) => fmtMoney(r.SalesRate) },
    { key: 'Unit', label: 'Unit' },
    { key: 'Remark', label: 'Remark' },
    {
      key: 'actions', label: 'Actions',
      render: (r) => (
        <div className="flex gap-2">
          <button onClick={() => openEdit(r)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-600"><Pencil size={16} /></button>
          <button onClick={() => handleDelete(r.MaterialId)} className="p-1.5 rounded-lg hover:bg-red-50 text-red-500"><Trash2 size={16} /></button>
        </div>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading materials..." />;

  return (
    <div>
      <PageHeader
        title="Material Master"
        subtitle="Manage materials with HSN, purchase rate, sales rate, unit and remarks"
        action={(
          <Button onClick={openAdd} disabled={subscription && !canAddMaterial}>
            <Plus size={16} /> Add Material
          </Button>
        )}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {subscription && (
        <Card className="p-4 mb-6">
          <p className="text-sm text-slate-600">
            Plan: <strong className="capitalize">{planType}</strong>
            {' · '}Materials: <strong>{activeMaterials}</strong> / {fmtLimit(maxMaterials)}
            {!canAddMaterial && (
              <span className="text-amber-600 ml-2">
                {subscription.subscriptionActive === false
                  ? 'Subscription expired — renew on Pricing page.'
                  : 'Material limit reached — upgrade your plan on Pricing page.'}
              </span>
            )}
          </p>
        </Card>
      )}

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">{editId ? 'Edit Material' : 'New Material'}</h3>
          <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <Input label="Material Name *" value={form.materialName} onChange={(e) => setForm({ ...form, materialName: e.target.value })} required />
            <Input label="Color" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} />
            <Input label="HSN Code" value={form.hsnCode} onChange={(e) => setForm({ ...form, hsnCode: e.target.value })} />
            <Input label="Purchase Rate *" type="number" step="0.01" value={form.rate} onChange={(e) => setForm({ ...form, rate: e.target.value })} required />
            <Input label="Sales Rate" type="number" step="0.01" value={form.salesRate} onChange={(e) => setForm({ ...form, salesRate: e.target.value })} />
            <Select label="Unit" value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })}>
              {['Pcs', 'Kg', 'Box', 'Sq.Ft', 'Meter', 'Ltr'].map((u) => <option key={u} value={u}>{u}</option>)}
            </Select>
            <div className="md:col-span-2 lg:col-span-3">
              <Textarea label="Remark" value={form.remark} onChange={(e) => setForm({ ...form, remark: e.target.value })} />
            </div>
            <div className="flex flex-col sm:flex-row gap-3 md:col-span-2 lg:col-span-3">
              <Button type="submit" loading={saving}>{saving ? 'Saving...' : 'Save'}</Button>
              <Button type="button" variant="secondary" onClick={() => setShowForm(false)}>Cancel</Button>
            </div>
          </form>
        </Card>
      )}

      <Card>
        <ListToolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search by material name, color, HSN code, remark..."
        />
        <Table columns={columns} data={items} keyField="MaterialId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
