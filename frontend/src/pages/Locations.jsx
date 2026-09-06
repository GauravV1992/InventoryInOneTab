import { useEffect, useMemo, useState } from 'react';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Alert, Table, ListToolbar, Pagination, PageLoading } from '../components/UI';
import { matchSearch, paginate, PAGE_SIZE } from '../utils/listHelpers';
import { fetchLocations, invalidateMasterCache } from '../utils/masterCache';

const emptyForm = { locationName: '', address: '', city: '' };
const SEARCH_FIELDS = ['LocationName', 'Address', 'City'];

const fmtLimit = (value) => (value == null || value >= 999999 ? 'Unlimited' : String(value));

export default function Locations() {
  const [locations, setLocations] = useState([]);
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
      fetchLocations(true),
      api.get('/billing/limits'),
    ]).then(([locations, limitsRes]) => {
      setLocations(locations);
      setSubscription(limitsRes.data);
    }).catch(() => {
      fetchLocations(true).then(setLocations).catch(() => {});
      api.get('/billing/subscription').then(({ data: sub }) => setSubscription(sub)).catch(() => {});
    }).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { setPage(1); }, [search]);

  const filtered = useMemo(
    () => locations.filter((l) => matchSearch(l, search, SEARCH_FIELDS)),
    [locations, search]
  );
  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  const planType = subscription?.planType ?? subscription?.PlanType;
  const maxWarehouses = subscription?.maxWarehouses ?? subscription?.MaxWarehouses;
  const activeWarehouses = subscription?.activeWarehouses ?? subscription?.ActiveWarehouses ?? locations.length;
  const canAddWarehouse = subscription?.canAddWarehouse ?? (maxWarehouses == null || maxWarehouses >= 999999 || activeWarehouses < maxWarehouses);

  const openAdd = () => {
    if (subscription && !canAddWarehouse) {
      if (subscription.subscriptionActive === false) {
        setError('Your subscription has expired. Please renew on the Pricing page.');
      } else {
        setError(`Warehouse limit reached (${activeWarehouses}/${fmtLimit(maxWarehouses)}). Upgrade your plan on Pricing page.`);
      }
      return;
    }
    setForm(emptyForm);
    setEditId(null);
    setShowForm(true);
    setError('');
    setSuccess('');
  };
  const openEdit = (l) => {
    setForm({ locationName: l.LocationName, address: l.Address || '', city: l.City || '' });
    setEditId(l.LocationId);
    setShowForm(true);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    if (!editId && subscription && !canAddWarehouse) {
      setError('Warehouse limit reached. Upgrade your plan on Pricing page.');
      return;
    }
    try {
      setSaving(true);
      await api.post('/locations', { locationId: editId, ...form });
      invalidateMasterCache('locations');
      setSuccess(editId ? 'Location updated' : 'Location added');
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this warehouse location?')) return;
    setError('');
    setSuccess('');
    try {
      await api.delete(`/locations/${id}`);
      invalidateMasterCache('locations');
      setSuccess('Warehouse deleted successfully');
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Cannot delete this warehouse';
      setError(msg);
      alert(msg);
    }
  };

  const columns = [
    { key: 'LocationName', label: 'Warehouse / Location' },
    { key: 'Address', label: 'Address' },
    { key: 'City', label: 'City' },
    {
      key: 'actions', label: 'Actions',
      render: (r) => (
        <div className="flex gap-2">
          <button onClick={() => openEdit(r)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-600"><Pencil size={16} /></button>
          <button onClick={() => handleDelete(r.LocationId)} className="p-1.5 rounded-lg hover:bg-red-50 text-red-500"><Trash2 size={16} /></button>
        </div>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading warehouse locations..." />;

  return (
    <div>
      <PageHeader
        title="Warehouse Locations"
        subtitle="Manage stock warehouse locations for inward and outward"
        action={(
          <Button onClick={openAdd} disabled={subscription && !canAddWarehouse}>
            <Plus size={16} /> Add Location
          </Button>
        )}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {subscription && (
        <Card className="p-4 mb-6">
          <p className="text-sm text-slate-600">
            Plan: <strong className="capitalize">{planType}</strong>
            {' · '}Warehouses: <strong>{activeWarehouses}</strong> / {fmtLimit(maxWarehouses)}
            {!canAddWarehouse && (
              <span className="text-amber-600 ml-2">
                {subscription.subscriptionActive === false
                  ? 'Subscription expired — renew on Pricing page.'
                  : 'Warehouse limit reached — upgrade your plan on Pricing page.'}
              </span>
            )}
          </p>
        </Card>
      )}

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">{editId ? 'Edit Location' : 'New Location'}</h3>
          <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Input label="Location Name *" value={form.locationName} onChange={(e) => setForm({ ...form, locationName: e.target.value })} required />
            <Input label="Address" value={form.address} onChange={(e) => setForm({ ...form, address: e.target.value })} />
            <Input label="City" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} />
            <div className="flex flex-col sm:flex-row gap-3 md:col-span-3">
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
          searchPlaceholder="Search by warehouse, address, city..."
        />
        <Table columns={columns} data={items} keyField="LocationId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
