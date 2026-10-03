import { AUDIO_CONFIG, sfx } from '../data/audio';
import type { BgmId, SfxGroup, SfxId } from '../data/audio';
import type { RunState } from '../state/RunState';
import type { Screen } from '../ui/screens';

export function musicForScene(screen: Screen, run: RunState | null): BgmId | null {
  if (screen === 'result') return null;
  if (screen === 'guild') return 'guild';
  if (run && ['waveActive', 'paused', 'revivalChoice', 'shop', 'postWave'].includes(screen)) return 'combat';
  return 'menu';
}
/** Wall-clock throttle, independent of simulation speed and frame rate. */
export class SoundGate {
  private readonly lastPlayed = new Map<SfxId, number>();
  allow(id: SfxId, now: number, activeVoices: number, normalVoices = activeVoices): boolean {
    if (activeVoices >= AUDIO_CONFIG.maxVoices) return false;
    if (!sfx[id].protected && normalVoices >= AUDIO_CONFIG.normalVoices) return false;
    if (now - (this.lastPlayed.get(id) ?? -Infinity) < sfx[id].interval) return false;
    this.lastPlayed.set(id, now);
    return true;
  }
  clear(group?: SfxGroup): void {
    if (!group) { this.lastPlayed.clear(); return; }
    for (const id of this.lastPlayed.keys()) if (sfx[id].group === group) this.lastPlayed.delete(id);
  }
}
