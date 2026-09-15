import { LayoutDashboard, LogOut, MapPin, Truck, Users as UsersIcon, UtensilsCrossed } from 'lucide-react'
import type { ReactNode } from 'react'
import { NavLink } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

const navItems = [
  { to: '/pedidos', label: 'Pedidos', icon: LayoutDashboard },
  { to: '/restaurantes', label: 'Restaurantes', icon: UtensilsCrossed },
  { to: '/zonas', label: 'Zonas de cobertura', icon: MapPin },
  { to: '/usuarios', label: 'Usuarios', icon: UsersIcon },
]

export function Layout({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth()

  return (
    <div className="flex min-h-screen">
      <aside className="flex w-64 shrink-0 flex-col bg-gradient-to-b from-teal-800 to-teal-950 text-white">
        <div className="flex items-center gap-3 px-6 py-6">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-500 shadow-lg">
            <Truck size={20} />
          </div>
          <div>
            <p className="text-lg font-bold leading-tight">DomiQuibdó</p>
            <p className="text-xs text-teal-200">Panel de administración</p>
          </div>
        </div>

        <nav className="mt-4 flex flex-1 flex-col gap-1 px-3">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                  isActive ? 'bg-white/15 text-white' : 'text-teal-100 hover:bg-white/10 hover:text-white'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-white/10 px-4 py-4">
          <p className="truncate px-2 text-sm font-medium">{user?.name}</p>
          <p className="truncate px-2 text-xs text-teal-300">{user?.email}</p>
          <button
            onClick={logout}
            className="mt-3 flex w-full items-center gap-2 rounded-lg px-2 py-2 text-sm text-teal-100 transition-colors hover:bg-white/10 hover:text-white"
          >
            <LogOut size={16} />
            Cerrar sesión
          </button>
        </div>
      </aside>

      <main className="flex-1 overflow-y-auto p-8">{children}</main>
    </div>
  )
}
