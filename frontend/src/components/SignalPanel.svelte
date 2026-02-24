<script>
  export let lastSignal = null

  const MAX = 6
  $: signals = [
    { label: '買い', key: 'buy', value: lastSignal?.buy ?? 0, cls: 'buy' },
    { label: '売り', key: 'sell', value: lastSignal?.sell ?? 0, cls: 'sell' },
    { label: '買決済', key: 'buy_exit', value: lastSignal?.buy_exit ?? 0, cls: 'profit' },
    { label: '売決済', key: 'sell_exit', value: lastSignal?.sell_exit ?? 0, cls: 'loss' },
  ]
  $: emergencyBuy = lastSignal?.emergency_buy_exit ?? 0
  $: emergencySell = lastSignal?.emergency_sell_exit ?? 0
</script>

<div class="card">
  <h3>シグナル</h3>
  <div class="signal-list">
    {#each signals as sig}
      <div class="signal-row">
        <span class="signal-label">{sig.label}</span>
        <div class="bar-track">
          <div class="bar-fill {sig.cls}" style="width: {(sig.value / MAX) * 100}%"></div>
        </div>
        <span class="signal-value tabular {sig.cls}">{sig.value}</span>
      </div>
    {/each}
  </div>
  {#if emergencyBuy > 0 || emergencySell > 0}
    <div class="emergency">
      {#if emergencyBuy > 0}
        <span class="emergency-badge">緊急買決済 {emergencyBuy}</span>
      {/if}
      {#if emergencySell > 0}
        <span class="emergency-badge">緊急売決済 {emergencySell}</span>
      {/if}
    </div>
  {/if}
</div>

<style>
  .card {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
    min-height: 240px;
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

  .signal-list { display: grid; gap: 10px; }

  .signal-row {
    display: grid;
    grid-template-columns: 52px 1fr 28px;
    align-items: center;
    gap: 10px;
  }
  .signal-label {
    font-size: 12px;
    color: var(--text-2);
  }

  .bar-track {
    height: 8px;
    background: var(--bg-2);
    border-radius: 4px;
    overflow: hidden;
  }
  .bar-fill {
    height: 100%;
    border-radius: 4px;
    transition: width 0.3s ease;
  }
  .bar-fill.buy { background: var(--buy); }
  .bar-fill.sell { background: var(--sell); }
  .bar-fill.profit { background: var(--profit); }
  .bar-fill.loss { background: var(--loss); }

  .signal-value {
    font-size: 16px;
    font-weight: 700;
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
  .signal-value.buy { color: var(--buy); }
  .signal-value.sell { color: var(--sell); }
  .signal-value.profit { color: var(--profit); }
  .signal-value.loss { color: var(--loss); }

  .emergency {
    margin-top: 12px;
    padding-top: 10px;
    border-top: 1px solid var(--border);
    display: flex;
    gap: 8px;
  }
  .emergency-badge {
    font-size: 11px;
    font-weight: 700;
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    background: var(--warning-bg);
    color: var(--warning);
  }
</style>
