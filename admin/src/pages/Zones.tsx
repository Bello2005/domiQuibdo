import { AlertCircle, Loader2, MapPin } from 'lucide-react'
import { useEffect, useState } from 'react'
import { api, apiErrorMessage, type Zone } from '../lib/api'

export function Zones() {
  const [zones, setZones] = useState<Zone[] | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    api
      .get<Zone[]>('/zones')
      .then(({ data }) => setZones(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }, [])

  return (
    <div>
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">Zonas de cobertura</h1>
        <p className="mt-1 text-sm text-slate-500">
          {zones ? `${zones.length} barrios con cobertura` : 'Barrios donde se pueden registrar direcciones.'}
        </p>
      </header>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-red-100 bg-red-50 p-4 text-sm text-red-600">
          <AlertCircle size={18} />
          {error}
        </div>
      )}

      {!zones && !error && (
        <div className="flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white p-12 text-slate-400 shadow-sm">
          <Loader2 size={20} className="animate-spin" />
          Cargando zonas...
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {zones?.map((zone) => (
          <div key={zone.id} className="flex items-start gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-teal-50 text-teal-700">
              <MapPin size={18} />
            </div>
            <div className="min-w-0">
              <p className="font-semibold text-slate-900">{zone.name}</p>
              <p className="mt-1 text-xs text-slate-500">
                {zone.center_lat.toFixed(4)}, {zone.center_lng.toFixed(4)}
              </p>
              <p className="mt-0.5 text-xs text-slate-500">Radio de cobertura: {zone.radius_m} m</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
