import type { ShopCardText } from '../types';
import { itemShopCardText } from '../shopCardText';
import type { StatKey, WeaponCapability } from '../stats';
export type Rarity = 'COMMON'|'UNCOMMON'|'RARE'|'EPIC'|'LEGENDARY';
export type ItemEffect = {type:'structureLimit';tag:WeaponCapability;value:number}|{type:'projectileCount';tag:WeaponCapability;value:number}|{type:'indirectLifesteal';value:number}
 | {type:'conditionalStat';condition:'stationary'|'moving'|'injured'|'wealth'|'dawn'|'pickupSprint';stat:StatKey;value:number;threshold:number;limit?:number}
 | {type:'conditionalDamage';condition:'opening'|'execute'|'close'|'distant';value:number;threshold:number}
 | {type:'killHeal'|'pickupHeal';value:number;every:number}
 | {type:'retaliate';value:number;radius:number;cooldown:number}
 | {type:'firstShield'|'lastStand';value:number};
export interface ItemShopText {effects:string[];penalties:string[]}
export interface ItemData {id:string;name:string;description:string;shopText:ItemShopText;shopCardText?:ShopCardText;rarity:Rarity;basePrice:number;statModifiers:{stat:StatKey;operation:'add'|'multiply';value:number}[];specialEffects:ItemEffect[];maxStacks:number|null;tags:string[];icon:string;unlockCondition:{wave?:number;metaItemId?:string}|null}
const labels:Record<StatKey,string>={damage:'피해량',attackSpeed:'공격 속도',meleeDamage:'근접 피해량',rangedDamage:'원거리 피해량',criticalChance:'치명타 확률',criticalDamage:'치명타 피해량',range:'사거리',area:'공격 범위',duration:'지속시간',projectileSpeed:'투사체 속도',maxHp:'최대 체력',armor:'방어력',dodge:'회피 확률',lifesteal:'흡혈',hpRegeneration:'초당 체력 회복',moveSpeed:'이동속도',currencyGain:'마력석 획득량',pickupRange:'획득 범위',luck:'행운',curse:'저주'};
const percentStats = new Set<StatKey>(['damage','attackSpeed','meleeDamage','rangedDamage','criticalChance','criticalDamage','range','area','duration','projectileSpeed','dodge','lifesteal','currencyGain']);
const number = (value:number):string => Number.isInteger(value) ? String(value) : value.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
const describeStat = (stat:StatKey, value:number):string => {
 const amount = percentStats.has(stat) ? `${number(Math.abs(value) * 100)}%` : number(Math.abs(value));
 return `${labels[stat]} ${value >= 0 ? '+' : '-'}${amount} ${value >= 0 ? '증가' : '감소'}`;
};
// Card copy is data, not a clipped excerpt of the full description. Keep each
// entry short enough for one 149px line at 14px; two benefit lines are reserved.
const shopLabels:Record<StatKey,string>={damage:'피해',attackSpeed:'공격속도',meleeDamage:'근접피해',rangedDamage:'원거리피해',criticalChance:'치명확률',criticalDamage:'치명피해',range:'사거리',area:'공격범위',duration:'지속시간',projectileSpeed:'투사체속도',maxHp:'최대HP',armor:'방어력',dodge:'회피',lifesteal:'흡혈',hpRegeneration:'초당회복',moveSpeed:'이동속도',currencyGain:'마력석획득',pickupRange:'획득범위',luck:'행운',curse:'저주'};
const shopStat = (stat:StatKey,value:number):string => `${shopLabels[stat]} ${value < 0 ? '-' : '+'}${number(Math.abs(value)*(percentStats.has(stat)?100:1))}${percentStats.has(stat)?'%':''}`;
const capabilityLabels:Partial<Record<WeaponCapability,string>>={STRUCTURE:'설치물',TURRET:'포탑',MINE:'지뢰',CHAIN:'연쇄',PROJECTILE:'투사체'};
function shopEffect(effect:ItemEffect):string[] {
 switch(effect.type) {
  case 'structureLimit':return [`${capabilityLabels[effect.tag]??effect.tag} 최대 수 +${number(effect.value)}`];
  case 'projectileCount':return [`${capabilityLabels[effect.tag]??effect.tag} 공격 수 +${number(effect.value)}`];
  case 'indirectLifesteal':return ['설치물 공격도 흡혈'];
  case 'conditionalStat':switch(effect.condition) {
   case 'stationary':return [`${number(effect.threshold)}초 정지: ${shopStat(effect.stat,effect.value)}`,'이동하면 해제'];
   case 'moving':return [`이동 중 ${shopStat(effect.stat,effect.value)}`,'멈추면 해제'];
   case 'injured':return [`손실HP${number(effect.threshold*100)}%당 피해+${number(effect.value*100)}%`,`최대 +${number((effect.limit??0)*100)}%`];
   case 'wealth':return [`마력석${number(effect.threshold)}당 피해+${number(effect.value*100)}%`,`최대+${number((effect.limit??0)*100)}%·소비 시 감소`];
   case 'dawn':return [`웨이브 첫 ${number(effect.threshold)}초`,`초당 HP +${number(effect.value)}`];
   case 'pickupSprint':return [`마력석 회수: 이속+${number(effect.value)}`,`${number(effect.threshold)}초·재회수 시 갱신`];
  }
  break;
  case 'conditionalDamage':switch(effect.condition) {
   case 'opening':return ['최대HP 적 첫 적중',`피해 +${number(effect.value*100)}%`];
   case 'execute':return [`적 HP ${number(effect.threshold*100)}% 이하`,`피해 +${number(effect.value*100)}%`];
   case 'close':return [`거리 ${number(effect.threshold)} 이내 적`,`피해 +${number(effect.value*100)}%`];
   case 'distant':return [`거리 ${number(effect.threshold)} 이상 적`,`피해 +${number(effect.value*100)}%`];
  }
  break;
  case 'killHeal':return [`보상 적 ${number(effect.every)}마리 처치`,`마다 HP +${number(effect.value)}`];
  case 'pickupHeal':return [`마력석 ${number(effect.every)}개 회수`,`마다 HP +${number(effect.value)}`];
  case 'retaliate':return [`피격: ${number(effect.radius)}범위 고정${number(effect.value)}`,`${number(effect.cooldown)}초 쿨·흡혈/치명 없음`];
  case 'firstShield':return [`웨이브 첫 피해 -${number(effect.value*100)}%`,'회피 시 소모 없음'];
  case 'lastStand':return ['한 판 1회: HP 1로 생존',`치명상 후 ${number(effect.value)}초 무적`];
 }
 return [];
}
export const items:Record<string,ItemData>={};
function add(id:string,name:string,rarity:Rarity,price:number,stat:StatKey,value:number,icon:string,maxStacks:number|null=rarity==='COMMON'?5:rarity==='UNCOMMON'?3:rarity==='RARE'?2:1,extra:ItemEffect[]=[],penalty?:{stat:StatKey;value:number}) {
 const effects=[{stat,operation:'add' as const,value},...(penalty?[{...penalty,operation:'add' as const}]:[])];
 items[id]={id,name,rarity,shopCardText:itemShopCardText[id]!,basePrice:Math.ceil(price*1.1),description:effects.map(e=>describeStat(e.stat,e.value)).join(' · ')+(extra.length?' · '+extra.map(e=>e.type==='structureLimit'?'설치물 최대 수 +'+e.value+' 증가':e.type==='projectileCount'?e.tag+' 공격 수 +'+e.value+' 증가':'설치물 공격 흡혈 허용').join(' · '):''),shopText:{effects:[shopStat(stat,value),...extra.flatMap(shopEffect)],penalties:penalty?[shopStat(penalty.stat,penalty.value)]:[]},statModifiers:effects,specialEffects:extra,maxStacks,tags:[stat,...(penalty?['TRADE_OFF']:[])],icon,unlockCondition:null};
}
function addPair(id:string,name:string,rarity:Rarity,price:number,first:StatKey,firstValue:number,second:StatKey,secondValue:number,icon:string,maxStacks:number|null,penalty?:{stat:StatKey;value:number}):void {
 add(id,name,rarity,price,first,firstValue,icon,maxStacks,[],penalty);
 const item=items[id]!;
 item.statModifiers.push({stat:second,operation:'add',value:secondValue});
 item.description+=' · '+describeStat(second,secondValue);
 item.shopText.effects.push(shopStat(second,secondValue));
 item.tags.push(second);
}
add('energyDrink','에너지 드링크','COMMON',12,'attackSpeed',0.05,'🥤');
add('riceBall','삼각김밥','COMMON',10,'maxHp',6,'🍙');
add('runningShoes','러닝화','COMMON',14,'moveSpeed',6,'👟');
add('scope','헌터 조준경','COMMON',14,'range',0.05,'🔭');
add('luckyCharm','행운 부적','COMMON',12,'luck',2,'🍀');
add('vest','방탄 조끼','COMMON',15,'armor',3,'🦺');
add('bandage','재생 붕대','COMMON',14,'hpRegeneration',0.18,'🩹');
add('wallet','튼튼한 지갑','COMMON',12,'currencyGain',0.04,'👛');
add('magnet','휴대용 자석','COMMON',10,'pickupRange',10,'🧲');
add('gloves','작업 장갑','COMMON',12,'meleeDamage',0.06,'🧤');
add('sight','레이저 사이트','COMMON',12,'rangedDamage',0.06,'🎯');
add('lens','마력 렌즈','COMMON',15,'damage',0.04,'🔮');
add('spring','압축 스프링','COMMON',10,'projectileSpeed',0.08,'🌀');
add('timer','디지털 타이머','COMMON',12,'duration',0.07,'⏱');
add('battery','과충전 배터리','UNCOMMON',24,'attackSpeed',0.16,'🔋',3,[],{stat:'maxHp',value:-8});
add('wideLens','광각 마력 렌즈','UNCOMMON',24,'area',0.12,'💠');
add('criticalEye','정밀 안경','UNCOMMON',25,'criticalChance',0.06,'👓',3);
add('sharpStone','예리한 숫돌','UNCOMMON',24,'criticalDamage',0.25,'🪨');
add('umbrella','회피 우산','UNCOMMON',24,'dodge',0.035,'☂',3);
add('bloodPack','헌터 혈액팩','UNCOMMON',28,'lifesteal',0.01,'🩸',3);
add('swordManual','검술 교본','UNCOMMON',24,'meleeDamage',0.2,'📕',3,[],{stat:'rangedDamage',value:-0.1});
add('toolbox','공구함','UNCOMMON',30,'armor',2,'🧰',2,[{type:'structureLimit',tag:'STRUCTURE',value:1}],{stat:'moveSpeed',value:-5});
add('conductor','연쇄 도체','EPIC',57,'rangedDamage',0.05,'⚡',1,[{type:'projectileCount',tag:'CHAIN',value:1}],{stat:'attackSpeed',value:-0.06});
add('splitter','분광 렌즈','EPIC',61,'projectileSpeed',0.05,'💎',1,[{type:'projectileCount',tag:'PROJECTILE',value:1}],{stat:'attackSpeed',value:-0.12});
add('mineCase','지뢰 보급함','RARE',42,'area',0.06,'📦',2,[{type:'structureLimit',tag:'MINE',value:1}],{stat:'moveSpeed',value:-5});
add('cursedStone','저주받은 마력석','RARE',45,'currencyGain',0.25,'🟣',2,[],{stat:'curse',value:8});
add('hunterCoat','헌터 방호 코트','RARE',45,'maxHp',30,'🧥',2,[],{stat:'hpRegeneration',value:-0.2});
add('bloodCircuit','흡혈 회로','LEGENDARY',85,'lifesteal',0.02,'❤️',1,[{type:'indirectLifesteal',value:1}],{stat:'maxHp',value:-12});
add('commandCore','지휘 코어','LEGENDARY',90,'damage',0.1,'🛰',1,[{type:'structureLimit',tag:'TURRET',value:1}],{stat:'moveSpeed',value:-8});
add('stormCore','폭풍 심장','LEGENDARY',90,'attackSpeed',0.12,'🌩',1,[{type:'projectileCount',tag:'CHAIN',value:2}],{stat:'maxHp',value:-24});

