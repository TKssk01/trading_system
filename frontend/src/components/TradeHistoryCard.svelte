<script>
  import { onMount, onDestroy } from 'svelte'
  import { Chart, registerables } from 'chart.js'

  Chart.register(...registerables)

  export let timeline = []
  export let dailyPl = []
  export let stats = {}

  let canvasEl
  let chart
  let viewMode = 'today' // 'today' or 'daily'

  function formatYen(v) {
    if (v == null) return '-'
    const sign = v >= 0 ? '+' : ''
    return sign + Math.round(v).toLocaleString() + '円'
  }

  function buildChart() {
    if (!canvasEl) return
    if (chart) chart.destroy()

    const isToday = viewMode === 'today'
    const data = isToday ? timeline : dailyPl
    if (!data || data.length === 0) {
      chart = null
      return
    }

    const labels = data.map(d => {
      if (isToday) {
        const t = d.timestamp || ''
        const m = t.match(/T(\d{2}:\d{2})/)
        return m ? m[1] : t.slice(11, 16)
      }
      return (d.date || '').slice(5) // MM-DD
    })
    const values = data.map(d => d.pl_total || 0)

    const ctx = canvasEl.getContext('2d')
    const gradient = ctx.createLinearGradient(0, 0, 0, canvasEl.height)
    const lastVal = values[values.length - 1] || 0
    if (lastVal >= 0) {
      gradient.addColorStop(0, 'rgba(0, 212, 170, 0.3)')
      gradient.addColorStop(1, 'rgba(0, 212, 170, 0.02)')
    } else {
      gradient.addColorStop(0, 'rgba(255, 75, 85, 0.3)')
      gradient.addColorStop(1, 'rgba(255, 75, 85, 0.02)')
    }

    chart = new Chart(canvasEl, {
      type: 'line',
      data: {
        labels,
        datasets: [{
          data: values,
          borderColor: lastVal >= 0 ? '#00d4aa' : '#ff4b55',
          backgroundColor: gradient,
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: isToday ? 0 : 3,
          pointHoverRadius: 4,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => formatYen(ctx.raw)
            }
          }
        },
        scales: {
          x: {
            ticks: { color: '#6b7a99', maxTicksLimit: 8, font: { size: 10 } },
            grid: { color: 'rgba(107, 122, 153, 0.1)' }
          },
          y: {
            ticks: {
              color: '#6b7a99',
              font: { size: 10 },
              callback: (v) => (v >= 0 ? '+' : '') + Math.round(v).toLocaleString()
            },
            grid: { color: 'rgba(107, 122, 153, 0.15)' }
          }
        },
        interaction: { intersect: false, mode: 'index' }
      }
    })
  }

  $: if (canvasEl && (timeline || dailyPl)) buildChart()

  onDestroy(() => { if (chart) chart.destroy() })
</script>

<div class="card">
  <div class="card-header">
    <span class="card-title">損益推移</span>
    <div class="view-toggle">
      <button class:active={viewMode === 'today'} on:click={() => { viewMode = 'today'; buildChart() }}>当日</button>
      <button class:active={viewMode === 'daily'} on:click={() => { viewMode = 'daily'; buildChart() }}>日別</button>
    </div>
  </div>

  <div class="chart-wrap">
    {#if (viewMode === 'today' && timeline.length === 0) || (viewMode === 'daily' && dailyPl.length === 0)}
      <div class="empty">取引データなし</div>
    {/if}
    <canvas bind:this={canvasEl}></canvas>
  </div>

  {#if stats && stats.trading_days > 0}
    <div class="stats-row">
      <div class="stat">
        <span class="stat-label">勝率</span>
        <span class="stat-value">{stats.win_rate}%</span>
      </div>
      <div class="stat">
        <span class="stat-label">取引日数</span>
        <span class="stat-value">{stats.trading_days}日</span>
      </div>
      <div class="stat">
        <span class="stat-label">累計損益</span>
        <span class="stat-value" class:profit={stats.total_pl > 0} class:loss={stats.total_pl < 0}>{formatYen(stats.total_pl)}</span>
      </div>
      <div class="stat">
        <span class="stat-label">日平均</span>
        <span class="stat-value" class:profit={stats.avg_daily_pl > 0} class:loss={stats.avg_daily_pl < 0}>{formatYen(stats.avg_daily_pl)}</span>
      </div>
    </div>
  {/if}
</div>

<style>
  .card {
    background: var(--bg-1);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 16px;
    min-height: 280px;
  }
  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }
  .card-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-1);
  }
  .view-toggle {
    display: flex;
    gap: 4px;
  }
  .view-toggle button {
    font-size: 11px;
    padding: 4px 10px;
    border-radius: var(--radius-sm);
    background: var(--bg-2);
    color: var(--text-3);
    border: none;
    cursor: pointer;
  }
  .view-toggle button.active {
    background: var(--accent-glow);
    color: var(--accent);
    font-weight: 600;
  }
  .chart-wrap {
    position: relative;
    height: 180px;
  }
  .empty {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
    color: var(--text-3);
    font-size: 13px;
  }
  .stats-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--border);
  }
  .stat {
    text-align: center;
  }
  .stat-label {
    display: block;
    font-size: 10px;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
  .stat-value {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-1);
  }
  .stat-value.profit { color: var(--profit); }
  .stat-value.loss { color: var(--loss); }
</style>
