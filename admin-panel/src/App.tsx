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
          colorPrimary:       '#7c3aed',
          colorBgBase:        '#07070e',
          colorBgContainer:   '#0f0f1c',
          colorBgElevated:    '#161623',
          borderRadius:       10,
          fontFamily:         "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
          colorBorder:        'rgba(255,255,255,0.1)',
          colorText:          '#e2e8f0',
          colorTextSecondary: '#94a3b8',
          colorTextPlaceholder: '#475569',
        },
        components: {
          Table: {
            headerBg:   '#161623',
            rowHoverBg: 'rgba(124,58,237,0.06)',
            borderColor: 'rgba(255,255,255,0.06)',
          },
          Card: { headerBg: '#161623' },
          Menu: { darkItemBg: 'transparent', darkSubMenuItemBg: 'transparent' },
          Modal: {
            contentBg: '#0f0f1c',
            headerBg:  '#0f0f1c',
          },
          Select: {
            optionSelectedBg: 'rgba(124,58,237,0.2)',
            colorBgContainer: '#161623',
          },
          Input: {
            colorBgContainer: '#161623',
            activeBg:  '#161623',
            hoverBg:   '#161623',
          },
          Spin: { colorPrimary: '#7c3aed' },
          Badge: { colorBgContainer: '#0f0f1c' },
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
