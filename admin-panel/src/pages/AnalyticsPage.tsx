import { useEffect, useState } from 'react'
import { Row, Col, Card, Typography, Spin } from 'antd'
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip,
  ResponsiveContainer, Cell, CartesianGrid, Legend,
} from 'recharts'
import { adminApi } from '../api/admin'

const COLORS = ['#7c3aed','#06b6d4','#10b981','#f59e0b','#ef4444','#ec4899','#8b5cf6','#14b8a6','#f97316','#3b82f6']

const cardStyle = { background: '#13131e', border: '1px solid #2a2a3e', borderRadius: 14 }
const chartTooltip = {
  contentStyle: { background: '#1a1a28', border: '1px solid #2a2a3e', borderRadius: 8, fontSize: 12 },
  labelStyle: { color: '#e2e8f0' },
}
const axisProps = { tick: { fontSize: 11, fill: '#94a3b8' }, tickLine: false as const, axisLine: false as const }

export default function AnalyticsPage() {
  const [data, setData]       = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminApi.getAnalytics().then(r => setData(r.data)).finally(() => setLoading(false))
  }, [])

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '80px auto' }} />
  if (!data) return null

  return (
    <>
      {/* KPI cards */}
      <Row gutter={[14, 14]} style={{ marginBottom: 20 }}>
        <Col span={6}>
          <Card style={{ ...cardStyle, background: 'linear-gradient(135deg, #7c3aed, #5b21b6)', border: 'none', boxShadow: '0 8px 24px #7c3aed33' }}
            bodyStyle={{ padding: '20px 22px' }}>
            <Typography.Text style={{ color: 'rgba(255,255,255,0.65)', fontSize: 12, display: 'block', marginBottom: 6 }}>Avg Match Similarity</Typography.Text>
            <Typography.Title level={2} style={{ color: '#fff', margin: 0, fontWeight: 700 }}>{data.avg_similarity_pct}%</Typography.Title>
          </Card>
        </Col>
        <Col span={6}>
          <Card style={{ ...cardStyle, background: 'linear-gradient(135deg, #06b6d4, #0e7490)', border: 'none', boxShadow: '0 8px 24px #06b6d433' }}
            bodyStyle={{ padding: '20px 22px' }}>
            <Typography.Text style={{ color: 'rgba(255,255,255,0.65)', fontSize: 12, display: 'block', marginBottom: 6 }}>Avg Tracks / User</Typography.Text>
            <Typography.Title level={2} style={{ color: '#fff', margin: 0, fontWeight: 700 }}>{data.avg_tracks_per_user}</Typography.Title>
          </Card>
        </Col>
      </Row>

      <Row gutter={[14, 14]} style={{ marginBottom: 14 }}>
        {/* DAU chart */}
        <Col span={16}>
          <Card title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Daily Active Users — Last 30 Days</span>}
            style={cardStyle} bodyStyle={{ padding: '12px 16px' }}>
            <ResponsiveContainer width="100%" height={220}>
              <LineChart data={data.daily_active_users}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e1e2e" />
                <XAxis dataKey="date" {...axisProps} />
                <YAxis {...axisProps} />
                <Tooltip {...chartTooltip} />
                <Line type="monotone" dataKey="active_users" stroke="#7c3aed" strokeWidth={2.5} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>

        {/* Top cities */}
        <Col span={8}>
          <Card title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Top Cities</span>}
            style={cardStyle} bodyStyle={{ padding: '12px 16px' }}>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={data.top_cities} layout="vertical">
                <XAxis type="number" {...axisProps} />
                <YAxis dataKey="city" type="category" {...axisProps} width={80} />
                <Tooltip {...chartTooltip} />
                <Bar dataKey="count" radius={[0, 6, 6, 0]}>
                  {data.top_cities.map((_: any, i: number) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>

      {/* Top genres */}
      <Row gutter={[14, 14]}>
        <Col span={24}>
          <Card title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Top Genres by Weight</span>}
            style={cardStyle} bodyStyle={{ padding: '12px 16px' }}>
            <ResponsiveContainer width="100%" height={230}>
              <BarChart data={data.top_genres} layout="vertical">
                <XAxis type="number" {...axisProps} />
                <YAxis dataKey="genre" type="category" {...axisProps} width={120} />
                <Tooltip {...chartTooltip} />
                <Bar dataKey="weight" radius={[0, 6, 6, 0]}>
                  {data.top_genres.map((_: any, i: number) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>
    </>
  )
}
