import type { StatKey, WeaponCapability } from '../stats';
export type Rarity = 'COMMON'|'UNCOMMON'|'RARE'|'LEGENDARY';
export type ItemEffect = {type:'structureLimit';tag:WeaponCapability;value:number}|{type:'projectileCount';tag:WeaponCapability;value:number}|{type:'indirectLifesteal';value:number};
export interface ItemData {id:string;name:string;description:string;rarity:Rarity;basePrice:number;statModifiers:{stat:StatKey;operation:'add'|'multiply';value:number}[];specialEffects:ItemEffect[];maxStacks:number|null;tags:string[];icon:string;unlockCondition:{wave?:number;metaItemId?:string}|null}
const labels:Record<StatKey,string>={damage:'피해량',attackSpeed:'공격 속도',meleeDamage:'근접 피해량',rangedDamage:'원거리 피해량',criticalChance:'치명타 확률',criticalDamage:'치명타 피해량',range:'사거리',area:'공격 범위',duration:'지속시간',projectileSpeed:'투사체 속도',maxHp:'최대 체력',armor:'방어력',dodge:'회피 확률',lifesteal:'흡혈',hpRegeneration:'초당 체력 회복',moveSpeed:'이동속도',currencyGain:'마력석 획득량',pickupRange:'획득 범위',luck:'행운',curse:'저주'};
const percentStats = new Set<StatKey>(['damage','attackSpeed','meleeDamage','rangedDamage','criticalChance','criticalDamage','range','area','duration','projectileSpeed','dodge','lifesteal','currencyGain']);
const number = (value:number):string => Number.isInteger(value) ? String(value) : value.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
const describeStat = (stat:StatKey, value:number):string => {
 const amount = percentStats.has(stat) ? `${number(Math.abs(value) * 100)}%` : number(Math.abs(value));
 return `${labels[stat]} ${value >= 0 ? '+' : '-'}${amount} ${value >= 0 ? '증가' : '감소'}`;
};
export const items:Record<string,ItemData>={};
function add(id:string,name:string,rarity:Rarity,price:number,stat:StatKey,value:number,icon:string,maxStacks:number|null=rarity==='COMMON'?5:rarity==='UNCOMMON'?3:rarity==='RARE'?2:1,extra:ItemEffect[]=[],penalty?:{stat:StatKey;value:number}) {
 const effects=[{stat,operation:'add' as const,value},...(penalty?[{...penalty,operation:'add' as const}]:[])];
 items[id]={id,name,rarity,basePrice:Math.ceil(price*1.1),description:effects.map(e=>describeStat(e.stat,e.value)).join(' · ')+(extra.length?' · '+extra.map(e=>e.type==='structureLimit'?'설치물 최대 수 +'+e.value+' 증가':e.type==='projectileCount'?e.tag+' 공격 수 +'+e.value+' 증가':'설치물 공격 흡혈 허용').join(' · '):''),statModifiers:effects,specialEffects:extra,maxStacks,tags:[stat,...(penalty?['TRADE_OFF']:[])],icon,unlockCondition:null};
}
function addPair(id:string,name:string,rarity:Rarity,price:number,first:StatKey,firstValue:number,second:StatKey,secondValue:number,icon:string,maxStacks:number|null,penalty?:{stat:StatKey;value:number}):void {
 add(id,name,rarity,price,first,firstValue,icon,maxStacks,[],penalty);
 const item=items[id]!;
 item.statModifiers.push({stat:second,operation:'add',value:secondValue});
 item.description+=' · '+describeStat(second,secondValue);
 item.tags.push(second);
}
add('energyDrink','에너지 드링크','COMMON',12,'attackSpeed',0.05,'🥤');
add('riceBall','삼각김밥','COMMON',10,'maxHp',6,'🍙');
add('runningShoes','러닝화','COMMON',14,'moveSpeed',6,'👟');
add('scope','헌터 조준경','COMMON',14,'range',0.05,'🔭');
add('luckyCharm','행운 부적','COMMON',12,'luck',2,'🍀');
add('vest','방탄 조끼','COMMON',15,'armor',3,'🦺');
add('bandage','재생 붕대','COMMON',14,'hpRegeneration',0.12,'🩹');
add('wallet','튼튼한 지갑','COMMON',12,'currencyGain',0.04,'👛');
add('magnet','휴대용 자석','COMMON',10,'pickupRange',10,'🧲');
add('gloves','작업 장갑','COMMON',12,'meleeDamage',0.06,'🧤');
add('sight','레이저 사이트','COMMON',12,'rangedDamage',0.06,'🎯');
add('lens','마력 렌즈','COMMON',15,'damage',0.04,'🔮');
add('spring','압축 스프링','COMMON',10,'projectileSpeed',0.08,'🌀');
add('timer','디지털 타이머','COMMON',12,'duration',0.07,'⏱');
add('battery','과충전 배터리','UNCOMMON',24,'attackSpeed',0.16,'🔋',3,[],{stat:'maxHp',value:-8});
add('wideLens','광각 마력 렌즈','UNCOMMON',24,'area',0.12,'💠');
add('criticalEye','정밀 안경','UNCOMMON',25,'criticalChance',0.04,'👓',3);
add('sharpStone','예리한 숫돌','UNCOMMON',24,'criticalDamage',0.18,'🪨');
add('umbrella','회피 우산','UNCOMMON',24,'dodge',0.035,'☂',3);
add('bloodPack','헌터 혈액팩','UNCOMMON',28,'lifesteal',0.02,'🩸',3);
add('swordManual','검술 교본','UNCOMMON',24,'meleeDamage',0.2,'📕',3,[],{stat:'rangedDamage',value:-0.1});
add('toolbox','공구함','UNCOMMON',30,'armor',2,'🧰',2,[{type:'structureLimit',tag:'STRUCTURE',value:1}],{stat:'moveSpeed',value:-5});
add('conductor','연쇄 도체','RARE',48,'rangedDamage',0.05,'⚡',1,[{type:'projectileCount',tag:'CHAIN',value:1}],{stat:'attackSpeed',value:-0.06});
add('splitter','분광 렌즈','RARE',55,'projectileSpeed',0.05,'💎',1,[{type:'projectileCount',tag:'PROJECTILE',value:1}],{stat:'attackSpeed',value:-0.08});
add('mineCase','지뢰 보급함','RARE',42,'area',0.06,'📦',2,[{type:'structureLimit',tag:'MINE',value:1}],{stat:'moveSpeed',value:-5});
add('cursedStone','저주받은 마력석','RARE',45,'currencyGain',0.25,'🟣',2,[],{stat:'curse',value:8});
add('hunterCoat','헌터 방호 코트','RARE',45,'maxHp',24,'🧥',2);
add('bloodCircuit','흡혈 회로','LEGENDARY',85,'lifesteal',0.04,'❤️',1,[{type:'indirectLifesteal',value:1}],{stat:'maxHp',value:-12});
add('commandCore','지휘 코어','LEGENDARY',90,'damage',0.1,'🛰',1,[{type:'structureLimit',tag:'TURRET',value:1}],{stat:'moveSpeed',value:-8});
add('stormCore','폭풍 심장','LEGENDARY',90,'attackSpeed',0.12,'🌩',1,[{type:'projectileCount',tag:'CHAIN',value:1}],{stat:'maxHp',value:-12});

