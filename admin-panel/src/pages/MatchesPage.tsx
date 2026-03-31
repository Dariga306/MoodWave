import { useEffect, useState } from 'react'
import { Table, Button, Select, Popconfirm, message, Tag, Progress, Typography, Space, Avatar } from 'antd'
import { DeleteOutlined, HeartFilled } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const { Option } = Select

const simColor = (v: number) => v >= 95 ? '#10b981' : v >= 85 ? '#7c3aed' : '#f59e0b'
const simLabel = (v: number) => v >= 95 ? 'Perfect' : v >= 85 ? 'Great' : 'Good'

export default function MatchesPage() {
  const [matches, setMatches]   = useState<any[]>([])
  const [loading, setLoading]   = useState(false)
  const [simRange, setSimRange] = useState<string>('all')

  const rangeMap: Record<string, { sim_min?: number; sim_max?: number }> = {
    all:  {},
    low:  { sim_min: 75, sim_max: 84 },
    mid:  { sim_min: 85, sim_max: 94 },
    high: { sim_min: 95, sim_max: 100 },
  }

  const fetchMatches = async (range = simRange) => {
    setLoading(true)
    try {
      const res = await adminApi.getMatches(rangeMap[range])
      setMatches(res.data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchMatches() }, [])

  const deleteMatch = async (id: number) => {
    await adminApi.deleteMatch(id)
    message.success('Match deleted')
    fetchMatches()
  }

  const columns = [
    {
      title: '#', dataIndex: 'id', key: 'id', width: 55,
      render: (v: number) => <span style={{ color: '#64748b', fontSize: 12 }}>#{v}</span>,
    },
    {
      title: 'User A', dataIndex: 'user_a', key: 'user_a',
      render: (v: string) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Avatar size={28} style={{ background: 'linear-gradient(135deg, #7c3aed, #5b21b6)', fontSize: 11, flexShrink: 0 }}>
            {v?.[0]?.toUpperCase()}
          </Avatar>
          <span style={{ color: '#e2e8f0', fontSize: 13 }}>@{v}</span>
        </div>
      ),
    },
    {
      title: '', key: 'heart', width: 36,
      render: () => <HeartFilled style={{ color: '#ec4899', fontSize: 16 }} />,
    },
    {
      title: 'User B', dataIndex: 'user_b', key: 'user_b',
      render: (v: string) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Avatar size={28} style={{ background: 'linear-gradient(135deg, #06b6d4, #0e7490)', fontSize: 11, flexShrink: 0 }}>
            {v?.[0]?.toUpperCase()}
          </Avatar>
          <span style={{ color: '#e2e8f0', fontSize: 13 }}>@{v}</span>
        </div>
      ),
    },
    {
      title: 'Compatibility', dataIndex: 'similarity_pct', key: 'similarity_pct', width: 220,
      sorter: (a: any, b: any) => a.similarity_pct - b.similarity_pct,
      render: (v: number) => {
        const color = simColor(v)
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Progress
              percent={v} showInfo={false} size="small"
              strokeColor={color} trailColor="#2a2a3e"
              style={{ flex: 1 }}
            />
            <Tag style={{ background: `${color}22`, border: `1px solid ${color}66`, color, borderRadius: 6, minWidth: 66, textAlign: 'center', fontSize: 11 }}>
              {v}% {simLabel(v)}
            </Tag>
          </div>
        )
      },
    },
    {
      title: 'Date', dataIndex: 'created_at', key: 'created_at', width: 100,
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 55,
      render: (_: any, r: any) => (
        <Popconfirm title="Delete this match?" onConfirm={() => deleteMatch(r.id)} okType="danger" okText="Delete">
          <Button size="small" danger icon={<DeleteOutlined />} />
        </Popconfirm>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={8}>
        <Select value={simRange} style={{ width: 190 }}
          onChange={(v) => { setSimRange(v); fetchMatches(v) }}>
          <Option value="all">All similarities</Option>
          <Option value="low">75–84% — Good</Option>
          <Option value="mid">85–94% — Great</Option>
          <Option value="high">95–100% — Perfect</Option>
        </Select>
        <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>{matches.length} matches</Typography.Text>
      </Space>

      <Table
        dataSource={matches} columns={columns} rowKey="id" loading={loading}
        size="small" pagination={{ pageSize: 20, showSizeChanger: false }}
        style={{ borderRadius: 14, overflow: 'hidden' }}
      />
    </>
  )
}
