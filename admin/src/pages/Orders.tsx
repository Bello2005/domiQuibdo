import { AlertCircle, Clock3, DollarSign, Loader2, PackageCheck, ShoppingBag } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { StatusBadge } from '../components/StatusBadge'
import { api, apiErrorMessage, type Order } from '../lib/api'

const currency = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })

function formatDate(iso: string | null) {
  if (!iso) return '—'
  return new Intl.DateTimeFormat('es-CO', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(iso))
}

export function Orders() {
  const [orders, setOrders] = useState<Order[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api
      .get<Order[]>('/admin/orders')
      .then(({ data }) => setOrders(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }, [])

  const stats = useMemo(() => {
    if (!orders) return null
    const active = orders.filter((o) => !['entregado', 'cancelado'].includes(o.status)).length
    const delivered = orders.filter((o) => o.status === 'entregado').length
    const revenue = orders.filter((o) => o.status === 'entregado').reduce((sum, o) => sum + o.total, 0)
    return { total: orders.length, active, delivered, revenue }
  }, [orders])

  return (
    <div>
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">Pedidos</h1>
        <p className="mt-1 text-sm text-slate-500">Últimos 100 pedidos de toda la plataforma.</p>
      </header>

      {stats && (
        <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
          <StatCard icon={ShoppingBag} label="Total" value={stats.total.toString()} color="bg-teal-600" />
          <StatCard icon={Clock3} label="Activos" value={stats.active.toString()} color="bg-orange-500" />
          <StatCard icon={PackageCheck} label="Entregados" value={stats.delivered.toString()} color="bg-emerald-600" />
          <StatCard icon={DollarSign} label="Ingresos (entregados)" value={currency.format(stats.revenue)} color="bg-violet-600" />
        </div>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        {error && (
          <div className="flex items-center gap-2 p-6 text-sm text-red-600">
            <AlertCircle size={18} />
            {error}
          </div>
        )}

        {!orders && !error && (
          <div className="flex items-center justify-center gap-2 p-12 text-slate-400">
            <Loader2 size={20} className="animate-spin" />
            Cargando pedidos...
          </div>
        )}

        {orders && orders.length === 0 && (
          <p className="p-12 text-center text-sm text-slate-400">Todavía no hay pedidos.</p>
        )}

        {orders && orders.length > 0 && (
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th className="px-4 py-3">#</th>
                <th className="px-4 py-3">Cliente</th>
                <th className="px-4 py-3">Restaurante</th>
                <th className="px-4 py-3">Repartidor</th>
                <th className="px-4 py-3">Estado</th>
                <th className="px-4 py-3">Ítems</th>
                <th className="px-4 py-3">Total</th>
                <th className="px-4 py-3">Fecha</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {orders.map((order) => (
                <tr key={order.id} className="hover:bg-slate-50">
                  <td className="px-4 py-3 font-medium text-slate-900">#{order.id}</td>
                  <td className="px-4 py-3">{order.customer?.name ?? '—'}</td>
                  <td className="px-4 py-3">{order.restaurant?.name ?? '—'}</td>
                  <td className="px-4 py-3">{order.repartidor?.name ?? '—'}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={order.status} label={order.status_label} />
                  </td>
                  <td className="px-4 py-3">{order.items_count ?? '—'}</td>
                  <td className="px-4 py-3 font-medium">{currency.format(order.total)}</td>
                  <td className="px-4 py-3 text-slate-500">{formatDate(order.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}

function StatCard({
  icon: Icon,
  label,
  value,
  color,
}: {
  icon: typeof ShoppingBag
  label: string
  value: string
  color: string
}) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
      <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${color} text-white`}>
        <Icon size={18} />
      </div>
      <div className="min-w-0">
        <p className="truncate text-xs text-slate-500">{label}</p>
        <p className="truncate text-lg font-bold text-slate-900">{value}</p>
      </div>
    </div>
  )
}
