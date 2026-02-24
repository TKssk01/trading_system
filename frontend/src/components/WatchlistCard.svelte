<script>
  import { fmtNumber, plClass } from '../lib/format.js'

  export let watchlist = []
</script>

<div class="card">
  <h3>ウォッチリスト</h3>
  {#if watchlist && watchlist.length}
    <div class="table-header">
      <span>コード</span>
      <span>銘柄名</span>
      <span class="right">現在値</span>
      <span class="right">前日比</span>
      <span class="right">騰落率</span>
    </div>
    <div class="table-body">
      {#each watchlist as item}
        <div class="row">
          <span class="code">{item.code}</span>
          <span class="name">{item.name}</span>
          <span class="right tabular">{item.price != null ? fmtNumber(item.price) : '-'}</span>
          <span class="right tabular {plClass(item.change)}">
            {item.change != null ? (item.change >= 0 ? '+' : '') + fmtNumber(item.change) : '-'}
          </span>
          <span class="right tabular {plClass(item.change_pct)}">
            {item.change_pct != null ? (item.change_pct >= 0 ? '+' : '') + item.change_pct.toFixed(2) + '%' : '-'}
          </span>
        </div>
      {/each}
    </div>
  {:else}
    <div class="empty">データ取得中...</div>
  {/if}
</div>

<style>
  .card {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
    min-height: 200px;
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
    grid-template-columns: 56px 1fr 80px 80px 70px;
    gap: 8px;
    padding: 6px 8px;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
    border-bottom: 1px solid var(--border);
  }

  .table-body {
    max-height: 400px;
    overflow-y: auto;
  }

  .row {
    display: grid;
    grid-template-columns: 56px 1fr 80px 80px 70px;
    gap: 8px;
    padding: 6px 8px;
    font-size: 12px;
    color: var(--text-2);
    border-radius: var(--radius-sm);
  }
  .row:nth-child(even) { background: rgba(255, 255, 255, 0.02); }
  .row:hover { background: var(--bg-2); }

  .code { color: var(--text-3); font-variant-numeric: tabular-nums; }
  .name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .right { text-align: right; }
  .tabular { font-variant-numeric: tabular-nums; }

  .profit { color: var(--profit); }
  .loss { color: var(--loss); }
  .neutral { color: var(--text-3); }

  .empty {
    padding: 24px;
    text-align: center;
    color: var(--text-3);
    font-size: 13px;
  }
</style>
