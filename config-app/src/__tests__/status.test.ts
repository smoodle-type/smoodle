import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import Status from '../routes/status.svelte';

vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn().mockImplementation((cmd: string) => {
    if (cmd === 'smoodle_running') return Promise.resolve({ running: true, version: '0.0.6' });
    if (cmd === 'dict_counts') return Promise.resolve({ base: 2000, user: 5, total: 2005 });
    if (cmd === 'schema_compile_log') return Promise.resolve('line1\nline2\nline3\nline4\nline5');
    if (cmd === 'telemetry_state') return Promise.resolve({ enabled: true, has_install_id: true, has_token: false });
    if (cmd === 'telemetry_set_opt_in') return Promise.resolve();
    if (cmd === 'telemetry_forget') return Promise.resolve(3);
    return Promise.resolve();
  }),
}));

describe('Status tab', () => {
  beforeEach(() => { vi.clearAllMocks(); });

  it('renders running state, version, and dict counts after mount', async () => {
    render(Status);
    expect(await screen.findByText(/0\.0\.6/)).toBeTruthy();
    expect(await screen.findByText(/2005/)).toBeTruthy();
  });

  it('forget button calls telemetry_forget', async () => {
    const { invoke } = await import('@tauri-apps/api/core');
    render(Status);
    await screen.findByText(/0\.0\.6/);
    fireEvent.click(screen.getByRole('button', { name: /delete my telemetry data/i }));
    await vi.waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('telemetry_forget');
    });
  });
});
