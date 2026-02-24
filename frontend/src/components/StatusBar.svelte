<script>
  import { fmtNumber, fmtPL, fmtTime, plClass } from '../lib/format.js'

  export let running = false
  export let symbol = ''
  export let symbolName = ''
  export let lastPrice = null
  export let plTotal = null
  export let lastUpdate = null
  export let backendOk = null
</script>

<header class="statusbar" class:running>
  <div class="status-indicator">
    <span class="status-dot" class:pulse={running}></span>
    <span class="status-text">{running ? 'RUNNING' : 'STOPPED'}</span>
  </div>
  <div class="status-item">
    <span class="label">銘柄</span>
    <span class="value">{symbol || '-'}</span>
    {#if symbolName}<span class="symbol-name">{symbolName}</span>{/if}
  </div>
  <div class="status-item">
    <span class="label">現在値</span>
    <span class="value price">{lastPrice != null ? fmtNumber(lastPrice) : '-'}</span>
  </div>
  <div class="status-item">
    <span class="label">評価損益</span>
    <span class="value pl {plClass(plTotal)}">{plTotal != null ? fmtPL(plTotal) : '-'}</span>
  </div>
  <div class="status-item">
    <span class="label">接続</span>
    <span class="conn" class:ok={backendOk === true} class:ng={backendOk === false}>
      {backendOk === true ? 'OK' : backendOk === false ? 'NG' : '...'}
    </span>
  </div>
  <div class="clock tabular">{fmtTime(lastUpdate)}</div>
</header>

<style>
  .statusbar {
    display: flex;
    align-items: center;
    gap: 24px;
    padding: 0 24px;
    height: 48px;
    background: var(--bg-1);
    border-bottom: 1px solid var(--border);
    border-left: 4px solid var(--loss);
  }
  .statusbar.running { border-left-color: var(--profit); }

  .status-indicator {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .status-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    background: var(--loss);
  }
  .status-dot.pulse {
    background: var(--profit);
    animation: pulse 2s ease-in-out infinite;
  }
  @keyframes pulse {
    0%, 100% { box-shadow: 0 0 0 0 rgba(0, 212, 170, 0.4); }
    50% { box-shadow: 0 0 0 6px rgba(0, 212, 170, 0); }
  }
  .status-text {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    color: var(--text-2);
  }

  .status-item {
    display: flex;
    align-items: baseline;
    gap: 6px;
  }
  .label {
    font-size: 11px;
    color: var(--text-3);
  }
  .value {
    font-size: 14px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    color: var(--text-1);
  }
  .value.price { font-size: 18px; }
  .value.pl { font-size: 18px; }
  .value.pl.profit { color: var(--profit); }
  .value.pl.loss { color: var(--loss); }
  .value.pl.neutral { color: var(--neutral); }

  .symbol-name {
    font-size: 12px;
    color: var(--text-3);
    font-weight: 400;
  }

  .conn {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 4px;
  }
  .conn.ok { background: var(--profit-bg); color: var(--profit); }
  .conn.ng { background: var(--loss-bg); color: var(--loss); }

  .clock {
    margin-left: auto;
    font-size: 16px;
    font-weight: 600;
    color: var(--text-2);
    font-variant-numeric: tabular-nums;
  }
</style>
