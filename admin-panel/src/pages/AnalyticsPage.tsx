import { useEffect, useState } from 'react'
import { Row, Col, Spin, Empty } from 'antd'
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend,
} from 'recharts'
import { adminApi } from '../api/admin'

const COLORS = [
  '#7c3aed', '#06b6d4', '#10b981', '#f59e0b', '#ef4444',
  '#ec4899', '#8b5cf6', '#14b8a6', '#f97316', '#3b82f6',
]

const tt = {
  contentStyle: { background: '#161623', border: '1px solid rgba(124,58,237,0.3)', borderRadius: 10, fontSize: 12 },
  labelStyle:   { color: '#e2e8f0', fontWeight: 600 },
  itemStyle:    { color: '#94a3b8' },
}
const ax = {
  tick: { fontSize: 11, fill: '#475569' },
  tickLine: false as const,
  axisLine: false as const,
}

const card = {
  background: '#0f0f1c',
  border: '1px solid rgba(255,255,255,0.07)',
  borderRadius: 16,
  overflow: 'hidden' as const,
}

function CardWrap({ title, children, height }: { title: string; children: React.ReactNode; height?: number }) {
  return (
    <div style={card}>
      <div style={{ padding: '14px 18px 10px', borderBottom: '1px solid rgba(255,255,255,0.05)', fontSize: 13, fontWeight: 600, color: '#e2e8f0' }}>
        {title}
      </div>
      <div style={{ padding: '8px 16px 16px' }}>
        {children}
      </div>
    </div>
  )
}

const renderLabel = ({ percent }: { percent: number }) =>
  percent > 0.06 ? `${(percent * 100).toFixed(0)}%` : ''

export default function AnalyticsPage() {
  const [data, setData]       = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminApi.getAnalytics().then(r => setData(r.data)).finally(() => setLoading(false))
  }, [])

  if (loading) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <Spin size="large" />
    </div>
  )
  if (!data) return null

  const dauData = (data.daily_active_users || []).map((d: any) => ({
    ...d,
    label: new Date(d.date).toLocaleDateString('en', { month: 'short', day: 'numeric' }),
  }))

  const topGenres  = (data.top_genres || []).slice(0, 10).map((g: any) => ({
    ...g,
    label: g.genre?.length > 14 ? g.genre.slice(0, 14) + '…' : (g.genre || '—'),
  }))
  const genrePie   = (data.top_genres || []).slice(0, 8)
  const topCities  = (data.top_cities || []).slice(0, 6)

  const kpis = [
    { label: 'Avg Match Similarity', value: `${data.avg_similarity_pct ?? 0}%`, from: '#7c3aed', to: '#5b21b6', glow: '#7c3aed' },
    { label: 'Avg Tracks / User',    value: data.avg_tracks_per_user ?? 0,       from: '#06b6d4', to: '#0e7490', glow: '#06b6d4' },
    { label: 'Genres Tracked',       value: (data.top_genres || []).length,      from: '#10b981', to: '#047857', glow: '#10b981' },
    { label: 'Cities Represented',   value: (data.top_cities || []).length,      from: '#f59e0b', to: '#b45309', glow: '#f59e0b' },
  ]

  return (
    <>
      {/* KPI row */}
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        {kpis.map((k, i) => (
          <Col span={6} key={i}>
            <div style={{
              background: `linear-gradient(135deg, ${k.from}, ${k.to})`,
              borderRadius: 16, padding: '20px 22px',
              boxShadow: `0 8px 24px ${k.glow}30`,
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{
                position: 'absolute', top: -15, right: -15,
                width: 70, height: 70, borderRadius: '50%',
                background: 'rgba(255,255,255,0.08)',
              }} />
              <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 12, marginBottom: 6, fontWeight: 500 }}>{k.label}</div>
              <div style={{ color: '#fff', fontSize: 30, fontWeight: 800, lineHeight: 1, letterSpacing: '-0.5px' }}>{k.value}</div>
            </div>
          </Col>
        ))}
      </Row>

      {/* DAU */}
      <Row gutter={[12, 12]} style={{ marginBottom: 12 }}>
        <Col span={24}>
          <CardWrap title="Daily Active Users — Last 30 Days">
            {dauData.length === 0 ? (
              <Empty description="No activity data" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ padding: '48px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={200}>
                <LineChart data={dauData}>
                  <defs>
                    <linearGradient id="dauGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%"  stopColor="#7c3aed" stopOpacity={0.25} />
                      <stop offset="95%" stopColor="#7c3aed" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
                  <XAxis dataKey="label" {...ax} interval="preserveStartEnd" />
                  <YAxis {...ax} allowDecimals={false} />
                  <Tooltip {...tt} formatter={(v: any) => [v, 'Active users']} />
                  <Line type="monotone" dataKey="active_users"
                    stroke="#7c3aed" strokeWidth={2.5} dot={false}
                    activeDot={{ r: 4, fill: '#a855f7', strokeWidth: 0 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </CardWrap>
        </Col>
      </Row>

      {/* Bottom charts */}
      <Row gutter={[12, 12]}>
        <Col span={10}>
          <CardWrap title="Top Genres by Preference">
            {topGenres.length === 0 ? (
              <Empty description="No genre data" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <BarChart data={topGenres} layout="vertical" margin={{ left: 0, right: 24 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" horizontal={false} />
                  <XAxis type="number" {...ax} allowDecimals={false} />
                  <YAxis dataKey="label" type="category" {...ax} width={100} />
                  <Tooltip {...tt} formatter={(v: any) => [Number(v).toFixed(1), 'Weight']} />
                  <Bar dataKey="weight" radius={[0, 6, 6, 0]} maxBarSize={16}>
                    {topGenres.map((_: any, i: number) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardWrap>
        </Col>

        <Col span={7}>
          <CardWrap title="Genre Share">
            {genrePie.length === 0 ? (
              <Empty description="No data" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <PieChart>
                  <Pie data={genrePie} dataKey="weight" nameKey="genre"
                    cx="50%" cy="44%" outerRadius={90} innerRadius={42}
                    label={renderLabel} labelLine={false}>
                    {genrePie.map((_: any, i: number) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                  </Pie>
                  <Tooltip {...tt} formatter={(v: any) => [Number(v).toFixed(1), 'Weight']} />
                  <Legend wrapperStyle={{ fontSize: 10, color: '#64748b', paddingTop: 4 }}
                    formatter={(v: any) => v?.length > 10 ? v.slice(0, 10) + '…' : v} />
                </PieChart>
              </ResponsiveContainer>
            )}
          </CardWrap>
        </Col>

        <Col span={7}>
          <CardWrap title="Top Cities">
            {topCities.length === 0 ? (
              <Empty description="No city data" image={Empty.PRESENTED_IMAGE_SIMPLE} style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <BarChart data={topCities} layout="vertical" margin={{ left: 0, right: 24 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" horizontal={false} />
                  <XAxis type="number" {...ax} allowDecimals={false} />
                  <YAxis dataKey="city" type="category" {...ax} width={80} />
                  <Tooltip {...tt} formatter={(v: any) => [v, 'Users']} />
                  <Bar dataKey="count" radius={[0, 6, 6, 0]} maxBarSize={20}>
                    {topCities.map((_: any, i: number) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </CardWrap>
        </Col>
      </Row>
    </>
  )
}
