import { useEffect, useState } from 'react'
import { Table, Button, Tag, Typography, Space, Popconfirm, message, Avatar, Badge } from 'antd'
import { DeleteOutlined, WarningOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const REASON: Record<string, { bg: string; border: string; color: string; label: string }> = {
  spam:          { bg: 'rgba(245,158,11,0.1)',  border: 'rgba(245,158,11,0.35)',  color: '#f59e0b', label: 'Spam' },
  inappropriate: { bg: 'rgba(239,68,68,0.1)',   border: 'rgba(239,68,68,0.35)',   color: '#ef4444', label: 'Inappropriate' },
  harassment:    { bg: 'rgba(124,58,237,0.1)',  border: 'rgba(124,58,237,0.35)',  color: '#a78bfa', label: 'Harassment' },
}

const tStyle = { background: '#0f0f1c', border: '1px solid rgba(255,255,255,0.07)', borderRadius: 14, overflow: 'hidden' as const }

export default function ReportsPage() {
  const [reports, setReports] = useState<any[]>([])
  const [loading, setLoading] = useState(false)

  const fetchReports = async () => {
    setLoading(true)
    try { const r = await adminApi.getReports(); setReports(r.data) }
    finally { setLoading(false) }
  }

  useEffect(() => { fetchReports() }, [])

  const dismiss = async (id: number) => {
    await adminApi.dismissReport(id)
    message.success('Report dismissed')
    fetchReports()
  }

  const columns = [
    {
      title: '#', dataIndex: 'id', key: 'id', width: 55,
      render: (v: number) => <span style={{ color: '#334155', fontSize: 12 }}>#{v}</span>,
    },
    {
      title: 'Reported User', key: 'reported',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Avatar size={30} style={{ background: 'linear-gradient(135deg, #ef4444, #be185d)', fontSize: 12, flexShrink: 0 }}>
            {r.reported_username?.[0]?.toUpperCase()}
          </Avatar>
          <span style={{ color: '#e2e8f0', fontWeight: 600, fontSize: 13 }}>@{r.reported_username}</span>
        </div>
      ),
    },
    {
      title: 'Reported By', key: 'reporter',
      render: (_: any, r: any) => (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Avatar size={26} style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.1)', fontSize: 11, color: '#64748b', flexShrink: 0 }}>
            {r.reporter_username?.[0]?.toUpperCase()}
          </Avatar>
          <span style={{ color: '#64748b', fontSize: 12 }}>@{r.reporter_username}</span>
        </div>
      ),
    },
    {
      title: 'Reason', dataIndex: 'reason', key: 'reason', width: 160,
      render: (v: string) => {
        const s = REASON[v] || { bg: 'rgba(255,255,255,0.05)', border: 'rgba(255,255,255,0.1)', color: '#94a3b8', label: v }
        return (
          <Tag icon={<WarningOutlined />}
            style={{ background: s.bg, border: `1px solid ${s.border}`, color: s.color, borderRadius: 6, fontSize: 11 }}>
            {s.label}
          </Tag>
        )
      },
    },
    {
      title: 'Details', dataIndex: 'details', key: 'details',
      render: (v: string) => (
        <Typography.Text style={{ color: '#64748b', fontSize: 12 }} ellipsis={{ tooltip: v }}>
          {v || '—'}
        </Typography.Text>
      ),
    },
    {
      title: 'Date', dataIndex: 'created_at', key: 'created_at', width: 110,
      render: (v: string) => <span style={{ color: '#334155', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 105,
      render: (_: any, r: any) => (
        <Popconfirm title="Dismiss this report?" onConfirm={() => dismiss(r.id)} okText="Dismiss">
          <Button size="small" icon={<DeleteOutlined />}
            style={{ background: '#161623', border: '1px solid rgba(255,255,255,0.1)', color: '#94a3b8', fontSize: 11, borderRadius: 8 }}>
            Dismiss
          </Button>
        </Popconfirm>
      ),
    },
  ]

  return (
    <>
      <Space style={{ marginBottom: 16 }} size={8}>
        <Badge count={reports.length} showZero color="#ef4444">
          <Typography.Text style={{ color: '#94a3b8', fontSize: 13, paddingRight: 4 }}>Pending reports</Typography.Text>
        </Badge>
      </Space>

      {reports.length === 0 && !loading ? (
        <div style={{ textAlign: 'center', padding: '80px 0' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>🎉</div>
          <div style={{ color: '#475569', fontSize: 15, fontWeight: 600, marginBottom: 6 }}>No pending reports</div>
          <div style={{ color: '#334155', fontSize: 12 }}>All clear — the community is behaving well</div>
        </div>
      ) : (
        <Table
          dataSource={reports} columns={columns} rowKey="id" loading={loading}
          size="small" pagination={{ pageSize: 20, showSizeChanger: false }}
          style={tStyle}
        />
      )}
    </>
  )
}
