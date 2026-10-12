import { weaponShopCardText } from '../shopCardText';
import { structureWeapons } from './structures';
import { weaponBranches } from './branches';
import type { Weapon } from '../types';

// Levels 2–4 grow damage; the six branch rows directly author levels 5–10.
const definitions: Record<string, Omit<Weapon, 'branches' | 'shopCardText'>> = {
  manaSword: {
    id: "manaSword",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "마력검",
    description: "가까운 적을 향해 넓은 부채꼴 베기",
    behavior: "slash",
    capabilities: ["MELEE", "AREA", "HAS_RANGE", "CAN_CRIT"],
    attackAngle: 1.0471975511965976,
    base: { projectileCount: 1, projectileSpeed: 1, duration: 0.25, penetration: 0, projectileRadius: 8, damage: 42, cooldown: 1, range: 140 },
    visual: { color: 10024418, shape: "triangle" },
    targeting: "nearest",
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 46.2 }, { damage: 50.4 }, { damage: 54.6 }, {}, {}, {}, {}, {}, {}],
  },
  guardianDaggers: {
    id: "guardianDaggers",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "수호 표창",
    description: "몸 주위를 도는 표창 3개로 근접 방어",
    behavior: "orbit",
    capabilities: ["MELEE", "ORBIT", "AREA", "HAS_RANGE", "CAN_CRIT"],
    base: { projectileCount: 3, projectileSpeed: 1, duration: 0.25, penetration: 0, projectileRadius: 8, damage: 18, cooldown: 0.35, range: 90 },
    visual: { sprite: "guardianShuriken", color: 11918847, shape: "diamond" },
    targeting: "nearest",
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 19.8 }, { damage: 21.6 }, { damage: 23.4 }, {}, {}, {}, {}, {}, {}],
  },
  piercingShot: {
    id: "piercingShot",
    family: "firearm",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "관통 사격",
    description: "여러 적을 관통하는 고속 장거리 탄",
    behavior: "projectile",
    capabilities: ["RANGED", "PROJECTILE", "DURATION", "HAS_RANGE", "PIERCING", "CAN_CRIT"],
    base: { projectileCount: 1, projectileSpeed: 900, duration: 1.3, penetration: 3, projectileRadius: 5, damage: 30, cooldown: 1.1, range: 600 },
    visual: { sprite: "piercingFx", color: 16420012, shape: "triangle" },
    targeting: "nearest",
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 33 }, { damage: 36 }, { damage: 39 }, {}, {}, {}, {}, {}, {}],
  },
  chainLightning: {
    id: "chainLightning",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "연쇄 번개",
    description: "적 사이로 전이되는 연쇄 공격",
    behavior: "chain",
    capabilities: ["RANGED", "CHAIN", "HAS_RANGE", "CAN_CRIT"],
    chainRange: 138,
    base: { projectileCount: 3, projectileSpeed: 1, duration: 0.25, penetration: 0, projectileRadius: 8, damage: 27, cooldown: 1.4, range: 300 },
    visual: { color: 10411007, shape: "circle" },
    targeting: "nearest",
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 29.7 }, { damage: 32.4 }, { damage: 35.1 }, {}, {}, {}, {}, {}, {}],
  },
  manaBombard: {
    id: "manaBombard",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "마력 폭격",
    description: "적이 있는 지점에 폭발하는 범위 공격",
    behavior: "bombard",
    capabilities: ["RANGED", "AREA", "EXPLOSIVE", "HAS_RANGE", "CAN_CRIT"],
    blastRadius: 110,
    base: { projectileCount: 1, projectileSpeed: 1, duration: 0.45, penetration: 0, projectileRadius: 8, damage: 65, cooldown: 2.3, explosionDelay: 0.9, range: 372 },
    visual: { color: 16038009, shape: "hexagon" },
    targeting: "nearest",
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 71.5 }, { damage: 78 }, { damage: 84.5 }, {}, {}, {}, {}, {}, {}],
  },
  manaBolt: {
    id: "manaBolt",
    maxLevel: 10,
    branchAtLevel: 5,
    name: "마력탄",
    description: "가장 가까운 적에게 날아가는 마력의 파편",
    targeting: "nearest",
    behavior: "projectile",
    capabilities: ["RANGED", "PROJECTILE", "DURATION", "HAS_RANGE", "PIERCING", "CAN_CRIT"],
    base: { damage: 22, cooldown: 0.65, projectileCount: 1, projectileSpeed: 560, range: 420, duration: 1.5, penetration: 0, projectileRadius: 6 },
    visual: { sprite: "manaBolt", color: 16179104, shape: "circle" },
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 24.2 }, { damage: 26.4 }, { damage: 28.6 }, {}, {}, {}, {}, {}, {}],
  },
  manaShotgun: {
    id: "manaShotgun",
    name: "마력 샷건",
    description: "짧은 거리에서 마력 산탄을 넓게 퍼뜨린다. 가까울수록 여러 탄이 적중한다.",
    family: "firearm",
    maxLevel: 10,
    branchAtLevel: 5,
    targeting: "nearest",
    behavior: "projectile",
    capabilities: ["RANGED", "PROJECTILE", "AREA", "HAS_RANGE", "CAN_CRIT"],
    base: { damage: 11, cooldown: 1.5, projectileCount: 5, projectileSpeed: 650, range: 205, duration: 0.36, penetration: 0, projectileRadius: 4.5, spreadAngle: 0.72 },
    visual: { sprite: "manaShotgunPellet", color: 10280689, shape: "circle" },
    // Lv.2–4 common growth; Lv.5–10 use the selected branch below.
    levels: [{ damage: 12.1 }, { damage: 13.2 }, { damage: 14.3 }, {}, {}, {}, {}, {}, {}],
  },
};

export const weapons: Record<string, Weapon> = {
  ...Object.fromEntries(Object.entries(definitions).map(([id, definition]) => [id, {
    ...definition, shopCardText: weaponShopCardText[id]!, branches: weaponBranches[id]!,
  }])),
  ...structureWeapons,
};
