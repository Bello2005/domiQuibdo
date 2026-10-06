import { AlertCircle, CheckCircle2, ExternalLink, Loader2, RotateCcw, ShieldAlert } from 'lucide-react'
import { useEffect, useState } from 'react'
import { api, apiErrorMessage, type Incident, type IncidentStatus } from '../lib/api'

const REFRESH_MS = 15_000

function formatDate(iso: string | null) {
  if (!iso) return '—'
  return new Intl.DateTimeFormat('es-CO', { dateStyle: 'short', timeStyle: 'short' }).format(new Date(iso))
}

function mapsLink(incident: Incident) {
  return `https://maps.google.com/?q=${incident.latitude},${incident.longitude}`
}

export function Incidents() {
  const [incidents, setIncidents] = useState<Incident[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [onlyOpen, setOnlyOpen] = useState(true)
  const [updatingId, setUpdatingId] = useState<number | null>(null)

  useEffect(() => {
    let cancelled = false
    const load = () =>
      api
        .get<Incident[]>('/admin/incidents', { params: onlyOpen ? { status: 'abierto' } : {} })
        .then(({ data }) => {
          if (cancelled) return
          setIncidents(data)
          setError(null)
        })
        .catch((err) => !cancelled && setError(apiErrorMessage(err)))

    load()
    // Las alertas SOS son urgentes: se refrescan solas.
    const timer = setInterval(load, REFRESH_MS)
    return () => {
      cancelled = true
      clearInterval(timer)
    }
  }, [onlyOpen])

  async function setStatus(incident: Incident, status: IncidentStatus) {
    setUpdatingId(incident.id)
    try {
      const { data } = await api.put<Incident>(`/admin/incidents/${incident.id}`, { status })
      setIncidents((current) =>
        onlyOpen && status === 'atendido'
          ? (current ?? []).filter((i) => i.id !== incident.id)
          : (current ?? []).map((i) => (i.id === incident.id ? data : i)),
      )
    } catch (err) {
      alert(apiErrorMessage(err))
    } finally {
      setUpdatingId(null)
    }
  }

  const openCount = incidents?.filter((i) => i.status === 'abierto').length ?? 0

  return (
    <div>
      <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Alertas</h1>
          <p className="mt-1 text-sm text-slate-500">
            SOS y reportes enviados desde la app por clientes, repartidores y restaurantes.
          </p>
        </div>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input type="checkbox" checked={onlyOpen} onChange={(e) => setOnlyOpen(e.target.checked)} />
          Solo abiertas
        </label>
      </header>

      {incidents && openCount > 0 && (
        <div className="mb-4 flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-medium text-red-700">
          <ShieldAlert size={18} />
          {openCount === 1 ? 'Hay 1 alerta abierta.' : `Hay ${openCount} alertas abiertas.`}
        </div>
      )}

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white shadow-sm">
        {error && (
          <div className="flex items-center gap-2 p-6 text-sm text-red-600">
            <AlertCircle size={18} />
            {error}
          </div>
        )}

        {!incidents && !error && (
          <div className="flex items-center justify-center gap-2 p-12 text-slate-400">
            <Loader2 size={20} className="animate-spin" />
            Cargando alertas...
          </div>
        )}

        {incidents && incidents.length === 0 && (
          <p className="p-12 text-center text-sm text-slate-400">
            {onlyOpen ? 'No hay alertas abiertas. Todo en calma.' : 'Todavía no hay alertas.'}
          </p>
        )}

        {incidents && incidents.length > 0 && (
          <table className="w-full min-w-[900px] text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th className="px-4 py-3">Tipo</th>
                <th className="px-4 py-3">Pedido</th>
                <th className="px-4 py-3">Quién reporta</th>
                <th className="px-4 py-3">Detalle</th>
                <th className="px-4 py-3">Fecha</th>
                <th className="px-4 py-3">Estado</th>
                <th className="px-4 py-3" />
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {incidents.map((incident) => (
                <tr key={incident.id} className={updatingId === incident.id ? 'opacity-50' : 'hover:bg-slate-50'}>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${
                        incident.type === 'sos' ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700'
                      }`}
                    >
                      {incident.type === 'sos' ? 'SOS' : 'Problema'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <p className="font-medium text-slate-900">#{incident.order_id}</p>
                    <p className="text-xs text-slate-500">{incident.order?.restaurant ?? '—'}</p>
                  </td>
                  <td className="px-4 py-3">
                    <p>{incident.reporter?.name ?? '—'}</p>
                    <p className="text-xs text-slate-500">
                      {incident.reporter?.role}
                      {incident.reporter?.phone ? ` · ${incident.reporter.phone}` : ''}
                    </p>
                  </td>
                  <td className="px-4 py-3">
                    {incident.message && <p className="max-w-xs text-slate-700">{incident.message}</p>}
                    {incident.latitude !== null && incident.longitude !== null ? (
                      <a
                        href={mapsLink(incident)}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-flex items-center gap-1 text-xs font-medium text-teal-700 hover:underline"
                      >
                        <ExternalLink size={12} />
                        Ver ubicación
                      </a>
                    ) : (
                      !incident.message && <span className="text-slate-400">Sin detalle</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-slate-500">{formatDate(incident.created_at)}</td>
                  <td className="px-4 py-3">
                    <span
                      className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${
                        incident.status === 'abierto' ? 'bg-orange-100 text-orange-700' : 'bg-emerald-100 text-emerald-700'
                      }`}
                    >
                      {incident.status === 'abierto' ? 'Abierta' : 'Atendida'}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    {incident.status === 'abierto' ? (
                      <button
                        onClick={() => setStatus(incident, 'atendido')}
                        disabled={updatingId === incident.id}
                        className="inline-flex items-center gap-1 rounded-lg bg-teal-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-teal-700 disabled:opacity-50"
                      >
                        <CheckCircle2 size={14} />
                        Marcar atendida
                      </button>
                    ) : (
                      <button
                        onClick={() => setStatus(incident, 'abierto')}
                        disabled={updatingId === incident.id}
                        className="inline-flex items-center gap-1 rounded-lg border border-slate-200 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
                      >
                        <RotateCcw size={14} />
                        Reabrir
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
