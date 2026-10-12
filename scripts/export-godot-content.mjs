import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';

// Evaluate the existing authored TS data, including generated Lv.10 progressions.
// No browser runtime, game state, secrets or local saves are copied.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const target = path.join(root, 'godot');
const audioOnly = process.argv.includes('--audio-only');
const modules = new Map();
const assetFiles = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full); else assetFiles.push(full);
  }
}
walk(path.join(root, 'assets'));
const globFiles = Object.fromEntries(assetFiles.map(full => ['../../' + path.relative(root, full).replaceAll('\\', '/'), full]));
function load(relative) {
  let full = path.resolve(root, relative);
  if (!fs.existsSync(full)) full += '.ts';
  if (fs.statSync(full).isDirectory()) full = path.join(full, 'index.ts');
  if (![path.join(root, 'src'), path.join(root, 'design/ui-premium-v5')].some(dir => full.startsWith(dir + path.sep))) throw new Error(`Non-content dependency: ${full}`);
  if (modules.has(full)) return modules.get(full).exports;
  const module = { exports: {} };
  modules.set(full, module);
  let source = fs.readFileSync(full, 'utf8');
  source = source.replaceAll('import.meta.env.BASE_URL', '"/"').replace(/import\.meta\.glob(?:<[^>]+>)?/g, '__glob');
  const code = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
  const wrapper = vm.runInThisContext(`(function(require,module,exports,__glob){${code}\n})`, { filename: full });
  wrapper(id => load(path.relative(root, path.resolve(path.dirname(full), id))), module, module.exports, () => globFiles);
  return module.exports;
}
const use = (file, name) => load(`src/${file}`)[name];
const manifest = use('data/images', 'images');
const media = [];
function copyAsset(full) {
  if (!full || !fs.existsSync(full)) return '';
  const relative = path.relative(root, full).replaceAll('\\', '/');
  const output = path.join(target, relative);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  if (!fs.existsSync(output) || fs.statSync(output).size !== fs.statSync(full).size || fs.statSync(output).mtimeMs < fs.statSync(full).mtimeMs) fs.copyFileSync(full, output);
  // Preserve edited PCM and exact loop seams; Godot's default WAV import is lossy QOA.
  if (/^assets\/audio\/sfx\/reborn-\d+\//.test(relative) && relative.endsWith('.wav')) {
    const settingsFile = output + '.import';
    const settings = fs.existsSync(settingsFile) ? fs.readFileSync(settingsFile, 'utf8')
      : '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\ncompress/mode=0\n';
    const pcm = /compress\/mode=\d+/.test(settings)
      ? settings.replace(/compress\/mode=\d+/, 'compress/mode=0')
      : settings.includes('[params]') ? settings.replace('[params]', '[params]\n\ncompress/mode=0')
      : settings + '\n[params]\n\ncompress/mode=0\n';
    if (!fs.existsSync(settingsFile) || pcm !== settings) fs.writeFileSync(settingsFile, pcm);
  }
  if (!media.some(entry => entry.source === relative)) media.push({ source: relative, sha256: crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex') });
  return 'res://' + relative;
}
function exportAudio() {
  const audio = load('src/data/audio');
  const sfx = Object.fromEntries(Object.entries(audio.sfx).map(([id, cue]) => [id, { ...cue, urls: cue.urls.map(copyAsset).filter(Boolean) }]));
  const bgm = Object.fromEntries(Object.entries(audio.bgm).map(([id, group]) => [id, { ...group, tracks: group.tracks.map(track => ({ ...track, url: copyAsset(track.url) })).filter(track => track.url) }]));
  copyAsset(path.join(root, 'assets/audio/sfx', audio.activeAudioRevision, 'provenance.json'));
  return { sfx, bgm, audioConfig: audio.AUDIO_CONFIG, audioConnections: audio.audioConnections, audioRevision: audio.activeAudioRevision };
}
// An audio adoption must not import concurrent artwork, balance or save-data edits.
if (audioOnly) {
  const contentFile = path.join(target, 'data/content.json');
  const existing = JSON.parse(fs.readFileSync(contentFile, 'utf8'));
  const { audioRevision, ...audioData } = exportAudio();
  if (JSON.stringify(existing.bgm) !== JSON.stringify(audioData.bgm)) throw new Error('Audio-only export refused a BGM change');
  fs.writeFileSync(contentFile, JSON.stringify({ ...existing, ...audioData }, null, 2) + '\n');
  const provenanceFile = path.join(target, 'data/import-provenance.json');
  const previous = fs.existsSync(provenanceFile) ? JSON.parse(fs.readFileSync(provenanceFile, 'utf8')) : {};
  const previousMedia = (previous.media || []).filter(entry => !entry.source.startsWith('assets/audio/'));
  fs.writeFileSync(provenanceFile, JSON.stringify({ ...previous, tool: 'scripts/export-godot-content.mjs', audioRevision, media: [...previousMedia, ...media] }, null, 2) + '\n');
  console.log(JSON.stringify({ mode: 'audio-only', revision: audioRevision, cues: Object.keys(audioData.sfx).length, assets: media.length }));
  process.exit(0);
}
// Preserved web-only artwork. Godot uses SD actor data and the battlefield title.
const webOnlyImages = new Set([
  'titleAwakeners', 'guildOperatorIllustration', 'guildOperatorLobbyFace', 'guildOperatorTopdown',
  'guildOperatorDownUpper', 'guildOperatorUpUpper', 'guildOperatorRightUpper', 'guildOperatorLeftUpper',
  'guildOperatorPogoSpring', 'guildOperatorPogoTip',
]);
const images = {};
for (const [id, image] of Object.entries(manifest)) {
  if (webOnlyImages.has(id)) continue;
  const full = image.url.startsWith('/') ? path.join(root, 'public', image.url) : image.url;
  images[id] = { ...image, url: copyAsset(full) };
}
const { sfx, audioConfig, audioConnections, bgm } = exportAudio();
copyAsset(path.join(root, 'assets/ui/inventory-transparent-provenance.json'));
copyAsset(path.join(root, 'assets/content-2026/provenance.json'));
copyAsset(path.join(root, 'assets/characters-sd/provenance.json'));
copyAsset(path.join(root, 'assets/characters-sd/provenance-02.json'));
copyAsset(path.join(root, 'assets/characters-sd/seoul-civilians-01/provenance.json'));
copyAsset(path.join(root, 'assets/characters-sd/seoul-civilians-01/catalog.json'));
copyAsset(path.join(root, 'assets/monsters-sd/provenance.json'));
copyAsset(path.join(root, 'assets/monsters-sd/provenance-02.json'));
copyAsset(path.join(root, 'assets/monsters-library/provenance.json'));
copyAsset(path.join(root, 'assets/lobby-sd/provenance.json'));
copyAsset(path.join(root, 'assets/environment-sd/provenance.json'));
copyAsset(path.join(root, 'assets/environment-sd/provenance-03.json'));
copyAsset(path.join(root, 'assets/visuals/structures/provenance.json'));
copyAsset(path.join(root, 'assets/ui/urban-operation/provenance.json'));
copyAsset(path.join(root, 'assets/ui/image-skin/provenance.json'));
for (const file of ['provenance.json','source-prompts.json']) copyAsset(path.join(root, 'assets/ui/image-skin/operations-standard-01', file));
for (const file of ['provenance.json','source-prompts.json']) copyAsset(path.join(root, 'assets/ui/image-skin/operations-light-controls-02', file));
copyAsset(path.join(root, 'assets/ui/image-skin/runtime/provenance.json'));
for (const file of ['provenance.json','source-prompts.json','approved-preview-manifest.json']) copyAsset(path.join(root, 'assets/ui/image-skin/seoul-support', file));
// Approved guild room/state atlases and their original generation records.
for (const file of ['rooms.png', 'room-states.png', 'provenance.json']) copyAsset(path.join(root, 'assets/ui/guild-management', file));
// Approved side-view corridors, elevator and building exterior.
for (const file of ['structure.png', 'structure.json', 'provenance.json']) {
  const source = path.join(root, 'assets/ui/guild-walk', file);
  copyAsset(source);
  // Retain authored import settings when supplied; otherwise keep Godot's existing settings.
  if (fs.existsSync(source + '.import')) copyAsset(source + '.import');
}

for (const file of [
  'BMJUA.ttf','Paperlogy-4Regular.ttf', 'Paperlogy-5Medium.ttf', 'Paperlogy-6SemiBold.ttf', 'Paperlogy-8ExtraBold.ttf',
  'KMU80HaeongSans.ttf', 'BarlowCondensed-SemiBold.ttf', 'BarlowCondensed-Bold.ttf',
  'SOURCES.md', 'BarlowCondensed-OFL.txt', 'OFL.txt', 'font-import-provenance.json',
]) copyAsset(path.join(root, 'assets/ui/fonts', file));
const weaponArt = { manaSword:'weaponManaSword',guardianDaggers:'weaponGuardianShuriken',manaBolt:'weaponManaBolt',manaShotgun:'weaponManaShotgun',piercingShot:'weaponPiercingShot',chainLightning:'weaponChainLightning',manaBombard:'weaponManaBombard',autoTurret:'weaponAutoTurret',mineLayer:'weaponMineLayer',manaField:'weaponManaField' };
// Accepted lobby backgrounds remain current; old v5 surfaces live in design history.
const premiumAssets = {
  premiumLobbyRain:'lobby-rain.png', premiumLobbyWind:'lobby-wind.png', premiumLobbyEnergy:'lobby-energy.png',
  premiumLobbyCheckpoint:'lobby-checkpoint.png', premiumLobbyRooftop:'lobby-rooftop.png',
};
for (const [id, file] of Object.entries(premiumAssets)) {
  images[id] = {url:copyAsset(path.join(root,'design/ui-premium-v5/assets',file)),heightRatio:1};
}
for (const file of ['generated-v5.json','generated-v4.json','provenance.json']) copyAsset(path.join(root,'design/ui-premium-v5/assets',file));
const premiumUI = {
  revision:'premium-v5', size:[915,412],
  scenes:['premiumLobbyRain','premiumLobbyWind','premiumLobbyEnergy','premiumLobbyCheckpoint','premiumLobbyRooftop'],
  atmospheres:['rain','wind','energy','snow','mist','embers'],
  weaponNotes:load('design/ui-premium-v5/weapon-notes.ts').weaponNotes,
};
const content = {
  schemaVersion: 1, sourceSaveVersion: use('save/SaveData','SAVE_VERSION'),
  characters: use('data/characters','characters'), weapons: use('data/weapons','weapons'), enemies: use('data/enemies','enemies'),
  items: use('data/items','items'), maps: use('data/maps','maps'), stats: use('data/stats','DEFAULT_STATS'), statRules: use('data/stats','STAT_RULES'),
  shop: use('data/shopConfig','SHOP_CONFIG'), weaponConfig: use('data/weaponConfig','WEAPON_CONFIG'), game: use('data/config','GAME_CONFIG'),
  balance: use('data/balanceConfig','BALANCE_CONFIG'),
  gate: use('data/economy','ECONOMY_GATE'), milestones: use('data/gateProgression','GATE_MILESTONES'), weeklyMonster: use('data/gateProgression','WEEKLY_MONSTER'), elites: use('data/eliteModifiers','eliteModifiers'), featuredElites: use('data/featuredElites','FEATURED_ELITE_RULES'),
  enemyRules: use('data/enemyConfig','ENEMY_RULES'), curseRules: use('data/enemyConfig','CURSE_RULES'), enemyMoveScale: use('data/enemyConfig','ENEMY_MOVE_SCALE'),
  enemyPresentation: use('data/enemyPresentation','enemyPresentation'), magicStone: use('data/magicStoneConfig','MAGIC_STONE_TIERS'),
  weeklyRules: use('data/weeklyGate','weeklyGateRules'), blessings: use('data/weeklyGate','dangunBlessings'),
  resources: use('data/economy','ECONOMY_RESOURCES'),
  growth: use('data/economy','ECONOMY_GROWTH'), offline: use('data/economy','ECONOMY_OFFLINE'), supply: use('data/economy','ECONOMY_SUPPLY'), daily: use('data/economy','ECONOMY_DAILY'), region: use('data/economy','ECONOMY_REGION'),
  guildManagement: use('data/guildManagement','GUILD_MANAGEMENT_DATA'), features: use('data/features','GAME_FEATURES'), draws: use('data/features','GAME_DRAWS'), runLoot: use('data/features','GAME_RUN_LOOT'),
  upgrades: use('data/economy','ECONOMY_UPGRADES'), guildRoom: use('data/guild','GUILD_ROOM'), guildFacilities: use('data/guild','guildFacilities'), guildPoints: use('data/guild','guildPoints'),
  guildFootprints: use('data/guild','guildCafeFootprints'), revivalStones: use('data/revivalStones','REVIVAL_STONES'),
  defaultMeta: use('state/MetaState','createDefaultMeta')(), images, weaponArt, premiumUI, sfx, bgm, audioConfig, audioConnections,
};
fs.mkdirSync(path.join(target, 'data'), { recursive: true });
fs.writeFileSync(path.join(target, 'data/content.json'), JSON.stringify(content, null, 2) + '\n');
fs.writeFileSync(path.join(target, 'data/import-provenance.json'), JSON.stringify({ tool: 'scripts/export-godot-content.mjs', description: 'Existing Seoul Hero artwork/audio reused unchanged. Original generation and audio license records remain alongside source assets.', media }, null, 2) + '\n');
console.log(JSON.stringify({ characters:Object.keys(content.characters).length,weapons:Object.keys(content.weapons).length,enemies:Object.keys(content.enemies).length,items:Object.keys(content.items).length,assets:media.length,missingImages:Object.entries(images).filter(([,image])=>!image.url).map(([id])=>id) }));
