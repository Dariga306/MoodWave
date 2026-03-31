import React, { createContext, useContext, useState, useEffect } from 'react'
import { adminApi } from '../api/admin'

interface AuthContextType {
  isAdmin: boolean
  loading: boolean
  adminEmail: string
  login: (email: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthContextType | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAdmin, setIsAdmin]     = useState(false)
  const [loading, setLoading]     = useState(true)
  const [adminEmail, setAdminEmail] = useState('')

  useEffect(() => {
    const token = localStorage.getItem('admin_token')
    const email = localStorage.getItem('admin_email') || ''
    setIsAdmin(!!token)
    setAdminEmail(email)
    setLoading(false)
  }, [])

  const login = async (email: string, password: string) => {
    const res = await adminApi.login(email, password)
    const { access_token, user } = res.data
    if (!user.is_admin) throw new Error('Admin access required')
    localStorage.setItem('admin_token', access_token)
    localStorage.setItem('admin_email', email)
    setIsAdmin(true)
    setAdminEmail(email)
  }

  const logout = () => {
    localStorage.removeItem('admin_token')
    localStorage.removeItem('admin_email')
    setIsAdmin(false)
    setAdminEmail('')
  }

  return (
    <AuthContext.Provider value={{ isAdmin, loading, adminEmail, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
