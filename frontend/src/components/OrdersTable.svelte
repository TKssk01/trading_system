<script>
  import { fmtNumber, fmtDateTime, sideLabel, sideClass, orderStateLabel, orderStateClass } from '../lib/format.js'

  export let orders = []
  export let symbol = ''
</script>

<div class="card">
  <h3>注文履歴</h3>
  {#if orders && orders.length}
    <div class="table-header">
      <span>時刻</span>
      <span>銘柄</span>
      <span>方向</span>
      <span>数量</span>
      <span>価格</span>
      <span>状態</span>
    </div>
    {#each orders.slice(0, 15) as order}
      <div class="order-row">
        <span class="time tabular">{fmtDateTime(order.RecvTime || order.OrderTime)}</span>
        <span>{order.Symbol || symbol}</span>
        <span class="side {sideClass(order.Side)}">{sideLabel(order.Side)}</span>
        <span class="tabular">{order.Qty || '-'}</span>
        <span class="tabular">{order.Price ? fmtNumber(order.Price) : '成行'}</span>
        <span class="state-badge {orderStateClass(order.State)}">{orderStateLabel(order.State)}</span>
      </div>
    {/each}
  {:else}
    <div class="empty">注文履歴なし</div>
  {/if}
</div>

<style>
  .card {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
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
    grid-template-columns: 100px 80px 60px 60px 80px 80px;
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
    grid-template-columns: 100px 80px 60px 60px 80px 80px;
    gap: 8px;
    padding: 8px;
    font-size: 12px;
    color: var(--text-2);
    border-radius: var(--radius-sm);
  }
  .order-row:nth-child(even) { background: rgba(255, 255, 255, 0.02); }
  .order-row:hover { background: var(--bg-2); }

  .time { color: var(--text-3); }
  .side { font-weight: 700; }
  .side.buy { color: var(--buy); }
  .side.sell { color: var(--sell); }

  .state-badge {
    font-size: 11px;
    font-weight: 600;
    padding: 2px 8px;
    border-radius: 4px;
    text-align: center;
  }
  .state-badge.profit { background: var(--profit-bg); color: var(--profit); }
  .state-badge.warning { background: var(--warning-bg); color: var(--warning); }
  .state-badge.accent { background: var(--accent-glow); color: var(--accent); }
  .state-badge.neutral { background: var(--bg-2); color: var(--text-3); }

  .empty {
    padding: 24px;
    text-align: center;
    color: var(--text-3);
    font-size: 13px;
  }
</style>
