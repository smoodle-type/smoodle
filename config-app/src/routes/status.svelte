<script lang="ts">
  import { onMount } from 'svelte';
  import { api, type SmoodleStatus, type DictCounts, type TelemetryState } from '$lib/api';

  let status = $state<SmoodleStatus | null>(null);
  let counts = $state<DictCounts | null>(null);
  let log = $state<string>('');
  let telState = $state<TelemetryState | null>(null);
  let toast = $state<{ msg: string; type: 'ok' | 'err' } | null>(null);

  async function load() {
    try {
      const [s, c, l, t] = await Promise.all([
        api.smoodleRunning(),
        api.dictCounts(),
        api.schemaCompileLog(),
        api.telemetryState(),
      ]);
      status = s; counts = c; log = l; telState = t;
    } catch (e) {
      toast = { msg: `Load failed: ${e}`, type: 'err' };
    }
  }

  async function toggleTelemetry(ev: Event) {
    const checked = (ev.target as HTMLInputElement).checked;
    try {
      await api.telemetrySetOptIn(checked, null);
      telState = await api.telemetryState();
    } catch (e) {
      toast = { msg: `Telemetry update failed: ${e}`, type: 'err' };
    }
  }

  async function forgetTelemetry() {
    try {
      const deleted = await api.telemetryForget();
      toast = { msg: `Deleted ${deleted} telemetry record(s) ✓`, type: 'ok' };
    } catch (e) {
      toast = { msg: `No install_id — nothing to forget`, type: 'err' };
    }
  }

  onMount(load);
</script>

<div class="status">
  <h2>Status</h2>

  <section>
    <div>
      Smoodle:
      {#if status}
        <span class="indicator {status.running ? 'on' : 'off'}">
          {status.running ? 'running ✓' : 'not running ✗'}
        </span>
      {:else}
        <span>loading…</span>
      {/if}
    </div>
    <div>Version: {status?.version ?? '—'}</div>
  </section>

  <section>
    {#if counts}
      <div>Dictionary: {counts.total} words ({counts.base} base + {counts.user} user)</div>
    {:else}
      <div>Dictionary: loading…</div>
    {/if}
  </section>

  <section>
    <div>Last deploy log (5 lines):</div>
    <pre>{log}</pre>
  </section>

  <section>
    <h3>Telemetry</h3>
    {#if telState}
      <label>
        <input type="checkbox" checked={telState.enabled} onchange={toggleTelemetry} />
        Send anonymous telemetry
      </label>
      <div>Install ID present: {telState.has_install_id ? 'yes' : 'no'}</div>
      <div>Bearer token saved: {telState.has_token ? 'yes' : 'no'}</div>
    {/if}
    <button onclick={forgetTelemetry}>Delete my telemetry data</button>
  </section>

  {#if toast}
    <div class="toast {toast.type}">{toast.msg}</div>
  {/if}
</div>

<!--
  Styles intentionally moved to src/app.css (global). svelte-vite-plugin
  v5 + Vite 6 has a known PartialEnvironment proxy error when preprocessing
  scoped <style> blocks inside vitest. Global CSS sidesteps it. Restore the
  scoped <style> when upstream issue resolves.
-->
