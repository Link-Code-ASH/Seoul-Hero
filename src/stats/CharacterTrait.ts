import { characters } from '../data/characters';
import type { Weapon } from '../data/types';

/** Character damage traits are additive with other percentage damage bonuses. */
export function characterWeaponDamageBonus(characterId: string, weapon: Weapon): number {
  const trait = characters[characterId]?.trait;
  if (!trait || (trait.weaponFamily && trait.weaponFamily !== weapon.family)
    || (trait.weaponCapability && !weapon.capabilities.includes(trait.weaponCapability))) return 0;
  return trait.weaponDamageBonus;
}
