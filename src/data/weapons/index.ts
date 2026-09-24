import { structureWeapons } from './structures';
import { weaponBranches } from './branches';
import type { Weapon } from '../types';
import { expandWeaponProgression } from './progression';
const definitions: Record<string, Omit<Weapon, "branches">> = {
  manaSword: {
    "id": "manaSword",
    maxLevel: 6, branchAtLevel: 3,
    "name": "마력검",
    "description": "가까운 적을 향해 넓은 부채꼴 베기",
    "behavior": "slash",
    "capabilities": ["MELEE","AREA","HAS_RANGE","CAN_CRIT"],
    "attackAngle": Math.PI / 3,
    "base": {
      "projectileCount": 1,
      "projectileSpeed": 1,
      "duration": 0.25,
      "penetration": 0,
      "projectileRadius": 8,
      "damage": 42,
      "cooldown": 1,
      "range": 140
    },
    "levels": [
      {
        "damage": 55
      },
      {
        "range": 165
      },
      {
        "damage": 72,
        "cooldown": 0.85
      },
      {
        "range": 190
      },
      {
        "damage": 100,
        "cooldown": 0.7
      }
    ],
    "visual": {
      "color": 10024418,
      "shape": "triangle"
    },
    "targeting": "nearest"
  },
  guardianDaggers: {
    "id": "guardianDaggers",
    maxLevel: 6, branchAtLevel: 3,
    "name": "수호 표창",
    "description": "몸 주위를 도는 표창 3개로 근접 방어",
    "behavior": "orbit",
    "capabilities": ["MELEE","ORBIT","AREA","HAS_RANGE","CAN_CRIT"],
    "base": {
      "projectileCount": 3,
      "projectileSpeed": 1,
      "duration": 0.25,
      "penetration": 0,
      "projectileRadius": 8,
      "damage": 18,
      "cooldown": 0.35,
      "range": 90
    },
    "levels": [
      {
        "damage": 24
      },
      {
        "projectileCount": 4
      },
      {
        "damage": 32
      },
      {
        "projectileCount": 5
      },
      {
        "damage": 42,
        "cooldown": 0.28
      }
    ],
    "visual": {
      "sprite": "guardianShuriken",
      "color": 11918847,
      "shape": "diamond"
    },
    "targeting": "nearest"
  },
  piercingShot: {
    "id": "piercingShot",
    maxLevel: 6, branchAtLevel: 3,
    "name": "관통 사격",
    "description": "여러 적을 관통하는 고속 장거리 탄",
    "behavior": "projectile",
    "capabilities": ["RANGED","PROJECTILE","DURATION","HAS_RANGE","PIERCING","CAN_CRIT"],
    "base": {
      "projectileCount": 1,
      "projectileSpeed": 900,
      "duration": 1.3,
      "penetration": 3,
      "projectileRadius": 5,
      "damage": 30,
      "cooldown": 1.1,
      "range": 600
    },
    "levels": [
      {
        "damage": 40
      },
      {
        "penetration": 5
      },
      {
        "projectileCount": 2
      },
      {
        "damage": 58
      },
      {
        "damage": 78,
        "cooldown": 0.85
      }
    ],
    "visual": {
      "sprite": "piercingFx",
      "color": 16420012,
      "shape": "triangle"
    },
    "targeting": "nearest"
  },
  chainLightning: {
    "id": "chainLightning",
    maxLevel: 6, branchAtLevel: 3,
    "name": "연쇄 번개",
    "description": "적 사이로 전이되는 연쇄 공격",
    "behavior": "chain",
    "capabilities": ["RANGED","CHAIN","HAS_RANGE","CAN_CRIT"],
    "chainRange": 138,
    "base": {
      "projectileCount": 3,
      "projectileSpeed": 1,
      "duration": 0.25,
      "penetration": 0,
      "projectileRadius": 8,
      "damage": 27,
      "cooldown": 1.4,
      "range": 300
    },
    "levels": [
      {
        "damage": 35
      },
      {
        "projectileCount": 4
      },
      {
        "cooldown": 1.15
      },
      {
        "damage": 48,
        "projectileCount": 5
      },
      {
        "damage": 65,
        "projectileCount": 6
      }
    ],
    "visual": {
      "color": 10411007,
      "shape": "circle"
    },
    "targeting": "nearest"
  },
  manaBombard: {
    "id": "manaBombard",
    maxLevel: 6, branchAtLevel: 3,
    "name": "마력 폭격",
    "description": "적이 있는 지점에 폭발하는 범위 공격",
    "behavior": "bombard",
    "capabilities": ["RANGED","AREA","EXPLOSIVE","HAS_RANGE","CAN_CRIT"],
    "blastRadius": 110,
    "base": {
      "projectileCount": 1,
      "projectileSpeed": 1,
      "duration": 0.45,
      "penetration": 0,
      "projectileRadius": 8,
      "damage": 65,
      "cooldown": 2.3,
      "explosionDelay": 0.9,
      "range": 372
    },
    "levels": [
      {
        "damage": 85
      },
      {
        "cooldown": 2
      },
      {
        "damage": 110
      },
      {
        "cooldown": 1.6
      },
      {
        "damage": 150
      }
    ],
    "visual": {
      "color": 16038009,
      "shape": "hexagon"
    },
    "targeting": "nearest"
  },
  manaBolt: { id: 'manaBolt', maxLevel: 6, branchAtLevel: 3, name: '마력탄', description: '가장 가까운 적에게 날아가는 마력의 파편', targeting: 'nearest', behavior: 'projectile', capabilities: ["RANGED","PROJECTILE","DURATION","HAS_RANGE","PIERCING","CAN_CRIT"],
    base: { damage: 22, cooldown: 0.65, projectileCount: 1, projectileSpeed: 560, range: 420, duration: 1.5, penetration: 0, projectileRadius: 6 },
    levels: [{ damage: 28, projectileSpeed: 620 }, { damage: 35, penetration: 1 }, { damage: 44, projectileCount: 2 }, { damage: 56, cooldown: 0.5 }, { damage: 72, penetration: 2 }],
    visual: { sprite: 'manaBolt', color: 0xf6dfa0, shape: 'circle' } },
  manaShotgun: {
    id: 'manaShotgun', name: '마력 샷건', description: '짧은 거리에서 마력 산탄을 넓게 퍼뜨린다. 가까울수록 여러 탄이 적중한다.',
    maxLevel: 10, branchAtLevel: 5, targeting: 'nearest', behavior: 'projectile',
    capabilities: ['RANGED', 'PROJECTILE', 'AREA', 'HAS_RANGE', 'CAN_CRIT'],
    base: { damage: 11, cooldown: 1.5, projectileCount: 5, projectileSpeed: 650, range: 205, duration: 0.36, penetration: 0, projectileRadius: 4.5, spreadAngle: 0.72 },
    levels: [
      { damage: 12 }, { cooldown: 1.43 }, { range: 220, projectileSpeed: 680 },
      { damage: 13 }, { damage: 14 }, { cooldown: 1.3 }, { damage: 15 },
      { range: 230 }, { damage: 16, cooldown: 1.2 },
    ],
    visual: { sprite: 'manaShotgunPellet', color: 0x9cdef1, shape: 'circle' },
  },
};


export const weapons: Record<string, Weapon> = Object.assign({}, Object.fromEntries(Object.entries(definitions).map(([id, definition]) => [id, expandWeaponProgression({ ...definition, branches: weaponBranches[id]! })])), structureWeapons);
