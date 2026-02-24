<script>
  import { fmtNumber, fmtPL, fmtPercent, plClass, sideLabel, sideClass } from '../lib/format.js'

  export let positions = []
  export let symbol = ''
</script>

<div class="card">
  <h3>ポジション</h3>
  {#if positions && positions.length}
    <div class="table-header">
      <span>方向</span>
      <span>数量</span>
      <span>建値</span>
      <span>現在値</span>
      <span>損益</span>
      <span>損益率</span>
    </div>
    {#each positions as pos}
      <div class="pos-row {plClass(pos.ProfitLoss)}">
        <span class="side {sideClass(pos.Side)}">{sideLabel(pos.Side)}</span>
        <span class="tabular">{pos.LeavesQty || pos.Qty}</span>
        <span class="tabular">{fmtNumber(pos.Price)}</span>
        <span class="tabular">{fmtNumber(pos.CurrentPrice)}</span>
        <span class="pl tabular {plClass(pos.ProfitLoss)}">{fmtPL(pos.ProfitLoss)}</span>
        <span class="pl tabular {plClass(pos.ProfitLossRate)}">{fmtPercent(pos.ProfitLossRate)}</span>
      </div>
    {/each}
  {:else}
    <div class="empty">ポジションなし</div>
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
    grid-template-columns: 60px 50px 1fr 1fr 1fr 80px;
    gap: 8px;
    padding: 6px 8px;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
    border-bottom: 1px solid var(--border);
  }

  .pos-row {
    display: grid;
    grid-template-columns: 60px 50px 1fr 1fr 1fr 80px;
    gap: 8px;
    padding: 8px;
    font-size: 13px;
    border-radius: var(--radius-sm);
    transition: background 0.15s ease;
  }
  .pos-row.profit { background: var(--profit-bg); }
  .pos-row.loss { background: var(--loss-bg); }
  .pos-row:hover { background: var(--bg-2); }

  .side {
    font-weight: 700;
    font-size: 12px;
  }
  .side.buy { color: var(--buy); }
  .side.sell { color: var(--sell); }

  .pl.profit { color: var(--profit); font-weight: 600; }
  .pl.loss { color: var(--loss); font-weight: 600; }
  .pl.neutral { color: var(--text-2); }

  .empty {
    padding: 32px;
    text-align: center;
    color: var(--text-3);
    font-size: 14px;
  }
</style>
