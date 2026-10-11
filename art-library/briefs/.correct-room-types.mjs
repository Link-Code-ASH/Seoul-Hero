import fs from 'node:fs/promises';
import path from 'node:path';
const root = path.resolve('art-library');
const sourcePath = path.join(root, 'briefs/additional.json');
const entries = JSON.parse(await fs.readFile(sourcePath, 'utf8'));
const configs = [
  ['training','직원 교육실','an ivory teaching console, round plum padded practice targets, mint holographic skill-demo panels and modular training stations with slate safety mats','교육 단말·훈련 표적·기술 실습 모듈'],
  ['refinery','마력 정제실','sealed violet catalyst distillation columns, copper filtration vessels, ivory crystal grading trays and stepped teal coolant pipes','촉매 증류탑·정제 여과기·결정 선별대']
];
const stages = [
  ['초기','one compact bench against the rear wall, low open shelves on one side, exposed rear pipes, a large open staff walking strip across the front','낮은 작업대와 열린 선반'],
  ['증설','a large central machine supported by two side cabinets, an overhead rail aligned behind the staff strip, raised rear utility racks','중앙 설비와 천장 레일'],
  ['전문','two physically separate workstations connected by a narrow rear conveyor, a reinforced overhead gantry, tiered back-wall storage and one enclosed processing bay','분리 작업구역과 상부 구조'],
  ['통합','three distinct work bays with a wide rear processing tower, enclosed transparent conduit bridge, ceiling crane and built-in control balcony entirely behind the clear staff strip','세 작업구역과 후면 제어층']
];
for(let i=0;i<8;i++){
  const id = 'facility-'+String(i+34).padStart(3,'0');
  const brief = entries.find(e=>e.id===id);
  const [slug,name,props,propsKo] = configs[Math.floor(i/4)];
  const stage = i%4;
  const s = stages[stage];
  const shape = `Strict FRONT CUTAWAY view of a 2:1 wide room. The room contains ${props}. Structural stage ${stage+1}: ${s[1]}. The front 20 percent is an unobstructed continuous staff walking strip, all machines and furniture stand behind it; no front walls, pillars or floating text obscure this area.`;
  const useKo = `길드 방 배경 · 시각 단계 ${stage+1}`;
  Object.assign(brief, {
    nameKo:`${name} · ${s[0]}형`, family:`room/${slug}`, tags:['시설','room',useKo],
    descriptionKo:`${propsKo}를 사용하는 ${s[2]}의 정면 단면 방. 단계마다 공간 구조가 달라짐.`,
    visualBrief:`ONE Seoul Hero facility illustration. ${shape.replace(/\.$/,'')}. Match the chunky SD urban-fantasy environment language: bold clean outlines, simple painted materials, pale ivory and navy structure with restrained teal/purple/orange indicators. No characters, baked labels, logos, UI frames, buttons or floor shadows on equipment. Clearly separate major silhouettes and retain generous safe margins. A complete fixed-view room/environment illustration; rear-wall depth only, no top-down/isometric alternative view.`,
    useKo
  });
  const promptPath = path.join(root,'prompts',id+'.txt');
  const prompt = await fs.readFile(promptPath,'utf8');
  await fs.writeFile(promptPath,prompt.replace(/^Primary request:.*$/m,'Primary request: '+brief.visualBrief),'utf8');
  const recordPath = path.join(root,'records',id+'.json');
  try{
    const record = JSON.parse(await fs.readFile(recordPath,'utf8'));
    record.status='needs-revision';
    record.review={...record.review,userApproval:'pending',notes:'Facility role corrected to '+slug+'; previous observatory/archive illustration is preserved, replacement room artwork is required.'};
    await fs.writeFile(recordPath,JSON.stringify(record,null,2)+'\n','utf8');
  }catch(error){if(error.code!=='ENOENT')throw error;}
}
await fs.writeFile(sourcePath,JSON.stringify(entries,null,2)+'\n','utf8');
console.log(JSON.stringify(entries.filter(e=>/^facility-0(3[4-9]|4[01])$/.test(e.id)).map(e=>({id:e.id,family:e.family,nameKo:e.nameKo}))));
