/** Authored sound identities. Never infer these from instance IDs, levels or randomness. */
export type SoundMaterial = 'soft' | 'metal' | 'stone' | 'crystal' | 'energy' | 'paper';
const hit = (weapon: string) => ({
  soft: `hit_${weapon}_soft`, metal: `hit_${weapon}_metal`, stone: `hit_${weapon}_stone`,
  crystal: `hit_${weapon}_crystal`, energy: `hit_${weapon}_energy`, paper: `hit_${weapon}_paper`,
});

export const audioIdentities = {
  defaultMaterial: 'soft',
  monsterMaterials: {
    copperCrab: 'metal', ironBoar: 'metal', chainWarden: 'metal', bulwark: 'metal', fenceSerpent: 'metal',
    haetaeHead: 'stone', tileTortoise: 'stone', gatekeeper: 'stone',
    crawler: 'soft', runner: 'soft', swarm: 'soft', charger: 'soft', riverEel: 'soft',
    bomber: 'soft', splitter: 'soft', mender: 'soft',
    paperCrane: 'paper',
    glassJelly: 'crystal', glassDrop: 'crystal', glassCrescent: 'crystal', glassTwin: 'crystal',
    glassSlab: 'crystal', glassCoil: 'crystal', glassTower: 'crystal', glassTrefoil: 'crystal',
    glassMask: 'crystal', glassNest: 'crystal', glassBud: 'crystal',
    signalMoth: 'energy', spitter: 'energy', lampFirefly: 'energy', lampDrop: 'energy', borderDrop: 'energy',
    summoner: 'energy', sentinel: 'energy', lurker: 'energy', riftQueen: 'energy',
    riftDrop: 'energy', riftCrescent: 'energy', riftTwin: 'energy', riftSlab: 'energy', riftCoil: 'energy',
    riftTower: 'energy', riftTrefoil: 'energy', riftMask: 'energy', riftNest: 'energy', riftBud: 'energy',
  } satisfies Record<string, SoundMaterial>,
  weaponHits: {
    manaSword: hit('manaSword'), guardianDaggers: hit('guardianDaggers'), manaBolt: hit('manaBolt'),
    manaShotgun: hit('manaShotgun'), piercingShot: hit('piercingShot'), chainLightning: hit('chainLightning'),
    manaBombard: hit('manaBombard'), autoTurret: hit('autoTurret'), mineLayer: hit('mineLayer'),
    // A sustained field stays quiet after its existing activation cue.
    manaField: null,
  },
  materialDeaths: {
    soft: 'death_soft', metal: 'death_metal', stone: 'death_stone', crystal: 'death_crystal',
    energy: 'death_energy', paper: 'death_paper',
  },
  pickups: {
    magicStone: 'pickup_magicStone', associationCoin: 'pickup_associationCoin',
    revivalStone: { low: 'pickup_revival_low', mid: 'pickup_revival_mid', high: 'pickup_revival_high' },
  },
  // Every current item has an explicit physical/acquisition identity; equal materials may share a cue.
  items: {
    energyDrink: 'item_consumable', riceBall: 'item_consumable', bandage: 'item_cloth',
    bloodPack: 'item_consumable', vitalAmpoule: 'item_consumable', dawnThermos: 'item_consumable',
    runningShoes: 'item_cloth', vest: 'item_cloth', wallet: 'item_cloth', gloves: 'item_cloth',
    umbrella: 'item_cloth', hunterCoat: 'item_cloth', ankleGuard: 'item_cloth', reinforcedHarness: 'item_cloth',
    scope: 'item_optic', sight: 'item_optic', lens: 'item_optic', wideLens: 'item_optic',
    criticalEye: 'item_optic', splitter: 'item_optic', resonancePrism: 'item_optic', horizonMirror: 'item_optic',
    luckyCharm: 'item_paper', swordManual: 'item_paper', openingTicket: 'item_paper', vaultLedger: 'item_paper',
    magnet: 'item_metal', spring: 'item_metal', sharpStone: 'item_metal', toolbox: 'item_metal',
    mineCase: 'item_metal', recoilBracer: 'item_metal', anchorBadge: 'item_metal', kineticSpool: 'item_metal',
    executionBell: 'item_metal', duelCompass: 'item_metal', fieldSuture: 'item_metal', salvageFilter: 'item_metal',
    courierWheel: 'item_metal', firstShield: 'item_metal',
    cursedStone: 'item_arcane', stormCore: 'item_arcane', tunedCore: 'item_arcane', scarSeal: 'item_arcane',
    phoenixMatch: 'item_arcane',
    timer: 'item_circuitry', battery: 'item_circuitry', conductor: 'item_circuitry',
    bloodCircuit: 'item_circuitry', commandCore: 'item_circuitry', magneticCollector: 'item_circuitry',
    harmonicCapacitor: 'item_circuitry', ionConductor: 'item_circuitry', shieldEmitter: 'item_circuitry',
    revengeFuse: 'item_circuitry',
  },
  weaponPurchases: {
    manaSword: 'weaponPurchase', guardianDaggers: 'weaponPurchase', manaBolt: 'weaponPurchase',
    manaShotgun: 'weaponPurchase', piercingShot: 'weaponPurchase', chainLightning: 'weaponPurchase',
    manaBombard: 'weaponPurchase', autoTurret: 'weaponPurchase', mineLayer: 'weaponPurchase', manaField: 'weaponPurchase',
  },
  aliases: { critical: 'enemyHit' },
} as const;
