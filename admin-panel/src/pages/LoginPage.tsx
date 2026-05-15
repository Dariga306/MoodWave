import { useState } from 'react'
import { Form, Input, Button, Typography, message } from 'antd'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function LoginPage() {
  const [loading, setLoading] = useState(false)
  const { login }   = useAuth()
  const navigate    = useNavigate()

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
    <div style={{
      minHeight: '100vh',
      background: '#07070e',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: "'Inter', sans-serif",
      position: 'relative',
      overflow: 'hidden',
    }}>
      {/* Background blobs */}
      <div style={{
        position: 'fixed', top: '10%', left: '5%',
        width: 500, height: 500, borderRadius: '50%', pointerEvents: 'none',
        background: 'radial-gradient(circle, rgba(124,58,237,0.15) 0%, transparent 65%)',
      }} />
      <div style={{
        position: 'fixed', bottom: '10%', right: '5%',
        width: 420, height: 420, borderRadius: '50%', pointerEvents: 'none',
        background: 'radial-gradient(circle, rgba(236,72,153,0.1) 0%, transparent 65%)',
      }} />
      <div style={{
        position: 'fixed', top: '40%', right: '20%',
        width: 300, height: 300, borderRadius: '50%', pointerEvents: 'none',
        background: 'radial-gradient(circle, rgba(6,182,212,0.08) 0%, transparent 65%)',
      }} />

      {/* Card */}
      <div style={{
        width: 420,
        padding: '44px 40px',
        background: 'rgba(15,15,28,0.95)',
        backdropFilter: 'blur(24px)',
        borderRadius: 24,
        border: '1px solid rgba(124,58,237,0.28)',
        boxShadow: '0 40px 80px rgba(0,0,0,0.7), 0 0 0 1px rgba(124,58,237,0.12), 0 0 60px rgba(124,58,237,0.08)',
        position: 'relative', zIndex: 10,
      }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: 40 }}>
          <div style={{
            width: 68, height: 68, borderRadius: 20, margin: '0 auto 18px',
            background: 'linear-gradient(135deg, #7c3aed, #a855f7, #ec4899)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 0 50px rgba(168,85,247,0.55), 0 0 80px rgba(168,85,247,0.2)',
          }}>
            <svg width="32" height="22" viewBox="0 0 32 22" fill="none">
              <rect x="0"  y="7"  width="4" height="8"  rx="2" fill="white"/>
              <rect x="5"  y="3"  width="4" height="16" rx="2" fill="white"/>
              <rect x="10" y="0"  width="4" height="22" rx="2" fill="white"/>
              <rect x="15" y="4"  width="4" height="14" rx="2" fill="white"/>
              <rect x="20" y="6"  width="4" height="10" rx="2" fill="white"/>
              <rect x="25" y="9"  width="4" height="4"  rx="2" fill="white"/>
            </svg>
          </div>
          <div style={{
            fontSize: 28, fontWeight: 900, letterSpacing: '-0.5px', marginBottom: 4,
            background: 'linear-gradient(90deg, #e2e8f0 0%, #c4b5fd 50%, #f9a8d4 100%)',
            WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent',
          }}>
            MoodWave
          </div>
          <div style={{ color: '#64748b', fontSize: 13 }}>
            Admin Panel · Restricted Access
          </div>
        </div>

        {/* Form */}
        <Form layout="vertical" onFinish={onFinish} requiredMark={false}>
          <Form.Item
            name="email"
            rules={[
              { required: true, message: 'Enter your email' },
              { type: 'email', message: 'Invalid email' },
            ]}
            style={{ marginBottom: 14 }}
          >
            <Input
              size="large"
              placeholder="Admin email"
              style={{
                background: '#161623',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 12,
                color: '#e2e8f0',
                height: 48,
                fontSize: 14,
              }}
            />
          </Form.Item>

          <Form.Item
            name="password"
            rules={[{ required: true, message: 'Enter your password' }]}
            style={{ marginBottom: 24 }}
          >
            <Input.Password
              size="large"
              placeholder="Password"
              style={{
                background: '#161623',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 12,
                color: '#e2e8f0',
                height: 48,
                fontSize: 14,
              }}
            />
          </Form.Item>

          <Button
            type="primary"
            htmlType="submit"
            loading={loading}
            block
            size="large"
            style={{
              height: 50,
              background: 'linear-gradient(135deg, #7c3aed, #a855f7)',
              border: 'none',
              borderRadius: 12,
              fontWeight: 700,
              fontSize: 15,
              boxShadow: '0 6px 28px rgba(124,58,237,0.5)',
            }}
          >
            Sign In
          </Button>
        </Form>

        <div style={{
          textAlign: 'center', marginTop: 28,
          color: '#2d3748', fontSize: 11,
        }}>
          Access restricted to authorized administrators only
        </div>
      </div>
    </div>
  )
}
