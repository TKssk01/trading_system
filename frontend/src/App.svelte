<script>
  import { onMount } from 'svelte'

  let status = {
    running: false,
    symbol: '',
    quantity: 0,
    last_price: null,
    last_signal: null,
    last_error: null,
    last_update: null,
    positions: []
  }
  let account = {
    wallet_cash: null,
    wallet_margin: null,
    positions_pl_total: null,
    orders: []
  }
  let logs = []
  let symbolInput = ''
  let quantityInput = ''
  let busy = false
  let apiPassword = ""
  let orderPassword = ""
  let secretsMessage = ""
  let backendOk = null
  let backendMessage = ''

  async function fetchJson(url, options) {
    const res = await fetch(url, options)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    return res.json()
  }

  async function refreshHealth() {
    try {
      await fetchJson('/api/health')
      backendOk = true
      backendMessage = ''
    } catch (e) {
      backendOk = false
      backendMessage = 'バックエンドに接続できません'
    }
  }

  async function refreshStatus() {
    try {
      const data = await fetchJson('/api/status')
      status = data
      if (!symbolInput) symbolInput = status.symbol || ''
      if (!quantityInput) quantityInput = status.quantity ? String(status.quantity) : ''
    } catch (e) {
      status.last_error = 'status fetch failed'
    }
  }

  async function refreshAccount() {
    try {
      const data = await fetchJson('/api/account')
      account = data
    } catch (e) {
      account = { wallet_cash: null, wallet_margin: null, positions_pl_total: null, orders: [] }
    }
  }

  async function refreshLogs() {
    try {
      const data = await fetchJson('/api/logs?limit=200')
      logs = data.logs || []
    } catch (e) {
      logs = logs
    }
  }

  async function updateConfig() {
    busy = true
    try {
      await fetchJson('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          symbol: symbolInput || null,
          quantity: quantityInput ? Number(quantityInput) : null
        })
      })
      await refreshStatus()
      await refreshAccount()
    } finally {
      busy = false
    }
  }

  async function start() {
    busy = true
    try {
      await updateConfig()
      await fetchJson('/api/start', { method: 'POST' })
      await refreshStatus()
    } finally {
      busy = false
    }
  }

  async function stop() {
    busy = true
    try {
      await fetchJson('/api/stop', { method: 'POST' })
      await refreshStatus()
    } finally {
      busy = false
    }
  }

  
  async function saveSecrets(save) {
    busy = true
    try {
      await fetchJson('/api/secrets', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_password: apiPassword || null,
          order_password: orderPassword || null,
          save: !!save
        })
      })
      secretsMessage = save ? '.envに保存しました' : '一時適用しました'
      await refreshAccount()
    } catch (e) {
      secretsMessage = '保存に失敗しました'
    } finally {
      busy = false
    }
  }

  async function forceClose() {
    busy = true
    try {
      await fetchJson('/api/force_close', { method: 'POST' })
      await refreshStatus()
      await refreshAccount()
    } finally {
      busy = false
    }
  }

  function fmtNumber(value) {
    if (value === null || value === undefined) return '-'
    try {
      return Number(value).toLocaleString('ja-JP')
    } catch {
      return value
    }
  }

  onMount(() => {
    refreshHealth()
    refreshStatus()
    refreshAccount()
    refreshLogs()
    const healthTimer = setInterval(refreshHealth, 3000)
    const statusTimer = setInterval(refreshStatus, 1000)
    const accountTimer = setInterval(refreshAccount, 5000)
    const logTimer = setInterval(refreshLogs, 2000)
    return () => {
      clearInterval(healthTimer)
      clearInterval(statusTimer)
      clearInterval(accountTimer)
      clearInterval(logTimer)
    }
  })
</script>

