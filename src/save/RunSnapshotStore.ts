import { characters } from '../data/characters';
import { maps } from '../data/maps';
import { weapons } from '../data/weapons';
import type { SimulationSnapshot } from '../core/Simulation';

const VERSION = 1;
const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);
const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value);

/** A disposable, device-local Run checkpoint; never part of the cloud Meta save. */
export class RunSnapshotStore {
  constructor(private readonly storage: Pick<Storage, 'getItem' | 'setItem' | 'removeItem'> = localStorage) {}
  private key(scope: string): string { return `seoul-hero.run.v${VERSION}.${encodeURIComponent(scope || 'guest')}`; }

  save(scope: string, snapshot: SimulationSnapshot): boolean {
    try {
      this.storage.setItem(this.key(scope), JSON.stringify({ version: VERSION, savedAt: Date.now(), snapshot }));
      return true;
    } catch { return false; }
  }
  clear(scope: string): void { try { this.storage.removeItem(this.key(scope)); } catch { /* storage unavailable */ } }

  load(scope: string): SimulationSnapshot | null {
    let raw: string | null;
    try { raw = this.storage.getItem(this.key(scope)); } catch { return null; }
    if (!raw) return null;
    try {
      const wrapper: unknown = JSON.parse(raw);
      if (!record(wrapper) || wrapper.version !== VERSION || !record(wrapper.snapshot)) return null;
      const snapshot = wrapper.snapshot;
      const run = snapshot.state;
      const spawn = snapshot.spawn;
      if (!record(run) || !record(spawn) || !record(run.player)) return null;
      if (typeof run.characterId !== 'string' || !Object.hasOwn(characters, run.characterId) ||
          typeof run.mapId !== 'string' || !Object.hasOwn(maps, run.mapId) ||
          typeof run.startingWeaponId !== 'string' || !Object.hasOwn(weapons, run.startingWeaponId)) return null;
      if (!['paused', 'waveActive', 'postWave', 'shop', 'revivalChoice'].includes(String(run.phase))) return null;
      if (!Number.isInteger(run.currentWave) || (run.currentWave as number) < 1 ||
          (run.currentWave as number) > maps[run.mapId]!.totalWaves ||
          !finite(run.waveElapsedTime) || !finite(run.waveRemainingTime) ||
          !finite(run.player.x) || !finite(run.player.y) || !finite(run.player.hp) || !finite(run.player.maxHp) ||
          !Number.isInteger(snapshot.sequence) || (snapshot.sequence as number) < 0 ||
          !finite(spawn.nextSpawn) || !Array.isArray(spawn.triggeredElites) ||
          !spawn.triggeredElites.every(index => Number.isInteger(index) && index >= 0)) return null;
      for (const key of ['ownedWeapons', 'enemies', 'projectiles', 'pickups', 'structures', 'runItems', 'effects', 'hostileProjectiles', 'hazards']) {
        if (!Array.isArray(run[key]) || run[key].length > 2000) return null;
      }
      if (!(run.projectiles as unknown[]).every(projectile => record(projectile) && Array.isArray(projectile.hitIds) &&
        projectile.hitIds.every(id => Number.isInteger(id) && id >= 0) &&
        (projectile.attackRef === undefined || (Number.isInteger(projectile.attackRef) && (projectile.attackRef as number) >= 0)))) return null;
      if (!(run.ownedWeapons as unknown[]).every(slot => record(slot) && typeof slot.id === 'string' && Object.hasOwn(weapons, slot.id))) return null;
      return snapshot as unknown as SimulationSnapshot;
    } catch { return null; }
  }
}
