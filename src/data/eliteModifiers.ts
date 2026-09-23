export const eliteModifiers = {
  GIANT: { hp: 2.5, speed: 0.8, damage: 1.3, size: 1.5, reward: 2, armor: 0, regeneration: 0, aura: false },
  BERSERK: { hp: 1.3, speed: 1.35, damage: 1.7, size: 1, reward: 1.6, armor: 0, regeneration: 0, aura: false },
  REGENERATING: { hp: 1.5, speed: 1, damage: 1, size: 1, reward: 1.5, armor: 0, regeneration: 0.025, aura: false },
  ARMORED: { hp: 1.2, speed: 0.9, damage: 1, size: 1, reward: 1.5, armor: 60, regeneration: 0, aura: false },
  CURSED_AURA: { hp: 1.4, speed: 1, damage: 1, size: 1, reward: 1.8, armor: 0, regeneration: 0, aura: true },
  FAST: { hp: 1.1, speed: 1.6, damage: 1, size: 1, reward: 1.4, armor: 0, regeneration: 0, aura: false },
} as const;
export type EliteModifierId = keyof typeof eliteModifiers;
