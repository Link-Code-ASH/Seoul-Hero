import type { MapData } from '../types';

/** A new regular enemy joins only after the previous roster has had two Waves to breathe. */
const enemyRoster = [
  { firstWave: 1, enemyId: 'crawler', weight: 3 },
  { firstWave: 1, enemyId: 'swarm', weight: 2 },
  { firstWave: 3, enemyId: 'runner', weight: 2 },
  { firstWave: 5, enemyId: 'spitter', weight: 1 },
  { firstWave: 7, enemyId: 'bulwark', weight: 1 },
  { firstWave: 9, enemyId: 'charger', weight: 1 },
  { firstWave: 11, enemyId: 'bomber', weight: 1 },
  { firstWave: 13, enemyId: 'splitter', weight: 1 },
  { firstWave: 15, enemyId: 'mender', weight: 1 },
  { firstWave: 17, enemyId: 'summoner', weight: 1 },
  { firstWave: 19, enemyId: 'sentinel', weight: 1 },
] as const;

const enemiesFor = (wave: number): { enemyId: string; weight: number }[] =>
  enemyRoster.filter(enemy => enemy.firstWave <= wave).map(({ enemyId, weight }) => ({ enemyId, weight }));

// Preserve a near-linear spawn rate even when the per-tick batch grows.
const spawnFor = (wave: number) => {
  const batch = wave < 5 ? 2 : wave < 10 ? 3 : wave < 15 ? 4 : 5;
  const enemiesPerSecond = 1.27 + (wave - 1) * 0.17;
  return { interval: Math.round(batch / enemiesPerSecond * 100) / 100,
    batch, maxEnemies: Math.round(63 + (wave - 1) * 8.5) };
};

// Duration/interval are seconds. Enemy composition and elite timing remain per-Wave data.
export const maps: Record<string, MapData> = {
  seoul: {
    id: "seoul",
    name: "서울 · 광화문 광장",
    description: "광화문 광장의 고정 화면 아레나",
    thumbnail: "seoulIntersection",
    arenaWidth: 1280,
    arenaHeight: 720,
    totalWaves: 20,
    bossWave: 20,
    seed: 7319,
    backgroundTheme: "neighborhood",
    clearReward: 200,
    // Canonical 100% stage. Future maps express differences relative to these values.
    balanceModifiers: { enemyHp: 1, enemyDamage: 1, enemySpeed: 1, spawnDensity: 1, rewards: 1 },
    waveDefinitions: [
      {"id":"wave_1","name":"1차 침식","waveNumber":1,"duration":30,...spawnFor(1),"enemies":enemiesFor(1)},
      {"id":"wave_2","name":"2차 침식","waveNumber":2,"duration":30,...spawnFor(2),"enemies":enemiesFor(2)},
      {"id":"wave_3","name":"3차 침식","waveNumber":3,"duration":35,...spawnFor(3),"enemies":enemiesFor(3)},
      {"id":"wave_4","name":"4차 침식","waveNumber":4,"duration":35,...spawnFor(4),"enemies":enemiesFor(4)},
      {"id":"wave_5","name":"5차 침식","waveNumber":5,"duration":40,...spawnFor(5),"enemies":enemiesFor(5),"elites":[{"at":12,"enemyId":"crawler","hpMultiplier":1,"rewardMultiplier":1,"modifiers":["GIANT"]}]},
      {"id":"wave_6","name":"6차 침식","waveNumber":6,"duration":40,...spawnFor(6),"enemies":enemiesFor(6)},
      {"id":"wave_7","name":"7차 침식","waveNumber":7,"duration":40,...spawnFor(7),"enemies":enemiesFor(7)},
      {"id":"wave_8","name":"8차 침식","waveNumber":8,"duration":40,...spawnFor(8),"enemies":enemiesFor(8)},
      {"id":"wave_9","name":"9차 침식","waveNumber":9,"duration":45,...spawnFor(9),"enemies":enemiesFor(9)},
      {"id":"wave_10","name":"10차 침식","waveNumber":10,"duration":45,...spawnFor(10),"enemies":enemiesFor(10),"elites":[{"at":15,"enemyId":"bulwark","hpMultiplier":1.35,"rewardMultiplier":1,"modifiers":["ARMORED"]}]},
      {"id":"wave_11","name":"11차 침식","waveNumber":11,"duration":45,...spawnFor(11),"enemies":enemiesFor(11)},
      {"id":"wave_12","name":"12차 침식","waveNumber":12,"duration":45,...spawnFor(12),"enemies":enemiesFor(12)},
      {"id":"wave_13","name":"13차 침식","waveNumber":13,"duration":50,...spawnFor(13),"enemies":enemiesFor(13)},
      {"id":"wave_14","name":"14차 침식","waveNumber":14,"duration":50,...spawnFor(14),"enemies":enemiesFor(14)},
      {"id":"wave_15","name":"15차 침식","waveNumber":15,"duration":50,...spawnFor(15),"enemies":enemiesFor(15),"elites":[{"at":18,"enemyId":"runner","hpMultiplier":2,"rewardMultiplier":1,"modifiers":["BERSERK","REGENERATING"]}]},
      {"id":"wave_16","name":"16차 침식","waveNumber":16,"duration":50,...spawnFor(16),"enemies":enemiesFor(16)},
      {"id":"wave_17","name":"17차 침식","waveNumber":17,"duration":55,...spawnFor(17),"enemies":enemiesFor(17)},
      {"id":"wave_18","name":"18차 침식","waveNumber":18,"duration":55,...spawnFor(18),"enemies":enemiesFor(18)},
      {"id":"wave_19","name":"19차 침식","waveNumber":19,"duration":55,...spawnFor(19),"enemies":enemiesFor(19)},
      {"id":"wave_20","name":"게이트 파수꾼","waveNumber":20,"duration":70,...spawnFor(20),"enemies":enemiesFor(20),"boss":{"enemyId":"gatekeeper"}},
    ],
  },
};



