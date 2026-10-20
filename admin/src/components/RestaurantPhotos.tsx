import { ImagePlus, Loader2, Star, Trash2 } from 'lucide-react'
import { useRef, useState } from 'react'
import { api, apiErrorMessage, type MenuItem, type Restaurant } from '../lib/api'

function photoForm(file: File) {
  const form = new FormData()
  form.append('photo', file)
  return form
}

/** Galería del negocio: subir (varias a la vez), elegir portada y borrar. */
export function RestaurantPhotos({ restaurant, onChange }: { restaurant: Restaurant; onChange: () => void }) {
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const photos = restaurant.photos ?? []

  async function run(action: () => Promise<unknown>) {
    setBusy(true)
    setError(null)
    try {
      await action()
      onChange()
    } catch (err) {
      setError(apiErrorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  function upload(files: FileList | null) {
    if (!files?.length) return
    run(async () => {
      for (const file of Array.from(files)) {
        await api.post(`/admin/restaurants/${restaurant.id}/photos`, photoForm(file))
      }
    })
  }

  function makeCover(photoId: number) {
    const ids = [photoId, ...photos.filter((p) => p.id !== photoId).map((p) => p.id)]
    run(() => api.put(`/admin/restaurants/${restaurant.id}/photos/order`, { ids }))
  }

  function remove(photoId: number) {
    if (!confirm('¿Eliminar esta foto?')) return
    run(() => api.delete(`/admin/photos/${photoId}`))
  }

  return (
    <div className="mb-4">
      <div className="mb-2 flex items-center justify-between">
        <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Fotos ({photos.length}/12)</p>
        <button
          onClick={() => input.current?.click()}
          disabled={busy}
          className="flex items-center gap-1 text-xs font-semibold text-teal-700 hover:text-teal-900 disabled:opacity-50"
        >
          {busy ? <Loader2 size={14} className="animate-spin" /> : <ImagePlus size={14} />}
          Subir fotos
        </button>
        <input
          ref={input}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          hidden
          onChange={(e) => {
            upload(e.target.files)
            e.target.value = ''
          }}
        />
      </div>
      {error && <p className="mb-2 text-xs text-red-600">{error}</p>}
      {photos.length === 0 ? (
        <p className="text-sm text-slate-400">Sin fotos. La primera que subas será la portada.</p>
      ) : (
        <div className="flex gap-2 overflow-x-auto pb-1">
          {photos.map((photo, i) => (
            <div key={photo.id} className="group relative h-20 w-28 shrink-0 overflow-hidden rounded-lg bg-slate-200">
              <img src={photo.thumb_url} alt="" className="h-full w-full object-cover" loading="lazy" />
              {i === 0 && (
                <span className="absolute bottom-1 left-1 rounded bg-black/60 px-1.5 py-0.5 text-[10px] font-semibold text-white">
                  Portada
                </span>
              )}
              <div className="absolute right-1 top-1 hidden gap-1 group-hover:flex">
                {i > 0 && (
                  <button
                    title="Usar como portada"
                    onClick={() => makeCover(photo.id)}
                    className="rounded bg-white/90 p-1 text-amber-500 hover:bg-white"
                  >
                    <Star size={12} />
                  </button>
                )}
                <button title="Eliminar" onClick={() => remove(photo.id)} className="rounded bg-white/90 p-1 text-red-600 hover:bg-white">
                  <Trash2 size={12} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

/** Miniatura del plato: clic para subir o cambiar la foto; la X la quita. */
export function MenuItemPhoto({ item, onChange }: { item: MenuItem; onChange: () => void }) {
  const input = useRef<HTMLInputElement>(null)
  const [busy, setBusy] = useState(false)

  async function run(action: () => Promise<unknown>) {
    setBusy(true)
    try {
      await action()
      onChange()
    } catch (err) {
      alert(apiErrorMessage(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="group relative h-9 w-9 shrink-0">
      <button
        title={item.image_url ? 'Cambiar foto' : 'Agregar foto'}
        onClick={() => input.current?.click()}
        disabled={busy}
        className="flex h-9 w-9 items-center justify-center overflow-hidden rounded-md border border-dashed border-slate-300 text-slate-400 hover:border-teal-600 hover:text-teal-700"
      >
        {busy ? (
          <Loader2 size={14} className="animate-spin" />
        ) : item.image_thumb_url ? (
          <img src={item.image_thumb_url} alt="" className="h-full w-full object-cover" loading="lazy" />
        ) : (
          <ImagePlus size={14} />
        )}
      </button>
      {item.image_url && !busy && (
        <button
          title="Quitar foto"
          onClick={() => confirm('¿Quitar la foto de este plato?') && run(() => api.delete(`/admin/menu-items/${item.id}/photo`))}
          className="absolute -right-1.5 -top-1.5 hidden h-4 w-4 items-center justify-center rounded-full bg-red-600 text-[10px] leading-none text-white group-hover:flex"
        >
          ×
        </button>
      )}
      <input
        ref={input}
        type="file"
        accept="image/jpeg,image/png,image/webp"
        hidden
        onChange={(e) => {
          const file = e.target.files?.[0]
          e.target.value = ''
          if (file) run(() => api.post(`/admin/menu-items/${item.id}/photo`, photoForm(file)))
        }}
      />
    </div>
  )
}
