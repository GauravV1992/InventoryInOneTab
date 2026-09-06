import { useEffect, useMemo, useState } from 'react';
import api from '../api';
import { PageHeader, Card, WarehouseSelect, MaterialSelect, Badge, Table, Button, PageLoading, Loader, ListToolbar, Pagination } from '../components/UI';
import { fetchMaterials, fetchLocations } from '../utils/masterCache';
import { matchSearch, paginate, PAGE_SIZE } from '../utils/listHelpers';

const SUMMARY_SEARCH = ['MaterialName', 'Color', 'HSNCode', 'LocationName'];
const LEDGER_SEARCH = ['MaterialName', 'Color', 'HSNCode', 'LocationName', 'ReferenceNo', 'TransactionType'];

const fmtQty = (n) => {
  const value = Number(n);
  if (!Number.isFinite(value)) return '—';
  return value.toLocaleString('en-IN', { maximumFractionDigits: 3 });
};

export default function StockReport() {
  const [report, setReport] = useState([]);
  const [ledger, setLedger] = useState([]);
  const [locations, setLocations] = useState([]);
  const [materials, setMaterials] = useState([]);
  const [filters, setFilters] = useState({ locationId: '', materialId: '', fromDate: '', toDate: '' });
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [tab, setTab] = useState('summary');
  const [showZeroStock, setShowZeroStock] = useState(false);
  const [loading, setLoading] = useState(true);
  const [filtering, setFiltering] = useState(false);

  useEffect(() => {
    Promise.all([fetchLocations(), fetchMaterials()])
      .then(([locations, materials]) => {
        setLocations(locations);
        setMaterials(materials);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
    loadSummary(true);
  }, []);

  useEffect(() => { setPage(1); }, [search, tab, report, ledger, showZeroStock]);

  const loadSummary = (silent = false) => {
    if (!silent) setFiltering(true);
    const params = {};
    if (filters.locationId) params.locationId = filters.locationId;
    if (filters.materialId) params.materialId = filters.materialId;
    api.get('/stock-report', { params })
      .then(({ data }) => setReport(data))
      .catch(() => {})
      .finally(() => { if (!silent) setFiltering(false); });
  };

  const loadLedger = () => {
    setFiltering(true);
    const params = {};
    if (filters.locationId) params.locationId = filters.locationId;
    if (filters.fromDate) params.fromDate = filters.fromDate;
    if (filters.toDate) params.toDate = filters.toDate;
    api.get('/stock-ledger', { params })
      .then(({ data }) => setLedger(data))
      .catch(() => {})
      .finally(() => setFiltering(false));
  };

  const handleFilter = () => {
    setSearch('');
    if (tab === 'summary') loadSummary();
    else loadLedger();
  };

  const filteredRows = useMemo(() => {
    let rows = tab === 'summary' ? report : ledger;
    if (tab === 'summary' && !showZeroStock) {
      rows = rows.filter((r) => Number(r.CurrentStock) > 0);
    }
    const fields = tab === 'summary' ? SUMMARY_SEARCH : LEDGER_SEARCH;
    return rows.filter((r) => matchSearch(r, search, fields));
  }, [tab, report, ledger, search, showZeroStock]);

  const { items, total, totalPages, currentPage } = useMemo(
    () => paginate(filteredRows, page, PAGE_SIZE),
    [filteredRows, page]
  );

  const summaryColumns = [
    { key: 'MaterialName', label: 'Material' },
    { key: 'Color', label: 'Color' },
    { key: 'HSNCode', label: 'HSN' },
    { key: 'LocationName', label: 'Warehouse' },
    { key: 'Unit', label: 'Unit' },
    { key: 'CurrentStock', label: 'Current Stock', render: (r) => fmtQty(r.CurrentStock) },
    { key: 'StockStatus', label: 'Status', render: (r) => <Badge status={r.StockStatus} /> },
  ];

  const ledgerColumns = [
    { key: 'TransactionDate', label: 'Date', render: (r) => new Date(r.TransactionDate).toLocaleDateString('en-IN') },
    { key: 'TransactionType', label: 'Type' },
    { key: 'ReferenceNo', label: 'Ref No' },
    { key: 'MaterialName', label: 'Material' },
    { key: 'Color', label: 'Color' },
    { key: 'HSNCode', label: 'HSN' },
    { key: 'LocationName', label: 'Warehouse' },
    { key: 'QuantityIn', label: 'In', render: (r) => r.QuantityIn || '—' },
    { key: 'QuantityOut', label: 'Out', render: (r) => r.QuantityOut || '—' },
  ];

  if (loading) return <PageLoading message="Loading stock report..." />;

  return (
    <div>
      <PageHeader
        title="Stock Report"
        subtitle="Current stock by location and transaction ledger"
      />

      <div className="flex gap-2 mb-6 overflow-x-auto pb-1">
        <button
          onClick={() => { setTab('summary'); setSearch(''); loadSummary(); }}
          className={`flex-1 sm:flex-none px-4 py-2.5 rounded-xl text-sm font-medium transition whitespace-nowrap ${tab === 'summary' ? 'bg-brand-500 text-white' : 'bg-white border text-slate-600 hover:bg-slate-50'}`}
        >
          Current Stock
        </button>
        <button
          onClick={() => { setTab('ledger'); setSearch(''); loadLedger(); }}
          className={`flex-1 sm:flex-none px-4 py-2.5 rounded-xl text-sm font-medium transition whitespace-nowrap ${tab === 'ledger' ? 'bg-brand-500 text-white' : 'bg-white border text-slate-600 hover:bg-slate-50'}`}
        >
          Stock Ledger
        </button>
      </div>

      <Card className="p-4 mb-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 items-end">
          <WarehouseSelect
            label="Warehouse"
            value={filters.locationId}
            onChange={(id) => setFilters({ ...filters, locationId: id })}
            locations={locations}
            allowEmpty
            emptyLabel="All Warehouses"
          />
          {tab === 'summary' && (
            <MaterialSelect
              label="Material"
              value={filters.materialId}
              onChange={(id) => setFilters({ ...filters, materialId: id })}
              materials={materials}
              allowEmpty
              emptyLabel="All Materials"
            />
          )}
          {tab === 'ledger' && (
            <>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">From Date</label>
                <input type="date" className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-base md:text-sm" value={filters.fromDate} onChange={(e) => setFilters({ ...filters, fromDate: e.target.value })} />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-600 mb-1.5">To Date</label>
                <input type="date" className="w-full px-4 py-2.5 rounded-xl border border-slate-200 text-base md:text-sm" value={filters.toDate} onChange={(e) => setFilters({ ...filters, toDate: e.target.value })} />
              </div>
            </>
          )}
          <Button onClick={handleFilter} loading={filtering}>{filtering ? 'Loading...' : 'Apply Filters'}</Button>
          {tab === 'summary' && (
            <label className="flex items-center gap-2 text-sm text-slate-600 pb-1 cursor-pointer select-none lg:col-span-4">
              <input
                type="checkbox"
                className="rounded border-slate-300"
                checked={showZeroStock}
                onChange={(e) => setShowZeroStock(e.target.checked)}
              />
              Show out of stock / zero qty
            </label>
          )}
        </div>
      </Card>

      <Card className="relative">
        {filtering && (
          <div className="absolute inset-0 z-10 flex items-center justify-center rounded-2xl bg-white/70">
            <Loader />
          </div>
        )}
        <ListToolbar
          search={search}
          onSearchChange={setSearch}
          searchPlaceholder="Search material, color, HSN, location..."
        />
        {tab === 'summary' ? (
          <Table columns={summaryColumns} data={items} />
        ) : (
          <Table columns={ledgerColumns} data={items} keyField="LedgerId" />
        )}
        <Pagination page={currentPage} totalPages={totalPages} total={total} onPageChange={setPage} pageSize={PAGE_SIZE} />
      </Card>
    </div>
  );
}
