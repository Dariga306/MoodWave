import { useEffect, useState } from 'react'
import { Table, Input, Button, Space, Typography, Popconfirm, message, Progress } from 'antd'
import { SearchOutlined, DeleteOutlined, SoundOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const tStyle = { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 14, overflow: 'hidden' as const }

export default function TracksPage() {
  const [tracks, setTracks]   = useState<any[]>([])
  const [loading, setLoading] = useState(false)
  const [search, setSearch]   = useState('')

  const fetchTracks = async (s = search) => {
    setLoading(true)
    try { const r = await adminApi.getTracks(s || undefined); setTracks(r.data) }
    finally { setLoading(false) }
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
            width: 38, height: 38, borderRadius: 10, flexShrink: 0,
            background: 'linear-gradient(135deg, rgba(124,58,237,0.15), rgba(6,182,212,0.15))',
            border: '1px solid rgba(124,58,237,0.25)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#7c3aed', fontSize: 16,
          }}>
            <SoundOutlined />
          </div>
          <div>
            <div style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>{r.title}</div>
            <div style={{ color: '#64748b', fontSize: 11 }}>{r.artist}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Album', dataIndex: 'album', key: 'album', responsive: ['md' as const],
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 12 }}>{v || '—'}</span>,
    },
    {
      title: 'Duration', dataIndex: 'duration_ms', key: 'duration_ms', width: 80,
      render: (v: number) => {
        if (!v) return <span style={{ color: '#334155' }}>—</span>
        const m = Math.floor(v / 60000)
        const s = Math.floor((v % 60000) / 1000)
        return <span style={{ color: '#94a3b8', fontSize: 12 }}>{m}:{s.toString().padStart(2, '0')}</span>
      },
    },
    {
      title: 'Plays', dataIndex: 'play_count', key: 'play_count', width: 175,
      sorter: (a: any, b: any) => a.play_count - b.play_count,
      defaultSortOrder: 'descend' as const,
      render: (v: number) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Progress percent={Math.round((v / maxPlays) * 100)} showInfo={false} size="small"
            strokeColor="linear-gradient(90deg, #7c3aed, #06b6d4)" trailColor="rgba(255,255,255,0.06)"
            style={{ flex: 1, minWidth: 70 }} />
          <span style={{ color: '#e2e8f0', fontSize: 12, minWidth: 22, textAlign: 'right' }}>{v}</span>
        </div>
      ),
    },
    {
      title: 'Cached', dataIndex: 'cached_at', key: 'cached_at', width: 100, responsive: ['lg' as const],
      render: (v: string) => <span style={{ color: '#334155', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 55,
      render: (_: any, r: any) => (
        <Popconfirm title="Remove from cache?" onConfirm={() => deleteTrack(r.spotify_id)} okType="danger" okText="Remove">
          <Button size="small" danger icon={<DeleteOutlined />} style={{ borderRadius: 8 }} />
        </Popconfirm>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={8}>
        <Input.Search
          placeholder="Search title or artist…"
          allowClear style={{ width: 280 }}
          onSearch={(v) => { setSearch(v); fetchTracks(v) }}
          onChange={(e) => { if (!e.target.value) fetchTracks('') }}
        />
        <Typography.Text style={{ color: '#475569', fontSize: 12 }}>
          {tracks.length.toLocaleString()} tracks in cache
        </Typography.Text>
      </Space>

      <Table
        dataSource={tracks} columns={columns} rowKey="spotify_id"
        loading={loading} size="small"
        pagination={{ pageSize: 25, showSizeChanger: false }}
        style={tStyle}
      />
    </>
  )
}
