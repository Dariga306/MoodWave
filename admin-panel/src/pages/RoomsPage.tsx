import { useEffect, useState } from 'react'
import { Table, Button, Tag, Typography, Space, Popconfirm, message, Avatar, Badge } from 'antd'
import { DeleteOutlined, ReloadOutlined, LockOutlined, GlobalOutlined, CustomerServiceOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

export default function RoomsPage() {
  const [rooms, setRooms]     = useState<any[]>([])
  const [loading, setLoading] = useState(false)

  const fetchRooms = async () => {
    setLoading(true)
    try {
      const res = await adminApi.getRooms()
      setRooms(res.data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchRooms() }, [])

  const closeRoom = async (id: number) => {
    await adminApi.closeRoom(id)
    message.success('Room closed')
    fetchRooms()
  }

  const activeCount = rooms.filter(r => r.is_active).length

  const columns = [
    {
      title: '#', dataIndex: 'id', key: 'id', width: 55,
      render: (v: number) => <span style={{ color: '#64748b', fontSize: 12 }}>#{v}</span>,
    },
    {
      title: 'Room', key: 'room',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 36, height: 36, borderRadius: 8, flexShrink: 0,
            background: r.is_active
              ? 'linear-gradient(135deg, #7c3aed, #06b6d4)'
              : '#1a1a28',
            border: r.is_active ? 'none' : '1px solid #2a2a3e',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 16,
          }}>
            <CustomerServiceOutlined />
          </div>
          <div>
            <div style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>
              {r.name || `Room #${r.id}`}
            </div>
            <div style={{ color: '#94a3b8', fontSize: 11 }}>host: @{r.host_username}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Status', key: 'status', width: 100,
      render: (_: any, r: any) => r.is_active
        ? <Badge status="processing" text={<span style={{ color: '#10b981', fontSize: 12 }}>Live</span>} />
        : <Badge status="default" text={<span style={{ color: '#475569', fontSize: 12 }}>Closed</span>} />,
    },
    {
      title: 'Type', key: 'visibility', width: 95,
      render: (_: any, r: any) => r.is_public
        ? (
          <Tag icon={<GlobalOutlined />}
            style={{ background: '#10b98122', border: '1px solid #10b98166', color: '#10b981', borderRadius: 6, fontSize: 11 }}>
            Public
          </Tag>
        ) : (
          <Tag icon={<LockOutlined />}
            style={{ background: '#7c3aed22', border: '1px solid #7c3aed66', color: '#7c3aed', borderRadius: 6, fontSize: 11 }}>
            Private
          </Tag>
        ),
    },
    {
      title: 'Now Playing', key: 'track',
      render: (_: any, r: any) => r.track_title
        ? (
          <span style={{ color: '#e2e8f0', fontSize: 12 }}>
            🎵 {r.track_title}
            {r.track_artist && <span style={{ color: '#94a3b8' }}> — {r.track_artist}</span>}
          </span>
        )
        : <span style={{ color: '#475569', fontSize: 12 }}>—</span>,
    },
    {
      title: 'Guests', key: 'guests', width: 80,
      render: (_: any, r: any) => (
        <span style={{ color: '#e2e8f0', fontSize: 13, fontWeight: 600 }}>
          {r.participant_count}
          <span style={{ color: '#64748b', fontWeight: 400 }}> / {r.max_guests}</span>
        </span>
      ),
    },
    {
      title: 'Created', dataIndex: 'created_at', key: 'created_at', width: 100,
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 90,
      render: (_: any, r: any) => r.is_active ? (
        <Popconfirm
          title="Force close this room?"
          description="All connected guests will be disconnected."
          onConfirm={() => closeRoom(r.id)} okType="danger" okText="Close"
        >
          <Button size="small" danger icon={<DeleteOutlined />}>Close</Button>
        </Popconfirm>
      ) : null,
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={12}>
        <Badge count={activeCount} showZero color="#10b981">
          <Typography.Text style={{ color: '#94a3b8', fontSize: 13, paddingRight: 4 }}>Active rooms</Typography.Text>
        </Badge>
        <Typography.Text style={{ color: '#475569', fontSize: 12 }}>· {rooms.length} total</Typography.Text>
        <Button size="small" icon={<ReloadOutlined />} onClick={fetchRooms}
          style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#94a3b8' }}>
          Refresh
        </Button>
      </Space>

      {rooms.length === 0 && !loading ? (
        <div style={{ textAlign: 'center', padding: '80px 0' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>🎧</div>
          <Typography.Title level={5} style={{ color: '#475569' }}>No rooms yet</Typography.Title>
          <Typography.Text style={{ color: '#334155', fontSize: 12 }}>Rooms will appear here when users create listening sessions</Typography.Text>
        </div>
      ) : (
        <Table
          dataSource={rooms} columns={columns} rowKey="id" loading={loading}
          size="small" pagination={{ pageSize: 20, showSizeChanger: false }}
          style={{ borderRadius: 14, overflow: 'hidden' }}
          rowClassName={(r: any) => r.is_active ? '' : 'dim-row'}
        />
      )}
    </>
  )
}
