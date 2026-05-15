import { useEffect, useState } from 'react'
import {
  Table, Input, Button, Space, Tag, Modal, Descriptions, List,
  Typography, Popconfirm, Select, message, Avatar, Badge, Tooltip, Spin,
} from 'antd'
import {
  SearchOutlined, EyeOutlined, HistoryOutlined, DeleteOutlined,
  StopOutlined, CheckCircleOutlined, CrownOutlined,
} from '@ant-design/icons'
import { adminApi } from '../api/admin'

const { Option } = Select

const ACTION_COLOR: Record<string, string> = {
  liked: '#10b981', completed: '#06b6d4', skipped: '#f59e0b',
  skipped_early: '#ef4444', replayed: '#7c3aed', added_to_playlist: '#ec4899',
}

const s = {
  table:   { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 14, overflow: 'hidden' as const },
  input:   { background: '#161623', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 10, color: '#e2e8f0', height: 36 },
  btn:     { background: '#161623', border: '1px solid rgba(255,255,255,0.1)', color: '#94a3b8', borderRadius: 8 },
  tag:     (c: string) => ({ background: `${c}1a`, border: `1px solid ${c}40`, color: c, borderRadius: 6, fontSize: 11 }),
}

export default function UsersPage() {
  const [users, setUsers]               = useState<any[]>([])
  const [total, setTotal]               = useState(0)
  const [loading, setLoading]           = useState(false)
  const [page, setPage]                 = useState(1)
  const [search, setSearch]             = useState('')
  const [filterActive, setFilterActive] = useState<boolean | undefined>(undefined)
  const [profileUser, setProfileUser]   = useState<any>(null)
  const [profileLoading, setProfileLoading] = useState(false)
  const [history, setHistory]           = useState<any[]>([])
  const [historyVisible, setHistoryVisible] = useState(false)
  const [historyUsername, setHistoryUsername] = useState('')

  const fetchUsers = async (p = page, q = search, active = filterActive) => {
    setLoading(true)
    try {
      const res = await adminApi.getUsers({ page: p, limit: 20, search: q || undefined, is_active: active })
      setUsers(res.data.items)
      setTotal(res.data.total)
    } finally { setLoading(false) }
  }

  useEffect(() => { fetchUsers() }, [])

  const openProfile = async (id: number) => {
    setProfileLoading(true)
    setProfileUser({})
    try { const r = await adminApi.getUserDetail(id); setProfileUser(r.data) }
    finally { setProfileLoading(false) }
  }

  const openHistory = async (id: number, username: string) => {
    setHistoryUsername(username)
    const r = await adminApi.getUserHistory(id)
    setHistory(r.data)
    setHistoryVisible(true)
  }

  const toggleBlock = async (id: number) => {
    await adminApi.toggleBlockUser(id)
    message.success('User status updated')
    fetchUsers()
    if (profileUser?.id === id) {
      const r = await adminApi.getUserDetail(id); setProfileUser(r.data)
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
                <Tag style={{ marginLeft: 6, fontSize: 10, borderRadius: 4, background: '#f59e0b1a', border: '1px solid #f59e0b40', color: '#f59e0b', padding: '0 5px', lineHeight: '16px' }}>ADMIN</Tag>
              )}
            </div>
            <div style={{ color: '#475569', fontSize: 11 }}>@{r.username}</div>
          </div>
        </div>
      ),
    },
    {
      title: 'Email', dataIndex: 'email', key: 'email',
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 12 }}>{v}</span>,
    },
    {
      title: 'City', dataIndex: 'city', key: 'city',
      render: (v: string) => <span style={{ color: '#94a3b8', fontSize: 12 }}>{v || '—'}</span>,
      responsive: ['md' as const],
    },
    {
      title: 'Status', key: 'status',
      render: (_: any, r: any) => (
        <Badge
          status={r.is_active ? 'success' : 'error'}
          text={<span style={{ fontSize: 12, color: r.is_active ? '#10b981' : '#ef4444' }}>
            {r.is_active ? 'Active' : 'Blocked'}
          </span>}
        />
      ),
    },
    {
      title: 'Joined', dataIndex: 'created_at', key: 'created_at',
      render: (v: string) => <span style={{ color: '#334155', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
      responsive: ['lg' as const],
    },
    {
      title: '', key: 'actions', width: 155,
      render: (_: any, r: any) => (
        <Space size={4}>
          <Tooltip title="View profile">
            <Button size="small" icon={<EyeOutlined />} onClick={() => openProfile(r.id)} style={s.btn} />
          </Tooltip>
          <Tooltip title="Listening history">
            <Button size="small" icon={<HistoryOutlined />} onClick={() => openHistory(r.id, r.username)} style={s.btn} />
          </Tooltip>
          <Tooltip title={r.is_active ? 'Block' : 'Unblock'}>
            <Button size="small"
              icon={r.is_active ? <StopOutlined /> : <CheckCircleOutlined />}
              onClick={() => toggleBlock(r.id)}
              style={r.is_active
                ? { background: 'rgba(239,68,68,0.08)', border: '1px solid rgba(239,68,68,0.25)', color: '#ef4444', borderRadius: 8 }
                : { background: 'rgba(16,185,129,0.08)', border: '1px solid rgba(16,185,129,0.25)', color: '#10b981', borderRadius: 8 }
              }
            />
          </Tooltip>
          <Tooltip title={r.is_admin ? 'Remove admin' : 'Make admin'}>
            <Button size="small" icon={<CrownOutlined />} onClick={() => toggleAdmin(r.id)}
              style={r.is_admin
                ? { background: 'rgba(245,158,11,0.08)', border: '1px solid rgba(245,158,11,0.25)', color: '#f59e0b', borderRadius: 8 }
                : s.btn
              }
            />
          </Tooltip>
          <Popconfirm title="Delete this user?" description="All their data will be removed." onConfirm={() => deleteUser(r.id)} okType="danger" okText="Delete">
            <Button size="small" danger icon={<DeleteOutlined />} style={{ borderRadius: 8 }} />
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
        <Typography.Text style={{ color: '#475569', fontSize: 12 }}>
          {total.toLocaleString()} users total
        </Typography.Text>
      </Space>

      <Table
        dataSource={users} columns={columns} rowKey="id"
        loading={loading} size="small"
        pagination={{
          current: page, total, pageSize: 20, showSizeChanger: false,
          onChange: (p) => { setPage(p); fetchUsers(p) },
          style: { marginTop: 16 },
        }}
        style={s.table}
      />

      {/* Profile Modal */}
      <Modal
        title={<span style={{ color: '#e2e8f0' }}>User Profile</span>}
        open={!!(profileUser !== null)} onCancel={() => setProfileUser(null)}
        footer={null} width={620}
        styles={{ content: { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.08)' }, header: { background: '#0f0f1c' } }}
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
                <div style={{ color: '#e2e8f0', fontSize: 16, fontWeight: 700 }}>{profileUser.display_name || profileUser.username}</div>
                <div style={{ color: '#64748b', fontSize: 12 }}>@{profileUser.username} · {profileUser.email}</div>
              </div>
            </div>
            <Descriptions column={2} size="small"
              labelStyle={{ color: '#64748b', fontSize: 12 }}
              contentStyle={{ color: '#e2e8f0', fontSize: 12 }}>
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
                <div style={{ color: '#64748b', fontSize: 12, marginBottom: 8 }}>Genres</div>
                <Space wrap size={4}>
                  {profileUser.genres.map((g: any) => (
                    <Tag key={g.genre} style={{ background: '#1a1a2e', border: '1px solid rgba(124,58,237,0.3)', color: '#c4b5fd', borderRadius: 6, fontSize: 11 }}>
                      {g.genre} <span style={{ color: '#7c3aed', marginLeft: 2 }}>{g.weight.toFixed(1)}</span>
                    </Tag>
                  ))}
                </Space>
              </div>
            )}
            <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
              <Button size="small" icon={profileUser.is_active ? <StopOutlined /> : <CheckCircleOutlined />}
                onClick={() => toggleBlock(profileUser.id)} danger={profileUser.is_active} style={{ borderRadius: 8 }}>
                {profileUser.is_active ? 'Block' : 'Unblock'}
              </Button>
              <Popconfirm title="Delete this user?" onConfirm={() => deleteUser(profileUser.id)} okType="danger" okText="Delete">
                <Button size="small" danger icon={<DeleteOutlined />} style={{ borderRadius: 8 }}>Delete</Button>
              </Popconfirm>
            </div>
          </>
        )}
      </Modal>

      {/* History Modal */}
      <Modal
        title={<span style={{ color: '#e2e8f0' }}>Listening History — @{historyUsername}</span>}
        open={historyVisible} onCancel={() => setHistoryVisible(false)}
        footer={null} width={600}
        styles={{ content: { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.08)' }, header: { background: '#0f0f1c' } }}
      >
        {history.length === 0 ? (
          <Typography.Text style={{ color: '#64748b' }}>No history yet</Typography.Text>
        ) : (
          <List size="small" dataSource={history}
            renderItem={(item: any) => (
              <List.Item style={{ borderColor: 'rgba(255,255,255,0.05)' }}>
                <List.Item.Meta
                  title={<span style={{ color: '#e2e8f0', fontSize: 13 }}>{item.track_title} <span style={{ color: '#64748b', fontWeight: 400 }}>— {item.track_artist}</span></span>}
                  description={<span style={{ color: '#334155', fontSize: 11 }}>{item.created_at ? new Date(item.created_at).toLocaleString() : '—'}</span>}
                />
                <Tag style={{ background: `${ACTION_COLOR[item.action] || '#64748b'}22`, border: `1px solid ${ACTION_COLOR[item.action] || '#64748b'}55`, color: ACTION_COLOR[item.action] || '#94a3b8', fontSize: 10, borderRadius: 6 }}>
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
