const API_BASE = '/api'

async function fetchJson(url, options) {
  const res = await fetch(url, options)
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  return res.json()
}

export async function getHealth() {
  return fetchJson(`${API_BASE}/health`)
}

export async function getStatus() {
  return fetchJson(`${API_BASE}/status`)
}

export async function getAccount() {
  return fetchJson(`${API_BASE}/account`)
}

export async function getLogs(limit = 200) {
  return fetchJson(`${API_BASE}/logs?limit=${limit}`)
}

export async function postStart() {
  return fetchJson(`${API_BASE}/start`, { method: 'POST' })
}

export async function postScheduleStart(time) {
  return fetchJson(`${API_BASE}/schedule_start`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ time })
  })
}

export async function postCancelSchedule() {
  return fetchJson(`${API_BASE}/cancel_schedule`, { method: 'POST' })
}

export async function getSchedule() {
  return fetchJson(`${API_BASE}/schedule`)
}

export async function postStop() {
  return fetchJson(`${API_BASE}/stop`, { method: 'POST' })
}

export async function postForceClose() {
  return fetchJson(`${API_BASE}/force_close`, { method: 'POST' })
}

export async function postConfig(symbol, quantity) {
  return fetchJson(`${API_BASE}/config`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      symbol: symbol || null,
      quantity: quantity ? Number(quantity) : null
    })
  })
}

export async function getSymbolInfo(code) {
  return fetchJson(`${API_BASE}/symbol/${code}`)
}

export async function getBoard(code) {
  return fetchJson(`${API_BASE}/board/${code}`)
}

export async function getIndices() {
  return fetchJson(`${API_BASE}/indices`)
}

export async function getWatchlist() {
  return fetchJson(`${API_BASE}/watchlist`)
}

export async function postSecrets(apiPassword, orderPassword, save) {
  return fetchJson(`${API_BASE}/secrets`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      api_password: apiPassword || null,
      order_password: orderPassword || null,
      save: !!save
    })
  })
}

export async function getTradeTimeline(date) {
  const q = date ? `?date=${date}` : ''
  return fetchJson(`${API_BASE}/trade-history/timeline${q}`)
}

export async function getTradeDaily(days = 30) {
  return fetchJson(`${API_BASE}/trade-history/daily?days=${days}`)
}

export async function getTradeStats(days = 30) {
  return fetchJson(`${API_BASE}/trade-history/stats?days=${days}`)
}
