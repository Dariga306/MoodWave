// Shared design tokens & style helpers

export const card = {
  background: '#0f0f1c',
  border: '1px solid rgba(255,255,255,0.07)',
  borderRadius: 16,
  overflow: 'hidden' as const,
}

export const cardBody = { padding: '16px 18px' }

export function cardHead(title: string): React.ReactNode {
  return null // use CardHeader component instead
}

export const tableStyle = {
  background: '#0f0f1c',
  borderRadius: 14,
  overflow: 'hidden' as const,
  border: '1px solid rgba(255,255,255,0.07)',
}

export const toolbarInput = {
  background: '#161623',
  border: '1px solid rgba(255,255,255,0.1)',
  borderRadius: 10,
  color: '#e2e8f0',
  height: 36,
}

export const actionBtn = {
  background: '#161623',
  border: '1px solid rgba(255,255,255,0.1)',
  color: '#94a3b8',
  borderRadius: 8,
}

export const dangerBtnStyle = {
  background: 'rgba(239,68,68,0.08)',
  border: '1px solid rgba(239,68,68,0.25)',
  color: '#ef4444',
  borderRadius: 8,
}

export const tagStyle = (color: string) => ({
  background: `${color}1a`,
  border: `1px solid ${color}40`,
  color,
  borderRadius: 6,
  fontSize: 11,
})

export const sectionHeading = {
  color: '#e2e8f0',
  fontSize: 13,
  fontWeight: 600 as const,
}

export const muted = { color: '#64748b', fontSize: 11 }
export const subtle = { color: '#94a3b8', fontSize: 12 }

export const avatarGradient = 'linear-gradient(135deg, #7c3aed, #06b6d4)'

export const C = {
  purple: '#7c3aed',
  purpleLight: '#a855f7',
  cyan: '#06b6d4',
  green: '#10b981',
  orange: '#f59e0b',
  pink: '#ec4899',
  red: '#ef4444',
  text: '#e2e8f0',
  text2: '#94a3b8',
  text3: '#64748b',
  border: 'rgba(255,255,255,0.07)',
  bg: '#07070e',
  bgCard: '#0f0f1c',
  bgElevated: '#161623',
}
