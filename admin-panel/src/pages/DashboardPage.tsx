import { useEffect, useState } from 'react'
import { Row, Col, Spin, Tag, Avatar, List, Empty } from 'antd'
import {
  UserOutlined, SoundOutlined, HeartOutlined,
  MessageOutlined, UnorderedListOutlined,
} from '@ant-design/icons'
import {
  AreaChart, Area, BarChart, Bar,
  XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'
import { adminApi } from '../api/admin'

const C = {
  purple: '#7c3aed', cyan: '#06b6d4', green: '#10b981',
  orange: '#f59e0b', pink: '#ec4899',
}

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
  played: '#94a3b8', disliked: '#ef4444',
}
const ACTION_LABEL: Record<string, string> = {
  liked: 'Liked', completed: 'Completed', skipped: 'Skipped',
  skipped_early: 'Skipped early', replayed: 'Replayed',
  added_to_playlist: 'Added', played: 'Played', disliked: 'Disliked',
}

const STAT_CARDS = [
  { key: 'users',     label: 'Total Users',   icon: <UserOutlined />,          from: '#7c3aed', to: '#5b21b6', glow: '#7c3aed' },
  { key: 'tracks',    label: 'Cached Tracks', icon: <SoundOutlined />,         from: '#06b6d4', to: '#0e7490', glow: '#06b6d4' },
  { key: 'playlists', label: 'Playlists',     icon: <UnorderedListOutlined />, from: '#10b981', to: '#047857', glow: '#10b981' },
  { key: 'matches',   label: 'Matches Made',  icon: <HeartOutlined />,         from: '#ec4899', to: '#be185d', glow: '#ec4899' },
  { key: 'chats',     label: 'Active Chats',  icon: <MessageOutlined />,       from: '#f59e0b', to: '#b45309', glow: '#f59e0b' },
]

const card = {
  background: '#0f0f1c',
  border: '1px solid rgba(255,255,255,0.07)',
  borderRadius: 16,
  overflow: 'hidden' as const,
}

const cardHead = (title: string) => (
  <div style={{
    padding: '14px 18px 10px',
    borderBottom: '1px solid rgba(255,255,255,0.06)',
    fontSize: 13, fontWeight: 600, color: '#e2e8f0',
  }}>
    {title}
  </div>
)

const tooltipStyle = {
  contentStyle: { background: '#161623', border: '1px solid rgba(124,58,237,0.3)', borderRadius: 10, fontSize: 12, padding: '8px 12px' },
  labelStyle:   { color: '#e2e8f0', fontWeight: 600 },
  itemStyle:    { color: '#94a3b8' },
}

const axisProps = {
  tick:     { fontSize: 11, fill: '#475569' },
  tickLine: false as const,
  axisLine: false as const,
}

