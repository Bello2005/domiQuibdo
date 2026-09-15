import { Loader2 } from 'lucide-react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { Layout } from './components/Layout'
import { AuthProvider, useAuth } from './context/AuthContext'
import { Login } from './pages/Login'
import { Orders } from './pages/Orders'
import { Restaurants } from './pages/Restaurants'
import { Users } from './pages/Users'
import { Zones } from './pages/Zones'

function Protected({ children }: { children: React.ReactNode }) {
  const { user, restoring } = useAuth()

  if (restoring) {
    return (
      <div className="flex min-h-screen items-center justify-center text-slate-400">
        <Loader2 size={24} className="animate-spin" />
      </div>
    )
  }
  if (!user) return <Navigate to="/login" replace />
  return <Layout>{children}</Layout>
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/pedidos"
        element={
          <Protected>
            <Orders />
          </Protected>
        }
      />
      <Route
        path="/restaurantes"
        element={
          <Protected>
            <Restaurants />
          </Protected>
        }
      />
      <Route
        path="/zonas"
        element={
          <Protected>
            <Zones />
          </Protected>
        }
      />
      <Route
        path="/usuarios"
        element={
          <Protected>
            <Users />
          </Protected>
        }
      />
      <Route path="*" element={<Navigate to="/pedidos" replace />} />
    </Routes>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  )
}
