<script>
  import { fmtNumber, fmtDateTime, fmtPL, plClass } from '../lib/format.js'

  export let trades = []
  export let summary = {}

  const sideLabel = (s) => s === 'buy' ? 'BUY' : 'SELL'
  const sideColor = (s) => s === 'buy' ? 'buy' : 'sell'
  const typeLabel = (t) => {
    const labels = { entry: 'エントリー', exit: '決済', emergency_exit: '損切り', force_close: '強制決済' }
    return labels[t] || t
  }
  const typeClass = (t) => {
    const classes = { entry: 'accent', exit: 'profit', emergency_exit: 'warning', force_close: 'warning' }
    return classes[t] || 'neutral'
  }
</script>

<div class="card">
  <h3>トレード履歴</h3>
  {#if trades && trades.length}
    <div class="table-header">
      <span>時刻</span>
      <span>銘柄</span>
      <span>方向</span>
      <span class="right">数量</span>
      <span class="right">約定価格</span>
      <span>種別</span>
      <span class="right">損益</span>
    </div>
    {#each trades.slice(0, 20) as trade}
      <div class="order-row">
        <span class="time tabular">{fmtDateTime(trade.timestamp)}</span>
        <span>{trade.symbol}</span>
        <span class="side {sideColor(trade.side)}">{sideLabel(trade.side)}</span>
        <span class="tabular right">{trade.quantity}</span>
        <span class="tabular right">{trade.exec_price ? fmtNumber(trade.exec_price) : '-'}</span>
        <span class="type-badge {typeClass(trade.trade_type)}">{typeLabel(trade.trade_type)}</span>
        <span class="tabular right {trade.realized_pl != null ? plClass(trade.realized_pl) : ''}">
          {trade.realized_pl != null ? fmtPL(trade.realized_pl) : '-'}
        </span>
      </div>
    {/each}
    {#if summary.total_realized_pl !== undefined}
      <div class="summary-row">
        <span class="summary-label">累計実現損益</span>
        <span class="summary-value {plClass(summary.total_realized_pl)}">
          {fmtPL(summary.total_realized_pl)}円
        </span>
        {#if summary.win_rate > 0}
          <span class="summary-stat">勝率 {summary.win_rate}%</span>
        {/if}
      </div>
    {/if}
  {:else}
    <div class="empty">トレード履歴なし</div>
  {/if}
</div>

<style>
  .card {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
    min-height: 160px;
    transition: border-color 0.15s ease;
  }
  .card:hover { border-color: var(--border-hover); }

  h3 {
    margin: 0 0 12px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-3);
  }

  .table-header {
    display: grid;
    grid-template-columns: 100px 70px 50px 50px 80px 70px 90px;
    gap: 8px;
    padding: 6px 8px;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
    border-bottom: 1px solid var(--border);
  }

  .order-row {
    display: grid;
    grid-template-columns: 100px 70px 50px 50px 80px 70px 90px;
    gap: 8px;
    padding: 8px;
    font-size: 12px;
    color: var(--text-2);
    border-radius: var(--radius-sm);
  }
  .order-row:nth-child(even) { background: rgba(255, 255, 255, 0.02); }
  .order-row:hover { background: var(--bg-2); }

  .right { text-align: right; }
  .time { color: var(--text-3); }
  .side { font-weight: 700; }
  .side.buy { color: var(--buy); }
  .side.sell { color: var(--sell); }

  .type-badge {
    font-size: 10px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 4px;
    text-align: center;
    white-space: nowrap;
  }
  .type-badge.profit { background: var(--profit-bg); color: var(--profit); }
  .type-badge.warning { background: var(--warning-bg); color: var(--warning); }
  .type-badge.accent { background: var(--accent-glow); color: var(--accent); }
  .type-badge.neutral { background: var(--bg-2); color: var(--text-3); }

  .profit { color: var(--profit); }
  .loss { color: var(--sell); }

  .summary-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 12px 8px 4px;
    margin-top: 8px;
    border-top: 1px solid var(--border);
  }
  .summary-label {
    font-size: 11px;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
  .summary-value {
    font-size: 16px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  .summary-stat {
    font-size: 11px;
    color: var(--text-3);
    margin-left: auto;
  }

  .empty {
    padding: 24px;
    text-align: center;
    color: var(--text-3);
    font-size: 13px;
  }
</style>
