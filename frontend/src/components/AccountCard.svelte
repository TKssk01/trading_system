<script>
  import { fmtNumber } from '../lib/format.js'

  export let walletCash = null
  export let walletMargin = null

  $: cashAmount = walletCash?.StockAccountWallet ?? null
  $: marginAmount = walletMargin?.MarginAccountWallet ?? null
</script>

<div class="card">
  <h3>口座サマリ</h3>
  <div class="account-item">
    <span class="account-label">現物買付可能額</span>
    <span class="account-value tabular">{fmtNumber(cashAmount)}</span>
  </div>
  <div class="account-item">
    <span class="account-label">信用新規可能額</span>
    <span class="account-value tabular">{fmtNumber(marginAmount)}</span>
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
    margin: 0 0 16px;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-3);
  }

  .account-item {
    margin-bottom: 16px;
  }
  .account-label {
    display: block;
    font-size: 11px;
    color: var(--text-3);
    margin-bottom: 4px;
  }
  .account-value {
    font-size: 24px;
    font-weight: 600;
    color: var(--text-1);
    font-variant-numeric: tabular-nums;
  }
</style>
