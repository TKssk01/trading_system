<script>
  export let logs = []

  let expanded = false
</script>

<div class="card">
  <button class="toggle" on:click={() => expanded = !expanded}>
    <h3>ログ</h3>
    <span class="arrow" class:open={expanded}></span>
  </button>
  {#if expanded}
    <div class="log-content">
      {(logs && logs.length) ? logs.join('\n') : 'ログはまだありません'}
    </div>
  {:else}
    <div class="log-preview">
      {#if logs && logs.length}
        {logs.slice(-3).join('\n')}
      {:else}
        ログはまだありません
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
    min-height: 120px;
    transition: border-color 0.15s ease;
  }
  .card:hover { border-color: var(--border-hover); }

  .toggle {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    background: none;
    padding: 0;
    margin: 0 0 8px;
    cursor: pointer;
    border-radius: 0;
    box-shadow: none;
  }
  .toggle:active { transform: none; }

  h3 {
    margin: 0;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--text-3);
  }

  .arrow {
    display: inline-block;
    width: 0; height: 0;
    border-left: 5px solid transparent;
    border-right: 5px solid transparent;
    border-top: 5px solid var(--text-3);
    transition: transform 0.2s ease;
  }
  .arrow.open { transform: rotate(180deg); }

  .log-content, .log-preview {
    font-family: "SF Mono", "Menlo", monospace;
    font-size: 11px;
    white-space: pre-wrap;
    line-height: 1.6;
    color: var(--text-2);
  }
  .log-content {
    max-height: 300px;
    overflow: auto;
  }
  .log-preview {
    max-height: 60px;
    overflow: hidden;
    opacity: 0.7;
  }
</style>
