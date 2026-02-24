<script>
  import { onMount } from 'svelte'
  import * as api from './lib/api.js'
  import StatusBar from './components/StatusBar.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import PLCard from './components/PLCard.svelte'
  import PositionsCard from './components/PositionsCard.svelte'
  import SignalPanel from './components/SignalPanel.svelte'
  import AccountCard from './components/AccountCard.svelte'
  import PriceCard from './components/PriceCard.svelte'
  import OrdersTable from './components/OrdersTable.svelte'
  import LogPanel from './components/LogPanel.svelte'
  import MarketTicker from './components/MarketTicker.svelte'
  import WatchlistCard from './components/WatchlistCard.svelte'
  import ErrorBanner from './components/ErrorBanner.svelte'

  let status = {
    running: false, symbol: '', quantity: 0,
    last_price: null, last_signal: null,
    last_error: null, last_update: null, positions: []
  }
  let account = {
    wallet_cash: null, wallet_margin: null,
    positions_pl_total: null, positions: [], orders: []
  }
  let logs = []
  let backendOk = null
  let busy = false
  let symbolName = ''
  let lastSymbolLookup = ''
  let board = null
  let indices = []
  let watchlist = []
  let symbolInput = ''
  let quantityInput = ''
  let apiPassword = ''
  let orderPassword = ''
  let secretsMessage = ''
  let scheduledTime = null
  let scheduleTimeInput = '09:00'

  async function refreshHealth() {
    try { await api.getHealth(); backendOk = true }
    catch { backendOk = false }
  }
  async function refreshStatus() {
    try {
      const data = await api.getStatus()
      status = data
      if (!symbolInput) symbolInput = status.symbol || ''
      if (!quantityInput) quantityInput = status.quantity ? String(status.quantity) : ''
      if (status.symbol && status.symbol !== lastSymbolLookup) {
        lastSymbolLookup = status.symbol
        try {
          const info = await api.getSymbolInfo(status.symbol)
          symbolName = info.display_name || info.symbol_name || ''
        } catch { /* keep previous */ }
      }
    } catch { status.last_error = 'status fetch failed' }
  }
  async function refreshAccount() {
    try { account = await api.getAccount() }
    catch { /* keep previous */ }
  }
  async function refreshBoard() {
    const sym = status.symbol
    if (!sym) return
    try { board = await api.getBoard(sym) }
    catch { /* keep previous */ }
  }
  async function refreshIndices() {
    try { indices = await api.getIndices() }
    catch { /* keep previous */ }
  }
  async function refreshWatchlist() {
    try { watchlist = await api.getWatchlist() }
    catch { /* keep previous */ }
  }
  async function refreshLogs() {
    try { const data = await api.getLogs(); logs = data.logs || [] }
    catch { /* keep previous */ }
  }

  async function updateConfig() {
    busy = true
    try {
      await api.postConfig(symbolInput, quantityInput)
      await refreshStatus()
      await refreshAccount()
    } finally { busy = false }
  }
  async function start() {
    busy = true
    try {
      await updateConfig()
      await api.postStart()
      await refreshStatus()
    } finally { busy = false }
  }
  async function stop() {
    busy = true
    try { await api.postStop(); await refreshStatus() }
    finally { busy = false }
  }
  async function forceClose() {
    busy = true
    try { await api.postForceClose(); await refreshStatus(); await refreshAccount() }
    finally { busy = false }
  }
  async function scheduleStart(e) {
    busy = true
    try {
      const time = e.detail.time
      await api.postConfig(symbolInput, quantityInput)
      const res = await api.postScheduleStart(time)
      if (res.ok) scheduledTime = res.scheduled_time || time
    } finally { busy = false }
  }
  async function cancelSchedule() {
    busy = true
    try {
      await api.postCancelSchedule()
      scheduledTime = null
    } finally { busy = false }
  }
  async function refreshSchedule() {
    try {
      const data = await api.getSchedule()
      scheduledTime = data.scheduled_time
    } catch { /* keep previous */ }
  }

  async function applySecrets() {
    busy = true
    try {
      await api.postSecrets(apiPassword, orderPassword, false)
      secretsMessage = '一時適用しました'
      await refreshAccount()
    } catch { secretsMessage = '適用に失敗しました' }
    finally { busy = false }
  }
  async function saveSecrets() {
    busy = true
    try {
      await api.postSecrets(apiPassword, orderPassword, true)
      secretsMessage = '.envに保存しました'
      await refreshAccount()
    } catch { secretsMessage = '保存に失敗しました' }
    finally { busy = false }
  }

  onMount(() => {
    refreshHealth(); refreshStatus(); refreshAccount(); refreshBoard(); refreshIndices(); refreshWatchlist(); refreshSchedule(); refreshLogs()
    const t1 = setInterval(refreshHealth, 3000)
    const t2 = setInterval(refreshStatus, 1000)
    const t3 = setInterval(refreshAccount, 5000)
    const t4 = setInterval(refreshBoard, 2000)
    const t5 = setInterval(refreshIndices, 10000)
    const t6 = setInterval(refreshWatchlist, 15000)
    const t7 = setInterval(refreshLogs, 2000)
    return () => { clearInterval(t1); clearInterval(t2); clearInterval(t3); clearInterval(t4); clearInterval(t5); clearInterval(t6); clearInterval(t7) }
  })
</script>

<div class="app-shell">
  <Sidebar
    running={status.running} {busy} {secretsMessage} {scheduledTime}
    bind:symbolInput bind:quantityInput bind:apiPassword bind:orderPassword bind:scheduleTimeInput
    on:start={start} on:stop={stop} on:forceClose={forceClose}
    on:updateConfig={updateConfig} on:applySecrets={applySecrets} on:saveSecrets={saveSecrets}
    on:scheduleStart={scheduleStart} on:cancelSchedule={cancelSchedule}
  />

  <div class="main-area">
    <MarketTicker {indices} {board} symbol={status.symbol} {symbolName} />
    <StatusBar
      running={status.running}
      symbol={status.symbol}
      {symbolName}
      lastPrice={board && board.current_price != null ? board.current_price : status.last_price}
      plTotal={account.positions_pl_total}
      lastUpdate={status.last_update}
      {backendOk}
    />

    <main class="main">
      <ErrorBanner lastError={status.last_error} />

      <section class="hero-zone">
        <PLCard
          plTotal={account.positions_pl_total}
          walletCash={account.wallet_cash}
          walletMargin={account.wallet_margin}
        />
        <PositionsCard
          positions={account.positions || account.all_positions || []}
          symbol={status.symbol}
        />
      </section>

      <section class="secondary-zone">
        <PriceCard {board} />
        <SignalPanel lastSignal={status.last_signal} />
      </section>

      <WatchlistCard {watchlist} />

      <section class="bottom-zone">
        <OrdersTable orders={account.orders || []} symbol={status.symbol} />
        <LogPanel {logs} />
      </section>
    </main>
  </div>
</div>

<style>
  .app-shell {
    display: grid;
    grid-template-columns: 220px 1fr;
    min-height: 100vh;
  }

  .main-area {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  .main {
    flex: 1;
    padding: 20px 24px;
    display: grid;
    gap: 16px;
    align-content: start;
  }

  .hero-zone {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .secondary-zone {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }

  .bottom-zone {
    display: grid;
    gap: 16px;
  }

  @media (max-width: 980px) {
    .app-shell {
      grid-template-columns: 1fr;
    }
    .hero-zone,
    .secondary-zone {
      grid-template-columns: 1fr;
    }
  }
</style>
