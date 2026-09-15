import { AlertCircle, ChevronDown, Loader2, Pencil, Phone, Plus, Star, Trash2 } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { FormField, Modal, inputClass } from '../components/Modal'
import { api, apiErrorMessage, type MenuItem, type Restaurant } from '../lib/api'

const currency = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })

type RestaurantForm = {
  name: string
  description: string
  category: string
  latitude: string
  longitude: string
  address_text: string
  phone: string
  cover_image_url: string
  rating_avg: string
  delivery_time_min: string
  is_active: boolean
}

const emptyRestaurantForm: RestaurantForm = {
  name: '',
  description: '',
  category: '',
  latitude: '',
  longitude: '',
  address_text: '',
  phone: '',
  cover_image_url: '',
  rating_avg: '',
  delivery_time_min: '',
  is_active: true,
}

type MenuItemForm = {
  name: string
  description: string
  price: string
  image_url: string
  is_available: boolean
}

const emptyMenuItemForm: MenuItemForm = { name: '', description: '', price: '', image_url: '', is_available: true }

export function Restaurants() {
  const [restaurants, setRestaurants] = useState<Restaurant[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [expanded, setExpanded] = useState<number | null>(null)

  const [editingRestaurant, setEditingRestaurant] = useState<Restaurant | 'new' | null>(null)
  const [restaurantForm, setRestaurantForm] = useState<RestaurantForm>(emptyRestaurantForm)
  const [restaurantFormError, setRestaurantFormError] = useState<string | null>(null)
  const [savingRestaurant, setSavingRestaurant] = useState(false)

  const [editingItem, setEditingItem] = useState<{ restaurantId: number; item: MenuItem | 'new' } | null>(null)
  const [itemForm, setItemForm] = useState<MenuItemForm>(emptyMenuItemForm)
  const [itemFormError, setItemFormError] = useState<string | null>(null)
  const [savingItem, setSavingItem] = useState(false)

  function load() {
    api
      .get<Restaurant[]>('/admin/restaurants')
      .then(({ data }) => setRestaurants(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }

  useEffect(load, [])

  function toggle(id: number) {
    setExpanded(expanded === id ? null : id)
  }

  // --- Restaurante ---

  function openCreateRestaurant() {
    setRestaurantForm(emptyRestaurantForm)
    setRestaurantFormError(null)
    setEditingRestaurant('new')
  }

  function openEditRestaurant(r: Restaurant) {
    setRestaurantForm({
      name: r.name,
      description: r.description ?? '',
      category: r.category,
      latitude: String(r.latitude),
      longitude: String(r.longitude),
      address_text: r.address_text,
      phone: r.phone ?? '',
      cover_image_url: r.cover_image_url ?? '',
      rating_avg: r.rating_avg != null ? String(r.rating_avg) : '',
      delivery_time_min: r.delivery_time_min != null ? String(r.delivery_time_min) : '',
      is_active: r.is_active,
    })
    setRestaurantFormError(null)
    setEditingRestaurant(r)
  }

  async function handleRestaurantSubmit(event: FormEvent) {
    event.preventDefault()
    setSavingRestaurant(true)
    setRestaurantFormError(null)
    const payload = {
      name: restaurantForm.name,
      description: restaurantForm.description || null,
      category: restaurantForm.category,
      latitude: Number(restaurantForm.latitude),
      longitude: Number(restaurantForm.longitude),
      address_text: restaurantForm.address_text,
      phone: restaurantForm.phone || null,
      cover_image_url: restaurantForm.cover_image_url || null,
      rating_avg: restaurantForm.rating_avg ? Number(restaurantForm.rating_avg) : null,
      delivery_time_min: restaurantForm.delivery_time_min ? Number(restaurantForm.delivery_time_min) : null,
      is_active: restaurantForm.is_active,
    }
    try {
      if (editingRestaurant === 'new') {
        await api.post('/admin/restaurants', payload)
      } else if (editingRestaurant) {
        await api.put(`/admin/restaurants/${editingRestaurant.id}`, payload)
      }
      setEditingRestaurant(null)
      load()
    } catch (err) {
      setRestaurantFormError(apiErrorMessage(err))
    } finally {
      setSavingRestaurant(false)
    }
  }

  async function handleDeleteRestaurant(r: Restaurant) {
    if (!confirm(`¿Eliminar "${r.name}" y todo su menú?`)) return
    try {
      await api.delete(`/admin/restaurants/${r.id}`)
      load()
    } catch (err) {
      alert(apiErrorMessage(err))
    }
  }

  // --- Ítem de menú ---

  function openCreateItem(restaurantId: number) {
    setItemForm(emptyMenuItemForm)
    setItemFormError(null)
    setEditingItem({ restaurantId, item: 'new' })
  }

  function openEditItem(restaurantId: number, item: MenuItem) {
    setItemForm({
      name: item.name,
      description: item.description ?? '',
      price: String(item.price),
      image_url: item.image_url ?? '',
      is_available: item.is_available,
    })
    setItemFormError(null)
    setEditingItem({ restaurantId, item })
  }

  async function handleItemSubmit(event: FormEvent) {
    event.preventDefault()
    if (!editingItem) return
    setSavingItem(true)
    setItemFormError(null)
    const payload = {
      name: itemForm.name,
      description: itemForm.description || null,
      price: Number(itemForm.price),
      image_url: itemForm.image_url || null,
      is_available: itemForm.is_available,
    }
    try {
      if (editingItem.item === 'new') {
        await api.post(`/admin/restaurants/${editingItem.restaurantId}/menu-items`, payload)
      } else {
        await api.put(`/admin/menu-items/${editingItem.item.id}`, payload)
      }
      setEditingItem(null)
      load()
    } catch (err) {
      setItemFormError(apiErrorMessage(err))
    } finally {
      setSavingItem(false)
    }
  }

  async function handleDeleteItem(item: MenuItem) {
    if (!confirm(`¿Eliminar "${item.name}" del menú?`)) return
    try {
      await api.delete(`/admin/menu-items/${item.id}`)
      load()
    } catch (err) {
      alert(apiErrorMessage(err))
    }
  }

  return (
    <div>
      <header className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Restaurantes</h1>
          <p className="mt-1 text-sm text-slate-500">
            {restaurants ? `${restaurants.length} negocios registrados` : 'Catálogo de restaurantes.'}
          </p>
        </div>
        <button
          onClick={openCreateRestaurant}
          className="flex shrink-0 items-center gap-2 rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800"
        >
          <Plus size={16} />
          Nuevo restaurante
        </button>
      </header>

      {error && (
        <div className="flex items-center gap-2 rounded-xl border border-red-100 bg-red-50 p-4 text-sm text-red-600">
          <AlertCircle size={18} />
          {error}
        </div>
      )}

      {!restaurants && !error && (
        <div className="flex items-center justify-center gap-2 rounded-xl border border-slate-200 bg-white p-12 text-slate-400 shadow-sm">
          <Loader2 size={20} className="animate-spin" />
          Cargando restaurantes...
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {restaurants?.map((restaurant) => {
          const isOpen = expanded === restaurant.id
          return (
            <div key={restaurant.id} className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
              <div className="p-4">
                <div className="flex items-start justify-between gap-2">
                  <button onClick={() => toggle(restaurant.id)} className="min-w-0 flex-1 text-left">
                    <div className="flex items-center gap-2">
                      <p className="truncate font-semibold text-slate-900">{restaurant.name}</p>
                      {!restaurant.is_active && (
                        <span className="shrink-0 rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold uppercase text-slate-500">
                          Inactivo
                        </span>
                      )}
                    </div>
                    <p className="mt-0.5 text-xs font-medium uppercase tracking-wide text-teal-700">{restaurant.category}</p>
                  </button>
                  <div className="flex shrink-0 items-center gap-1">
                    <button onClick={() => openEditRestaurant(restaurant)} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-teal-700">
                      <Pencil size={16} />
                    </button>
                    <button onClick={() => handleDeleteRestaurant(restaurant)} className="rounded-lg p-1.5 text-slate-400 hover:bg-red-50 hover:text-red-600">
                      <Trash2 size={16} />
                    </button>
                    <button onClick={() => toggle(restaurant.id)} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100">
                      <ChevronDown size={18} className={`transition-transform ${isOpen ? 'rotate-180' : ''}`} />
                    </button>
                  </div>
                </div>

                <p className="mt-2 line-clamp-2 text-sm text-slate-500">{restaurant.description}</p>

                <div className="mt-3 flex items-center gap-4 text-xs text-slate-500">
                  <span className="flex items-center gap-1">
                    <Star size={14} className="text-amber-400" />
                    {restaurant.rating_avg?.toFixed(1) ?? '—'}
                  </span>
                  {restaurant.phone && (
                    <span className="flex items-center gap-1">
                      <Phone size={14} />
                      {restaurant.phone}
                    </span>
                  )}
                  {restaurant.delivery_time_min != null && <span>~{restaurant.delivery_time_min} min</span>}
                </div>
              </div>

              {isOpen && (
                <div className="border-t border-slate-100 bg-slate-50 p-4">
                  <div className="mb-2 flex items-center justify-between">
                    <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Menú</p>
                    <button
                      onClick={() => openCreateItem(restaurant.id)}
                      className="flex items-center gap-1 text-xs font-semibold text-teal-700 hover:text-teal-900"
                    >
                      <Plus size={14} />
                      Agregar ítem
                    </button>
                  </div>
                  {(!restaurant.menu_items || restaurant.menu_items.length === 0) && (
                    <p className="text-sm text-slate-400">Sin ítems en el menú.</p>
                  )}
                  {restaurant.menu_items && restaurant.menu_items.length > 0 && (
                    <ul className="space-y-1">
                      {restaurant.menu_items.map((item) => (
                        <li key={item.id} className="flex items-center justify-between gap-2 rounded-lg bg-white px-3 py-2 text-sm shadow-sm">
                          <div className="min-w-0">
                            <span className={`truncate ${item.is_available ? 'text-slate-700' : 'text-slate-400 line-through'}`}>
                              {item.name}
                            </span>
                          </div>
                          <div className="flex shrink-0 items-center gap-2">
                            <span className="font-medium text-slate-900">{currency.format(item.price)}</span>
                            <button onClick={() => openEditItem(restaurant.id, item)} className="rounded p-1 text-slate-400 hover:text-teal-700">
                              <Pencil size={14} />
                            </button>
                            <button onClick={() => handleDeleteItem(item)} className="rounded p-1 text-slate-400 hover:text-red-600">
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>

      {editingRestaurant && (
        <Modal title={editingRestaurant === 'new' ? 'Nuevo restaurante' : 'Editar restaurante'} onClose={() => setEditingRestaurant(null)}>
          <form onSubmit={handleRestaurantSubmit} className="space-y-4">
            <FormField label="Nombre">
              <input required className={inputClass} value={restaurantForm.name} onChange={(e) => setRestaurantForm({ ...restaurantForm, name: e.target.value })} />
            </FormField>
            <FormField label="Categoría">
              <input required className={inputClass} value={restaurantForm.category} onChange={(e) => setRestaurantForm({ ...restaurantForm, category: e.target.value })} />
            </FormField>
            <FormField label="Descripción">
              <textarea className={inputClass} rows={2} value={restaurantForm.description} onChange={(e) => setRestaurantForm({ ...restaurantForm, description: e.target.value })} />
            </FormField>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="Latitud">
                <input required type="number" step="any" className={inputClass} value={restaurantForm.latitude} onChange={(e) => setRestaurantForm({ ...restaurantForm, latitude: e.target.value })} />
              </FormField>
              <FormField label="Longitud">
                <input required type="number" step="any" className={inputClass} value={restaurantForm.longitude} onChange={(e) => setRestaurantForm({ ...restaurantForm, longitude: e.target.value })} />
              </FormField>
            </div>
            <FormField label="Dirección">
              <input required className={inputClass} value={restaurantForm.address_text} onChange={(e) => setRestaurantForm({ ...restaurantForm, address_text: e.target.value })} />
            </FormField>
            <FormField label="Teléfono">
              <input className={inputClass} value={restaurantForm.phone} onChange={(e) => setRestaurantForm({ ...restaurantForm, phone: e.target.value })} />
            </FormField>
            <FormField label="URL de portada">
              <input type="url" className={inputClass} value={restaurantForm.cover_image_url} onChange={(e) => setRestaurantForm({ ...restaurantForm, cover_image_url: e.target.value })} />
            </FormField>
            <div className="grid grid-cols-2 gap-3">
              <FormField label="Calificación (0-5)">
                <input type="number" step="0.1" min="0" max="5" className={inputClass} value={restaurantForm.rating_avg} onChange={(e) => setRestaurantForm({ ...restaurantForm, rating_avg: e.target.value })} />
              </FormField>
              <FormField label="Tiempo de entrega (min)">
                <input type="number" min="0" className={inputClass} value={restaurantForm.delivery_time_min} onChange={(e) => setRestaurantForm({ ...restaurantForm, delivery_time_min: e.target.value })} />
              </FormField>
            </div>
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input type="checkbox" checked={restaurantForm.is_active} onChange={(e) => setRestaurantForm({ ...restaurantForm, is_active: e.target.checked })} />
              Restaurante activo (visible para clientes)
            </label>

            {restaurantFormError && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{restaurantFormError}</p>}

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setEditingRestaurant(null)} className="rounded-lg px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100">
                Cancelar
              </button>
              <button type="submit" disabled={savingRestaurant} className="rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800 disabled:opacity-60">
                {savingRestaurant ? 'Guardando...' : 'Guardar'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {editingItem && (
        <Modal title={editingItem.item === 'new' ? 'Nuevo ítem de menú' : 'Editar ítem'} onClose={() => setEditingItem(null)}>
          <form onSubmit={handleItemSubmit} className="space-y-4">
            <FormField label="Nombre">
              <input required className={inputClass} value={itemForm.name} onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })} />
            </FormField>
            <FormField label="Descripción">
              <textarea className={inputClass} rows={2} value={itemForm.description} onChange={(e) => setItemForm({ ...itemForm, description: e.target.value })} />
            </FormField>
            <FormField label="Precio (COP)">
              <input required type="number" min="0" className={inputClass} value={itemForm.price} onChange={(e) => setItemForm({ ...itemForm, price: e.target.value })} />
            </FormField>
            <FormField label="URL de imagen">
              <input type="url" className={inputClass} value={itemForm.image_url} onChange={(e) => setItemForm({ ...itemForm, image_url: e.target.value })} />
            </FormField>
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input type="checkbox" checked={itemForm.is_available} onChange={(e) => setItemForm({ ...itemForm, is_available: e.target.checked })} />
              Disponible
            </label>

            {itemFormError && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{itemFormError}</p>}

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setEditingItem(null)} className="rounded-lg px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100">
                Cancelar
              </button>
              <button type="submit" disabled={savingItem} className="rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800 disabled:opacity-60">
                {savingItem ? 'Guardando...' : 'Guardar'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}
