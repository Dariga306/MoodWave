import { useEffect, useState } from 'react'
import { Row, Col, Card, Table, Button, Typography, Spin, Popconfirm, message, List, Tag } from 'antd'
import { ClearOutlined, ReloadOutlined, DatabaseOutlined, ThunderboltOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
}

const cardStyle = { background: '#13131e', border: '1px solid #2a2a3e', borderRadius: 14 }

export default function SystemPage() {
  const [data, setData]       = useState<any>(null)
  const [loading, setLoading] = useState(true)
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

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '80px auto' }} />
  if (!data) return null

  const tableCountData = Object.entries(data.table_counts).map(([table, count]) => ({ table, count: count as number }))

  return (
    <>
      <Row gutter={[14, 14]} style={{ marginBottom: 20 }}>
        {/* Redis card */}
        <Col span={6}>
          <Card style={{ ...cardStyle, background: 'linear-gradient(135deg, #1a1a28, #13131e)' }} bodyStyle={{ padding: '20px 22px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 10, background: 'linear-gradient(135deg, #7c3aed, #5b21b6)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: 20 }}>
                <ThunderboltOutlined />
              </div>
              <div>
                <Typography.Text style={{ color: '#94a3b8', fontSize: 12, display: 'block' }}>Redis Cache Keys</Typography.Text>
                <Typography.Title level={3} style={{ color: '#e2e8f0', margin: 0, fontWeight: 700 }}>{data.redis_track_cache_count}</Typography.Title>
              </div>
            </div>
          </Card>
        </Col>

        {/* Tables card */}
        <Col span={6}>
          <Card style={cardStyle} bodyStyle={{ padding: '20px 22px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 10, background: 'linear-gradient(135deg, #10b981, #047857)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: 20 }}>
                <DatabaseOutlined />
              </div>
              <div>
                <Typography.Text style={{ color: '#94a3b8', fontSize: 12, display: 'block' }}>Tables Monitored</Typography.Text>
                <Typography.Title level={3} style={{ color: '#e2e8f0', margin: 0, fontWeight: 700 }}>{tableCountData.length}</Typography.Title>
              </div>
            </div>
          </Card>
        </Col>

        {/* Actions */}
        <Col span={12} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Popconfirm
            title="Clear all Redis caches?"
            description="Removes cached tracks, recommendations, sessions and taste vectors."
            onConfirm={clearCache} okType="danger" okText="Clear All"
          >
            <Button danger icon={<ClearOutlined />} loading={clearing} size="large" style={{ height: 44 }}>
              Clear All Cache
            </Button>
          </Popconfirm>
          <Button icon={<ReloadOutlined />} onClick={fetchSystem} size="large"
            style={{ height: 44, background: '#1a1a28', border: '1px solid #2a2a3e', color: '#e2e8f0' }}>
            Refresh
          </Button>
        </Col>
      </Row>

      <Row gutter={[14, 14]}>
        {/* Table counts */}
        <Col span={8}>
          <Card title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Table Row Counts</span>} style={cardStyle}>
            <Table
              dataSource={tableCountData}
              columns={[
                {
                  title: 'Table', dataIndex: 'table', key: 'table',
                  render: (v: string) => <span style={{ color: '#94a3b8', fontSize: 12, fontFamily: 'monospace' }}>{v}</span>,
                },
                {
                  title: 'Rows', dataIndex: 'count', key: 'count', align: 'right' as const,
                  render: (v: number) => (
                    <Tag style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#e2e8f0', borderRadius: 6, fontSize: 11 }}>
                      {v >= 0 ? v.toLocaleString() : 'err'}
                    </Tag>
                  ),
                },
              ]}
              rowKey="table" size="small" pagination={false}
            />
          </Card>
        </Col>

        {/* Recent events */}
        <Col span={16}>
          <Card title={<span style={{ color: '#e2e8f0', fontSize: 14 }}>Recent Activity (last 20)</span>}
            style={cardStyle} bodyStyle={{ padding: 0 }}>
            <List
              size="small"
              dataSource={data.recent_events}
              renderItem={(item: any) => (
                <List.Item style={{ padding: '10px 16px', borderColor: '#2a2a3e' }}>
                  <List.Item.Meta
                    title={<span style={{ fontSize: 12, color: '#e2e8f0' }}><b>@{item.username}</b> · {item.track_title}</span>}
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
