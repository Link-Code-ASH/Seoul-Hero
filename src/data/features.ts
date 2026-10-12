/**
 * Godot feature switches (2026-10-10, "브로타토 수준의 단순함").
 * A disabled feature keeps its code, data and save fields but is hidden from the
 * game and gives or consumes nothing. Flip a switch back to true to restore it.
 */
export const GAME_FEATURES = {
  guild: false,
  offlineReward: false,
  supplyBox: false,
  /** 조각 · 전략지원 화면 */
  fragments: false,
  dailyGift: false,
  revivalStones: true,
  /** 단군의 축복 레벨 성장. 꺼지면 해금한 축복은 1단계 효과로 고정 */
  blessingLevels: false,
} as const;

/**
 * 협회 코인 뽑기: 아직 없는 각성자·무기·축복 중 하나가 무작위로 해금된다(중복 없음).
 * starter는 새 저장에서 처음 열려 있는 것. 기존 저장의 해금은 그대로 둔다.
 */
export const GAME_DRAWS = {
  costs: { character: 400, weapon: 200, blessing: 200 },
  starter: {
    characters: ['awakener', 'leeSomin', 'jungMinseok', 'ohJieun', 'moonTaeo', 'kimMigyeong', 'baeSeongho', 'chaYujun', 'baekNari', 'imGicheol', 'seoHyejin'],
    weapons: ['manaSword', 'manaBolt', 'guardianDaggers'],
  },
} as const;

/**
 * 몬스터 드랍(뱀서 금화 방식). 마력석은 그 판에서만 쓰고, 협회 코인과 생환석은
 * 전투 중 주워서 판이 끝나면(죽어도) 계정에 들어간다. 클리어 보상 코인은 없다.
 * normal = 일반 적, elite = 정예, boss = 보스. 생환석은 등급마다 따로 굴린다.
 */
export const GAME_RUN_LOOT = {
  coin: {
    normal: { chance: 0.04, amount: 1 },
    elite: { chance: 1, amount: 5 },
    boss: { chance: 1, amount: 25 },
  },
  revivalStone: {
    normal: { low: 0.002, mid: 0.0005, high: 0.0001 },
    elite: { low: 0.05, mid: 0.015, high: 0.005 },
    boss: { low: 0.3, mid: 0.1, high: 0.03 },
  },
} as const;
