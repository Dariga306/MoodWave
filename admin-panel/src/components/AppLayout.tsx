import { useState } from 'react'
import { Layout, Menu, Button, Avatar, Typography, Tooltip, Badge } from 'antd'
import {
  DashboardOutlined, UserOutlined, SoundOutlined, UnorderedListOutlined,
  HeartOutlined, BarChartOutlined, SettingOutlined, LogoutOutlined,
  WarningOutlined, CustomerServiceOutlined, MenuFoldOutlined, MenuUnfoldOutlined,
} from '@ant-design/icons'
import { Outlet, useNavigate, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

const { Sider, Header, Content } = Layout

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
  const navigate  = useNavigate()
  const location  = useLocation()
  const { logout, adminEmail } = useAuth()
  const [collapsed, setCollapsed] = useState(false)

  const currentLabel = menuItems.find(i => i.key === location.pathname)?.label || 'Dashboard'

  return (
    <Layout style={{ minHeight: '100vh', background: '#0d0d14' }}>
      <Sider
        width={220}
        collapsed={collapsed}
        trigger={null}
        style={{
          background: 'linear-gradient(180deg, #1a0a3e 0%, #0d0820 50%, #0a0d1a 100%)',
          borderRight: '1px solid #2a2a3e',
          position: 'fixed',
          height: '100vh',
          left: 0, top: 0,
          zIndex: 100,
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Logo */}
        <div style={{
          padding: collapsed ? '18px 0' : '18px 20px',
          display: 'flex', alignItems: 'center', gap: 10,
          borderBottom: '1px solid #2a2a3e', marginBottom: 8,
          justifyContent: collapsed ? 'center' : 'flex-start',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: 10, flexShrink: 0,
            background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 18, boxShadow: '0 0 20px rgba(124,58,237,0.4)',
          }}>🎵</div>
          {!collapsed && (
            <div>
              <div style={{ color: '#e2e8f0', fontWeight: 700, fontSize: 15, lineHeight: 1.2 }}>MoodWave</div>
              <div style={{ color: '#7c3aed', fontSize: 11 }}>Admin Panel</div>
            </div>
          )}
        </div>

        {/* Navigation */}
        <div style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}>
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
        <div style={{ borderTop: '1px solid #2a2a3e', padding: collapsed ? '12px 0' : '12px 16px' }}>
          {!collapsed && adminEmail && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
              <Avatar size={28} style={{ background: 'linear-gradient(135deg, #7c3aed, #06b6d4)', flexShrink: 0, fontSize: 12 }}>
                {adminEmail[0].toUpperCase()}
              </Avatar>
              <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }} ellipsis>
                {adminEmail}
              </Typography.Text>
            </div>
          )}
          <div style={{ display: 'flex', gap: 6, justifyContent: collapsed ? 'center' : 'flex-start' }}>
            <Tooltip title={collapsed ? 'Expand' : 'Collapse'} placement="right">
              <Button
                type="text"
                icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
                onClick={() => setCollapsed(c => !c)}
                style={{ color: '#94a3b8' }}
              />
            </Tooltip>
            {!collapsed && (
              <Tooltip title="Sign out">
                <Button type="text" icon={<LogoutOutlined />} onClick={logout} style={{ color: '#ef4444' }} />
              </Tooltip>
            )}
          </div>
        </div>
      </Sider>

      <Layout style={{ marginLeft: collapsed ? 80 : 220, transition: 'margin-left 0.2s', background: '#0d0d14' }}>
        <Header style={{
          background: '#13131e', padding: '0 24px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          borderBottom: '1px solid #2a2a3e',
          position: 'sticky', top: 0, zIndex: 99, height: 54,
        }}>
          <Typography.Text style={{ color: '#e2e8f0', fontSize: 15, fontWeight: 600 }}>
            {currentLabel}
          </Typography.Text>
          <Badge dot color="#10b981" offset={[-2, 2]}>
            <span style={{ color: '#475569', fontSize: 12 }}>Live</span>
          </Badge>
        </Header>

        <Content style={{ margin: '20px 24px', minHeight: 360 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
