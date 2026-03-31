import { useEffect, useState } from 'react'
import { Row, Col, Card, Typography, Spin, Tag, Avatar, List } from 'antd'
import { UserOutlined, SoundOutlined, HeartOutlined, MessageOutlined, UnorderedListOutlined } from '@ant-design/icons'
import {
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, ResponsiveContainer, Legend, CartesianGrid,
} from 'recharts'
import { adminApi } from '../api/admin'

const C = {
  purple: '#7c3aed', cyan: '#06b6d4', green: '#10b981',
  orange: '#f59e0b', pink: '#ec4899', red: '#ef4444',
}
const PIE_COLORS = [C.purple, C.cyan, C.green, C.orange, C.pink, C.red, '#8b5cf6', '#14b8a6', '#f97316', '#3b82f6']
const ACTION_COLOR: Record<string, string> = {
  liked: C.green, completed: C.cyan, skipped: C.orange,
  skipped_early: C.red, replayed: C.purple, added_to_playlist: C.pink,
}

const STAT_CARDS = [
  { key: 'users',     label: 'Total Users',   icon: <UserOutlined />,           bg: `linear-gradient(135deg, ${C.purple}, #5b21b6)`, glow: C.purple },
  { key: 'tracks',    label: 'Cached Tracks', icon: <SoundOutlined />,          bg: `linear-gradient(135deg, ${C.cyan}, #0e7490)`,   glow: C.cyan },
  { key: 'playlists', label: 'Playlists',      icon: <UnorderedListOutlined />,  bg: `linear-gradient(135deg, ${C.green}, #047857)`,  glow: C.green },
  { key: 'matches',   label: 'Matches',        icon: <HeartOutlined />,          bg: `linear-gradient(135deg, ${C.pink}, #be185d)`,   glow: C.pink },
  { key: 'chats',     label: 'Active Chats',   icon: <MessageOutlined />,        bg: `linear-gradient(135deg, ${C.orange}, #b45309)`, glow: C.orange },
]

const chartTooltip = {
  contentStyle: { background: '#1a1a28', border: '1px solid #2a2a3e', borderRadius: 8, fontSize: 12 },
  labelStyle: { color: '#e2e8f0' },
}
const axisProps = {
  tick: { fontSize: 11, fill: '#94a3b8' },
  tickLine: false as const,
  axisLine: false as const,
}

export default function DashboardPage() {
  const [data, setData]     = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminApi.getStats().then(r => setData(r.data)).finally(() => setLoading(false))
  }, [])

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '80px auto' }} />
  if (!data) return null

  const cardStyle = { background: '#13131e', border: '1px solid #2a2a3e', borderRadius: 14 }

  return (
    <>
      {/* Stat cards */}
      <Row gutter={[14, 14]} style={{ marginBottom: 20 }}>
        {STAT_CARDS.map(card => (
          <Col xs={12} sm={8} xl={24 / STAT_CARDS.length} key={card.key}>
            <Card
              style={{ background: card.bg, border: 'none', borderRadius: 14, boxShadow: `0 8px 24px ${card.glow}33` }}
              bodyStyle={{ padding: '20px 22px' }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <Typography.Text style={{ color: 'rgba(255,255,255,0.65)', fontSize: 12, display: 'block', marginBottom: 6 }}>
                    {card.label}
                  </Typography.Text>
                  <Typography.Title level={2} style={{ color: '#fff', margin: 0, fontWeight: 700, lineHeight: 1 }}>
                    {(data.totals?.[card.key] ?? 0).toLocaleString()}
                  </Typography.Title>
                </div>
                <div style={{
                  width: 44, height: 44, borderRadius: 12,
                  background: 'rgba(255,255,255,0.18)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 20, color: '#fff',
                }}>
                  {card.icon}
                </div>
              </div>
            </Card>
          </Col>
        ))}
      </Row>

      <Row gutter={[14, 14]} style={{ marginBottom: 14 }}>
        {/* Registrations line chart */}
        <Col span={16}>
          <Card
            title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>New Registrations — Last 30 Days</span>}
            style={cardStyle}
            bodyStyle={{ padding: '12px 16px' }}
          >
            <ResponsiveContainer width="100%" height={210}>
              <LineChart data={data.registrations_per_day}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e1e2e" />
                <XAxis dataKey="date" {...axisProps} />
                <YAxis {...axisProps} />
                <Tooltip {...chartTooltip} />
                <Line type="monotone" dataKey="count" stroke={C.purple} strokeWidth={2.5} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </Card>
        </Col>

        {/* Mood pie */}
        <Col span={8}>
          <Card
            title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Mood Distribution</span>}
            style={cardStyle}
            bodyStyle={{ padding: '8px 4px' }}
          >
            <ResponsiveContainer width="100%" height={210}>
              <PieChart>
                <Pie data={data.mood_distribution} dataKey="value" nameKey="mood"
                  cx="50%" cy="50%" outerRadius={78} innerRadius={36}>
                  {data.mood_distribution.map((_: any, i: number) => (
                    <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip {...chartTooltip} />
                <Legend wrapperStyle={{ fontSize: 10, color: '#94a3b8' }} />
              </PieChart>
            </ResponsiveContainer>
          </Card>
        </Col>
      </Row>

      <Row gutter={[14, 14]}>
        {/* Top tracks bar */}
        <Col span={12}>
          <Card
            title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Top Tracks by Plays</span>}
            style={cardStyle}
            bodyStyle={{ padding: '12px 16px' }}
          >
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={data.top_tracks.slice(0, 8)} layout="vertical">
                <XAxis type="number" {...axisProps} />
                <YAxis dataKey="title" type="category" {...axisProps} width={110} />
                <Tooltip {...chartTooltip} />
                <Bar dataKey="play_count" fill={C.cyan} radius={[0, 6, 6, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </Card>
        </Col>

        {/* Recent events */}
        <Col span={12}>
          <Card
            title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Recent Events</span>}
            style={cardStyle}
            bodyStyle={{ padding: 0 }}
          >
            <List
              size="small"
              dataSource={data.recent_events}
              renderItem={(item: any) => (
                <List.Item style={{ padding: '10px 16px', borderColor: '#2a2a3e' }}>
                  <List.Item.Meta
                    avatar={
                      <Avatar size={30} style={{ background: 'linear-gradient(135deg, #7c3aed, #06b6d4)', fontSize: 11, flexShrink: 0 }}>
                        {item.username?.[0]?.toUpperCase() || '?'}
                      </Avatar>
                    }
                    title={<span style={{ fontSize: 12, color: '#e2e8f0' }}><b>{item.username}</b> · {item.track_title}</span>}
                    description={<span style={{ fontSize: 11, color: '#94a3b8' }}>{item.created_at ? new Date(item.created_at).toLocaleString() : '—'}</span>}
                  />
                  <Tag
                    style={{
                      background: `${ACTION_COLOR[item.action] || '#64748b'}22`,
                      border: `1px solid ${ACTION_COLOR[item.action] || '#64748b'}55`,
                      color: ACTION_COLOR[item.action] || '#94a3b8',
                      fontSize: 10, borderRadius: 6,
                    }}
                  >
                    {item.action}
                  </Tag>
                </List.Item>
              )}
            />
          </Card>
        </Col>
      </Row>
    </>
  )
}
