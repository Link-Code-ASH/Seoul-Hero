import fs from 'node:fs/promises';
const file=new URL('./additional.json',import.meta.url);
const entries=JSON.parse(await fs.readFile(file,'utf8'));
const metadata={
 construction:{tags:['금속','합금','건축'],use:'금속 계열 · 건설·증축·금속 가공'},
 electronic:{tags:['전자','회로','제어'],use:'전자 계열 · 제어 장치·회로 연구·정밀 장비'},
 catalyst:{tags:['마력','촉매','정제'],use:'마력 계열 · 마력 정제·촉매 제조·생환석 제작'},
 biological:{tags:['생체','시약','의료'],use:'생체 계열 · 생환·직원 교육·생체 분석'},
 logistics:{tags:['탐험','보급','운송'],use:'탐험 계열 · 탐험 준비·원정 보급·운송 장비'},
 archive:{tags:['연구','자료','기록'],use:'연구 계열 · 연구 기록·분석 자료·조합법 보관'},
 energy:{tags:['동력','축전','생산'],use:'동력 계열 · 시설 가동·축전 장치·생산 동력'},
 ritual:{tags:['각성','의식','축복'],use:'각성 계열 · 각성 의식·축복 공명·옵션 분석'},
 survey:{tags:['증표','관측 인증','광학 기록'],use:'증표 계열 · 게이트 관측 인증 기록·지역 조사 완료 증표'},
 salvage:{tags:['유물','이계 회수','감정'],use:'유물 계열 · 이계 유물 회수·감정·복원'}
};
let count=0;
for(const entry of entries){
 if(entry.category!=='currency')continue;
 const data=metadata[entry.family];
 if(!data)throw new Error(`Unknown currency family: ${entry.family}`);
 entry.tags=[...new Set([...entry.tags,...data.tags,data.use])];
 entry.useKo=`${data.use}의 재료 후보 · 현행 지갑/가격/보상에 미연결`;
 count++;
}
if(count!==80)throw new Error(`Expected 80 currency briefs, got ${count}`);
await fs.writeFile(file,JSON.stringify(entries,null,2)+'\n','utf8');
console.log(JSON.stringify({updatedCurrencyBriefs:count,preserved:['nameKo','family','visualBrief','prompts','originals','records','provenance']}));
