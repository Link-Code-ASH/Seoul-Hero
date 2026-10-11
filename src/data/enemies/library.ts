import type { EnemyPresentation } from '../enemyPresentation';
import type { ImageId } from '../images';
import type { EnemyDefinition } from '../types';

/**
 * Art-library monster families met in deeper gates. Every entry reuses the behaviour
 * of the original enemy named in `like`; the family multiplies that enemy's stats.
 */
const FAMILIES = {
  rift: { prefix: '균열', lead: '균열빛이 번진 흐린 점액 몸.', hp: 1.15, damage: 1.08, reward: 1.1 },
  glass: { prefix: '유리', lead: '속이 비치는 유리질 해파리 몸.', hp: 1.3, damage: 1.15, reward: 1.2 },
} as const;
type FamilyId = keyof typeof FAMILIES;

// Catalog order of art-library/catalog.json: monster-(first + 16 × row).
const FIRST_ASSET: Record<FamilyId, number> = { rift: 1, glass: 3 };

const SHAPES: readonly { key: string; name: string; like: Record<FamilyId, string>; text: string }[] = [
  { key: 'Drop', name: '단핵 방울', like: { rift: 'crawler', glass: 'copperCrab' }, text: '핵 하나를 품고 끈질기게 다가옵니다.' },
  { key: 'Crescent', name: '초승 껍질', like: { rift: 'spitter', glass: 'signalMoth' }, text: '초승달 껍질 뒤에서 거리를 두고 마력탄을 쏩니다.' },
  { key: 'Twin', name: '쌍핵 껴안개', like: { rift: 'mender', glass: 'glassJelly' }, text: '맞댄 두 핵으로 주변 괴물의 상처를 봉합하므로 먼저 처치해야 합니다.' },
  { key: 'Slab', name: '납작 숨판', like: { rift: 'bulwark', glass: 'chainWarden' }, text: '납작한 몸으로 버티며 길목을 막습니다.' },
  { key: 'Coil', name: '말림 고리', like: { rift: 'charger', glass: 'runner' }, text: '몸을 고리로 말았다가 직선으로 튕겨 돌진합니다.' },
  { key: 'Tower', name: '층진 맥동탑', like: { rift: 'sentinel', glass: 'ironBoar' }, text: '층층이 쌓인 몸이 맥동하며 주기적으로 태세를 바꿉니다.' },
  { key: 'Trefoil', name: '삼엽 포옹체', like: { rift: 'splitter', glass: 'splitter' }, text: '세 잎이 서로를 끌어안고 있다가 쓰러지면 작은 개체로 흩어집니다.' },
  { key: 'Mask', name: '주름 가면', like: { rift: 'lurker', glass: 'lurker' }, text: '주름진 가면 뒤에 숨어 희미하게 다가오다 갑자기 파고듭니다.' },
  { key: 'Nest', name: '둥지 품핵', like: { rift: 'summoner', glass: 'summoner' }, text: '둥지 속 핵에서 군집 벌레를 계속 불러냅니다.' },
];

export interface LibraryMonster { id: string; family: FamilyId; like: string; asset: string; name: string; description: string; boss?: boolean; radius?: number }

export const LIBRARY_MONSTERS: readonly LibraryMonster[] = (Object.keys(FAMILIES) as FamilyId[]).flatMap(family => {
  const asset = (row: number) => `monster-${String(FIRST_ASSET[family] + row * 16).padStart(3, '0')}`;
  const { prefix, lead } = FAMILIES[family];
  return [
    ...SHAPES.map((shape, row) => ({ id: `${family}${shape.key}`, family, like: shape.like[family], asset: asset(row), name: `${prefix} ${shape.name}`, description: `${lead} ${shape.text}` })),
    // 비대칭 봉오리: the rift bud is the deep-gate boss, the glass bud a named elite body.
    family === 'rift'
      ? { id: 'riftBud', family, like: 'riftQueen', asset: asset(9), name: '균열 봉오리 여왕', description: '한쪽으로 기운 거대한 균열 봉오리 보스. 떠다니며 소환과 대규모 탄막으로 전장을 잠식합니다.', boss: true }
      : { id: 'glassBud', family, like: 'bulwark', asset: asset(9), name: '유리 비대칭 봉오리', description: `${lead} 한쪽으로 기운 봉오리가 느리게 다가와 넓은 충격으로 공간을 장악합니다.`, radius: 36 },
  ];
});

const round = (value: number, digits = 0) => Math.round(value * 10 ** digits) / 10 ** digits;

export function libraryEnemies(base: Record<string, EnemyDefinition>): Record<string, EnemyDefinition> {
  return Object.fromEntries(LIBRARY_MONSTERS.map(monster => {
    const source = base[monster.like]!, scale = FAMILIES[monster.family];
    // The boss keeps the tuned boss numbers; only its body changes.
    const stats = monster.boss ? {} : {
      maxHp: round(source.maxHp * scale.hp), contactDamage: round(source.contactDamage * scale.damage),
      magicStoneDrop: round(source.magicStoneDrop * scale.reward, 4),
    };
    return [monster.id, { ...source, ...stats, id: monster.id, name: monster.name, description: monster.description, radius: monster.radius ?? source.radius,
      visual: { ...source.visual, sprite: `${monster.id}Lib` as ImageId } }];
  }));
}

/** Same single-image motion as the matching enemy; jellyfish float instead of hopping. */
export function libraryPresentation(base: Record<string, EnemyPresentation>): Record<string, EnemyPresentation> {
  return Object.fromEntries(LIBRARY_MONSTERS.map(monster => {
    const source = base[monster.like]!;
    const motion: EnemyPresentation = monster.family === 'glass' && !monster.boss
      ? { ...source, mode: 'float', bob: 4.2, squash: 0.035, bodyWave: 0.014, wingMotion: 0, shadowAlpha: Math.min(source.shadowAlpha, 0.24) }
      : { ...source, wingMotion: 0 };
    return [monster.id, motion];
  }));
}
