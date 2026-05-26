<script lang="ts">
  import { onMount } from 'svelte';
  import Words from './routes/words.svelte';
  import Status from './routes/status.svelte';
  import Settings from './routes/settings.svelte';
  import { api } from './lib/api';

  let active = $state<'words' | 'status' | 'settings'>('words');
  let running = $state(false);
  let version = $state<string | null>(null);

  async function refreshStatus() {
    try {
      const s = await api.smoodleRunning();
      running = s.running;
      version = s.version;
    } catch { /* leave defaults */ }
  }

  onMount(() => {
    refreshStatus();
    const id = setInterval(refreshStatus, 5000);
    return () => clearInterval(id);
  });
</script>

<div class="app">
  <header>
    <h1>Smoodle Config</h1>
    <span class="version">{version ?? '0.0.8b'}</span>
  </header>
  <nav>
    <button class:active={active === 'words'} onclick={() => active = 'words'}>Words</button>
    <button class:active={active === 'status'} onclick={() => active = 'status'}>Status</button>
    <button class:active={active === 'settings'} onclick={() => active = 'settings'}>Settings</button>
  </nav>
  <main>
    {#if active === 'words'}<Words />{/if}
    {#if active === 'status'}<Status />{/if}
    {#if active === 'settings'}<Settings />{/if}
  </main>
  <footer>
    <span class="status-dot" class:on={running}>●</span>
    <span>{running ? 'Smoodle running' : 'Smoodle not running'}</span>
  </footer>
</div>

<!--
  Styles intentionally in src/app.css (global). See words.svelte for
  the Vite 6 + svelte-vite-plugin v5 scoped-style preprocess bug context.
-->
