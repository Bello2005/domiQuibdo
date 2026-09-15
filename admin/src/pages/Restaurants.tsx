import { AlertCircle, ChevronDown, Loader2, Phone, Star } from 'lucide-react'
import { useEffect, useState } from 'react'
import { api, apiErrorMessage, type Restaurant } from '../lib/api'

const currency = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })

export function Restaurants() {
  const [restaurants, setRestaurants] = useState<Restaurant[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [expanded, setExpanded] = useState<number | null>(null)
  const [menus, setMenus] = useState<Record<number, Restaurant>>({})
  const [loadingMenu, setLoadingMenu] = useState<number | null>(null)

  useEffect(() => {
    api
      .get<Restaurant[]>('/restaurants')
      .then(({ data }) => setRestaurants(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }, [])

  async function toggle(restaurant: Restaurant) {
    if (expanded === restaurant.id) {
      setExpanded(null)
      return
    }
    setExpanded(restaurant.id)
    if (!menus[restaurant.id]) {
      setLoadingMenu(restaurant.id)
      try {
        const { data } = await api.get<Restaurant>(`/restaurants/${restaurant.id}`)
        setMenus((prev) => ({ ...prev, [restaurant.id]: data }))
      } catch {
        // el detalle se puede reintentar simplemente cerrando y abriendo la fila
      } finally {
        setLoadingMenu(null)
      }
    }
  }

  return (
    <div>
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-slate-900">Restaurantes</h1>
        <p className="mt-1 text-sm text-slate-500">
          {restaurants ? `${restaurants.length} negocios activos` : 'Catálogo de restaurantes activos.'}
        </p>
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
          const menu = menus[restaurant.id]?.menu_items
          return (
            <div key={restaurant.id} className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
              <button onClick={() => toggle(restaurant)} className="w-full p-4 text-left">
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="truncate font-semibold text-slate-900">{restaurant.name}</p>
                    <p className="mt-0.5 text-xs font-medium uppercase tracking-wide text-teal-700">
                      {restaurant.category}
                    </p>
                  </div>
                  <ChevronDown
                    size={18}
                    className={`mt-1 shrink-0 text-slate-400 transition-transform ${isOpen ? 'rotate-180' : ''}`}
                  />
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
                  {restaurant.delivery_time_min && <span>~{restaurant.delivery_time_min} min</span>}
                </div>
              </button>

              {isOpen && (
                <div className="border-t border-slate-100 bg-slate-50 p-4">
                  {loadingMenu === restaurant.id && (
                    <div className="flex items-center gap-2 text-sm text-slate-400">
                      <Loader2 size={14} className="animate-spin" />
                      Cargando menú...
                    </div>
                  )}
                  {menu && menu.length === 0 && <p className="text-sm text-slate-400">Sin ítems en el menú.</p>}
                  {menu && menu.length > 0 && (
                    <ul className="space-y-2">
                      {menu.map((item) => (
                        <li key={item.id} className="flex items-center justify-between gap-3 text-sm">
                          <span className="min-w-0 truncate text-slate-700">{item.name}</span>
                          <span className="shrink-0 font-medium text-slate-900">{currency.format(item.price)}</span>
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
    </div>
  )
}
