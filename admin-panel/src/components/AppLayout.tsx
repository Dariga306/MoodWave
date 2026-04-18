import { useState } from 'react'
import { Layout, Menu, Button, Avatar, Typography, Tooltip } from 'antd'
import {
  DashboardOutlined, UserOutlined, SoundOutlined, UnorderedListOutlined,
  HeartOutlined, BarChartOutlined, SettingOutlined, LogoutOutlined,
  WarningOutlined, CustomerServiceOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
} from '@ant-design/icons'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

const { Sider, Content } = Layout

const menuItems = [
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

export default function AppLayout() {
  const navigate   = useNavigate()
  const location   = useLocation()
  const { logout, adminEmail } = useAuth()
  const [collapsed, setCollapsed] = useState(false)

  const currentLabel = menuItems.find(i => i.key === location.pathname)?.label || 'Dashboard'

  return (
    <Layout style={{ minHeight: '100vh', background: '#0a0a12' }}>
      <Sider
        width={220}
        collapsed={collapsed}
        trigger={null}
        style={{
          background: 'linear-gradient(180deg, #12082e 0%, #0d0818 60%, #080c18 100%)',
          borderRight: '1px solid rgba(124,58,237,0.12)',
          position: 'fixed', height: '100vh', left: 0, top: 0, zIndex: 100,
          display: 'flex', flexDirection: 'column',
        }}
      >
        {/* Logo */}
        <div style={{
          padding: collapsed ? '16px 0' : '16px 20px',
          display: 'flex', alignItems: 'center', gap: 10,
          borderBottom: '1px solid rgba(255,255,255,0.06)',
          marginBottom: 6,
          justifyContent: collapsed ? 'center' : 'flex-start',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10, flexShrink: 0,
            background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 18, boxShadow: '0 0 20px rgba(124,58,237,0.5)',
          }}>
            🎵
          </div>
          {!collapsed && (
            <div>
              <div style={{ color: '#e2e8f0', fontWeight: 700, fontSize: 15, lineHeight: 1.2, letterSpacing: '-0.3px' }}>
                MoodWave
              </div>
              <div style={{ color: '#7c3aed', fontSize: 10, letterSpacing: 1.5, textTransform: 'uppercase' as const }}>
                Admin
              </div>
            </div>
          )}
        </div>

        {/* Navigation */}
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '4px 0' }}>
          <Menu
            theme="dark"
            mode="inline"
            selectedKeys={[location.pathname]}
            items={menuItems}
            onClick={({ key }) => navigate(key)}
            style={{ background: 'transparent', border: 'none' }}
          />
        </div>

        {/* Bottom bar */}
        <div style={{
          borderTop: '1px solid rgba(255,255,255,0.06)',
          padding: collapsed ? '10px 0' : '10px 14px',
        }}>
          {!collapsed && adminEmail && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <Avatar size={26} style={{
                background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
                flexShrink: 0, fontSize: 11,
              }}>
                {adminEmail[0].toUpperCase()}
              </Avatar>
              <Typography.Text style={{ color: '#64748b', fontSize: 11 }} ellipsis>
                {adminEmail}
              </Typography.Text>
            </div>
          )}
          <div style={{ display: 'flex', gap: 6, justifyContent: collapsed ? 'center' : 'flex-start' }}>
            <Tooltip title={collapsed ? 'Expand sidebar' : 'Collapse'} placement="right">
              <Button
                type="text"
                icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                onClick={() => setCollapsed(c => !c)}
                style={{ color: '#475569' }}
                size="small"
              />
            </Tooltip>
            {!collapsed && (
              <Tooltip title="Sign out">
                <Button
                  type="text" icon={<LogoutOutlined />}
                  onClick={logout}
                  style={{ color: '#ef4444' }}
                  size="small"
                />
              </Tooltip>
            )}
          </div>
        </div>
      </Sider>

      <Layout style={{
        marginLeft: collapsed ? 80 : 220,
        transition: 'margin-left 0.2s ease',
        background: '#0a0a12',
        minHeight: '100vh',
      }}>
        {/* Slim header */}
        <div style={{
          background: 'rgba(13,13,20,0.95)',
          backdropFilter: 'blur(12px)',
          padding: '0 24px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          borderBottom: '1px solid rgba(255,255,255,0.05)',
          position: 'sticky', top: 0, zIndex: 99, height: 50,
        }}>
          <Typography.Text style={{ color: '#e2e8f0', fontSize: 15, fontWeight: 600, letterSpacing: '-0.2px' }}>
            {currentLabel}
          </Typography.Text>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <div style={{
              width: 7, height: 7, borderRadius: '50%',
              background: '#10b981', boxShadow: '0 0 6px #10b981',
            }} />
            <span style={{ color: '#475569', fontSize: 12 }}>Live</span>
          </div>
        </div>

        <Content style={{ margin: '20px 24px', minHeight: 360 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
