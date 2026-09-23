import { cloudClient } from './CloudClient';
import { parseSave } from '../save/migrations';

export interface CloudSnapshot { raw: string; revision: number }

/** All cloud writes are conditional on the last revision read by this browser. */
export async function readCloudSave(userId: string): Promise<CloudSnapshot | null> {
  const { data, error } = await cloudClient.from('seoul_gate_saves')
    .select('payload,revision').eq('user_id', userId).maybeSingle();
  if (error) throw error;
  if (!data) return null;
  const raw = JSON.stringify(data.payload);
  parseSave(raw);
  return { raw, revision: Number(data.revision) };
}

export async function writeCloudSave(userId: string, raw: string, revision: number | null): Promise<number> {
  const payload = JSON.parse(raw) as unknown;
  if (revision === null) {
    const { data, error } = await cloudClient.from('seoul_gate_saves')
      .insert({ user_id: userId, payload }).select('revision').single();
    if (error) {
      if (error.code === '23505') throw new Error('CLOUD_CONFLICT');
      throw error;
    }
    return Number(data.revision);
  }
  const { data, error } = await cloudClient.from('seoul_gate_saves')
    .update({ payload, revision: revision + 1, updated_at: new Date().toISOString() })
    .eq('user_id', userId).eq('revision', revision).select('revision').maybeSingle();
  if (error) throw error;
  if (!data) throw new Error('CLOUD_CONFLICT');
  return Number(data.revision);
}
