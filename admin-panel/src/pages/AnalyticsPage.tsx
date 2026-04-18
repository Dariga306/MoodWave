import { useEffect, useState } from 'react'
import { Row, Col, Card, Spin, Empty } from 'antd'
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend,
} from 'recharts'
import { adminApi } from '../api/admin'

const COLORS = [
  '#7c3aed', '#06b6d4', '#10b981', '#f59e0b', '#ef4444',
  '#ec4899', '#8b5cf6', '#14b8a6', '#f97316', '#3b82f6',
]

const chartTooltip = {
  contentStyle: { background: '#1a1a28', border: '1px solid #2a2a3e', borderRadius: 8, fontSize: 12 },
  labelStyle: { color: '#e2e8f0', fontWeight: 600 },
  itemStyle: { color: '#94a3b8' },
}

const axisProps = {
  tick: { fontSize: 11, fill: '#64748b' },
  tickLine: false as const,
  axisLine: false as const,
}

const cardStyle = { background: '#13131e', border: '1px solid #1e1e30', borderRadius: 16 }
const sectionTitle = (text: string) => (
  <span style={{ color: '#e2e8f0', fontSize: 14, fontWeight: 600 }}>{text}</span>
)
const renderCustomLabel = ({ percent }: { percent: number }) =>
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

  const topGenres = (data.top_genres || []).slice(0, 10).map((g: any) => ({
    ...g,
    label: g.genre?.length > 14 ? g.genre.slice(0, 14) + '\u2026' : (g.genre || '\u2014'),
  }))

  const genrePieData = (data.top_genres || []).slice(0, 8)
  const topCities = (data.top_cities || []).slice(0, 6)

  const kpiCards = [
    { label: 'Avg Match Similarity', value: `${data.avg_similarity_pct ?? 0}%`, bg: 'linear-gradient(135deg, #7c3aed, #5b21b6)', glow: '#7c3aed' },
    { label: 'Avg Tracks / User',    value: data.avg_tracks_per_user ?? 0,       bg: 'linear-gradient(135deg, #06b6d4, #0e7490)', glow: '#06b6d4' },
    { label: 'Genres Tracked',       value: (data.top_genres || []).length,      bg: 'linear-gradient(135deg, #10b981, #047857)', glow: '#10b981' },
    { label: 'Cities Represented',   value: (data.top_cities || []).length,      bg: 'linear-gradient(135deg, #f59e0b, #b45309)', glow: '#f59e0b' },
  ]

  return (
    <>
      {/* KPI row */}
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        {kpiCards.map((kpi, i) => (
          <Col span={6} key={i}>
            <div style={{
              background: kpi.bg, borderRadius: 16, padding: '18px 22px',
              boxShadow: `0 6px 20px ${kpi.glow}28`,
            }}>
              <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 12, marginBottom: 6 }}>{kpi.label}</div>
              <div style={{ color: '#fff', fontSize: 30, fontWeight: 800, lineHeight: 1 }}>{kpi.value}</div>
            </div>
          </Col>
        ))}
      </Row>

      {/* DAU line chart */}
      <Row gutter={[12, 12]} style={{ marginBottom: 12 }}>
        <Col span={24}>
          <Card title={sectionTitle('Daily Active Users \u2014 Last 30 Days')} style={cardStyle}
            bodyStyle={{ padding: '8px 16px 16px' }}>
            {dauData.length === 0 ? (
              <Empty description="No activity data yet" image={Empty.PRESENTED_IMAGE_SIMPLE}
                style={{ padding: '48px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={200}>
                <LineChart data={dauData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1a1a28" vertical={false} />
                  <XAxis dataKey="label" {...axisProps} interval="preserveStartEnd" />
                  <YAxis {...axisProps} allowDecimals={false} />
                  <Tooltip {...chartTooltip} formatter={(v: any) => [v, 'Active users']} />
                  <Line type="monotone" dataKey="active_users"
                    stroke="#7c3aed" strokeWidth={2.5} dot={false}
                    activeDot={{ r: 4, fill: '#7c3aed', strokeWidth: 0 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            )}
          </Card>
        </Col>
      </Row>

      {/* Bottom 3 charts */}
      <Row gutter={[12, 12]}>
        {/* Top Genres horizontal bar */}
        <Col span={10}>
          <Card title={sectionTitle('Top Genres by Preference')} style={cardStyle}
            bodyStyle={{ padding: '8px 16px 16px' }}>
            {topGenres.length === 0 ? (
              <Empty description="No genre data" image={Empty.PRESENTED_IMAGE_SIMPLE}
                style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <BarChart data={topGenres} layout="vertical" margin={{ left: 0, right: 24 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1a1a28" horizontal={false} />
                  <XAxis type="number" {...axisProps} allowDecimals={false} />
                  <YAxis dataKey="label" type="category" {...axisProps} width={100} />
                  <Tooltip {...chartTooltip} formatter={(v: any) => [Number(v).toFixed(1), 'Weight']} />
                  <Bar dataKey="weight" radius={[0, 6, 6, 0]} maxBarSize={16}>
                    {topGenres.map((_: any, i: number) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </Card>
        </Col>

        {/* Genre share donut */}
        <Col span={7}>
          <Card title={sectionTitle('Genre Share')} style={cardStyle}
            bodyStyle={{ padding: '8px 0 16px' }}>
            {genrePieData.length === 0 ? (
              <Empty description="No data" image={Empty.PRESENTED_IMAGE_SIMPLE}
                style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <PieChart>
                  <Pie
                    data={genrePieData} dataKey="weight" nameKey="genre"
                    cx="50%" cy="44%" outerRadius={90} innerRadius={42}
                    label={renderCustomLabel} labelLine={false}
                  >
                    {genrePieData.map((_: any, i: number) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip {...chartTooltip} formatter={(v: any) => [Number(v).toFixed(1), 'Weight']} />
                  <Legend
                    wrapperStyle={{ fontSize: 10, color: '#64748b', paddingTop: 4 }}
                    formatter={(v: any) => v?.length > 10 ? v.slice(0, 10) + '\u2026' : v}
                  />
                </PieChart>
              </ResponsiveContainer>
            )}
          </Card>
        </Col>

        {/* Top Cities */}
        <Col span={7}>
          <Card title={sectionTitle('Top Cities')} style={cardStyle}
            bodyStyle={{ padding: '8px 16px 16px' }}>
            {topCities.length === 0 ? (
              <Empty description="No city data" image={Empty.PRESENTED_IMAGE_SIMPLE}
                style={{ padding: '40px 0', color: '#475569' }} />
            ) : (
              <ResponsiveContainer width="100%" height={270}>
                <BarChart data={topCities} layout="vertical" margin={{ left: 0, right: 24 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1a1a28" horizontal={false} />
                  <XAxis type="number" {...axisProps} allowDecimals={false} />
                  <YAxis dataKey="city" type="category" {...axisProps} width={80} />
                  <Tooltip {...chartTooltip} formatter={(v: any) => [v, 'Users']} />
                  <Bar dataKey="count" radius={[0, 6, 6, 0]} maxBarSize={20}>
                    {topCities.map((_: any, i: number) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            )}
          </Card>
        </Col>
      </Row>
    </>
  )
}
