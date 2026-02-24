<script>
  import { createEventDispatcher } from 'svelte'

  export let running = false
  export let busy = false
  export let secretsMessage = ''
  export let scheduledTime = null

  export let symbolInput = ''
  export let quantityInput = ''
  export let apiPassword = ''
  export let orderPassword = ''
  export let scheduleTimeInput = '09:00'

  const dispatch = createEventDispatcher()
</script>

<aside class="sidebar">
  <div class="brand">
    <div class="brand-mark">SP</div>
    <div>
      <div class="brand-title">Sphere</div>
      <div class="brand-sub">v3.0</div>
    </div>
  </div>

  <div class="nav-block">
    <div class="nav-title">操作</div>
    <div class="controls">
      <label for="symbol">銘柄</label>
      <input id="symbol" bind:value={symbolInput} placeholder="1579" />
      <label for="quantity">数量</label>
      <input id="quantity" bind:value={quantityInput} type="number" min="1" />
      <button class="btn-secondary" on:click={() => dispatch('updateConfig')} disabled={busy}>設定反映</button>
      {#if running}
        <button class="btn-secondary" on:click={() => dispatch('stop')} disabled={busy}>停止</button>
      {:else}
        <button class="btn-primary" on:click={() => dispatch('start')} disabled={busy}>開始</button>
      {/if}
      <button class="btn-danger" on:click={() => dispatch('forceClose')} disabled={busy}>強制決済</button>

      <div class="schedule-section">
        <label for="scheduleTime">予約開始</label>
        {#if scheduledTime}
          <div class="schedule-active">
            <span class="schedule-badge">{scheduledTime} に開始予定</span>
            <button class="btn-cancel" on:click={() => dispatch('cancelSchedule')} disabled={busy}>取消</button>
          </div>
        {:else}
          <div class="schedule-row">
            <input id="scheduleTime" type="time" bind:value={scheduleTimeInput} />
            <button class="btn-schedule" on:click={() => dispatch('scheduleStart', { time: scheduleTimeInput })} disabled={busy || running}>予約</button>
          </div>
        {/if}
      </div>
    </div>
  </div>

  <div class="nav-block">
    <div class="nav-title">認証情報</div>
    <div class="controls">
      <label for="apiPw">APIパスワード</label>
      <input id="apiPw" bind:value={apiPassword} type="password" placeholder="API Password" />
      <label for="orderPw">注文パスワード</label>
      <input id="orderPw" bind:value={orderPassword} type="password" placeholder="Order Password" />
      <button class="btn-secondary" on:click={() => dispatch('applySecrets')} disabled={busy}>一時適用</button>
      <button class="btn-primary" on:click={() => dispatch('saveSecrets')} disabled={busy}>.envに保存</button>
      {#if secretsMessage}
        <div class="hint">{secretsMessage}</div>
      {/if}
    </div>
  </div>
</aside>

<style>
  .sidebar {
    background: linear-gradient(180deg, var(--bg-1) 0%, var(--bg-0) 100%);
    padding: 20px;
    border-right: 1px solid var(--border);
    position: sticky;
    top: 0;
    height: 100vh;
    overflow: auto;
  }

  .brand {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 24px;
  }
  .brand-mark {
    width: 40px; height: 40px;
    border-radius: var(--radius-md);
    display: grid;
    place-items: center;
    font-weight: 700;
    background: linear-gradient(135deg, var(--accent), var(--profit));
    color: var(--bg-0);
  }
  .brand-title { font-size: 16px; font-weight: 600; }
  .brand-sub { font-size: 11px; color: var(--text-3); }

  .nav-block {
    margin-bottom: 16px;
    padding: 14px;
    background: rgba(17, 22, 32, 0.8);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
  }
  .nav-title {
    font-size: 11px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--text-3);
    margin-bottom: 10px;
  }

  .controls { display: grid; gap: 8px; }
  .controls label {
    font-size: 11px;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--text-3);
  }

  .btn-primary {
    background: linear-gradient(135deg, var(--accent), #5a6cff);
    color: #fff;
    box-shadow: 0 8px 16px rgba(20, 60, 120, 0.3);
  }
  .btn-secondary {
    background: var(--bg-2);
    color: var(--text-1);
  }
  .btn-danger {
    background: var(--loss);
    color: #fff;
  }

  .hint {
    font-size: 12px;
    color: var(--text-2);
    margin-top: 4px;
  }

  .schedule-section {
    margin-top: 8px;
    padding-top: 10px;
    border-top: 1px solid var(--border);
  }

  .schedule-row {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 6px;
    margin-top: 6px;
  }
  .schedule-row input[type="time"] {
    font-size: 14px;
    padding: 6px 8px;
  }

  .btn-schedule {
    background: var(--accent-glow);
    color: var(--accent);
    font-size: 12px;
    font-weight: 600;
    padding: 6px 12px;
    white-space: nowrap;
  }

  .schedule-active {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 6px;
  }
  .schedule-badge {
    font-size: 12px;
    font-weight: 600;
    color: var(--accent);
    background: var(--accent-glow);
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    flex: 1;
  }
  .btn-cancel {
    background: var(--bg-2);
    color: var(--text-2);
    font-size: 11px;
    padding: 4px 10px;
  }
</style>
