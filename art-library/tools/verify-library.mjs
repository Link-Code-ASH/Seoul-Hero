import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Inventory checks for this standalone art library; does not import the game.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'));
const targets = {weapon:120,character:80,monster:160,blessing:100,staff:80,map:60,effect:240,facility:80,currency:80};
const errors = [];
const ids = new Set();
const originals = new Map();
const byCategory = {};
const sequences = [];
const exists = value => typeof value === 'string' && fs.existsSync(path.resolve(root, value));
for (const asset of catalog.assets) {
  if (ids.has(asset.id)) errors.push(`중복 ID: ${asset.id}`);
  ids.add(asset.id);
  byCategory[asset.category] = (byCategory[asset.category] ?? 0) + 1;
  if (asset.status !== 'complete' || !asset.fileReady) errors.push(`제작 미완료: ${asset.id}`);
  if (!asset.record?.review?.visualChecked) errors.push(`시각 확인 기록 없음: ${asset.id}`);
  for (const warning of asset.warnings ?? []) errors.push(`${asset.id}: ${warning}`);
  const original = asset.record?.files?.find(file => !file.derived);
  if (!original?.actualSha256) errors.push(`원본 해시 없음: ${asset.id}`);
  else {
    const previous = originals.get(original.actualSha256);
    if (previous) errors.push(`동일 원본 중복 집계: ${previous}, ${asset.id}`);
    originals.set(original.actualSha256, asset.id);
  }
  if (!asset.record?.prompt?.trim() || !exists(asset.record?.source?.promptWebPath)) errors.push(`프롬프트 없음: ${asset.id}`);
  if (asset.transparent && !original?.hasTransparency) errors.push(`요청한 원본 투명도 없음: ${asset.id}`);
  if (asset.format === 'sequence8') {
    const sequence = asset.record?.sequence;
    const frames = asset.record?.files?.filter(file => /frame-\d+\.png$/.test(file.path)) ?? [];
    const canvases = [...new Set(frames.map(file => `${file.actualWidth}x${file.actualHeight}`))];
    if (sequence?.frameCount !== 8 || sequence?.fps !== 12 || !sequence?.aligned || frames.length !== 8 || canvases.length !== 1 || !sequence?.framesExist) errors.push(`프레임 기록 확인 필요: ${asset.id}`);
    if (frames.some(file => !file.hasTransparency || !file.actualAlphaChannel)) errors.push(`프레임 알파 확인 필요: ${asset.id}`);
    sequences.push({id:asset.id,frameCount:frames.length,canvas:canvases[0],fps:sequence?.fps,aligned:sequence?.aligned});
  }
}
for (const [category, target] of Object.entries(targets)) if (byCategory[category] !== target) errors.push(`분류 수량: ${category} ${byCategory[category]} / ${target}`);
if (catalog.assets.length !== 1000 || originals.size !== 1000) errors.push('독립 원본 1,000종이 모두 갖춰지지 않았습니다.');
if (sequences.length !== 48) errors.push(`시퀀스 수량: ${sequences.length} / 48`);
const recipeIds = new Set();
const recipeFamilies = {};
for (const recipe of catalog.recipes) {
  if (recipeIds.has(recipe.id)) errors.push(`중복 레시피 ID: ${recipe.id}`);
  recipeIds.add(recipe.id);
  recipeFamilies[recipe.family] = (recipeFamilies[recipe.family] ?? 0) + 1;
  if (!recipe.ready || !recipe.layers?.length) errors.push(`레시피 소재 미완료: ${recipe.id}`);
  if (!Number.isFinite(recipe.duration) || recipe.duration <= 0 || !Array.isArray(recipe.anchor) || !Array.isArray(recipe.canvas)) errors.push(`타임라인 정보 없음: ${recipe.id}`);
  for (const layer of [...(recipe.layers ?? []),...(recipe.contextLayers ?? [])]) {
    const sourceId=layer.assetId ?? layer.referenceId;
    const sourceExists=layer.referenceId ? catalog.references.some(reference=>reference.id===layer.referenceId&&reference.exists) : ids.has(layer.assetId);
    if (!sourceExists || !Number.isFinite(layer.start) || !Number.isFinite(layer.end) || layer.end <= layer.start || !Number.isFinite(layer.z) || !layer.keyframes?.length) errors.push(`레이어 정보 확인 필요: ${recipe.id}/${sourceId}`);
    let previousTime = -Infinity;
    for (const key of layer.keyframes ?? []) {
      if (![key.t,key.x,key.y,key.scale,key.rotation,key.opacity].every(Number.isFinite) || key.t < previousTime || key.opacity < 0 || key.opacity > 1) errors.push(`키프레임 확인 필요: ${recipe.id}/${sourceId}`);
      previousTime = key.t;
    }
  }
}
if (catalog.recipes.length !== 80) errors.push(`레시피 수량: ${catalog.recipes.length} / 80`);
for (const [family, target] of Object.entries({upgrade:30,open:30,acquire:10,facility:10})) if (recipeFamilies[family] !== target) errors.push(`레시피 분류 수량: ${family} ${recipeFamilies[family]} / ${target}`);
for (const [start, end, target] of [[1,12,12],[61,76,16],[161,172,12],[201,208,8]]) if (sequences.filter(sequence => { const ordinal = Number(sequence.id.split('-').at(-1)); return ordinal >= start && ordinal <= end; }).length !== target) errors.push(`시퀀스 배정 확인 필요: effect-${start}..${end}`);
for (const reference of catalog.references) if (!reference.exists) errors.push(`참고 이미지 없음: ${reference.id}`);
for (const batch of catalog.counts.byBatch) if (batch.planned !== 100 || batch.complete !== 100) errors.push(`묶음 미완료: ${batch.batch} ${batch.complete} / 100`);
const report = {checkedAt:new Date().toISOString(),scope:'독립 라이브러리의 수량·원본 중복·경로·해시·해상도 기록·투명도 기록·프레임 및 레시피 메타데이터 확인. 게임 테스트·플레이·성능 확인을 포함하지 않습니다.',ok:errors.length === 0,assets:catalog.assets.length,independentOriginalHashes:originals.size,complete:catalog.counts.complete,byCategory,sequences,sequentialFrames:sequences.reduce((sum, sequence) => sum + sequence.frameCount, 0),recipes:catalog.recipes.length,readyRecipes:catalog.counts.readyRecipes,recipeFamilies,errors};
fs.writeFileSync(path.join(root,'metadata-check.json'), JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({ok:report.ok,assets:report.assets,complete:report.complete,independentOriginalHashes:report.independentOriginalHashes,sequences:sequences.length,sequentialFrames:report.sequentialFrames,recipes:report.recipes,readyRecipes:report.readyRecipes,errors:errors.length},null,2));
process.exitCode = errors.length ? 1 : 0;
