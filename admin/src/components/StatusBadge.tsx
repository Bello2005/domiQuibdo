import type { OrderStatus } from '../lib/api'

const styles: Record<OrderStatus, string> = {
  pendiente: 'bg-amber-100 text-amber-700',
  confirmado: 'bg-blue-100 text-blue-700',
  preparando: 'bg-violet-100 text-violet-700',
  en_camino: 'bg-orange-100 text-orange-700',
  entregado: 'bg-emerald-100 text-emerald-700',
  cancelado: 'bg-red-100 text-red-700',
}

export function StatusBadge({ status, label }: { status: OrderStatus; label: string }) {
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${styles[status]}`}>
      {label}
    </span>
  )
}
