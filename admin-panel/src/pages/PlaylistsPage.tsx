import { useEffect, useState } from 'react'
import { Table, Button, Space, Tag, Modal, List, Typography, Popconfirm, Select, message, Avatar } from 'antd'
import { DeleteOutlined, UnorderedListOutlined, TeamOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const { Option } = Select

const VIS_STYLE: Record<string, { bg: string; border: string; color: string }> = {
  public:  { bg: '#10b98122', border: '#10b98166', color: '#10b981' },
  friends: { bg: '#7c3aed22', border: '#7c3aed66', color: '#7c3aed' },
  private: { bg: '#ef444422', border: '#ef444466', color: '#ef4444' },
}

export default function PlaylistsPage() {
  const [playlists, setPlaylists] = useState<any[]>([])
  const [loading, setLoading]     = useState(false)
  const [visFilter, setVisFilter] = useState<string | undefined>(undefined)
  const [modal, setModal] = useState<{ open: boolean; tracks: any[]; name: string }>({ open: false, tracks: [], name: '' })

  const fetchPlaylists = async (vis = visFilter) => {
    setLoading(true)
    try {
      const res = await adminApi.getPlaylists(vis ? { visibility: vis } : {})
      setPlaylists(res.data)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchPlaylists() }, [])

  const openTracks = async (id: number, name: string) => {
    const res = await adminApi.getPlaylistTracks(id)
    setModal({ open: true, tracks: res.data, name })
  }

  const deletePlaylist = async (id: number) => {
    await adminApi.deletePlaylist(id)
    message.success('Playlist deleted')
    fetchPlaylists()
  }

  const columns = [
    {
      title: 'Playlist', key: 'playlist',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Avatar size={36} icon={<UnorderedListOutlined />}
            style={{ background: 'linear-gradient(135deg, #7c3aed, #5b21b6)', flexShrink: 0 }} />
          <div>
            <div style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>
              {r.name}
              {r.collaborative && (
                <Tag icon={<TeamOutlined />} style={{ marginLeft: 6, fontSize: 10, borderRadius: 4, background: '#06b6d422', border: '1px solid #06b6d466', color: '#06b6d4', lineHeight: '16px', padding: '0 5px' }}>
                  Collab
                </Tag>
              )}
            </div>
            <div style={{ color: '#94a3b8', fontSize: 11 }}>by @{r.owner_username}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Visibility', dataIndex: 'visibility', key: 'visibility', width: 110,
      render: (v: string) => {
        const s = VIS_STYLE[v] || { bg: '#1a1a28', border: '#2a2a3e', color: '#94a3b8' }
        return (
          <Tag style={{ background: s.bg, border: `1px solid ${s.border}`, color: s.color, borderRadius: 6, fontSize: 11 }}>
            {v?.toUpperCase()}
          </Tag>
        )
      },
    },
    {
      title: 'Tracks', dataIndex: 'track_count', key: 'track_count', width: 75,
      render: (v: number) => <span style={{ color: '#e2e8f0', fontWeight: 600 }}>{v}</span>,
    },
    {
      title: 'Created', dataIndex: 'created_at', key: 'created_at', width: 110,
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 110,
      render: (_: any, r: any) => (
        <Space size={4}>
          <Button size="small" onClick={() => openTracks(r.id, r.name)}
            style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#94a3b8', fontSize: 11 }}>
            Tracks
          </Button>
          <Popconfirm title="Delete this playlist?" onConfirm={() => deletePlaylist(r.id)} okType="danger" okText="Delete">
            <Button size="small" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={8}>
        <Select placeholder="All visibility" allowClear style={{ width: 160 }}
          onChange={(v) => { setVisFilter(v); fetchPlaylists(v) }}>
          <Option value="public">Public</Option>
          <Option value="friends">Friends</Option>
          <Option value="private">Private</Option>
        </Select>
        <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>{playlists.length} playlists total</Typography.Text>
      </Space>

      <Table
        dataSource={playlists} columns={columns} rowKey="id" loading={loading}
        size="small" pagination={{ pageSize: 20, showSizeChanger: false }}
        style={{ borderRadius: 14, overflow: 'hidden' }}
      />

      <Modal
        title={<span style={{ color: '#e2e8f0' }}>Tracks — {modal.name}</span>}
        open={modal.open}
        onCancel={() => setModal(p => ({ ...p, open: false }))}
        footer={null} width={520}
      >
        {modal.tracks.length === 0 ? (
          <Typography.Text style={{ color: '#94a3b8' }}>No tracks in this playlist</Typography.Text>
        ) : (
          <List
            size="small"
            dataSource={modal.tracks}
            renderItem={(item: any) => (
              <List.Item style={{ borderColor: '#2a2a3e' }}>
                <List.Item.Meta
                  avatar={<span style={{ color: '#475569', fontSize: 12, width: 24, display: 'block', textAlign: 'center', paddingTop: 2 }}>#{item.position}</span>}
                  title={<span style={{ color: '#e2e8f0', fontSize: 13 }}>{item.title}</span>}
                  description={<span style={{ color: '#94a3b8', fontSize: 11 }}>{item.artist}{item.album ? ` · ${item.album}` : ''}</span>}
                />
              </List.Item>
            )}
          />
        )}
      </Modal>
    </>
  )
}
