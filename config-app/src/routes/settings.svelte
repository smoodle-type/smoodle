<script lang="ts">
  import { onMount } from 'svelte';
  import { api, type DefaultCustomPatch } from '$lib/api';

  let candidateCount = $state<number>(5);
  let schemaList = $state<string[]>([]);
  let deployOnSave = $state(true);
  let toast = $state<{ msg: string; type: 'ok' | 'err' } | null>(null);

  async function load() {
    try {
      const patch = await api.readDefaultCustom();
      candidateCount = patch.candidate_count ?? 5;
      schemaList = patch.schema_list ?? [];
    } catch (e) {
      toast = { msg: `Load failed: ${e}`, type: 'err' };
    }
  }

  function removeSchema(idx: number) {
    schemaList = schemaList.filter((_, i) => i !== idx);
  }

  async function save() {
    try {
      const patch: DefaultCustomPatch = { candidate_count: candidateCount, schema_list: schemaList };
      await api.writeDefaultCustom(patch);
      if (deployOnSave) await api.deploySquirrel();
      toast = { msg: 'Settings saved ✓', type: 'ok' };
    } catch (e) {
      toast = { msg: `Save failed: ${e}`, type: 'err' };
    }
  }

  async function openFolder() {
    try { await api.openRimeFolder(); }
    catch (e) { toast = { msg: `Open failed: ${e}`, type: 'err' }; }
  }

  async function resetDefaults() {
    if (!window.confirm('Reset all settings to defaults?')) return;
    try {
      await api.resetToDefaults();
      await load();
      toast = { msg: 'Reset to defaults ✓', type: 'ok' };
    } catch (e) {
      toast = { msg: `Reset failed: ${e}`, type: 'err' };
    }
  }

  onMount(load);
</script>

<div class="settings">
  <h2>Settings</h2>

  <form onsubmit={(ev) => { ev.preventDefault(); save(); }}>
    <fieldset>
      <legend>Candidate count</legend>
      {#each [3, 5, 9] as n}
        <label>
          <input
            type="radio"
            name="candidate_count"
            value={n}
            checked={candidateCount === n}
            onchange={() => { candidateCount = n; }}
          />
          {n}
        </label>
      {/each}
    </fieldset>

    <fieldset>
      <legend>Schema list</legend>
      <ul>
        {#each schemaList as schema, i}
          <li>
            {schema}
            <button type="button" onclick={() => removeSchema(i)}>Remove</button>
          </li>
        {/each}
      </ul>
    </fieldset>

    <label><input type="checkbox" bind:checked={deployOnSave} /> Deploy on save</label>

    <div class="buttons">
      <button type="button" onclick={openFolder}>Open Rime Folder</button>
      <button type="button" onclick={resetDefaults}>Reset to Defaults</button>
      <button type="submit">Save</button>
    </div>
  </form>

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
