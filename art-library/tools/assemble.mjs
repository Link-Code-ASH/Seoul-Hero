import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const library = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repository = path.dirname(library);
const readJson = (filename, fallback) => fs.existsSync(filename) ? JSON.parse(fs.readFileSync(filename, 'utf8')) : fallback;
const slash = value => value.split(path.sep).join('/');
const resolveFile = value => {
  if (!value || typeof value !== 'string') return null;
  if (path.isAbsolute(value)) return value;
  return path.resolve(value.replaceAll('\\', '/').startsWith('art-library/') ? repository : library, value);
};
const webPath = value => {
  const absolute = resolveFile(value);
  return absolute ? slash(path.relative(library, absolute)) : '';
};
const statFile = value => {
  const absolute = resolveFile(value);
  return Boolean(absolute && fs.existsSync(absolute) && fs.statSync(absolute).isFile());
};
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const categories = ['weapon','character','monster','blessing','staff','map','effect','facility','currency'];
const labels = {weapon:'무기',character:'각성자',monster:'몬스터',blessing:'축복',staff:'직원',map:'맵',effect:'효과',facility:'시설',currency:'재화'};
const perBatch = {weapon:12,character:8,monster:16,blessing:10,staff:8,map:6,effect:24,facility:8,currency:8};
const briefsDirectory = path.join(library, 'briefs');
const briefFiles = fs.existsSync(briefsDirectory) ? fs.readdirSync(briefsDirectory).filter(name => name.endsWith('.json') && name !== 'recipes.json').sort() : [];
const briefs = briefFiles.flatMap(name => {
  const values = readJson(path.join(briefsDirectory, name), []);
  if (!Array.isArray(values)) throw new Error(`Brief source must be an array: ${name}`);
  return values;
});
const seen = new Set();
for (const brief of briefs) {
  if (!brief.id || seen.has(brief.id)) throw new Error(`Missing or duplicate asset ID: ${brief.id}`);
  if (!categories.includes(brief.category)) throw new Error(`Unknown category for ${brief.id}: ${brief.category}`);
  seen.add(brief.id);
}
const recordsDirectory = path.join(library, 'records');
const records = new Map();
if (fs.existsSync(recordsDirectory)) {
  for (const filename of fs.readdirSync(recordsDirectory).filter(name => name.endsWith('.json')).sort()) {
    const record = readJson(path.join(recordsDirectory, filename), null);
    if (!record?.id || records.has(record.id)) throw new Error(`Missing or duplicate record ID: ${filename}`);
    records.set(record.id, record);
  }
}
const orphanRecords = [...records.keys()].filter(id => !seen.has(id));
const assets = briefs.map(brief => {
  const ordinal = Number(brief.id.split('-').at(-1));
  const batch = Math.floor((ordinal-1)/perBatch[brief.category])+1;
  const record = records.get(brief.id) ?? null;
  const warnings = [];
  const files = (record?.files ?? []).map(file => {
    const exists = statFile(file.path);
    const result = {...file, webPath:webPath(file.path), exists};
    if (!exists) warnings.push(`파일 없음: ${file.path}`);
    else {
      const bytes = fs.readFileSync(resolveFile(file.path));
      result.actualSha256 = hash(bytes);
      if (file.sha256 && file.sha256 !== result.actualSha256) warnings.push(`해시 불일치: ${file.path}`);
      const png = bytes.length >= 26 && bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
      if (png) {
        result.actualWidth = bytes.readUInt32BE(16);
        result.actualHeight = bytes.readUInt32BE(20);
        result.actualAlphaChannel = [4,6].includes(bytes[25]);
        if (file.width !== result.actualWidth || file.height !== result.actualHeight) warnings.push(`크기 기록 불일치: ${file.path}`);
        if (typeof file.alphaChannel === 'boolean' && file.alphaChannel !== result.actualAlphaChannel) warnings.push(`알파 채널 기록 불일치: ${file.path}`);
      }
      else warnings.push(`PNG 파일 확인 필요: ${file.path}`);
    }
    return result;
  });
  const framePaths = record?.sequence?.framePaths ?? [];
  const sequence = record?.sequence ? {...record.sequence,frameWebPaths:framePaths.map(webPath),framesExist:framePaths.length === 8 && framePaths.every(statFile),sourceSheetWebPath:webPath(record.sequence.sourceSheetPath),sheetWebPath:webPath(record.sequence.sheetPath)} : null;
  if (brief.format === 'sequence8' && record && !sequence?.framesExist) warnings.push('8개 애니메이션 프레임이 모두 존재하지 않습니다.');
  if (sequence && sequence.frameCount !== 8) warnings.push('프레임 수 기록이 8과 다릅니다.');
  let prompt = '';
  const promptFile = resolveFile(record?.source?.promptPath);
  if (promptFile && statFile(promptFile)) prompt = fs.readFileSync(promptFile,'utf8');
  let thumbnail = '';
  if (record?.thumbnail && statFile(record.thumbnail)) thumbnail = webPath(record.thumbnail);
  else if (sequence?.framesExist) thumbnail = sequence.frameWebPaths[0];
  else thumbnail = files.find(file => file.exists)?.webPath ?? '';
  const fileReady = files.some(file => file.exists) && warnings.length === 0 && (brief.format !== 'sequence8' || Boolean(sequence?.framesExist));
  return {...brief,batch,tags:[...(brief.tags??[]),`묶음${String(batch).padStart(2,'0')}`],status:record?.status ?? 'planned',record:record ? {...record,files,sequence,source:{...record.source,promptWebPath:webPath(record.source?.promptPath)},prompt} : null,thumbnail,fileReady,warnings};
});
const byId = new Map(assets.map(asset => [asset.id,asset]));
const sourceReferences = readJson(path.join(library,'references.json'),[]);
const references = (Array.isArray(sourceReferences) ? sourceReferences : []).map(reference => ({...reference,webPath:webPath(reference.path),exists:statFile(reference.path)}));
const sourceRecipes = readJson(path.join(briefsDirectory,'recipes.json'),[]);
if (!Array.isArray(sourceRecipes)) throw new Error('recipes.json must be an array.');
const recipes = sourceRecipes.map(recipe => {
  const missingLayers = (recipe.layers ?? []).filter(layer => {
    const asset = byId.get(layer.assetId);
    return !asset || asset.status !== 'complete' || !asset.fileReady;
  });
  return {...recipe,ready:missingLayers.length === 0 && (recipe.layers?.length ?? 0)>0,missingLayers:missingLayers.length,missingAssets:[...new Set(missingLayers.map(layer => layer.assetId))]};
});
const counts = {
  plannedTarget:1000,briefs:assets.length,
  complete:assets.filter(asset => asset.status === 'complete' && asset.fileReady).length,
  generated:assets.filter(asset => Boolean(asset.thumbnail)).length,
  visuallyChecked:assets.filter(asset => asset.record?.review?.visualChecked === true).length,
  userApproved:assets.filter(asset => asset.record?.review?.userApproval === 'approved').length,
  pending:assets.filter(asset => !asset.record).length,
  recipes:recipes.length,readyRecipes:recipes.filter(recipe => recipe.ready).length,
  byCategory:Object.fromEntries(categories.map(category => [category,assets.filter(asset => asset.category === category).length]))
};
counts.byBatch = Array.from({length:10},(_,index)=>({batch:index+1,target:100,planned:assets.filter(asset=>asset.batch===index+1).length,complete:assets.filter(asset=>asset.batch===index+1&&asset.status==='complete'&&asset.fileReady).length}));
const catalog = {schemaVersion:1,title:'서울 히어로 미래 원화 후보 라이브러리',generatedAt:new Date().toISOString(),boundary:'게임에 연결하지 않은 독립 원화 후보입니다.',categories:categories.map(id => ({id,nameKo:labels[id]})),counts,assets,recipes,references,sourceFiles:briefFiles.map(name => `briefs/${name}`),orphanRecords};
fs.mkdirSync(library,{recursive:true});
fs.writeFileSync(path.join(library,'catalog.json'),JSON.stringify(catalog,null,2)+'\n');
const embedded = JSON.stringify(catalog).replace(/</g,'\\u003c').replace(/\u2028/g,'\\u2028').replace(/\u2029/g,'\\u2029');
const template = fs.readFileSync(path.join(library,'gallery-template.html'),'utf8');
if (!template.includes('__ART_LIBRARY_CATALOG__')) throw new Error('Gallery template embedding marker is missing.');
fs.writeFileSync(path.join(library,'index.html'),template.replace('__ART_LIBRARY_CATALOG__',embedded));
console.log(JSON.stringify({briefs:counts.briefs,generated:counts.generated,complete:counts.complete,recipes:counts.recipes,readyRecipes:counts.readyRecipes,orphanRecords},null,2));
