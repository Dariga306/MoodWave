import { useEffect, useState } from 'react'
import { Row, Col, Card, Table, Button, Typography, Spin, Popconfirm, message, List, Tag, Badge } from 'antd'
import { ClearOutlined, ReloadOutlined, DatabaseOutlined, ThunderboltOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
  played: '#94a3b8', disliked: '#ef4444',
}

const cardStyle = { background: '#13131e', border: '1px solid #1e1e30', borderRadius: 16 }
const sectionTitle = (text: string) => (
  <span style={{ color: '#e2e8f0', fontSize: 14, fontWeight: 600 }}>{text}</span>
)

export default function SystemPage() {
  const [data, setData]         = useState<any>(null)
  const [loading, setLoading]   = useState(true)
  const [clearing, setClearing] = useState(false)

  const fetchSystem = async () => {
    setLoading(true)
    try {
      const res = await adminApi.getSystem()
      setData(res.data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchSystem() }, [])

  const clearCache = async () => {
    setClearing(true)
    try {
      const res = await adminApi.clearCache()
      message.success(res.data.detail)
      fetchSystem()
    } finally {
      setClearing(false)
    }
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

  // Group tables for display
  const GROUPS: Record<string, string[]> = {
    'Users':   ['users', 'user_genres', 'user_moods', 'taste_vectors'],
    'Music':   ['tracks_cache', 'listening_history', 'playlists', 'playlist_tracks'],
    'Social':  ['matches', 'match_decisions', 'friends', 'blocks', 'reports'],
    'Comms':   ['chats', 'listening_rooms', 'room_participants'],
  }

  return (
    <>
      {/* ── Top row: Redis info + actions ──────────────────────────── */}
      <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
        <Col span={5}>
          <div style={{
            background: 'linear-gradient(135deg, #7c3aed, #5b21b6)',
            borderRadius: 16, padding: '18px 20px',
            boxShadow: '0 6px 20px #7c3aed28',
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: 'rgba(255,255,255,0.18)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 22, color: '#fff',
            }}>
              <ThunderboltOutlined />
            </div>
            <div>
              <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 12, marginBottom: 4 }}>Redis Keys</div>
              <div style={{ color: '#fff', fontSize: 26, fontWeight: 800, lineHeight: 1 }}>
                {data.redis_track_cache_count}
              </div>
            </div>
          </div>
        </Col>

        <Col span={5}>
          <div style={{
            background: 'linear-gradient(135deg, #10b981, #047857)',
            borderRadius: 16, padding: '18px 20px',
            boxShadow: '0 6px 20px #10b98128',
            display: 'flex', alignItems: 'center', gap: 14,
          }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12,
              background: 'rgba(255,255,255,0.18)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 22, color: '#fff',
            }}>
              <DatabaseOutlined />
            </div>
            <div>
              <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 12, marginBottom: 4 }}>DB Tables</div>
              <div style={{ color: '#fff', fontSize: 26, fontWeight: 800, lineHeight: 1 }}>
                {tableRows.length}
              </div>
            </div>
          </div>
        </Col>

        <Col span={14} style={{ display: 'flex', alignItems: 'center', gap: 10, paddingLeft: 8 }}>
          <Popconfirm
            title="Clear all Redis caches?"
            description="Removes cached searches, recommendations, sessions and taste vectors."
            onConfirm={clearCache} okType="danger" okText="Clear"
          >
            <Button danger icon={<ClearOutlined />} loading={clearing} size="middle" style={{ height: 38 }}>
              Clear All Cache
            </Button>
          </Popconfirm>
          <Button icon={<ReloadOutlined />} onClick={fetchSystem} size="middle"
            style={{ height: 38, background: '#1a1a28', border: '1px solid #2a2a3e', color: '#e2e8f0' }}>
            Refresh
          </Button>
          <Typography.Text style={{ color: '#475569', fontSize: 12, marginLeft: 4 }}>
            Last updated: {new Date().toLocaleTimeString()}
          </Typography.Text>
        </Col>
      </Row>

      {/* ── Table counts + Recent events ───────────────────────────── */}
      <Row gutter={[12, 12]}>
        <Col span={9}>
          <Card title={sectionTitle('Database Table Counts')} style={cardStyle}
            bodyStyle={{ padding: 0 }}>
            {Object.entries(GROUPS).map(([group, tables]) => (
              <div key={group}>
                <div style={{
                  padding: '8px 16px 4px',
                  color: '#475569', fontSize: 10,
                  letterSpacing: 1.2, textTransform: 'uppercase' as const,
                  borderTop: '1px solid #1a1a28',
                }}>
                  {group}
                </div>
                {tables.map(tbl => {
                  const count = data.table_counts?.[tbl] ?? -1
                  return (
                    <div key={tbl} style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      padding: '7px 16px',
                    }}>
                      <span style={{ color: '#94a3b8', fontSize: 12, fontFamily: 'monospace' }}>
                        {tbl}
                      </span>
                      <Badge
                        count={count >= 0 ? count.toLocaleString() : 'err'}
                        showZero
                        style={{
                          background: count > 0 ? '#2a1a5e' : '#1a1a28',
                          color: count > 0 ? '#a78bfa' : '#475569',
                          border: 'none', fontSize: 11,
                          boxShadow: 'none',
                        }}
                      />
                    </div>
                  )
                })}
              </div>
            ))}
          </Card>
        </Col>

        <Col span={15}>
          <Card title={sectionTitle('Recent Activity (last 20 events)')} style={cardStyle}
            bodyStyle={{ padding: 0, maxHeight: 520, overflowY: 'auto' }}>
            <List
              size="small"
              dataSource={data.recent_events || []}
              renderItem={(item: any) => (
                <List.Item style={{ padding: '9px 16px', borderColor: '#1a1a28' }}>
                  <List.Item.Meta
                    title={
                      <span style={{ fontSize: 12, color: '#e2e8f0' }}>
                        <b style={{ fontWeight: 600, color: '#a78bfa' }}>@{item.username}</b>
                        <span style={{ color: '#64748b', fontWeight: 400 }}> · {item.track_title || '—'}</span>
                      </span>
                    }
                    description={
                      <span style={{ fontSize: 11, color: '#475569' }}>
                        {item.created_at
                          ? new Date(item.created_at).toLocaleString('en', {
                              month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
                            })
                          : '—'}
                      </span>
                    }
                  />
                  <Tag style={{
                    background: `${ACTION_COLOR[item.action] || '#64748b'}18`,
                    border: `1px solid ${ACTION_COLOR[item.action] || '#64748b'}40`,
                    color: ACTION_COLOR[item.action] || '#64748b',
                    fontSize: 10, borderRadius: 6,
                  }}>
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
