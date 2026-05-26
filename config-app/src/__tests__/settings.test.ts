import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import Settings from '../routes/settings.svelte';

vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn().mockImplementation((cmd: string) => {
    if (cmd === 'read_default_custom') return Promise.resolve({ candidate_count: 5, schema_list: ['thai_phonetic'] });
    if (cmd === 'write_default_custom') return Promise.resolve();
    if (cmd === 'deploy_squirrel') return Promise.resolve('ok');
    if (cmd === 'open_rime_folder') return Promise.resolve();
    if (cmd === 'reset_to_defaults') return Promise.resolve();
    return Promise.resolve();
  }),
}));

describe('Settings tab', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it('renders candidate_count from read_default_custom', async () => {
    render(Settings);
    // The radio for value 5 should be checked after load
    const radio5 = await screen.findByDisplayValue('5');
    expect((radio5 as HTMLInputElement).checked).toBe(true);
  });

  it('save button calls write_default_custom then deploy_squirrel', async () => {
    const { invoke } = await import('@tauri-apps/api/core');
    render(Settings);
    await screen.findByDisplayValue('5');
    fireEvent.click(screen.getByRole('button', { name: /save/i }));
    await vi.waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('write_default_custom', { patch: { candidate_count: 5, schema_list: ['thai_phonetic'] } });
      expect(invoke).toHaveBeenCalledWith('deploy_squirrel');
    });
  });
});
