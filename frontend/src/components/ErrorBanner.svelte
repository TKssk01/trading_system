<script>
  export let lastError = null
</script>

{#if lastError}
  <div class="error-banner">
    <span class="error-icon">!</span>
    <span class="error-text">{lastError}</span>
  </div>
{/if}

<style>
  .error-banner {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    background: var(--loss-bg);
    border: 1px solid rgba(255, 71, 87, 0.3);
    border-radius: var(--radius-md);
    color: var(--loss);
    font-size: 13px;
  }

  .error-icon {
    width: 24px; height: 24px;
    border-radius: 50%;
    background: var(--loss);
    color: #fff;
    display: grid;
    place-items: center;
    font-weight: 700;
    font-size: 14px;
    flex-shrink: 0;
  }

  .error-text {
    font-family: "SF Mono", "Menlo", monospace;
    font-size: 12px;
    word-break: break-all;
  }
</style>
