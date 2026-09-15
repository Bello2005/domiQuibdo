import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, apiErrorMessage, clearToken, getToken, setToken, type AdminUser } from '../lib/api'

interface AuthContextValue {
  user: AdminUser | null
  loading: boolean
  restoring: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [loading, setLoading] = useState(false)
  const [restoring, setRestoring] = useState(true)

  useEffect(() => {
    const token = getToken()
    if (!token) {
      setRestoring(false)
      return
    }
    api
      .get('/me')
      .then(({ data }) => {
        if (data.role === 'admin') setUser(data)
        else clearToken()
      })
      .catch(() => clearToken())
      .finally(() => setRestoring(false))
  }, [])

  async function login(email: string, password: string) {
    setLoading(true)
    try {
      const { data } = await api.post('/auth/login', { email, password })
      if (data.user.role !== 'admin') {
        throw new Error('Esta cuenta no tiene rol de administrador.')
      }
      setToken(data.token)
      setUser(data.user)
    } catch (error) {
      clearToken()
      if (error instanceof Error && !('response' in error)) throw error
      throw new Error(apiErrorMessage(error))
    } finally {
      setLoading(false)
    }
  }

  function logout() {
    clearToken()
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, loading, restoring, login, logout }}>{children}</AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return ctx
}
