import { useEffect, useMemo, useState } from 'react';
import { Plus, Pencil, Trash2 } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, Button, Input, Textarea, Alert, Table, ListToolbar, Pagination, PageLoading } from '../components/UI';
import { matchSearch, paginate, PAGE_SIZE } from '../utils/listHelpers';
import { fetchSuppliers, invalidateMasterCache } from '../utils/masterCache';

const emptyForm = {
  supplierName: '',
  gstNo: '',
  mobileNo: '',
  address1: '',
  address2: '',
  remark: '',
  email: '',
};

const SEARCH_FIELDS = ['SupplierName', 'GSTNo', 'MobileNo', 'Address1', 'Address2', 'Remark', 'Email'];

export default function SupplierMaster() {
  const [suppliers, setSuppliers] = useState([]);
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
    fetchSuppliers(true).then(setSuppliers).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { setPage(1); }, [search]);

  const filtered = useMemo(
    () => suppliers.filter((s) => matchSearch(s, search, SEARCH_FIELDS)),
    [suppliers, search]
  );
  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filtered, page, PAGE_SIZE),
    [filtered, page]
  );

  const openAdd = () => {
    setForm(emptyForm);
    setEditId(null);
    setShowForm(true);
    setError('');
    setSuccess('');
  };

  const openEdit = (s) => {
    setForm({
      supplierName: s.SupplierName || '',
      gstNo: s.GSTNo || '',
      mobileNo: s.MobileNo || '',
      address1: s.Address1 || '',
      address2: s.Address2 || '',
      remark: s.Remark || '',
      email: s.Email || '',
    });
    setEditId(s.SupplierId);
    setShowForm(true);
    setError('');
    setSuccess('');
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    try {
      setSaving(true);
      await api.post('/suppliers', { supplierId: editId, ...form });
      invalidateMasterCache('suppliers');
      setSuccess(editId ? 'Supplier updated' : 'Supplier added');
      setShowForm(false);
      load();
    } catch (err) {
      setError(err.response?.data?.error || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this supplier?')) return;
    setError('');
    setSuccess('');
    try {
      await api.delete(`/suppliers/${id}`);
      invalidateMasterCache('suppliers');
      setSuccess('Supplier deleted successfully');
      load();
    } catch (err) {
      const msg = err.response?.data?.error || 'Cannot delete this supplier';
      setError(msg);
      alert(msg);
    }
  };

  const columns = [
    { key: 'SupplierName', label: 'Supplier Name' },
    { key: 'GSTNo', label: 'GST No' },
    { key: 'MobileNo', label: 'Mobile No' },
    { key: 'Email', label: 'Email' },
    { key: 'Address1', label: 'Address 1' },
    { key: 'Address2', label: 'Address 2' },
    { key: 'Remark', label: 'Remark' },
    {
      key: 'actions', label: 'Actions',
      render: (r) => (
        <div className="flex gap-2">
          <button onClick={() => openEdit(r)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-600"><Pencil size={16} /></button>
          <button onClick={() => handleDelete(r.SupplierId)} className="p-1.5 rounded-lg hover:bg-red-50 text-red-500"><Trash2 size={16} /></button>
        </div>
      ),
    },
  ];

  if (loading) return <PageLoading message="Loading suppliers..." />;

  return (
    <div>
      <PageHeader
        title="Supplier Master"
        subtitle="Manage suppliers with GST, contact and address details"
        action={<Button onClick={openAdd}><Plus size={16} /> Add Supplier</Button>}
      />
      <Alert type="error" message={error} />
      <Alert type="success" message={success} />

      {showForm && (
        <Card className="p-4 sm:p-6 mb-6">
          <h3 className="font-semibold mb-4">{editId ? 'Edit Supplier' : 'New Supplier'}</h3>
          <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <Input label="Supplier Name *" value={form.supplierName} onChange={(e) => setForm({ ...form, supplierName: e.target.value })} required />
            <Input label="GST No" value={form.gstNo} onChange={(e) => setForm({ ...form, gstNo: e.target.value })} />
            <Input label="Mobile No" value={form.mobileNo} onChange={(e) => setForm({ ...form, mobileNo: e.target.value })} />
            <Input label="Email" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <Input label="Address 1" value={form.address1} onChange={(e) => setForm({ ...form, address1: e.target.value })} />
            <Input label="Address 2" value={form.address2} onChange={(e) => setForm({ ...form, address2: e.target.value })} />
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
          searchPlaceholder="Search by supplier name, GST, mobile, email, address..."
        />
        <Table columns={columns} data={items} keyField="SupplierId" />
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
