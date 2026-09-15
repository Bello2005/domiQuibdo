import { AlertCircle, Loader2, Pencil, Plus, Trash2, UserCircle } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { FormField, Modal, inputClass } from '../components/Modal'
import { useAuth } from '../context/AuthContext'
import { api, apiErrorMessage, USER_ROLES, type AdminUser } from '../lib/api'

type UserForm = {
  name: string
  email: string
  phone: string
  role: AdminUser['role']
  password: string
}

const emptyForm: UserForm = { name: '', email: '', phone: '', role: 'cliente', password: '' }

const roleStyles: Record<AdminUser['role'], string> = {
  admin: 'bg-violet-100 text-violet-700',
  restaurante: 'bg-orange-100 text-orange-700',
  repartidor: 'bg-blue-100 text-blue-700',
  cliente: 'bg-emerald-100 text-emerald-700',
}

export function Users() {
  const { user: currentUser } = useAuth()
  const [users, setUsers] = useState<AdminUser[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [editing, setEditing] = useState<AdminUser | 'new' | null>(null)
  const [form, setForm] = useState<UserForm>(emptyForm)
  const [formError, setFormError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  function load() {
    api
      .get<AdminUser[]>('/admin/users')
      .then(({ data }) => setUsers(data))
      .catch((err) => setError(apiErrorMessage(err)))
  }

  useEffect(load, [])

  function openCreate() {
    setForm(emptyForm)
    setFormError(null)
    setEditing('new')
  }

  function openEdit(user: AdminUser) {
    setForm({ name: user.name, email: user.email, phone: user.phone ?? '', role: user.role, password: '' })
    setFormError(null)
    setEditing(user)
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault()
    setSaving(true)
    setFormError(null)
    const payload: Record<string, unknown> = {
      name: form.name,
      email: form.email,
      phone: form.phone || null,
      role: form.role,
    }
    if (form.password) payload.password = form.password
    try {
      if (editing === 'new') {
        await api.post('/admin/users', payload)
      } else if (editing) {
        await api.put(`/admin/users/${editing.id}`, payload)
      }
      setEditing(null)
      load()
    } catch (err) {
      setFormError(apiErrorMessage(err))
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(user: AdminUser) {
    if (!confirm(`¿Eliminar a "${user.name}"?`)) return
    try {
      await api.delete(`/admin/users/${user.id}`)
      load()
    } catch (err) {
      alert(apiErrorMessage(err))
    }
  }

  return (
    <div>
      <header className="mb-6 flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Usuarios</h1>
          <p className="mt-1 text-sm text-slate-500">{users ? `${users.length} cuentas registradas` : 'Clientes, repartidores, restaurantes y admins.'}</p>
        </div>
        <button
          onClick={openCreate}
          className="flex shrink-0 items-center gap-2 rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800"
        >
          <Plus size={16} />
          Nuevo usuario
        </button>
      </header>

      <div className="overflow-hidden rounded-xl border border-slate-200 bg-white shadow-sm">
        {error && (
          <div className="flex items-center gap-2 p-6 text-sm text-red-600">
            <AlertCircle size={18} />
            {error}
          </div>
        )}

        {!users && !error && (
          <div className="flex items-center justify-center gap-2 p-12 text-slate-400">
            <Loader2 size={20} className="animate-spin" />
            Cargando usuarios...
          </div>
        )}

        {users && users.length > 0 && (
          <table className="w-full text-left text-sm">
            <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
              <tr>
                <th className="px-4 py-3">Nombre</th>
                <th className="px-4 py-3">Correo</th>
                <th className="px-4 py-3">Teléfono</th>
                <th className="px-4 py-3">Rol</th>
                <th className="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {users.map((user) => (
                <tr key={user.id} className="hover:bg-slate-50">
                  <td className="px-4 py-3">
                    <span className="flex items-center gap-2 font-medium text-slate-900">
                      <UserCircle size={18} className="text-slate-300" />
                      {user.name}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-slate-600">{user.email}</td>
                  <td className="px-4 py-3 text-slate-600">{user.phone ?? '—'}</td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold ${roleStyles[user.role]}`}>
                      {USER_ROLES.find((r) => r.value === user.role)?.label ?? user.role}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-1">
                      <button onClick={() => openEdit(user)} className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-teal-700">
                        <Pencil size={16} />
                      </button>
                      {currentUser?.id !== user.id && (
                        <button onClick={() => handleDelete(user)} className="rounded-lg p-1.5 text-slate-400 hover:bg-red-50 hover:text-red-600">
                          <Trash2 size={16} />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {editing && (
        <Modal title={editing === 'new' ? 'Nuevo usuario' : 'Editar usuario'} onClose={() => setEditing(null)}>
          <form onSubmit={handleSubmit} className="space-y-4">
            <FormField label="Nombre">
              <input required className={inputClass} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
            </FormField>
            <FormField label="Correo">
              <input required type="email" className={inputClass} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            </FormField>
            <FormField label="Teléfono">
              <input className={inputClass} value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
            </FormField>
            <FormField label="Rol">
              <select className={inputClass} value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as AdminUser['role'] })}>
                {USER_ROLES.map((r) => (
                  <option key={r.value} value={r.value}>
                    {r.label}
                  </option>
                ))}
              </select>
            </FormField>
            <FormField label={editing === 'new' ? 'Contraseña' : 'Nueva contraseña (dejar en blanco para no cambiarla)'}>
              <input
                type="password"
                required={editing === 'new'}
                minLength={8}
                className={inputClass}
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
              />
            </FormField>

            {formError && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{formError}</p>}

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setEditing(null)} className="rounded-lg px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100">
                Cancelar
              </button>
              <button type="submit" disabled={saving} className="rounded-lg bg-teal-700 px-4 py-2 text-sm font-semibold text-white hover:bg-teal-800 disabled:opacity-60">
                {saving ? 'Guardando...' : 'Guardar'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  )
}
