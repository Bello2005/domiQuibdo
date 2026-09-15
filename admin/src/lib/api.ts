import axios from 'axios'

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'https://domiquibdo.onrender.com/api'

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { Accept: 'application/json' },
})

const TOKEN_KEY = 'domiquibdo_admin_token'

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY)
}

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) clearToken()
    return Promise.reject(error)
  },
)

export function apiErrorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: string; errors?: Record<string, string[]> } | undefined
    if (data?.errors) {
      const first = Object.values(data.errors)[0]?.[0]
      if (first) return first
    }
    if (data?.message) return data.message
    if (!error.response) return 'No pudimos conectar con el servidor.'
  }
  return 'Ocurrió un error inesperado.'
}

// --- Tipos que reflejan los API Resources de Laravel ---

export type OrderStatus = 'pendiente' | 'confirmado' | 'preparando' | 'en_camino' | 'entregado' | 'cancelado'

export interface AdminUser {
  id: number
  name: string
  email: string
  phone: string | null
  role: 'cliente' | 'repartidor' | 'restaurante' | 'admin'
}

export interface MenuItem {
  id: number
  restaurant_id: number
  name: string
  description: string | null
  price: number
  image_url: string | null
  is_available: boolean
}

export interface Restaurant {
  id: number
  name: string
  description: string | null
  category: string
  latitude: number
  longitude: number
  address_text: string
  phone: string | null
  cover_image_url: string | null
  rating_avg: number | null
  delivery_time_min: number | null
  is_active: boolean
  menu_items?: MenuItem[]
}

export interface Zone {
  id: number
  name: string
  center_lat: number
  center_lng: number
  radius_m: number
  is_active: boolean
}

export interface Order {
  id: number
  status: OrderStatus
  status_label: string
  subtotal: number
  delivery_fee: number
  total: number
  payment_method: string
  notes: string | null
  created_at: string | null
  restaurant?: Restaurant
  items_count?: number
  repartidor_id: number | null
  repartidor?: { name: string; phone: string | null } | null
  customer?: { name: string; phone: string | null } | null
}

export const ORDER_STATUSES: { value: OrderStatus; label: string }[] = [
  { value: 'pendiente', label: 'Pendiente' },
  { value: 'confirmado', label: 'Confirmado' },
  { value: 'preparando', label: 'Preparando' },
  { value: 'en_camino', label: 'En camino' },
  { value: 'entregado', label: 'Entregado' },
  { value: 'cancelado', label: 'Cancelado' },
]

export const USER_ROLES: { value: AdminUser['role']; label: string }[] = [
  { value: 'cliente', label: 'Cliente' },
  { value: 'repartidor', label: 'Repartidor' },
  { value: 'restaurante', label: 'Restaurante' },
  { value: 'admin', label: 'Admin' },
]
