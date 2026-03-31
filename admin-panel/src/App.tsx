import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { ConfigProvider, theme } from 'antd'
import { AuthProvider } from './contexts/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import AppLayout from './components/AppLayout'
import LoginPage from './pages/LoginPage'
import DashboardPage from './pages/DashboardPage'
import UsersPage from './pages/UsersPage'
import TracksPage from './pages/TracksPage'
import PlaylistsPage from './pages/PlaylistsPage'
import MatchesPage from './pages/MatchesPage'
import AnalyticsPage from './pages/AnalyticsPage'
import ReportsPage from './pages/ReportsPage'
import RoomsPage from './pages/RoomsPage'
import SystemPage from './pages/SystemPage'

export default function App() {
  return (
    <ConfigProvider
      theme={{
        algorithm: theme.darkAlgorithm,
        token: {
          colorPrimary: '#7c3aed',
          colorBgBase: '#0d0d14',
          colorBgContainer: '#13131e',
          colorBgElevated: '#1a1a28',
          borderRadius: 10,
          fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
          colorBorder: '#2a2a3e',
          colorText: '#e2e8f0',
          colorTextSecondary: '#94a3b8',
        },
        components: {
          Table: { headerBg: '#1a1a28', rowHoverBg: '#1e1e30' },
          Card:  { headerBg: '#1a1a28' },
          Menu:  { darkItemBg: 'transparent', darkSubMenuItemBg: 'transparent' },
          Modal: { contentBg: '#13131e', headerBg: '#13131e' },
          Select: { optionSelectedBg: '#2a1a5e' },
        },
      }}
    >
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route
              path="/"
              element={
                <ProtectedRoute>
                  <AppLayout />
                </ProtectedRoute>
              }
            >
              <Route index          element={<DashboardPage />} />
              <Route path="users"     element={<UsersPage />} />
              <Route path="tracks"    element={<TracksPage />} />
              <Route path="playlists" element={<PlaylistsPage />} />
              <Route path="matches"   element={<MatchesPage />} />
              <Route path="analytics" element={<AnalyticsPage />} />
              <Route path="reports"   element={<ReportsPage />} />
              <Route path="rooms"     element={<RoomsPage />} />
              <Route path="system"    element={<SystemPage />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ConfigProvider>
  )
}
