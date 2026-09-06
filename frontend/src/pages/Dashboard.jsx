import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Package, MapPin, ShoppingCart, TrendingUp, AlertTriangle, Boxes } from 'lucide-react';
import api from '../api';
import { PageHeader, Card, PageLoading } from '../components/UI';
const statCards = [
  { key: 'TotalMaterials', label: 'Materials', icon: Package, color: 'bg-blue-500' },
  { key: 'TotalLocations', label: 'Locations', icon: MapPin, color: 'bg-violet-500' },
  { key: 'TotalPurchases', label: 'Purchases', icon: ShoppingCart, color: 'bg-emerald-500' },
  { key: 'TotalSales', label: 'Sales', icon: TrendingUp, color: 'bg-brand-500' },
  { key: 'TotalStockQty', label: 'Total Stock Qty', icon: Boxes, color: 'bg-cyan-500' },
  { key: 'LowStockItems', label: 'Low Stock Items', icon: AlertTriangle, color: 'bg-amber-500' },
];

export default function Dashboard() {
  const [stats, setStats] = useState({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/dashboard')
      .then(({ data }) => setStats(data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <PageLoading message="Loading dashboard..." />;

  return (
    <div>
      <PageHeader
        title="Dashboard"
        subtitle="Overview of your inventory and business activity"
      />

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {statCards.map(({ key, label, icon: Icon, color }) => (
          <Card key={key} className="p-4 sm:p-6">
            <div className="flex items-center gap-4">
              <div className={`w-12 h-12 rounded-xl ${color} flex items-center justify-center text-white`}>
                <Icon size={22} />
              </div>
              <div>
                <p className="text-sm text-slate-500">{label}</p>
                <p className="text-2xl font-bold text-slate-800">{stats[key] ?? '—'}</p>
              </div>
            </div>
          </Card>
        ))}
      </div>

      <Card className="mt-8 p-4 sm:p-6">
        <h3 className="font-semibold text-lg mb-2">Quick Start</h3>
        <ol className="text-sm text-slate-600 space-y-2 list-decimal list-inside">
          <li>Add warehouse locations under <Link to="/locations" className="text-brand-600 hover:text-brand-700 font-medium">Warehouse Locations</Link></li>
          <li>Create materials in <Link to="/materials" className="text-brand-600 hover:text-brand-700 font-medium">Material Master</Link></li>
          <li>Set opening stock with location in <Link to="/opening-stock" className="text-brand-600 hover:text-brand-700 font-medium">Opening Stock</Link></li>
          <li>Record purchases in <Link to="/purchase-inward" className="text-brand-600 hover:text-brand-700 font-medium">Purchase Inward</Link> (stock in)</li>
          <li>Record sales in <Link to="/sales" className="text-brand-600 hover:text-brand-700 font-medium">Sales</Link> (stock out)</li>
          <li>View current stock in <Link to="/stock-report" className="text-brand-600 hover:text-brand-700 font-medium">Stock Report</Link></li>
        </ol>
      </Card>    </div>
  );
}
