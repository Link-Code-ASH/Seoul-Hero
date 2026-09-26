import { AUDIO_CONFIG, sfx } from '../data/audio';
import type { BgmId, SfxId } from '../data/audio';
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
  allow(id: SfxId, now: number, activeVoices: number): boolean {
    const important = sfx[id].priority >= 4;
    if (activeVoices >= (important ? AUDIO_CONFIG.maxVoices : AUDIO_CONFIG.maxVoices - AUDIO_CONFIG.reservedImportantVoices)) return false;
    if (now - (this.lastPlayed.get(id) ?? -Infinity) < sfx[id].interval) return false;
    this.lastPlayed.set(id, now);
    return true;
  }
  clear(): void { this.lastPlayed.clear(); }
}
