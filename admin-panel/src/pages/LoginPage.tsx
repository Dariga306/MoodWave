import { useState } from 'react'
import { Form, Input, Button, Typography, message, ConfigProvider, theme } from 'antd'
import { UserOutlined, LockOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate  = useNavigate()

  const onFinish = async (values: { email: string; password: string }) => {
    setLoading(true)
    try {
      await login(values.email, values.password)
      navigate('/')
    } catch (e: any) {
      message.error(e.response?.data?.detail || e.message || 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <ConfigProvider theme={{
      algorithm: theme.darkAlgorithm,
      token: {
        colorBgContainer: '#1a1a28',
        colorBorder: '#2a2a3e',
        colorText: '#e2e8f0',
        colorTextPlaceholder: '#475569',
        colorPrimary: '#7c3aed',
        borderRadius: 10,
      },
      components: {
        Input: {
          colorBgContainer: '#1a1a28',
          colorBorder: '#2a2a3e',
          activeBg: '#1a1a28',
          hoverBg: '#1a1a28',
        },
      },
    }}>
    <div style={{
      minHeight: '100vh',
      background: 'radial-gradient(ellipse at 20% 50%, #1a0a3e 0%, #0d0820 40%, #0a0d1a 100%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      {/* Ambient glow orbs */}
      <div style={{
        position: 'fixed', top: '15%', left: '8%', width: 320, height: 320, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(124,58,237,0.18) 0%, transparent 70%)',
        pointerEvents: 'none',
      }} />
      <div style={{
        position: 'fixed', bottom: '15%', right: '8%', width: 380, height: 380, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(6,182,212,0.12) 0%, transparent 70%)',
        pointerEvents: 'none',
      }} />

      <div style={{
        width: 420, padding: '44px 40px',
        background: 'rgba(19,19,30,0.92)',
        backdropFilter: 'blur(24px)',
        borderRadius: 20,
        border: '1px solid rgba(124,58,237,0.25)',
        boxShadow: '0 32px 64px rgba(0,0,0,0.6), 0 0 0 1px rgba(124,58,237,0.1)',
        position: 'relative', zIndex: 10,
      }}>
        {/* Logo block */}
        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <div style={{
            width: 64, height: 64, borderRadius: 18,
            background: 'linear-gradient(135deg, #7c3aed, #a855f7, #ec4899)',
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
            marginBottom: 16,
            boxShadow: '0 0 40px rgba(168,85,247,0.55)',
          }}>
            <svg width="34" height="24" viewBox="0 0 34 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect x="0" y="8" width="4" height="8" rx="2" fill="white"/>
              <rect x="6" y="3" width="4" height="18" rx="2" fill="white"/>
              <rect x="12" y="0" width="4" height="24" rx="2" fill="white"/>
              <rect x="18" y="4" width="4" height="16" rx="2" fill="white"/>
              <rect x="24" y="7" width="4" height="10" rx="2" fill="white"/>
              <rect x="30" y="10" width="4" height="4" rx="2" fill="white"/>
            </svg>
          </div>
          <Typography.Title level={3} style={{ color: '#e2e8f0', margin: 0, fontWeight: 700, letterSpacing: '-0.5px' }}>
            MoodWave
          </Typography.Title>
          <Typography.Text style={{ color: '#94a3b8', fontSize: 13 }}>
            Admin Panel — Restricted Access
          </Typography.Text>
        </div>

        <Form layout="vertical" onFinish={onFinish} size="large" requiredMark={false}>
          <Form.Item
            name="email"
            rules={[{ required: true, message: 'Enter your email' }, { type: 'email', message: 'Invalid email' }]}
          >
            <Input
              prefix={<UserOutlined style={{ color: '#94a3b8' }} />}
              placeholder="Admin email"
              style={{ background: '#1a1a28', borderColor: '#2a2a3e', height: 46 }}
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[{ required: true, message: 'Enter your password' }]}
          >
            <Input.Password
              prefix={<LockOutlined style={{ color: '#94a3b8' }} />}
              placeholder="Password"
              style={{ background: '#1a1a28', borderColor: '#2a2a3e', height: 46 }}
            />
          </Form.Item>

          <Form.Item style={{ marginBottom: 0, marginTop: 8 }}>
            <Button
              type="primary"
              htmlType="submit"
              loading={loading}
              block

              style={{
                height: 48,
                background: 'linear-gradient(135deg, #7c3aed, #5b21b6)',
                border: 'none',
                fontWeight: 600, fontSize: 15,
                boxShadow: '0 4px 24px rgba(124,58,237,0.45)',
                borderRadius: 12,
              }}
            >
              Sign In
            </Button>
          </Form.Item>
        </Form>

        <Typography.Text style={{
          color: '#334155', fontSize: 11,
          display: 'block', textAlign: 'center', marginTop: 28,
        }}>
          Access restricted to authorized administrators only
        </Typography.Text>
      </div>
    </div>
    </ConfigProvider>
  )
}
