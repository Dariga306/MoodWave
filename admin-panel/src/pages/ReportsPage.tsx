import { useEffect, useState } from 'react'
import { Table, Button, Tag, Typography, Space, Popconfirm, message, Avatar, Badge } from 'antd'
import { DeleteOutlined, WarningOutlined } from '@ant-design/icons'
import { adminApi } from '../api/admin'

const REASON_STYLE: Record<string, { bg: string; border: string; color: string; label: string }> = {
  spam:          { bg: '#f59e0b22', border: '#f59e0b66', color: '#f59e0b', label: 'Spam' },
  inappropriate: { bg: '#ef444422', border: '#ef444466', color: '#ef4444', label: 'Inappropriate' },
  harassment:    { bg: '#7c3aed22', border: '#7c3aed66', color: '#7c3aed', label: 'Harassment' },
}

export default function ReportsPage() {
  const [reports, setReports] = useState<any[]>([])
  const [loading, setLoading] = useState(false)

  const fetchReports = async () => {
    setLoading(true)
    try {
      const res = await adminApi.getReports()
      setReports(res.data)
    } finally {
      setLoading(false)
    }
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
      render: (v: number) => <span style={{ color: '#64748b', fontSize: 12 }}>#{v}</span>,
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
          <Avatar size={26} style={{ background: '#1a1a28', border: '1px solid #2a2a3e', fontSize: 11, color: '#94a3b8', flexShrink: 0 }}>
            {r.reporter_username?.[0]?.toUpperCase()}
          </Avatar>
          <span style={{ color: '#94a3b8', fontSize: 12 }}>@{r.reporter_username}</span>
        </div>
      ),
    },
    {
      title: 'Reason', dataIndex: 'reason', key: 'reason', width: 150,
      render: (v: string) => {
        const s = REASON_STYLE[v] || { bg: '#1a1a28', border: '#2a2a3e', color: '#94a3b8', label: v }
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
        <Typography.Text style={{ color: '#94a3b8', fontSize: 12 }} ellipsis={{ tooltip: v }}>
          {v || '—'}
        </Typography.Text>
      ),
    },
    {
      title: 'Date', dataIndex: 'created_at', key: 'created_at', width: 110,
      render: (v: string) => <span style={{ color: '#64748b', fontSize: 11 }}>{v ? new Date(v).toLocaleDateString() : '—'}</span>,
    },
    {
      title: '', key: 'actions', width: 105,
      render: (_: any, r: any) => (
        <Popconfirm title="Dismiss this report?" onConfirm={() => dismiss(r.id)} okText="Dismiss">
          <Button size="small" icon={<DeleteOutlined />}
            style={{ background: '#1a1a28', border: '1px solid #2a2a3e', color: '#94a3b8', fontSize: 11 }}>
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
          <Typography.Title level={5} style={{ color: '#475569' }}>No pending reports</Typography.Title>
          <Typography.Text style={{ color: '#334155', fontSize: 12 }}>All clear — the community is behaving well</Typography.Text>
        </div>
      ) : (
        <Table
          dataSource={reports} columns={columns} rowKey="id" loading={loading}
          size="small" pagination={{ pageSize: 20, showSizeChanger: false }}
          style={{ borderRadius: 14, overflow: 'hidden' }}
        />
      )}
    </>
  )
}
