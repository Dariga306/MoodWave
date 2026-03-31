import { useEffect, useState } from 'react'
import {
  Table, Input, Button, Space, Tag, Modal, Descriptions, List,
  Typography, Popconfirm, Select, message, Avatar, Badge, Tooltip, Spin,
} from 'antd'
import {
  SearchOutlined, EyeOutlined, HistoryOutlined, DeleteOutlined,
  StopOutlined, CheckCircleOutlined, CrownOutlined, UserOutlined,
} from '@ant-design/icons'
import { adminApi } from '../api/admin'

const { Option } = Select

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
}

export default function UsersPage() {
  const [users, setUsers]           = useState<any[]>([])
  const [total, setTotal]           = useState(0)
  const [loading, setLoading]       = useState(false)
  const [page, setPage]             = useState(1)
  const [search, setSearch]         = useState('')
  const [filterActive, setFilterActive] = useState<boolean | undefined>(undefined)

  const [profileUser, setProfileUser]     = useState<any>(null)
  const [profileLoading, setProfileLoading] = useState(false)
  const [history, setHistory]             = useState<any[]>([])
  const [historyVisible, setHistoryVisible] = useState(false)
  const [historyUsername, setHistoryUsername] = useState('')

  const fetchUsers = async (p = page, s = search, active = filterActive) => {
    setLoading(true)
    try {
      const res = await adminApi.getUsers({ page: p, limit: 20, search: s || undefined, is_active: active })
      setUsers(res.data.items)
      setTotal(res.data.total)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchUsers() }, [])

  const openProfile = async (id: number) => {
    setProfileLoading(true)
    setProfileUser({})
    try {
      const res = await adminApi.getUserDetail(id)
      setProfileUser(res.data)
    } finally {
      setProfileLoading(false)
    }
  }

  const openHistory = async (id: number, username: string) => {
    setHistoryUsername(username)
    const res = await adminApi.getUserHistory(id)
    setHistory(res.data)
    setHistoryVisible(true)
  }

  const toggleBlock = async (id: number) => {
    await adminApi.toggleBlockUser(id)
    message.success('User status updated')
    fetchUsers()
    if (profileUser?.id === id) {
      const res = await adminApi.getUserDetail(id)
      setProfileUser(res.data)
    }
  }

  const toggleAdmin = async (id: number) => {
    await adminApi.toggleAdminUser(id)
    message.success('Admin status updated')
    fetchUsers()
  }

  const deleteUser = async (id: number) => {
    await adminApi.deleteUser(id)
    message.success('User deleted')
    setProfileUser(null)
    fetchUsers()
  }

  const columns = [
    {
      title: 'User', key: 'user',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Avatar size={36} style={{ background: 'linear-gradient(135deg, #7c3aed, #06b6d4)', flexShrink: 0, fontSize: 14 }}>
            {r.username?.[0]?.toUpperCase()}
          </Avatar>
          <div>
            <div style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>
              {r.display_name || r.username}
              {r.is_admin && (
                <Tag color="gold" style={{ marginLeft: 6, fontSize: 10, borderRadius: 4, lineHeight: '16px', padding: '0 5px' }}>ADMIN</Tag>
              )}
            </div>
            <div style={{ color: '#94a3b8', fontSize: 11 }}>@{r.username}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Email', dataIndex: 'email', key: 'email',
      render: (v: string) => <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>{v}</Typography.Text>,
    },
    { title: 'City', dataIndex: 'city', key: 'city', render: (v: string) => v || '—', responsive: ['md' as const] },
    {
      title: 'Status', key: 'status',
      render: (_: any, r: any) => (
        <Space size={4}>
          <Badge
            status={r.is_active ? 'success' : 'error'}
            text={<span style={{ fontSize: 12, color: r.is_active ? '#10b981' : '#ef4444' }}>{r.is_active ? 'Active' : 'Blocked'}</span>}
          />
          {r.is_verified && (
            <Tag color="blue" style={{ fontSize: 10, borderRadius: 4, marginLeft: 4, lineHeight: '16px', padding: '0 5px' }}>✓ Verified</Tag>
          )}
        </Space>
      ),
    },
    {
      title: 'Joined', dataIndex: 'created_at', key: 'created_at',
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
      responsive: ['lg' as const],
    },
    {
      title: '', key: 'actions', width: 148,
      render: (_: any, r: any) => (
        <Space size={4}>
          <Tooltip title="View profile">
            <Button size="small" icon={<EyeOutlined />} onClick={() => openProfile(r.id)}
              style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#94a3b8' }} />
          </Tooltip>
          <Tooltip title="Listening history">
            <Button size="small" icon={<HistoryOutlined />} onClick={() => openHistory(r.id, r.username)}
              style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#94a3b8' }} />
          </Tooltip>
          <Tooltip title={r.is_active ? 'Block user' : 'Unblock user'}>
            <Button
              size="small"
              icon={r.is_active ? <StopOutlined /> : <CheckCircleOutlined />}
              onClick={() => toggleBlock(r.id)}
              style={r.is_active
                ? { background: '#2d0e0e', border: '1px solid #7f1d1d', color: '#ef4444' }
                : { background: '#0d2d1a', border: '1px solid #14532d', color: '#10b981' }
              }
            />
          </Tooltip>
          <Tooltip title={r.is_admin ? 'Remove admin' : 'Make admin'}>
            <Button
              size="small"
              icon={<CrownOutlined />}
              onClick={() => toggleAdmin(r.id)}
              style={r.is_admin
                ? { background: '#2d1e00', border: '1px solid #78350f', color: '#f59e0b' }
                : { background: '#1a1a28', border: '1px solid #2a2a3e', color: '#64748b' }
              }
            />
          </Tooltip>
          <Popconfirm title="Delete this user?" description="All their data will be removed." onConfirm={() => deleteUser(r.id)} okType="danger" okText="Delete">
            <Button size="small" danger icon={<DeleteOutlined />} />
          </Popconfirm>
        </Space>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16, flexWrap: 'wrap' as const }} size={8}>
        <Input.Search
          placeholder="Search username or email…"
          allowClear
          style={{ width: 280 }}
          prefix={<SearchOutlined style={{ color: '#94a3b8' }} />}
          onSearch={(v) => { setSearch(v); setPage(1); fetchUsers(1, v, filterActive) }}
          onChange={(e) => { if (!e.target.value) { setSearch(''); fetchUsers(1, '', filterActive) } }}
        />
        <Select
          value={filterActive === undefined ? 'all' : String(filterActive)}
          style={{ width: 140 }}
          onChange={(v) => {
            const active = v === 'all' ? undefined : v === 'true'
            setFilterActive(active); setPage(1); fetchUsers(1, search, active)
          }}
        >
          <Option value="all">All Status</Option>
          <Option value="true">Active</Option>
          <Option value="false">Blocked</Option>
        </Select>
        <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>{total.toLocaleString()} users total</Typography.Text>
      </Space>

      <Table
        dataSource={users}
        columns={columns}
        rowKey="id"
        loading={loading}
        size="small"
        pagination={{
          current: page, total, pageSize: 20, showSizeChanger: false,
          onChange: (p) => { setPage(p); fetchUsers(p) },
          style: { marginTop: 16 },
        }}
        style={{ borderRadius: 14, overflow: 'hidden' }}
      />

      {/* Profile modal */}
      <Modal
        title={<span style={{ color: '#e2e8f0' }}>User Profile</span>}
        open={!!(profileUser !== null)}
        onCancel={() => setProfileUser(null)}
        footer={null}
        width={620}
      >
        {profileLoading ? (
          <div style={{ textAlign: 'center', padding: 32 }}><Spin /></div>
        ) : profileUser && Object.keys(profileUser).length > 0 && (
          <>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20 }}>
              <Avatar size={56} style={{ background: 'linear-gradient(135deg, #7c3aed, #06b6d4)', fontSize: 22, flexShrink: 0 }}>
                {profileUser.username?.[0]?.toUpperCase()}
              </Avatar>
              <div>
                <Typography.Title level={5} style={{ margin: 0, color: '#e2e8f0' }}>
                  {profileUser.display_name || profileUser.username}
                </Typography.Title>
                <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }}>
                  @{profileUser.username} · {profileUser.email}
                </Typography.Text>
              </div>
            </div>
            <Descriptions column={2} size="small" labelStyle={{ color: '#94a3b8', fontSize: 12 }} contentStyle={{ color: '#e2e8f0', fontSize: 12 }}>
              <Descriptions.Item label="City">{profileUser.city || '—'}</Descriptions.Item>
              <Descriptions.Item label="Gender">{profileUser.gender || '—'}</Descriptions.Item>
              <Descriptions.Item label="Verified">{profileUser.is_verified ? '✅ Yes' : '❌ No'}</Descriptions.Item>
              <Descriptions.Item label="Admin">{profileUser.is_admin ? '👑 Yes' : '—'}</Descriptions.Item>
              <Descriptions.Item label="Active">{profileUser.is_active ? '✅ Active' : '🚫 Blocked'}</Descriptions.Item>
              <Descriptions.Item label="Joined">{profileUser.created_at ? new Date(profileUser.created_at).toLocaleDateString() : '—'}</Descriptions.Item>
              {profileUser.bio && <Descriptions.Item label="Bio" span={2}>{profileUser.bio}</Descriptions.Item>}
            </Descriptions>
            {profileUser.genres?.length > 0 && (
              <div style={{ marginTop: 14 }}>
                <Typography.Text style={{ color: '#94a3b8', fontSize: 12, display: 'block', marginBottom: 8 }}>Genres</Typography.Text>
                <Space wrap size={4}>
                  {profileUser.genres.map((g: any) => (
                    <Tag key={g.genre} style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#e2e8f0', borderRadius: 6, fontSize: 11 }}>
                      {g.genre} <span style={{ color: '#7c3aed', marginLeft: 2 }}>{g.weight.toFixed(1)}</span>
                    </Tag>
                  ))}
                </Space>
              </div>
            )}
            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <Button
                size="small"
                icon={profileUser.is_active ? <StopOutlined /> : <CheckCircleOutlined />}
                onClick={() => toggleBlock(profileUser.id)}
                danger={profileUser.is_active}
              >
                {profileUser.is_active ? 'Block' : 'Unblock'}
              </Button>
              <Popconfirm title="Delete this user?" onConfirm={() => deleteUser(profileUser.id)} okType="danger" okText="Delete">
                <Button size="small" danger icon={<DeleteOutlined />}>Delete</Button>
              </Popconfirm>
            </div>
          </>
        )}
      </Modal>

      {/* History modal */}
      <Modal
        title={<span style={{ color: '#e2e8f0' }}>Listening History — @{historyUsername}</span>}
        open={historyVisible}
        onCancel={() => setHistoryVisible(false)}
        footer={null}
        width={600}
      >
        {history.length === 0 ? (
          <Typography.Text style={{ color: '#94a3b8' }}>No history yet</Typography.Text>
        ) : (
          <List
            size="small"
            dataSource={history}
            renderItem={(item: any) => (
              <List.Item style={{ borderColor: '#2a2a3e' }}>
                <List.Item.Meta
                  title={
                    <span style={{ color: '#e2e8f0', fontSize: 13 }}>
                      {item.track_title}
                      <span style={{ color: '#94a3b8', fontWeight: 400 }}> — {item.track_artist}</span>
                    </span>
                  }
                  description={<span style={{ color: '#94a3b8', fontSize: 11 }}>{item.created_at ? new Date(item.created_at).toLocaleString() : '—'}</span>}
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
        )}
      </Modal>
    </>
  )
}