addPair('recoilBracer','반동 안정 팔찌','COMMON',16,'rangedDamage',0.04,'projectileSpeed',0.04,'itemRecoilBracer',4);
addPair('vitalAmpoule','응급 회복 앰플','COMMON',16,'hpRegeneration',0.08,'maxHp',4,'itemVitalAmpoule',4);
addPair('ankleGuard','전술 발목 보호대','COMMON',17,'dodge',0.02,'moveSpeed',3,'itemAnkleGuard',4);
addPair('magneticCollector','자력 회수기','COMMON',15,'pickupRange',8,'currencyGain',0.02,'itemMagneticCollector',4);
addPair('reinforcedHarness','강화 전술 하네스','UNCOMMON',29,'maxHp',10,'armor',2,'itemReinforcedHarness',3);
addPair('harmonicCapacitor','위상 축전기','UNCOMMON',29,'attackSpeed',0.08,'duration',0.05,'itemHarmonicCapacitor',3);
addPair('ionConductor','이온 도체','UNCOMMON',31,'rangedDamage',0.25,'projectileSpeed',0.18,'itemIonConductor',2,{stat:'area',value:-0.18});
addPair('shieldEmitter','휴대 차폐기','RARE',49,'armor',4,'dodge',0.025,'itemShieldEmitter',2,{stat:'moveSpeed',value:-6});
addPair('resonancePrism','공명 프리즘','EPIC',59,'area',0.1,'duration',0.08,'itemResonancePrism',1,{stat:'attackSpeed',value:-0.06});
addPair('tunedCore','조율 마력핵','LEGENDARY',90,'damage',0.13,'attackSpeed',0.08,'itemTunedCore',1,{stat:'maxHp',value:-15});

