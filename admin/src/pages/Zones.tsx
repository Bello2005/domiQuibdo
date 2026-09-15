import { AlertCircle, Loader2, MapPin, Pencil, Plus, Trash2 } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { FormField, Modal, inputClass } from '../components/Modal'
import { api, apiErrorMessage, type Zone } from '../lib/api'

type ZoneForm = {
  name: string
  center_lat: string
  center_lng: string
  radius_m: string
  is_active: boolean
}

const emptyForm: ZoneForm = { name: '', center_lat: '', center_lng: '', radius_m: '', is_active: true }

export function Zones() {
  const [zones, setZones] = useState<Zone[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [editing, setEditing] = useState<Zone | 'new' | null>(null)
  const [form, setForm] = useState<ZoneForm>(emptyForm)
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  function load() {
    api
      .get<Zone[]>('/admin/zones')
      .then(({ data }) => setZones(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }

  useEffect(load, [])

  function openCreate() {
    setForm(emptyForm)
    setFormError(null)
    setEditing('new')
  }

  function openEdit(zone: Zone) {
    setForm({
      name: zone.name,
      center_lat: String(zone.center_lat),
      center_lng: String(zone.center_lng),
      radius_m: String(zone.radius_m),
      is_active: zone.is_active,
    })
    setFormError(null)
    setEditing(zone)
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setFormError(null)
    const payload = {
      name: form.name,
      center_lat: Number(form.center_lat),
      center_lng: Number(form.center_lng),
      radius_m: Number(form.radius_m),
      is_active: form.is_active,
    }
    try {
      if (editing === 'new') {
        await api.post('/admin/zones', payload)
      } else if (editing) {
        await api.put(`/admin/zones/${editing.id}`, payload)
      }
      setEditing(null)
      load()
    } catch (err) {
      setFormError(apiErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(zone: Zone) {
    if (!confirm(`¿Eliminar la zona "${zone.name}"?`)) return
    try {
      await api.delete(`/admin/zones/${zone.id}`)
      load()
    } catch (err) {
      alert(apiErrorMessage(err))
    }
  }

  return (
    <div>
      <header className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Zonas de cobertura</h1>
          <p className="mt-1 text-sm text-slate-500">
            {zones ? `${zones.length} zonas registradas` : 'Barrios donde se pueden registrar direcciones.'}
          </p>
        </div>
        <button
          onClick={openCreate}
          className="flex shrink-0 items-center gap-2 rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800"
        >
          <Plus size={16} />
          Nueva zona
        </button>
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
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <p className="truncate font-semibold text-slate-900">{zone.name}</p>
                {!zone.is_active && (
                  <span className="shrink-0 rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase text-slate-500">
                    Inactiva
                  </span>
                )}
              </div>
              <p className="mt-1 text-xs text-slate-500">
                {zone.center_lat.toFixed(4)}, {zone.center_lng.toFixed(4)}
              </p>
              <p className="mt-0.5 text-xs text-slate-500">Radio de cobertura: {zone.radius_m} m</p>
            </div>
            <div className="flex shrink-0 gap-1">
              <button onClick={() => openEdit(zone)} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-teal-700">
                <Pencil size={16} />
              </button>
              <button onClick={() => handleDelete(zone)} className="rounded-lg p-1.5 text-slate-400 hover:bg-red-50 hover:text-red-600">
                <Trash2 size={16} />
              </button>
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <Modal title={editing === 'new' ? 'Nueva zona' : 'Editar zona'} onClose={() => setEditing(null)}>
          <form onSubmit={handleSubmit} className="space-y-4">
            <FormField label="Nombre">
              <input
                required
                className={inputClass}
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </FormField>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="Latitud">
                <input
                  required
                  type="number"
                  step="any"
                  className={inputClass}
                  value={form.center_lat}
                  onChange={(e) => setForm({ ...form, center_lat: e.target.value })}
                />
              </FormField>
              <FormField label="Longitud">
                <input
                  required
                  type="number"
                  step="any"
                  className={inputClass}
                  value={form.center_lng}
                  onChange={(e) => setForm({ ...form, center_lng: e.target.value })}
                />
              </FormField>
            </div>
            <FormField label="Radio de cobertura (metros)">
              <input
                required
                type="number"
                className={inputClass}
                value={form.radius_m}
                onChange={(e) => setForm({ ...form, radius_m: e.target.value })}
              />
            </FormField>
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={form.is_active}
                onChange={(e) => setForm({ ...form, is_active: e.target.checked })}
              />
              Zona activa
            </label>

            {formError && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{formError}</p>}

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setEditing(null)} className="rounded-lg px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100">
                Cancelar
              </button>
              <button
                type="submit"
                disabled={saving}
                className="rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800 disabled:opacity-60"
              >
                {saving ? 'Guardando...' : 'Guardar'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}
