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
function add(id:string,name:string,rarity:Rarity,price:number,stat:StatKey,value:number,icon:string,maxStacks:number|null=null,extra:ItemEffect[]=[],penalty?:{stat:StatKey;value:number}) {
 const effects=[{stat,operation:'add' as const,value},...(penalty?[{...penalty,operation:'add' as const}]:[])];
 items[id]={id,name,rarity,basePrice:price,description:effects.map(e=>describeStat(e.stat,e.value)).join(' · ')+(extra.length?' · '+extra.map(e=>e.type==='structureLimit'?'설치물 최대 수 +'+e.value+' 증가':e.type==='projectileCount'?e.tag+' 공격 수 +'+e.value+' 증가':'설치물 공격 흡혈 허용').join(' · '):''),statModifiers:effects,specialEffects:extra,maxStacks,tags:[stat,...(penalty?['TRADE_OFF']:[])],icon,unlockCondition:null};
}
add('energyDrink','에너지 드링크','COMMON',12,'attackSpeed',0.08,'🥤');
add('riceBall','삼각김밥','COMMON',10,'maxHp',8,'🍙');
add('runningShoes','러닝화','COMMON',14,'moveSpeed',10,'👟');
add('scope','헌터 조준경','COMMON',14,'range',0.08,'🔭');
add('luckyCharm','행운 부적','COMMON',12,'luck',4,'🍀');
add('vest','방탄 조끼','COMMON',15,'armor',5,'🦺');
add('bandage','재생 붕대','COMMON',14,'hpRegeneration',0.2,'🩹');
add('wallet','튼튼한 지갑','COMMON',12,'currencyGain',0.08,'👛');
add('magnet','휴대용 자석','COMMON',10,'pickupRange',15,'🧲');
add('gloves','작업 장갑','COMMON',12,'meleeDamage',0.1,'🧤');
add('sight','레이저 사이트','COMMON',12,'rangedDamage',0.1,'🎯');
add('lens','마력 렌즈','COMMON',15,'damage',0.07,'🔮');
add('spring','압축 스프링','COMMON',10,'projectileSpeed',0.12,'🌀');
add('timer','디지털 타이머','COMMON',12,'duration',0.1,'⏱');
add('battery','과충전 배터리','UNCOMMON',24,'attackSpeed',0.22,'🔋',3,[],{stat:'maxHp',value:-8});
add('wideLens','광각 마력 렌즈','UNCOMMON',24,'area',0.2,'💠');
add('criticalEye','정밀 안경','UNCOMMON',25,'criticalChance',0.06,'👓',5);
add('sharpStone','예리한 숫돌','UNCOMMON',24,'criticalDamage',0.25,'🪨');
add('umbrella','회피 우산','UNCOMMON',24,'dodge',0.05,'☂',5);
add('bloodPack','헌터 혈액팩','UNCOMMON',28,'lifesteal',0.03,'🩸',5);
add('swordManual','검술 교본','UNCOMMON',24,'meleeDamage',0.3,'📕',3,[],{stat:'rangedDamage',value:-0.1});
add('toolbox','공구함','UNCOMMON',30,'armor',3,'🧰',3,[{type:'structureLimit',tag:'STRUCTURE',value:1}]);
add('conductor','연쇄 도체','RARE',48,'rangedDamage',0.12,'⚡',3,[{type:'projectileCount',tag:'CHAIN',value:1}]);
add('splitter','분광 렌즈','RARE',55,'projectileSpeed',0.15,'💎',2,[{type:'projectileCount',tag:'PROJECTILE',value:1}]);
add('mineCase','지뢰 보급함','RARE',42,'area',0.15,'📦',3,[{type:'structureLimit',tag:'MINE',value:2}]);
add('cursedStone','저주받은 마력석','RARE',45,'currencyGain',0.5,'🟣',3,[],{stat:'curse',value:10});
add('hunterCoat','헌터 방호 코트','RARE',45,'maxHp',35,'🧥',3);
add('bloodCircuit','흡혈 회로','LEGENDARY',85,'lifesteal',0.08,'❤️',1,[{type:'indirectLifesteal',value:1}]);
add('commandCore','지휘 코어','LEGENDARY',90,'damage',0.2,'🛰',1,[{type:'structureLimit',tag:'TURRET',value:2}]);
add('stormCore','폭풍 심장','LEGENDARY',90,'attackSpeed',0.2,'🌩',1,[{type:'projectileCount',tag:'CHAIN',value:3}]);

items.bloodCircuit!.unlockCondition={metaItemId:'bloodCircuit'};