addPair('recoilBracer','반동 안정 팔찌','COMMON',16,'rangedDamage',0.04,'projectileSpeed',0.04,'itemRecoilBracer',4);
addPair('vitalAmpoule','응급 회복 앰플','COMMON',16,'hpRegeneration',0.08,'maxHp',4,'itemVitalAmpoule',4);
addPair('ankleGuard','전술 발목 보호대','COMMON',17,'dodge',0.02,'moveSpeed',3,'itemAnkleGuard',4);
addPair('magneticCollector','자력 회수기','COMMON',15,'pickupRange',8,'currencyGain',0.02,'itemMagneticCollector',4);
addPair('reinforcedHarness','강화 전술 하네스','UNCOMMON',29,'maxHp',10,'armor',2,'itemReinforcedHarness',3);
addPair('harmonicCapacitor','위상 축전기','UNCOMMON',29,'attackSpeed',0.08,'duration',0.05,'itemHarmonicCapacitor',3);
addPair('ionConductor','이온 도체','UNCOMMON',31,'rangedDamage',0.09,'projectileSpeed',0.06,'itemIonConductor',3);
addPair('shieldEmitter','휴대 차폐기','RARE',49,'armor',4,'dodge',0.025,'itemShieldEmitter',2,{stat:'moveSpeed',value:-6});
addPair('resonancePrism','공명 프리즘','RARE',51,'area',0.1,'duration',0.08,'itemResonancePrism',2,{stat:'attackSpeed',value:-0.06});
addPair('tunedCore','조율 마력핵','LEGENDARY',90,'damage',0.13,'attackSpeed',0.08,'itemTunedCore',1,{stat:'maxHp',value:-15});

items.bloodCircuit!.unlockCondition={metaItemId:'bloodCircuit'};
