import { WEEKLY_MONSTER } from '../gateProgression';
import type { MapData, Wave } from '../types';

/** One row per Wave. Slots are [enemyId, weight%]; the first slot is that Wave's lead threat. */
type WaveRoster = readonly (readonly [enemyId: string, weight: number])[];
type FeaturedElites = Readonly<Record<number, NonNullable<Wave['elites']>>>;
type Surges = Readonly<Record<number, NonNullable<Wave['surge']>>>;

// 광화문 keeps the same four regulars at every floor: 균열체 (근거리), 마탄 사수 (원거리),
// 질주체 (돌진), 철갑 점액 (땅울림). Swap this table to give another map its own cast.
// The weekly monster (gateProgression.ts) takes the lead slot of Waves 3/6/9/12/15/18.
const seoulRoster: readonly WaveRoster[] = [
  [['crawler', 100]],
  [['runner', 30], ['crawler', 70]],
  [['crawler', 65], ['runner', 35]],
  [['spitter', 30], ['crawler', 50], ['runner', 20]],
  [['runner', 40], ['crawler', 40], ['spitter', 20]],
  [['bulwark', 15], ['crawler', 50], ['runner', 20], ['spitter', 15]],
  [['spitter', 35], ['crawler', 45], ['runner', 20]],
  [['bulwark', 20], ['crawler', 40], ['runner', 25], ['spitter', 15]],
  [['runner', 45], ['crawler', 30], ['spitter', 25]],
  [['spitter', 40], ['crawler', 30], ['bulwark', 15], ['runner', 15]],
  [['bulwark', 25], ['crawler', 35], ['runner', 25], ['spitter', 15]],
  [['runner', 40], ['spitter', 30], ['crawler', 30]],
  [['spitter', 40], ['bulwark', 20], ['crawler', 25], ['runner', 15]],
  [['crawler', 40], ['runner', 30], ['spitter', 20], ['bulwark', 10]],
  [['bulwark', 30], ['runner', 30], ['spitter', 25], ['crawler', 15]],
  [['runner', 40], ['spitter', 35], ['bulwark', 15], ['crawler', 10]],
  [['spitter', 40], ['bulwark', 25], ['runner', 25], ['crawler', 10]],
  [['bulwark', 35], ['runner', 30], ['spitter', 25], ['crawler', 10]],
  [['runner', 30], ['spitter', 30], ['bulwark', 30], ['crawler', 10]],
  // Boss Wave: the regulars keep coming beside the boss and its two elites.
  [['runner', 30], ['spitter', 30], ['bulwark', 30], ['crawler', 10]],
];

// Every Run draws one of these for all its elite Waves; the first is the fallback body.
const seoulElitePool = ['charger', 'haetaeHead'];

// hp is the depth-1 max HP of each elite, whichever body the Run drew: Wave 7 is about
// 30% of the gatekeeper, Wave 14 keeps the former 1550 total across its pair.
const featuredElite = (at: number, hp: number): NonNullable<Wave['elites']>[number] =>
  ({ at, enemyId: seoulElitePool[0]!, hpMultiplier: 1, hp, rewardMultiplier: 1, featured: true });
const seoulFeaturedElites: FeaturedElites = {
  7: [featuredElite(10, 1560)],
  14: [featuredElite(8, 775), featuredElite(14, 775)],
  20: [featuredElite(10, 1000), featuredElite(18, 1000)],
};

const seoulSurges: Surges = {
  14: { name: '균열 폭주', lastSeconds: 15, spawnMultiplier: 1.5, rewardMultiplier: 1.5 },
};

const seoulDurations = [30, 30, 35, 35, 40, 40, 40, 40, 45, 45, 45, 45, 50, 50, 50, 50, 55, 55, 55, 70];

// Preserve a near-linear spawn rate even when the per-tick batch grows.
const spawnFor = (wave: number) => {
  const batch = wave < 5 ? 2 : wave < 10 ? 3 : wave < 15 ? 4 : 5;
  const enemiesPerSecond = 1.27 + (wave - 1) * 0.17;
  const baseInterval = Math.round(batch / enemiesPerSecond * 100) / 100;
  return { interval: Math.round(baseInterval / 0.7 * 100) / 100,
    batch, maxEnemies: Math.round(Math.round(63 + (wave - 1) * 8.5) * 0.7) };
};

// Duration/interval are seconds. The last row becomes the boss Wave and spawns at the density of the Wave before it.
const buildWaves = (roster: readonly WaveRoster[], durations: readonly number[], boss: { enemyId: string; name: string }, featured: FeaturedElites = {}, surges: Surges = {}): Wave[] =>
  roster.map((slots, index) => {
    const waveNumber = index + 1, last = waveNumber === roster.length;
    return {
      id: `wave_${waveNumber}`, name: last ? boss.name : `${waveNumber}차 침식`, waveNumber, duration: durations[index]!,
      ...spawnFor(last ? waveNumber - 1 : waveNumber),
      enemies: slots.map(([enemyId, weight]) => ({ enemyId, weight })),
      ...(featured[waveNumber] ? { elites: featured[waveNumber] } : {}),
      ...(surges[waveNumber] ? { surge: surges[waveNumber] } : {}),
      ...(last ? { boss: { enemyId: boss.enemyId } } : {}),
    };
  });

export const maps: Record<string, MapData> = {
  seoul: {
    id: "seoul",
    name: "광화문 광장",
    description: "광화문 광장의 고정 화면 아레나",
    thumbnail: "gwanghwamunPlazaSD",
    // Galaxy S24 Ultra landscape: approximately 20:9, every arena point is ground.
    arenaWidth: 1600,
    arenaHeight: 720,
    // Landmark sculptures are baked into the backdrop; all ground is traversable.
    objects: [],
    totalWaves: 20,
    bossWave: 20,
    seed: 7319,
    backgroundTheme: "neighborhood",
    clearReward: 200,
    // Canonical 100% stage. Future maps express differences relative to these values.
    balanceModifiers: { enemyHp: 1, enemyDamage: 1, enemySpeed: 1, spawnDensity: 1, rewards: 1 },
    elitePool: seoulElitePool,
    // Monsters met on this map; archived ones stay out of its archive pages.
    archiveContent: { enemyIds: ['crawler', 'spitter', 'runner', 'bulwark', ...seoulElitePool, 'gatekeeper', ...(WEEKLY_MONSTER.enabled ? WEEKLY_MONSTER.pool : [])] },
    waveDefinitions: buildWaves(seoulRoster, seoulDurations, { enemyId: 'gatekeeper', name: '게이트 파수꾼' }, seoulFeaturedElites, seoulSurges),
  },
};
