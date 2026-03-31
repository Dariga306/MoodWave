import { useEffect, useState } from 'react'
import { Table, Input, Button, Space, Typography, Popconfirm, message, Progress } from 'antd'
import { SearchOutlined, DeleteOutlined, SoundOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

export default function TracksPage() {
  const [tracks, setTracks]   = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [search, setSearch]   = useState('')

  const fetchTracks = async (s = search) => {
    setLoading(true)
    try {
      const res = await adminApi.getTracks(s || undefined)
      setTracks(res.data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchTracks() }, [])

  const deleteTrack = async (id: string) => {
    await adminApi.deleteTrack(id)
    message.success('Removed from cache')
    fetchTracks()
  }

  const maxPlays = Math.max(...tracks.map((t: any) => t.play_count || 0), 1)

  const columns = [
    {
      title: 'Track', key: 'track',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 8, flexShrink: 0,
            background: 'linear-gradient(135deg, #7c3aed22, #06b6d422)',
            border: '1px solid #2a2a3e',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#7c3aed', fontSize: 16,
          }}>
            <SoundOutlined />
          </div>
          <div>
            <div style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>{r.title}</div>
            <div style={{ color: '#94a3b8', fontSize: 11 }}>{r.artist}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Album', dataIndex: 'album', key: 'album', responsive: ['md' as const],
      render: (v: string) => <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>{v || '—'}</Typography.Text>,
    },
    {
      title: 'Duration', dataIndex: 'duration_ms', key: 'duration_ms', width: 80,
      render: (v: number) => {
        if (!v) return <span style={{ color: '#64748b' }}>—</span>
        const m = Math.floor(v / 60000)
        const s = Math.floor((v % 60000) / 1000)
        return <span style={{ color: '#94a3b8', fontSize: 12 }}>{m}:{s.toString().padStart(2, '0')}</span>
      },
    },
    {
      title: 'Plays', dataIndex: 'play_count', key: 'play_count', width: 170,
      sorter: (a: any, b: any) => a.play_count - b.play_count,
      defaultSortOrder: 'descend' as const,
      render: (v: number) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Progress
            percent={Math.round((v / maxPlays) * 100)}
            showInfo={false} size="small"
            strokeColor="#7c3aed" trailColor="#2a2a3e"
            style={{ flex: 1, minWidth: 70 }}
          />
          <span style={{ color: '#e2e8f0', fontSize: 12, minWidth: 22, textAlign: 'right' }}>{v}</span>
        </div>
      ),
    },
    {
      title: 'Cached', dataIndex: 'cached_at', key: 'cached_at', width: 100,
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
      responsive: ['lg' as const],
    },
    {
      title: '', key: 'actions', width: 55,
      render: (_: any, r: any) => (
        <Popconfirm title="Remove from cache?" onConfirm={() => deleteTrack(r.spotify_id)} okType="danger" okText="Remove">
          <Button size="small" danger icon={<DeleteOutlined />} />
        </Popconfirm>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={8}>
        <Input.Search
          placeholder="Search title or artist…"
          allowClear
          style={{ width: 280 }}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          onSearch={(v) => { setSearch(v); fetchTracks(v) }}
          onChange={(e) => { if (!e.target.value) fetchTracks('') }}
        />
        <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>
          {tracks.length.toLocaleString()} tracks in cache
        </Typography.Text>
      </Space>

      <Table
        dataSource={tracks}
        columns={columns}
        rowKey="spotify_id"
        loading={loading}
        size="small"
        pagination={{ pageSize: 25, showSizeChanger: false }}
        style={{ borderRadius: 14, overflow: 'hidden' }}
      />
    </>
  )
}
