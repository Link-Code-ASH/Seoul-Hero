import type { MetaState } from '../state/MetaState';

export const SAVE_VERSION = 11;
export const SAVE_KEY = 'seoul-gate.save';
export const BACKUP_KEY = 'seoul-gate.save.backup';
export const RECOVERY_KEY = 'seoul-gate.save.recovery';

export interface SaveData {
  saveVersion: number;
  savedAt: string;
  meta: MetaState;
}
