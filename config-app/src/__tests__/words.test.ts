import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { invoke } from '@tauri-apps/api/core';
import Words from '../routes/words.svelte';

vi.mock('@tauri-apps/api/core', () => ({ invoke: vi.fn() }));

function smoodle(deploy: () => Promise<unknown> = () => Promise.resolve('deployed in 0.9s')) {
  vi.mocked(invoke).mockImplementation((cmd: string) => {
    if (cmd === 'read_user_dict') return Promise.resolve([
      { word: 'ลีเอ็กซ์', romanization: 'lex', weight: 100 },
    ]);
    if (cmd === 'deploy_squirrel') return deploy();
    return Promise.resolve();
  });
}

async function addWord(word: string, romanization: string) {
  render(Words);
  await screen.findByText('ลีเอ็กซ์');
  fireEvent.input(screen.getAllByPlaceholderText('ลีเอ็กซ์')[0], { target: { value: word } });
  fireEvent.input(screen.getAllByPlaceholderText('lex')[0], { target: { value: romanization } });
  fireEvent.submit(screen.getByRole('button', { name: 'Add' }).closest('form')!);
}

describe('Words tab', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    smoodle();
  });

  it('renders existing entries', async () => {
    render(Words);
    expect(await screen.findByText('ลีเอ็กซ์')).toBeTruthy();
  });

  it('add button calls add_user_word + deploy_squirrel', async () => {
    await addWord('ขนม', 'khanom');
    await vi.waitFor(() => {
      expect(invoke).toHaveBeenCalledWith('add_user_word', { word: 'ขนม', romanization: 'khanom', weight: 100 });
      expect(invoke).toHaveBeenCalledWith('deploy_squirrel');
    });
    expect(await screen.findByText(/Added 'ขนม' · deployed in/)).toBeTruthy();
  });

  it('a failed deploy still reports the word as added', async () => {
    smoodle(() => Promise.reject("Smoodle isn't running"));
    await addWord('ขนม', 'khanom');
    expect(await screen.findByText(/Added 'ขนม', but deploy failed: Smoodle isn't running/)).toBeTruthy();
  });
});
