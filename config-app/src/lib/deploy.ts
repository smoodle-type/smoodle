import { api } from './api';

export type Toast = { msg: string; type: 'ok' | 'err' };

/**
 * Deploy after a change that is already saved, and report both steps.
 * A failed deploy must not read as a failed save: the file did change, and
 * Smoodle loads it on its next start or manual Deploy.
 */
export async function deployAndReport(done: string, startedAt: number, deployOnSave: boolean): Promise<Toast> {
  if (!deployOnSave) return { msg: `${done} ✓ — choose Deploy in the S menu to use it`, type: 'ok' };
  try {
    await api.deploySquirrel();
    const secs = ((performance.now() - startedAt) / 1000).toFixed(1);
    return { msg: `${done} · deployed in ${secs}s ✓`, type: 'ok' };
  } catch (e) {
    return { msg: `${done}, but deploy failed: ${e}`, type: 'err' };
  }
}
