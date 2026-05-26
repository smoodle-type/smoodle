<script lang="ts">
  import { onMount } from 'svelte';
  import { api, type DictEntry } from '$lib/api';

  let entries = $state<DictEntry[]>([]);
  let newWord = $state('');
  let newRom = $state('');
  let newWeight = $state(100);
  let deployOnSave = $state(true);
  let toast = $state<{ msg: string; type: 'ok' | 'err' } | null>(null);

  async function load() {
    try { entries = await api.readUserDict(); }
    catch (e) { toast = { msg: `Couldn't load user dict: ${e}`, type: 'err' }; }
  }

  async function add() {
    try {
      const t0 = performance.now();
      await api.addUserWord(newWord, newRom, newWeight);
      if (deployOnSave) await api.deploySquirrel();
      const dt = ((performance.now() - t0) / 1000).toFixed(1);
      toast = { msg: `Added '${newWord}' · deployed in ${dt}s ✓`, type: 'ok' };
      newWord = ''; newRom = ''; newWeight = 100;
      await load();
    } catch (e) {
      toast = { msg: `Add failed: ${e}`, type: 'err' };
    }
  }

  async function remove(idx: number) {
    try {
      await api.deleteUserWord(idx);
      if (deployOnSave) await api.deploySquirrel();
      await load();
    } catch (e) { toast = { msg: `Delete failed: ${e}`, type: 'err' }; }
  }

  onMount(load);
</script>

<div class="words">
  <h2>Custom words</h2>
  <table>
    <thead><tr><th>Thai</th><th>Romanization</th><th>Weight</th><th></th></tr></thead>
    <tbody>
      {#each entries as e, i}
        <tr><td>{e.word}</td><td>{e.romanization}</td><td>{e.weight}</td>
          <td><button onclick={() => remove(i)}>Delete</button></td></tr>
      {/each}
    </tbody>
  </table>

  <form onsubmit={(ev) => { ev.preventDefault(); add(); }}>
    <input placeholder="ลีเอ็กซ์" bind:value={newWord} required />
    <input placeholder="lex" bind:value={newRom} required />
    <input type="number" bind:value={newWeight} min="1" max="100000" />
    <button type="submit">Add</button>
  </form>

  <label><input type="checkbox" bind:checked={deployOnSave} /> Deploy on save</label>

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