<div class="app-shell">
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">SP</div>
      <div>
        <div class="brand-title">Sphere</div>
        <div class="brand-sub">v3.0 ローカルUI</div>
      </div>
    </div>

    <div class="nav-block">
      <div class="nav-title">接続状態</div>
      <div class={`status-pill ${backendOk === true ? 'ok' : backendOk === false ? 'ng' : ''}`}>
        {#if backendOk === true}
          バックエンド接続OK
        {:else if backendOk === false}
          バックエンド未接続
        {:else}
          確認中...
        {/if}
      </div>
      {#if backendMessage}
        <div class="hint">{backendMessage}</div>
      {/if}
    </div>

    <div class="nav-block">
      <div class="nav-title">運用状態</div>
      <div class={`status-pill ${status.running ? 'ok' : 'ng'}`}>
        {status.running ? '稼働中' : '停止中'}
      </div>
    </div>

    <div class="nav-block">
      <div class="nav-title">操作</div>
      <div class="controls">
        <label for="symbol">銘柄</label>
        <input id="symbol" bind:value={symbolInput} placeholder="1579" />
        <label for="quantity">数量</label>
        <input id="quantity" bind:value={quantityInput} type="number" min="1" />
        <button class="btn-secondary" on:click={updateConfig} disabled={busy}>設定反映</button>
        {#if status.running}
          <button class="btn-secondary" on:click={stop} disabled={busy}>停止</button>
        {:else}
          <button class="btn-primary" on:click={start} disabled={busy}>開始</button>
        {/if}
        <button class="btn-danger" on:click={forceClose} disabled={busy}>強制決済</button>
      </div>
    </div>

    <div class="nav-block">
      <div class="nav-title">認証情報</div>
      <div class="controls">
        <label for="apiPassword">APIパスワード</label>
        <input id="apiPassword" bind:value={apiPassword} type="password" placeholder="API Password" />
        <label for="orderPassword">注文パスワード</label>
        <input id="orderPassword" bind:value={orderPassword} type="password" placeholder="Order Password" />
        <button class="btn-secondary" on:click={() => saveSecrets(false)} disabled={busy}>一時適用</button>
        <button class="btn-primary" on:click={() => saveSecrets(true)} disabled={busy}>.envに保存</button>
        {#if secretsMessage}
          <div class="hint">{secretsMessage}</div>
        {/if}
      </div>
    </div>

  </aside>

  <main class="main">
    <header class="topbar">
      <div class="title">Sphere ダッシュボード</div>
      <div class="time">{status.last_update ? status.last_update.slice(11, 19) : '--:--:--'}</div>
    </header>

    <section class="grid">
      <div class="card">
        <h3>ステータス</h3>
        <div class="row">
          <span>銘柄</span>
          <strong>{status.symbol || '-'}</strong>
        </div>
        <div class="row">
          <span>数量</span>
          <strong>{status.quantity || '-'}</strong>
        </div>
        <div class="row">
          <span>最新価格</span>
          <strong>{status.last_price ?? '-'}</strong>
        </div>
        <div class="row">
          <span>最終更新</span>
          <strong>{status.last_update ? status.last_update.slice(0, 19).replace('T',' ') : '-'}</strong>
        </div>
      </div>

      <div class="card">
        <h3>口座サマリ</h3>
        <div class="row">
          <span>現物買付可能額</span>
          <strong>{fmtNumber(account.wallet_cash?.StockAccountWallet)}</strong>
        </div>
        <div class="row">
          <span>信用新規可能額</span>
          <strong>{fmtNumber(account.wallet_margin?.MarginAccountWallet)}</strong>
        </div>
        <div class="row">
          <span>評価損益合計</span>
          <strong>{fmtNumber(account.positions_pl_total)}</strong>
        </div>
      </div>

      <div class="card">
        <h3>シグナル</h3>
        <div class="row">
          <span>買い</span>
          <strong>{status.last_signal?.buy ?? 0}</strong>
        </div>
        <div class="row">
          <span>売り</span>
          <strong>{status.last_signal?.sell ?? 0}</strong>
        </div>
        <div class="row">
          <span>買い決済</span>
          <strong>{status.last_signal?.buy_exit ?? 0}</strong>
        </div>
        <div class="row">
          <span>売り決済</span>
          <strong>{status.last_signal?.sell_exit ?? 0}</strong>
        </div>
      </div>

      <div class="card">
        <h3>ポジション</h3>
        {#if status.positions && status.positions.length}
          {#each status.positions as pos}
            <div class="row">
              <span>{pos.Symbol || status.symbol}</span>
              <strong>{pos.Side === '2' ? 'BUY' : 'SELL'} {pos.LeavesQty || pos.Qty}</strong>
            </div>
          {/each}
        {:else}
          <div class="hint">ポジションなし</div>
        {/if}
      </div>

      <div class="card wide">
        <h3>チャート</h3>
        <div class="chart-placeholder">チャート準備中</div>
      </div>
    </section>

    <section class="card logs">
      <h3>注文履歴</h3>
      {#if account.orders && account.orders.length}
        <div class="table">
          {#each account.orders.slice(0, 10) as order}
            <div class="row table-row">
              <span>{order.Symbol || status.symbol}</span>
              <span>{order.Side === '2' ? 'BUY' : 'SELL'}</span>
              <span>{order.Qty || '-'}</span>
              <span>{order.Price || '-'}</span>
              <span>{order.RecvTime || order.OrderTime || '-'}</span>
            </div>
          {/each}
        </div>
      {:else}
        <div class="hint">注文履歴なし</div>
      {/if}
    </section>

    <section class="card logs">
      <h3>ログ</h3>
      <div class="log">{(logs && logs.length) ? logs.join('\n') : 'ログはまだありません'}</div>
    </section>

    {#if status.last_error}
      <section class="card alert">
        <h3>エラー</h3>
        <div class="log">{status.last_error}</div>
      </section>
    {/if}
  </main>
</div>
