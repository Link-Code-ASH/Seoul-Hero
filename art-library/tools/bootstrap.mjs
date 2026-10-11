import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repo = path.dirname(root);
const require = createRequire(import.meta.url);
const sharp = require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const sources = [
 ['weapon-style','assets/ui/weapons/weapon_mana_sword_casual_01.png'],
 ['character-style','assets/characters-sd/song_sd_01.png'],
 ['monster-style','assets/monsters-sd/gatekeeper_sd_01.png'],
 ['blessing-style','assets/ui/archive/blessing_cheonbu_oath_casual_01.png'],
 ['staff-style','assets/characters-sd/han_seoa_sd_01.png'],
 ['map-style','assets/environment-sd/gwanghwamun_sd_03.png'],
 ['effect-style','assets/effects/effect_vfx_critical_01.png'],
 ['facility-style','assets/ui/guild-management/rooms.png'],
 ['currency-style','assets/ui/economy-01/guildElectronicParts.png'],
 ['upgrade-icon','assets/ui/weapons/weapon_mana_sword_casual_01.png'],
 ['supply-crate','assets/ui/image-skin/seoul-support/supply_package_body.png'],
 ['supply-lid','assets/ui/image-skin/seoul-support/supply_package_lid.png']
];
const sourceDocs={
 'weapon-style':['assets/ui/weapons/SOURCES.md'],
 'character-style':['assets/characters-sd/provenance.json','assets/characters-sd/provenance-02.json'],
 'monster-style':['assets/monsters-sd/provenance.json'],
 'blessing-style':['assets/ui/archive/provenance.json','assets/ui/archive/SOURCES.md'],
 'staff-style':['assets/characters-sd/provenance.json','assets/characters-sd/provenance-02.json'],
 'map-style':['assets/environment-sd/provenance-03.json'],
 'effect-style':['assets/vfx-art-provenance.json'],
 'facility-style':['assets/ui/guild-management/provenance.json'],
 'currency-style':['assets/ui/economy-01/provenance.json','assets/ui/economy-01/source-prompts.json'],
 'upgrade-icon':['assets/ui/weapons/SOURCES.md'],
 'supply-crate':['assets/ui/image-skin/seoul-support/provenance.json','assets/ui/image-skin/seoul-support/source-prompts.json'],
 'supply-lid':['assets/ui/image-skin/seoul-support/provenance.json','assets/ui/image-skin/seoul-support/source-prompts.json']
};
for (const directory of ['briefs','records','prompts','references','originals','thumbnails','contact-sheets','recipes']) await fs.mkdir(path.join(root,directory),{recursive:true});
const references = [];
for (const [id,originalPath] of sources) {
 const data = await fs.readFile(path.join(repo,originalPath));
 const relative = `references/${id}.png`;
 await fs.writeFile(path.join(root,relative),data);
 const meta = await sharp(data).metadata();
 const documentation=[];
 for(const doc of sourceDocs[id]??[]){const content=await fs.readFile(path.join(repo,doc));const saved=`references/provenance/${id}/${path.basename(doc)}`;await fs.mkdir(path.dirname(path.join(root,saved)),{recursive:true});await fs.writeFile(path.join(root,saved),content);documentation.push({path:saved,originalPath:doc,sha256:crypto.createHash('sha256').update(content).digest('hex')});}
 references.push({id,path:relative,originalPath,sha256:crypto.createHash('sha256').update(data).digest('hex'),width:meta.width,height:meta.height,role:id.endsWith('style')?'style reference':'existing preview context',countsAsNewDesign:false,documentation});
}
await fs.writeFile(path.join(root,'references.json'),JSON.stringify(references,null,2)+'\n');
console.log(JSON.stringify({references:references.length,root}));
