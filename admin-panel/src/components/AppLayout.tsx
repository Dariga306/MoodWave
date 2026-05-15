import { useState } from 'react'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import { Tooltip, Badge } from 'antd'
import {
  DashboardOutlined, UserOutlined, SoundOutlined, UnorderedListOutlined,
  HeartOutlined, BarChartOutlined, SettingOutlined, LogoutOutlined,
  WarningOutlined, CustomerServiceOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
} from '@ant-design/icons'
import { useAuth } from '../contexts/AuthContext'

const NAV = [
  { key: '/',          icon: <DashboardOutlined />,      label: 'Dashboard' },
  { key: '/users',     icon: <UserOutlined />,            label: 'Users' },
  { key: '/tracks',    icon: <SoundOutlined />,           label: 'Tracks' },
  { key: '/playlists', icon: <UnorderedListOutlined />,   label: 'Playlists' },
  { key: '/matches',   icon: <HeartOutlined />,           label: 'Matches' },
  { key: '/analytics', icon: <BarChartOutlined />,        label: 'Analytics' },
  { key: '/reports',   icon: <WarningOutlined />,         label: 'Reports' },
  { key: '/rooms',     icon: <CustomerServiceOutlined />, label: 'Rooms' },
  { key: '/system',    icon: <SettingOutlined />,         label: 'System' },
]

const SIDEBAR_W = 230
const SIDEBAR_COLLAPSED = 64

