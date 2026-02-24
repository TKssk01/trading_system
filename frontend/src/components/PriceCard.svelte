<script>
  import { fmtNumber, fmtPercent, plClass } from '../lib/format.js'

  export let board = null
</script>

<div class="card">
  <h3>マーケット</h3>
  {#if board && board.current_price != null}
    <div class="price-main">
      <span class="current-price">{fmtNumber(board.current_price)}</span>
      <span class="change {plClass(board.change)}">
        {board.change >= 0 ? '+' : ''}{fmtNumber(board.change)}
        ({fmtPercent(board.change_pct)})
      </span>
    </div>
    <div class="price-grid">
      <div class="item">
        <span class="label">始値</span>
        <span class="val">{fmtNumber(board.opening_price)}</span>
      </div>
      <div class="item">
        <span class="label">高値</span>
        <span class="val high">{fmtNumber(board.high_price)}</span>
      </div>
      <div class="item">
        <span class="label">安値</span>
        <span class="val low">{fmtNumber(board.low_price)}</span>
      </div>
      <div class="item">
        <span class="label">前日終値</span>
        <span class="val">{fmtNumber(board.previous_close)}</span>
      </div>
      <div class="item">
        <span class="label">出来高</span>
        <span class="val">{fmtNumber(board.trading_volume)}</span>
      </div>
      <div class="item">
        <span class="label">VWAP</span>
        <span class="val">{board.vwap ? board.vwap.toFixed(2) : '-'}</span>
      </div>
    </div>
    <div class="spread">
      <div class="bid">
        <span class="label">売気配</span>
        <span class="val">{fmtNumber(board.bid_price)}</span>
        <span class="qty">x{fmtNumber(board.bid_qty)}</span>
      </div>
      <div class="ask">
        <span class="label">買気配</span>
        <span class="val">{fmtNumber(board.ask_price)}</span>
        <span class="qty">x{fmtNumber(board.ask_qty)}</span>
      </div>
    </div>
  {:else}
    <div class="empty">市場データなし（閉場中）</div>
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

  .price-main {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 16px;
  }
  .current-price {
    font-size: 32px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
    color: var(--text-1);
  }
  .change {
    font-size: 14px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .change.profit { color: var(--profit); }
  .change.loss { color: var(--loss); }
  .change.neutral { color: var(--text-3); }

  .price-grid {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 12px;
    margin-bottom: 16px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border);
  }

  .item {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .label {
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--text-3);
  }
  .val {
    font-size: 14px;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
    color: var(--text-2);
  }
  .val.high { color: var(--loss); }
  .val.low { color: var(--buy); }

  .spread {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .bid, .ask {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .qty {
    font-size: 11px;
    color: var(--text-3);
    font-variant-numeric: tabular-nums;
  }

  .empty {
    padding: 24px;
    text-align: center;
    color: var(--text-3);
    font-size: 13px;
  }
</style>
