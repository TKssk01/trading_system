<script>
  import { fmtNumber, fmtPL, plClass } from '../lib/format.js'

  export let plTotal = null
  export let walletCash = null
  export let walletMargin = null

  $: cashAmount = walletCash?.StockAccountWallet ?? null
  $: marginAmount = walletMargin?.MarginAccountWallet ?? null
  $: plCls = plClass(plTotal)
</script>

<div class="card pl-card {plCls}">
  <h3>評価損益</h3>
  <div class="pl-hero">
    <span class="pl-number tabular">{fmtPL(plTotal)}</span>
    <span class="pl-unit">円</span>
  </div>

  <div class="wallet-grid">
    <div class="wallet-item">
      <span class="wallet-label">現物買付可能額</span>
      <span class="wallet-value tabular">{fmtNumber(cashAmount)}</span>
    </div>
    <div class="wallet-item">
      <span class="wallet-label">信用新規可能額</span>
      <span class="wallet-value tabular">{fmtNumber(marginAmount)}</span>
    </div>
  </div>
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
    margin: 0 0 8px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-3);
  }

  .pl-hero {
    display: flex;
    align-items: baseline;
    gap: 6px;
    margin-bottom: 20px;
  }
  .pl-number {
    font-size: 42px;
    font-weight: 700;
    line-height: 1;
    font-variant-numeric: tabular-nums;
  }
  .pl-unit {
    font-size: 14px;
    color: var(--text-3);
  }

  .pl-card.profit .pl-number { color: var(--profit); }
  .pl-card.profit { background: var(--profit-bg); border-color: rgba(0, 212, 170, 0.2); }
  .pl-card.loss .pl-number { color: var(--loss); }
  .pl-card.loss { background: var(--loss-bg); border-color: rgba(255, 71, 87, 0.2); }
  .pl-card.neutral .pl-number { color: var(--text-1); }

  .wallet-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
  }
  .wallet-label {
    display: block;
    font-size: 11px;
    color: var(--text-3);
    margin-bottom: 4px;
  }
  .wallet-value {
    font-size: 22px;
    font-weight: 600;
    color: var(--text-1);
    font-variant-numeric: tabular-nums;
  }
</style>
