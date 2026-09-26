import { images, type ImageId } from '../data/images';

const atlas = new URL('../../assets/ui/inventory_atlas_01.png', import.meta.url).href;
const itemIds = ['energyDrink','riceBall','runningShoes','scope','luckyCharm','vest','bandage','wallet','notebook','magnet','gloves','sight','lens','spring','timer','battery','wideLens','criticalEye','sharpStone','umbrella','bloodPack','swordManual','toolbox','conductor','splitter','mineCase','cursedStone','hunterCoat','bloodCircuit','commandCore','stormCore'];
const weaponDetailImages: Record<string,ImageId> = {
  manaSword:'weaponManaSword', guardianDaggers:'weaponGuardianShuriken', manaBolt:'weaponManaBolt',
  manaShotgun:'weaponManaShotgun',
  piercingShot:'weaponPiercingShot', chainLightning:'weaponChainLightning', manaBombard:'weaponManaBombard',
  autoTurret:'weaponAutoTurret', mineLayer:'weaponMineLayer', manaField:'weaponManaField',
};
export function inventoryArt(index: number): string {
  return `<span class="inventory-art" aria-hidden="true" style="background-image:url('${atlas}');background-position:${index % 8 / 7 * 100}% ${Math.floor(index / 8) / 5 * 100}%"></span>`;
}
export const itemArt = (id: string): string => inventoryArt(Math.max(0, itemIds.indexOf(id)));
export const weaponArt = (id: string): string =>
  `<span class="inventory-art weapon-inventory-art" aria-hidden="true" style="background-image:url('${images[weaponDetailImages[id]??'weaponManaBolt'].url}');background-position:center;background-size:contain;background-repeat:no-repeat"></span>`;
export const weaponDetailArt = (id:string):string => `<img class="weapon-detail-art" src="${images[weaponDetailImages[id]??'weaponManaBolt'].url}" alt="">`;