export default function DashboardPage() {
  const [data, setData]       = useState<any>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    adminApi.getStats().then(r => setData(r.data)).finally(() => setLoading(false))
  }, [])

  if (loading) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <Spin size="large" />
    </div>
  )
  if (!data) return null

  const regData = (data.registrations_per_day || []).map((d: any) => ({
    ...d,
    label: new Date(d.date).toLocaleDateString('en', { month: 'short', day: 'numeric' }),
  }))

  const topTracks = (data.top_tracks || []).slice(0, 6).map((t: any) => ({
    ...t,
    label: t.title?.length > 22 ? t.title.slice(0, 22) + '…' : (t.title || '—'),
  }))

  return (
    <>
      {/* ── Stat Cards ─────────────────────────────────────────────── */}
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        {STAT_CARDS.map(s => (
          <Col xs={12} sm={8} xl={Math.floor(24 / STAT_CARDS.length)} key={s.key}>
            <div style={{
              background: `linear-gradient(135deg, ${s.from}, ${s.to})`,
              borderRadius: 16, padding: '20px 22px',
              boxShadow: `0 8px 24px ${s.glow}30`,
              display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              position: 'relative', overflow: 'hidden',
            }}>
              <div style={{
                position: 'absolute', top: -20, right: -20,
                width: 90, height: 90, borderRadius: '50%',
                background: 'rgba(255,255,255,0.07)',
              }} />
              <div>
                <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 12, marginBottom: 6, fontWeight: 500 }}>
                  {s.label}
                </div>
                <div style={{ color: '#fff', fontSize: 30, fontWeight: 800, lineHeight: 1, letterSpacing: '-0.5px' }}>
                  {(data.totals?.[s.key] ?? 0).toLocaleString()}
                </div>
              </div>
              <div style={{
                width: 46, height: 46, borderRadius: 14,
                background: 'rgba(255,255,255,0.18)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 20, color: '#fff', flexShrink: 0,
              }}>
                {s.icon}
              </div>
            </div>
          </Col>
        ))}
      </Row>

      {/* ── Registration trend + Recent events ─────────────────────── */}
      <Row gutter={[12, 12]} style={{ marginBottom: 12 }}>
        <Col span={15}>
          <div style={card}>
            {cardHead('Registrations — Last 30 Days')}
            <div style={{ padding: '8px 16px 16px' }}>
              {regData.length === 0 ? (
                <Empty description="No data yet" image={Empty.PRESENTED_IMAGE_SIMPLE}
                  style={{ padding: '48px 0', color: '#475569' }} />
              ) : (
                <ResponsiveContainer width="100%" height={220}>
                  <AreaChart data={regData}>
                    <defs>
                      <linearGradient id="regGrad" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%"  stopColor="#7c3aed" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="#7c3aed" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
                    <XAxis dataKey="label" {...axisProps} interval="preserveStartEnd" />
                    <YAxis {...axisProps} allowDecimals={false} />
                    <Tooltip {...tooltipStyle} formatter={(v: any) => [v, 'Registrations']} />
                    <Area type="monotone" dataKey="count"
                      stroke="#7c3aed" strokeWidth={2.5}
                      fill="url(#regGrad)" dot={false}
                      activeDot={{ r: 4, fill: '#a855f7', strokeWidth: 0 }}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )}
            </div>
          </div>
        </Col>

        <Col span={9}>
          <div style={{ ...card, height: '100%', display: 'flex', flexDirection: 'column' }}>
            {cardHead('Recent Activity')}
            <div style={{ flex: 1, maxHeight: 280, overflowY: 'auto' }}>
              {(data.recent_events || []).length === 0 ? (
                <Empty description="No events yet" image={Empty.PRESENTED_IMAGE_SIMPLE}
                  style={{ padding: '48px 0', color: '#475569' }} />
              ) : (
                <List size="small" dataSource={data.recent_events}
                  renderItem={(item: any) => (
                    <List.Item style={{ padding: '9px 16px', borderColor: 'rgba(255,255,255,0.04)' }}>
                      <List.Item.Meta
                        avatar={
                          <Avatar size={28} style={{
                            background: 'linear-gradient(135deg, #7c3aed, #06b6d4)',
                            fontSize: 11, flexShrink: 0,
                          }}>
                            {item.username?.[0]?.toUpperCase() || '?'}
                          </Avatar>
                        }
                        title={
                          <span style={{ fontSize: 12, color: '#e2e8f0' }}>
                            <b style={{ fontWeight: 600 }}>{item.username}</b>
                            <span style={{ color: '#475569', fontWeight: 400 }}> · {item.track_title || '—'}</span>
                          </span>
                        }
                        description={
                          <span style={{ fontSize: 10, color: '#334155' }}>
                            {item.created_at
                              ? new Date(item.created_at).toLocaleString('en', {
                                  month: 'short', day: 'numeric',
                                  hour: '2-digit', minute: '2-digit',
                                })
                              : '—'}
                          </span>
                        }
                      />
                      <Tag style={{
                        background: `${ACTION_COLOR[item.action] || '#64748b'}1a`,
                        border: `1px solid ${ACTION_COLOR[item.action] || '#64748b'}40`,
                        color: ACTION_COLOR[item.action] || '#64748b',
                        fontSize: 10, borderRadius: 6, padding: '1px 6px', flexShrink: 0,
                      }}>
                        {ACTION_LABEL[item.action] || item.action}
                      </Tag>
                    </List.Item>
                  )}
                />
              )}
            </div>
          </div>
        </Col>
      </Row>

      {/* ── Top Tracks ─────────────────────────────────────────────── */}
      <div style={card}>
        {cardHead('Top Tracks by Plays')}
        <div style={{ padding: '8px 16px 16px' }}>
          {topTracks.length === 0 ? (
            <Empty description="No tracks played yet" image={Empty.PRESENTED_IMAGE_SIMPLE}
              style={{ padding: '32px 0', color: '#475569' }} />
          ) : (
            <ResponsiveContainer width="100%" height={186}>
              <BarChart data={topTracks} layout="vertical" margin={{ left: 0, right: 30 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" horizontal={false} />
                <XAxis type="number" {...axisProps} allowDecimals={false} />
                <YAxis dataKey="label" type="category" {...axisProps} width={145} />
                <Tooltip {...tooltipStyle}
                  formatter={(v: any, _: any, p: any) => [
                    `${v} plays`,
                    p.payload?.artist ? `${p.payload.title} — ${p.payload.artist}` : p.payload?.title,
                  ]}
                />
                <Bar dataKey="play_count" fill="#06b6d4" radius={[0, 6, 6, 0]} maxBarSize={14} />
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>
      </div>
    </>
  )
}
