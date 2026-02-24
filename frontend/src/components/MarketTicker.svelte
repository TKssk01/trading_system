<script>
  import { fmtNumber, plClass } from '../lib/format.js'

  export let indices = []
  export let board = null
  export let symbol = ''
  export let symbolName = ''
</script>

<div class="ticker">
  {#each indices as idx}
    <div class="ticker-item">
      <span class="name">{idx.name}</span>
      <span class="price">{idx.price != null ? fmtNumber(idx.price) : '-'}</span>
      {#if idx.change != null}
        <span class="change {plClass(idx.change)}">
          {idx.change >= 0 ? '+' : ''}{fmtNumber(idx.change)}
          ({idx.change_pct >= 0 ? '+' : ''}{idx.change_pct?.toFixed(2)}%)
        </span>
      {/if}
    </div>
  {/each}
  {#if board && board.current_price != null}
    <div class="ticker-item">
      <span class="name">{symbol} {symbolName}</span>
      <span class="price">{fmtNumber(board.current_price)}</span>
      {#if board.change != null}
        <span class="change {plClass(board.change)}">
          {board.change >= 0 ? '+' : ''}{fmtNumber(board.change)}
          ({board.change_pct >= 0 ? '+' : ''}{board.change_pct?.toFixed(2)}%)
        </span>
      {/if}
    </div>
  {/if}
</div>

<style>
  .ticker {
    display: flex;
    align-items: center;
    gap: 24px;
    padding: 6px 24px;
    background: var(--bg-0);
    border-bottom: 1px solid var(--border);
    overflow-x: auto;
  }

  .ticker-item {
    display: flex;
    align-items: center;
    gap: 8px;
    white-space: nowrap;
  }

  .name {
    font-size: 11px;
    color: var(--text-3);
    font-weight: 600;
  }

  .price {
    font-size: 13px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    color: var(--text-1);
  }

  .change {
    font-size: 11px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .change.profit { color: var(--profit); }
  .change.loss { color: var(--loss); }
  .change.neutral { color: var(--text-3); }
</style>