export default function AppLayout() {
  const navigate              = useNavigate()
  const location              = useLocation()
  const { logout, adminEmail } = useAuth()
  const [collapsed, setCollapsed] = useState(false)

  const active = NAV.find(n => n.key === location.pathname)?.label ?? 'Dashboard'
  const w      = collapsed ? SIDEBAR_COLLAPSED : SIDEBAR_W

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#07070e', fontFamily: "'Inter', sans-serif" }}>
      {/* ── Sidebar ─────────────────────────────────────────────────── */}
      <aside style={{
        width: w,
        minWidth: w,
        height: '100vh',
        position: 'fixed',
        top: 0, left: 0,
        zIndex: 100,
        display: 'flex',
        flexDirection: 'column',
        background: 'linear-gradient(180deg, #110828 0%, #0b0618 55%, #070710 100%)',
        borderRight: '1px solid rgba(124,58,237,0.18)',
        transition: 'width 0.22s ease',
        overflow: 'hidden',
      }}>
        {/* Logo */}
        <div style={{
          height: 60,
          display: 'flex',
          alignItems: 'center',
          justifyContent: collapsed ? 'center' : 'flex-start',
          padding: collapsed ? 0 : '0 18px',
          borderBottom: '1px solid rgba(255,255,255,0.05)',
          flexShrink: 0,
          gap: 12,
        }}>
          <div style={{
            width: 34, height: 34, borderRadius: 10, flexShrink: 0,
            background: 'linear-gradient(135deg, #7c3aed, #a855f7)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 0 18px rgba(124,58,237,0.6)',
          }}>
            <svg width="18" height="14" viewBox="0 0 24 18" fill="none">
              <rect x="0"  y="6"  width="3" height="6"  rx="1.5" fill="white"/>
              <rect x="4"  y="2"  width="3" height="14" rx="1.5" fill="white"/>
              <rect x="8"  y="0"  width="3" height="18" rx="1.5" fill="white"/>
              <rect x="12" y="3"  width="3" height="12" rx="1.5" fill="white"/>
              <rect x="16" y="5"  width="3" height="8"  rx="1.5" fill="white"/>
              <rect x="20" y="7"  width="3" height="4"  rx="1.5" fill="white"/>
            </svg>
          </div>
          {!collapsed && (
            <div style={{ overflow: 'hidden' }}>
              <div style={{ fontSize: 15, fontWeight: 800, letterSpacing: '-0.3px', lineHeight: 1.2,
                background: 'linear-gradient(90deg, #e2e8f0, #a78bfa)',
                WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
              }}>
                MoodWave
              </div>
              <div style={{ fontSize: 9, letterSpacing: 2, textTransform: 'uppercase', color: '#7c3aed', lineHeight: 1.4 }}>
                Admin Panel
              </div>
            </div>
          )}
        </div>

        {/* Nav */}
        <nav style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '8px 0' }}>
          {NAV.map(item => {
            const isActive = location.pathname === item.key
            return (
              <Tooltip key={item.key} title={collapsed ? item.label : ''} placement="right">
                <div
                  onClick={() => navigate(item.key)}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 11,
                    padding: collapsed ? '11px 0' : '11px 16px',
                    justifyContent: collapsed ? 'center' : 'flex-start',
                    margin: '2px 8px',
                    borderRadius: 10,
                    cursor: 'pointer',
                    position: 'relative',
                    background: isActive ? 'rgba(124,58,237,0.18)' : 'transparent',
                    border: `1px solid ${isActive ? 'rgba(124,58,237,0.35)' : 'transparent'}`,
                    transition: 'all 0.15s ease',
                    color: isActive ? '#c4b5fd' : '#64748b',
                  }}
                  onMouseEnter={e => {
                    if (!isActive) (e.currentTarget as HTMLElement).style.background = 'rgba(255,255,255,0.04)'
                  }}
                  onMouseLeave={e => {
                    if (!isActive) (e.currentTarget as HTMLElement).style.background = 'transparent'
                  }}
                >
                  {isActive && (
                    <div style={{
                      position: 'absolute', left: -8, top: '50%', transform: 'translateY(-50%)',
                      width: 3, height: 20, borderRadius: 2,
                      background: 'linear-gradient(180deg, #a855f7, #7c3aed)',
                      boxShadow: '0 0 8px #7c3aed',
                    }} />
                  )}
                  <span style={{ fontSize: 16, display: 'flex', flexShrink: 0 }}>
                    {item.icon}
                  </span>
                  {!collapsed && (
                    <span style={{ fontSize: 13, fontWeight: isActive ? 600 : 400, whiteSpace: 'nowrap' }}>
                      {item.label}
                    </span>
                  )}
                </div>
              </Tooltip>
            )
          })}
        </nav>

        {/* Bottom */}
        <div style={{
          borderTop: '1px solid rgba(255,255,255,0.05)',
          padding: collapsed ? '12px 0' : '12px 16px',
          flexShrink: 0,
        }}>
          {!collapsed && adminEmail && (
            <div style={{
              display: 'flex', alignItems: 'center', gap: 8,
              marginBottom: 10, overflow: 'hidden',
            }}>
              <div style={{
                width: 28, height: 28, borderRadius: '50%', flexShrink: 0,
                background: 'linear-gradient(135deg, #7c3aed, #ec4899)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 11, color: '#fff', fontWeight: 700,
              }}>
                {adminEmail[0].toUpperCase()}
              </div>
              <span style={{ fontSize: 11, color: '#475569', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {adminEmail}
              </span>
            </div>
          )}
          <div style={{ display: 'flex', gap: 6, justifyContent: collapsed ? 'center' : 'flex-start' }}>
            <Tooltip title={collapsed ? 'Expand' : 'Collapse'} placement="right">
              <button onClick={() => setCollapsed(c => !c)} style={{
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.08)',
                borderRadius: 8, color: '#475569',
                width: 30, height: 30, cursor: 'pointer',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 13, transition: 'all 0.15s',
              }}>
                {collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
              </button>
            </Tooltip>
            {!collapsed && (
              <Tooltip title="Sign out">
                <button onClick={logout} style={{
                  background: 'rgba(239,68,68,0.08)',
                  border: '1px solid rgba(239,68,68,0.2)',
                  borderRadius: 8, color: '#ef4444',
                  width: 30, height: 30, cursor: 'pointer',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 13, transition: 'all 0.15s',
                }}>
                  <LogoutOutlined />
                </button>
              </Tooltip>
            )}
          </div>
        </div>
      </aside>

      {/* ── Main ────────────────────────────────────────────────────── */}
      <div style={{
        flex: 1,
        marginLeft: w,
        transition: 'margin-left 0.22s ease',
        display: 'flex',
        flexDirection: 'column',
        minHeight: '100vh',
      }}>
        {/* Header */}
        <header style={{
          height: 52,
          background: 'rgba(7,7,14,0.9)',
          backdropFilter: 'blur(20px)',
          borderBottom: '1px solid rgba(255,255,255,0.05)',
          position: 'sticky', top: 0, zIndex: 99,
          display: 'flex', alignItems: 'center',
          padding: '0 24px',
          justifyContent: 'space-between',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <h1 style={{
              margin: 0, fontSize: 16, fontWeight: 700,
              letterSpacing: '-0.3px',
              background: 'linear-gradient(90deg, #e2e8f0, #a78bfa)',
              WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
            }}>
              {active}
            </h1>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Badge
              status="processing"
              style={{ '--ant-badge-processing-color': '#10b981' } as React.CSSProperties}
            />
            <span style={{ color: '#475569', fontSize: 12 }}>Live</span>
          </div>
        </header>

        {/* Content */}
        <main style={{ flex: 1, padding: '20px 24px' }}>
          <Outlet />
        </main>
      </div>
    </div>
  )
}
