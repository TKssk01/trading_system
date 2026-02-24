export function fmtNumber(value) {
  if (value === null || value === undefined) return '-'
  try {
    return Number(value).toLocaleString('ja-JP')
  } catch {
    return String(value)
  }
}

export function fmtCurrency(value) {
  if (value === null || value === undefined) return '-'
  return `¥${fmtNumber(value)}`
}

export function fmtPL(value) {
  if (value === null || value === undefined) return '-'
  const n = Number(value)
  const sign = n >= 0 ? '+' : ''
  return `${sign}${fmtNumber(n)}`
}

export function fmtPercent(value) {
  if (value === null || value === undefined) return '-'
  const n = Number(value)
  const sign = n >= 0 ? '+' : ''
  return `${sign}${n.toFixed(2)}%`
}

export function fmtTime(isoString) {
  if (!isoString) return '--:--:--'
  return isoString.slice(11, 19)
}

export function fmtDateTime(isoString) {
  if (!isoString) return '-'
  return isoString.slice(5, 16).replace('T', ' ')
}

export function plClass(value) {
  if (value === null || value === undefined) return 'neutral'
  const n = Number(value)
  if (n > 0) return 'profit'
  if (n < 0) return 'loss'
  return 'neutral'
}

export function sideLabel(sideCode) {
  return sideCode === '2' ? 'BUY' : 'SELL'
}

export function sideClass(sideCode) {
  return sideCode === '2' ? 'buy' : 'sell'
}

export function orderStateLabel(stateCode) {
  const states = { 1: '待機', 2: '処理中', 3: '処理済', 4: '訂正取消中', 5: '終了' }
  return states[stateCode] || String(stateCode)
}

export function orderStateClass(stateCode) {
  const classes = { 1: 'warning', 2: 'accent', 3: 'profit', 4: 'warning', 5: 'neutral' }
  return classes[stateCode] || 'neutral'
}
