import type { WeaponBranch } from '../types';
/** Legacy milestones are expanded to the Lv.5-10 cadence by progression.ts. */
export const weaponBranches: Record<string, WeaponBranch[]> = {
  manaBolt: [
    { id: 'A', name: '다중 마력 난사', description: '넓게 퍼지는 여러 마력탄. 최종 3발.', levels: [{ projectileCount: 2, penetration: 0, damage: 32 }, { damage: 36 }, { projectileCount: 3, cooldown: 0.6 }, { damage: 40, cooldown: 0.56 }] },
    { id: 'B', name: '초관통 마력탄', description: '한 발로 긴 적 대열을 관통. 최종 8회 관통.', levels: [{ projectileCount: 1, penetration: 3, damage: 42 }, { damage: 50, projectileSpeed: 720 }, { penetration: 6 }, { penetration: 8, damage: 72, cooldown: 0.58, projectileRadius: 9 }] },
  ],
  manaSword: [
    { id: 'A', name: '광역 검격', description: '90°의 넓은 검격. 사거리와 위력이 성장합니다.', levels: [{ attackAngle: Math.PI / 2, range: 180, damage: 58 }, { damage: 68 }, { range: 210, cooldown: 0.82 }, { damage: 94, range: 225, cooldown: 0.76 }] },
    { id: 'B', name: '연속 검격', description: '60° 범위를 빠르게 연속으로 베어냅니다.', levels: [{ repeatCount: 2, repeatInterval: 0.14, range: 135, attackAngle: Math.PI / 3, damage: 34 }, { damage: 39 }, { cooldown: 0.7 }, { repeatCount: 2, damage: 48, cooldown: 0.64 }] },
  ],
  guardianDaggers: [
    { id: 'A', name: '표창 군무', description: '회전 표창 증가. 최종 6개.', levels: [{ projectileCount: 5, damage: 24 }, { damage: 27 }, { cooldown: 0.32 }, { projectileCount: 6, damage: 30, cooldown: 0.3 }] },
    { id: 'B', name: '중량 표창', description: '표창 3개를 유지하고 크기·피해 확대.', levels: [{ projectileCount: 3, areaMultiplier: 1.45, damage: 36 }, { damage: 44 }, { areaMultiplier: 1.7 }, { areaMultiplier: 1.9, damage: 58, cooldown: 0.32 }] },
  ],
  piercingShot: [
    { id: 'A', name: '관통 포격', description: '한 발의 폭과 관통 수 증가.', levels: [{ projectileCount: 1, penetration: 6, projectileRadius: 9, damage: 45 }, { damage: 54 }, { penetration: 9, projectileRadius: 13 }, { penetration: 12, damage: 78, projectileRadius: 16, cooldown: 0.82 }] },
    { id: 'B', name: '산개 사격', description: '관통은 3회, 여러 방향으로 동시 발사.', levels: [{ projectileCount: 2, penetration: 3, damage: 34 }, { damage: 40 }, { projectileCount: 3 }, { projectileCount: 3, damage: 50, cooldown: 0.84 }] },
  ],
  chainLightning: [
    { id: 'A', name: '연쇄 폭풍', description: '많은 적을 연결. 최종 7개 대상.', levels: [{ projectileCount: 5, damage: 31 }, { projectileCount: 6, damage: 34 }, { cooldown: 1.15 }, { projectileCount: 7, damage: 42, cooldown: 1.05 }] },
    { id: 'B', name: '집중 뇌격', description: '대상을 2개로 제한하고 강한 타격.', levels: [{ projectileCount: 2, damage: 58 }, { damage: 72 }, { cooldown: 1.05 }, { damage: 108, cooldown: 0.96 }] },
  ],
  manaBombard: [
    { id: 'A', name: '대형 폭발', description: '예고 후 넓은 한 번의 폭발.', levels: [{ blastRadius: 155, repeatCount: 1, damage: 82 }, { damage: 98 }, { blastRadius: 190, cooldown: 1.8 }, { blastRadius: 215, damage: 132, cooldown: 1.6 }] },
    { id: 'B', name: '연속 폭격', description: '작은 폭발을 같은 목표 지점에 연속 투하.', levels: [{ blastRadius: 78, repeatCount: 2, repeatInterval: 0.2, damage: 40 }, { damage: 44 }, { repeatCount: 3, cooldown: 1.8 }, { repeatCount: 3, damage: 50, cooldown: 1.62 }] },
  ],
};
