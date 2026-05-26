import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import Words from '../routes/words.svelte';

vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn().mockImplementation((cmd: string, args: any) => {
    if (cmd === 'read_user_dict') return Promise.resolve([
      { word: 'ลีเอ็กซ์', romanization: 'lex', weight: 100 },
    ]);
    if (cmd === 'add_user_word') return Promise.resolve();
    if (cmd === 'deploy_squirrel') return Promise.resolve('ok');
    return Promise.resolve();
  }),
}));

describe('Words tab', () => {
  it('renders existing entries', async () => {
    render(Words);
    expect(await screen.findByText('ลีเอ็กซ์')).toBeTruthy();
  });

  it('add button calls add_user_word + deploy_squirrel', async () => {
    const { invoke } = await import('@tauri-apps/api/core');
    render(Words);
    await screen.findByText('ลีเอ็กซ์');
    const wordInput = screen.getAllByPlaceholderText('ลีเอ็กซ์')[0];
    fireEvent.input(wordInput, { target: { value: 'ขนม' } });
    const romInput = screen.getAllByPlaceholderText('lex')[0];
    fireEvent.input(romInput, { target: { value: 'khanom' } });
    fireEvent.submit(screen.getByRole('button', { name: 'Add' }).closest('form')!);
    await vi.waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('add_user_word', { word: 'ขนม', romanization: 'khanom', weight: 100 });
      expect(invoke).toHaveBeenCalledWith('deploy_squirrel');
    });
  });
});
