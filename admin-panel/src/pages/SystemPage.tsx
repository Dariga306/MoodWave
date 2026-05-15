import { useEffect, useState } from 'react'
import { Row, Col, Button, Typography, Spin, Popconfirm, message, List, Tag, Badge } from 'antd'
import { ClearOutlined, ReloadOutlined, DatabaseOutlined, ThunderboltOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
  played: '#94a3b8', disliked: '#ef4444',
}

const card = { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 16, overflow: 'hidden' as const }

const GROUPS: Record<string, string[]> = {
  'Users':  ['users', 'user_genres', 'user_moods', 'taste_vectors'],
  'Music':  ['tracks_cache', 'listening_history', 'playlists', 'playlist_tracks'],
  'Social': ['matches', 'match_decisions', 'friends', 'blocks', 'reports'],
  'Comms':  ['chats', 'listening_rooms', 'room_participants'],
}

const GROUP_COLORS: Record<string, string> = {
  'Users': '#7c3aed', 'Music': '#06b6d4', 'Social': '#ec4899', 'Comms': '#10b981',
}

export default function SystemPage() {
  const [data, setData]         = useState<any>(null)
  const [loading, setLoading]   = useState(true)
  const [clearing, setClearing] = useState(false)

  const fetchSystem = async () => {
    setLoading(true)
    try { const r = await adminApi.getSystem(); setData(r.data) }
    finally { setLoading(false) }
  }

  useEffect(() => { fetchSystem() }, [])

  const clearCache = async () => {
    setClearing(true)
    try {
      const r = await adminApi.clearCache()
      message.success(r.data.detail)
      fetchSystem()
    } finally { setClearing(false) }
  }

  if (loading) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <Spin size="large" />
    </div>
  )
  if (!data) return null

  const tableRows = Object.entries(data.table_counts as Record<string, number>)
    .map(([table, count]) => ({ table, count }))
    .sort((a, b) => b.count - a.count)

  return (
    <>
      {/* Top stat cards + actions */}
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        <Col span={5}>
          <div style={{
            background: 'linear-gradient(135deg, #7c3aed, #5b21b6)',
            borderRadius: 16, padding: '20px 22px',
            boxShadow: '0 8px 24px rgba(124,58,237,0.3)',
            display: 'flex', alignItems: 'center', gap: 14,
            position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', top: -15, right: -15, width: 70, height: 70, borderRadius: '50%', background: 'rgba(255,255,255,0.08)' }} />
            <div style={{ width: 46, height: 46, borderRadius: 14, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, color: '#fff' }}>
              <ThunderboltOutlined />
            </div>
            <div>
              <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 12, marginBottom: 4, fontWeight: 500 }}>Redis Keys</div>
              <div style={{ color: '#fff', fontSize: 28, fontWeight: 800, lineHeight: 1, letterSpacing: '-0.5px' }}>
                {data.redis_track_cache_count}
              </div>
            </div>
          </div>
        </Col>

        <Col span={5}>
          <div style={{
            background: 'linear-gradient(135deg, #10b981, #047857)',
            borderRadius: 16, padding: '20px 22px',
            boxShadow: '0 8px 24px rgba(16,185,129,0.3)',
            display: 'flex', alignItems: 'center', gap: 14,
            position: 'relative', overflow: 'hidden',
          }}>
            <div style={{ position: 'absolute', top: -15, right: -15, width: 70, height: 70, borderRadius: '50%', background: 'rgba(255,255,255,0.08)' }} />
            <div style={{ width: 46, height: 46, borderRadius: 14, background: 'rgba(255,255,255,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, color: '#fff' }}>
              <DatabaseOutlined />
            </div>
            <div>
              <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 12, marginBottom: 4, fontWeight: 500 }}>DB Tables</div>
              <div style={{ color: '#fff', fontSize: 28, fontWeight: 800, lineHeight: 1, letterSpacing: '-0.5px' }}>
                {tableRows.length}
              </div>
            </div>
          </div>
        </Col>

        <Col span={14} style={{ display: 'flex', alignItems: 'center', gap: 10, paddingLeft: 12 }}>
          <Popconfirm
            title="Clear all Redis caches?"
            description="Removes cached searches, recommendations, sessions and taste vectors."
            onConfirm={clearCache} okType="danger" okText="Clear"
          >
            <Button danger icon={<ClearOutlined />} loading={clearing} style={{ height: 40, borderRadius: 10, fontWeight: 600 }}>
              Clear All Cache
            </Button>
          </Popconfirm>
          <Button icon={<ReloadOutlined />} onClick={fetchSystem}
            style={{ height: 40, borderRadius: 10, background: '#161623', border: '1px solid rgba(255,255,255,0.1)', color: '#e2e8f0' }}>
            Refresh
          </Button>
          <Typography.Text style={{ color: '#334155', fontSize: 12, marginLeft: 4 }}>
            Updated: {new Date().toLocaleTimeString()}
          </Typography.Text>
        </Col>
      </Row>

      {/* Table counts + Recent events */}
      <Row gutter={[12, 12]}>
        <Col span={9}>
          <div style={card}>
            <div style={{ padding: '14px 18px 10px', borderBottom: '1px solid rgba(255,255,255,0.05)', fontSize: 13, fontWeight: 600, color: '#e2e8f0' }}>
              Database Table Counts
            </div>
            {Object.entries(GROUPS).map(([group, tables]) => (
              <div key={group}>
                <div style={{
                  padding: '8px 18px 4px',
                  color: GROUP_COLORS[group] || '#475569',
                  fontSize: 10, letterSpacing: 1.5,
                  textTransform: 'uppercase' as const,
                  borderTop: '1px solid rgba(255,255,255,0.04)',
                  fontWeight: 600,
                }}>
                  {group}
                </div>
                {tables.map(tbl => {
                  const count = data.table_counts?.[tbl] ?? -1
                  return (
                    <div key={tbl} style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      padding: '7px 18px',
                    }}>
                      <span style={{ color: '#64748b', fontSize: 12, fontFamily: 'monospace' }}>{tbl}</span>
                      <Badge
                        count={count >= 0 ? count.toLocaleString() : 'err'}
                        showZero
                        style={{
                          background: count > 0 ? 'rgba(124,58,237,0.2)' : 'rgba(255,255,255,0.05)',
                          color: count > 0 ? '#a78bfa' : '#334155',
                          border: 'none', fontSize: 11, boxShadow: 'none',
                        }}
                      />
                    </div>
                  )
                })}
              </div>
            ))}
          </div>
        </Col>

        <Col span={15}>
          <div style={{ ...card, height: '100%' }}>
            <div style={{ padding: '14px 18px 10px', borderBottom: '1px solid rgba(255,255,255,0.05)', fontSize: 13, fontWeight: 600, color: '#e2e8f0' }}>
              Recent Activity
              <span style={{ color: '#334155', fontSize: 11, fontWeight: 400, marginLeft: 8 }}>last 20 events</span>
            </div>
            <div style={{ maxHeight: 500, overflowY: 'auto' }}>
              <List size="small" dataSource={data.recent_events || []}
                renderItem={(item: any) => (
                  <List.Item style={{ padding: '9px 18px', borderColor: 'rgba(255,255,255,0.04)' }}>
                    <List.Item.Meta
                      title={
                        <span style={{ fontSize: 12, color: '#e2e8f0' }}>
                          <b style={{ fontWeight: 600, color: '#a78bfa' }}>@{item.username}</b>
                          <span style={{ color: '#334155', fontWeight: 400 }}> · {item.track_title || '—'}</span>
                        </span>
                      }
                      description={
                        <span style={{ fontSize: 11, color: '#334155' }}>
                          {item.created_at
                            ? new Date(item.created_at).toLocaleString('en', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
                            : '—'}
                        </span>
                      }
                    />
                    <Tag style={{
                      background: `${ACTION_COLOR[item.action] || '#64748b'}1a`,
                      border: `1px solid ${ACTION_COLOR[item.action] || '#64748b'}40`,
                      color: ACTION_COLOR[item.action] || '#64748b',
                      fontSize: 10, borderRadius: 6,
                    }}>
                      {item.action}
                    </Tag>
                  </List.Item>
                )}
              />
            </div>
          </div>
        </Col>
      </Row>
    </>
  )
}
