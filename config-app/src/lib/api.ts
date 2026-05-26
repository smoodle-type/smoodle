import { invoke } from '@tauri-apps/api/core';

export interface DictEntry { word: string; romanization: string; weight: number; }
export interface DictCounts { base: number; user: number; total: number; }
export interface SmoodleStatus { running: boolean; version: string | null; }
export interface DefaultCustomPatch { candidate_count: number | null; schema_list: string[]; }
export interface TelemetryState { enabled: boolean; has_install_id: boolean; has_token: boolean; }

export const api = {
  readUserDict: () => invoke<DictEntry[]>('read_user_dict'),
  addUserWord: (word: string, romanization: string, weight: number) => invoke<void>('add_user_word', { word, romanization, weight }),
  deleteUserWord: (lineId: number) => invoke<void>('delete_user_word', { lineId }),
  deploySquirrel: () => invoke<string>('deploy_squirrel'),
  smoodleRunning: () => invoke<SmoodleStatus>('smoodle_running'),
  schemaCompileLog: () => invoke<string>('schema_compile_log'),
  dictCounts: () => invoke<DictCounts>('dict_counts'),
  readDefaultCustom: () => invoke<DefaultCustomPatch>('read_default_custom'),
  writeDefaultCustom: (patch: DefaultCustomPatch) => invoke<void>('write_default_custom', { patch }),
  openRimeFolder: () => invoke<void>('open_rime_folder'),
  resetToDefaults: () => invoke<void>('reset_to_defaults'),
  telemetryState: () => invoke<TelemetryState>('telemetry_state'),
  telemetrySetOptIn: (enabled: boolean, token: string | null) => invoke<void>('telemetry_set_opt_in', { enabled, token }),
  telemetryForget: () => invoke<number>('telemetry_forget'),
};