items.bloodCircuit!.unlockCondition={metaItemId:'bloodCircuit'};

// Distinct triggers and tradeoffs; never add a numerical variant of an existing item.
function unique(id:string,name:string,rarity:Rarity,price:number,description:string,effect:ItemEffect,penalty?:{stat:StatKey;value:number}):void {
 items[id]={id,name,rarity,shopCardText:itemShopCardText[id]!,basePrice:price,description:description+(penalty?' · '+describeStat(penalty.stat,penalty.value):''),shopText:{effects:shopEffect(effect),penalties:penalty?[shopStat(penalty.stat,penalty.value)]:[]},statModifiers:penalty?[{...penalty,operation:'add'}]:[],specialEffects:[effect],maxStacks:1,tags:['UNIQUE_TRIGGER',...(penalty?['TRADE_OFF']:[])],icon:id+'Icon',unlockCondition:null};
}
unique('anchorBadge','정박 배지','UNCOMMON',34,'0.7초 정지하면 피해 +30%. 이동 시 해제.',{type:'conditionalStat',condition:'stationary',stat:'damage',value:0.3,threshold:0.7},{stat:'moveSpeed',value:-4});
unique('kineticSpool','관성 릴','UNCOMMON',35,'이동 중 공격 속도 +22%. 멈추면 해제.',{type:'conditionalStat',condition:'moving',stat:'attackSpeed',value:0.22,threshold:0},{stat:'maxHp',value:-12});
unique('scarSeal','흉터 인장','EPIC',64,'잃은 체력 10%마다 피해 +5%, 최대 +40%.',{type:'conditionalStat',condition:'injured',stat:'damage',value:0.05,threshold:0.1,limit:0.4},{stat:'dodge',value:-0.03});
unique('openingTicket','개문 승차권','UNCOMMON',36,'체력이 가득 찬 적에게 첫 적중 피해 +65%.',{type:'conditionalDamage',condition:'opening',value:0.65,threshold:1},{stat:'attackSpeed',value:-0.06});
unique('executionBell','종결 종','RARE',49,'체력 25% 이하의 적에게 피해 +55%.',{type:'conditionalDamage',condition:'execute',value:0.55,threshold:0.25});
unique('duelCompass','결투 나침반','UNCOMMON',38,'거리 110 이내의 적에게 피해 +35%.',{type:'conditionalDamage',condition:'close',value:0.35,threshold:110},{stat:'range',value:-0.12});
unique('horizonMirror','지평 거울','RARE',47,'거리 250 이상의 적에게 피해 +45%.',{type:'conditionalDamage',condition:'distant',value:0.45,threshold:250},{stat:'maxHp',value:-12});
unique('dawnThermos','새벽 보온병','UNCOMMON',35,'각 웨이브 첫 20초 동안 초당 체력 1 회복.',{type:'conditionalStat',condition:'dawn',stat:'hpRegeneration',value:1,threshold:20},{stat:'attackSpeed',value:-0.08});
unique('fieldSuture','전장 봉합기','RARE',46,'보상 대상 적 8마리 처치마다 체력 3 회복.',{type:'killHeal',value:3,every:8});
unique('revengeFuse','보복 퓨즈','EPIC',66,'피격 시 반경 140에 고정 피해 24. 재사용 6초. 흡혈·치명타 없음.',{type:'retaliate',value:24,radius:140,cooldown:6},{stat:'dodge',value:-0.04});
unique('salvageFilter','회수 여과기','UNCOMMON',37,'마력석 픽업 12개 회수마다 체력 5 회복.',{type:'pickupHeal',value:5,every:12});
unique('courierWheel','배달 바퀴','UNCOMMON',33,'마력석 회수 후 1.5초 동안 이동속도 +30. 재회수 시 시간 갱신.',{type:'conditionalStat',condition:'pickupSprint',stat:'moveSpeed',value:30,threshold:1.5},{stat:'pickupRange',value:-8});
unique('firstShield','초회 방패패','RARE',50,'웨이브마다 처음 받는 피해를 70% 줄임. 회피는 횟수를 소모하지 않음.',{type:'firstShield',value:0.7});
unique('vaultLedger','금고 장부','RARE',48,'보유 마력석 20마다 피해 +2%, 최대 +30%. 소비 시 즉시 감소.',{type:'conditionalStat',condition:'wealth',stat:'damage',value:0.02,threshold:20,limit:0.3},{stat:'pickupRange',value:-10});
unique('phoenixMatch','불사 성냥','LEGENDARY',96,'한 판에 1회, 치명적 피해에서 체력 1로 생존하고 2.5초 무적.',{type:'lastStand',value:2.5},{stat:'maxHp',value:-10});
