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
  if (relative.startsWith('assets/audio/sfx/reborn-01/') && relative.endsWith('.wav')) {
    const settingsFile = output + '.import';
    const settings = fs.existsSync(settingsFile) ? fs.readFileSync(settingsFile, 'utf8')
      : '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n[params]\n\ncompress/mode=0\n';
    const pcm = settings.replace(/compress\/mode=\d+/, 'compress/mode=0');
    if (!fs.existsSync(settingsFile) || pcm !== settings) fs.writeFileSync(settingsFile, pcm);
  }
  if (!media.some(entry => entry.source === relative)) media.push({ source: relative, sha256: crypto.createHash('sha256').update(fs.readFileSync(full)).digest('hex') });
  return 'res://' + relative;
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
const audio = load('src/data/audio');
const sfx = Object.fromEntries(Object.entries(audio.sfx).map(([id, cue]) => [id, { ...cue, urls: cue.urls.map(copyAsset).filter(Boolean) }]));
const audioConfig = audio.AUDIO_CONFIG;
const audioConnections = audio.audioConnections;
const bgm = Object.fromEntries(Object.entries(audio.bgm).map(([id, group]) => [id, { ...group, tracks: group.tracks.map(track => ({ ...track, url: copyAsset(track.url) })).filter(track => track.url) }]));
copyAsset(path.join(root, 'assets/audio/sfx/reborn-01/provenance.json'));
copyAsset(path.join(root, 'assets/ui/inventory-transparent-provenance.json'));
copyAsset(path.join(root, 'assets/content-2026/provenance.json'));
copyAsset(path.join(root, 'assets/characters-sd/provenance.json'));
copyAsset(path.join(root, 'assets/characters-sd/provenance-02.json'));
copyAsset(path.join(root, 'assets/monsters-sd/provenance.json'));
copyAsset(path.join(root, 'assets/lobby-sd/provenance.json'));
copyAsset(path.join(root, 'assets/environment-sd/provenance.json'));
copyAsset(path.join(root, 'assets/environment-sd/provenance-03.json'));
copyAsset(path.join(root, 'assets/visuals/structures/provenance.json'));
copyAsset(path.join(root, 'assets/ui/urban-operation/provenance.json'));
copyAsset(path.join(root, 'assets/ui/image-skin/provenance.json'));
copyAsset(path.join(root, 'assets/ui/image-skin/runtime/provenance.json')); 
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
  gate: use('data/gateProgression','GATE_CONFIG'), milestones: use('data/gateProgression','GATE_MILESTONES'), elites: use('data/eliteModifiers','eliteModifiers'),
  enemyRules: use('data/enemyConfig','ENEMY_RULES'), curseRules: use('data/enemyConfig','CURSE_RULES'), enemyMoveScale: use('data/enemyConfig','ENEMY_MOVE_SCALE'),
  enemyPresentation: use('data/enemyPresentation','enemyPresentation'), magicStone: use('data/magicStoneConfig','MAGIC_STONE_TIERS'),
  weeklyRules: use('data/weeklyGate','weeklyGateRules'), blessings: use('data/weeklyGate','dangunBlessings'),
  growth: use('data/metaFacilities','META_GROWTH_CONFIG'), offline: use('data/metaFacilities','OFFLINE_REWARD_CONFIG'), supply: use('data/metaFacilities','SUPPLY_BOX_CONFIG'),
  upgrades: use('data/meta','metaUpgrades'), guildRoom: use('data/guild','GUILD_ROOM'), guildFacilities: use('data/guild','guildFacilities'), guildPoints: use('data/guild','guildPoints'),
  guildFootprints: use('data/guild','guildCafeFootprints'), revivalStones: use('data/revivalStones','REVIVAL_STONES'),
  defaultMeta: use('state/MetaState','createDefaultMeta')(), images, weaponArt, premiumUI, sfx, bgm, audioConfig, audioConnections,
};
fs.mkdirSync(path.join(target, 'data'), { recursive: true });
fs.writeFileSync(path.join(target, 'data/content.json'), JSON.stringify(content, null, 2) + '\n');
fs.writeFileSync(path.join(target, 'data/import-provenance.json'), JSON.stringify({ tool: 'scripts/export-godot-content.mjs', description: 'Existing Seoul Hero artwork/audio reused unchanged. Original generation and audio license records remain alongside source assets.', media }, null, 2) + '\n');
console.log(JSON.stringify({ characters:Object.keys(content.characters).length,weapons:Object.keys(content.weapons).length,enemies:Object.keys(content.enemies).length,items:Object.keys(content.items).length,assets:media.length,missingImages:Object.entries(images).filter(([,image])=>!image.url).map(([id])=>id) }));
