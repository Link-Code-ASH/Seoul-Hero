import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const briefs=[];
for(const name of ['core.json','additional.json']){try{briefs.push(...JSON.parse(await fs.readFile(path.join(root,'briefs',name),'utf8')));}catch(error){if(error.code!=='ENOENT')throw error;}}
const rules={
 weapon:'One standalone equipment icon, full object, no hand or character. Distinct readable silhouette at 48px. No floor or cast shadow.',
 character:'One full-body Korean awakened human. Match reference SD proportion: head about 60 percent of total height, tiny torso, extremely short arms and legs, BOTH HANDS EMPTY relaxed at sides. Front three-quarter idle stance, face and full shoes visible. No floating weapon, no floor shadow, no rig parts.',
 staff:'One full-body Korean guild employee. Match reference SD proportion: head about 60 percent of height, tiny torso, extremely short limbs. BOTH HANDS EMPTY, relaxed idle stance. No handheld tool, no floor shadow, no rig parts.',
 monster:'One cute threatening legless monster. Absolutely NO LEGS, NO FEET, NO WALKING JOINTS, NO HUMAN ARMS. Single cohesive body, full silhouette visible, no floor shadow or ground plane.',
 blessing:'One Korean folklore blessing artifact or protection emblem. Strong readable silhouette at 48px, polished material detail. No text, no icon frame, no floor shadow.',
 currency:'One distinctive future resource inventory object. Clear material and silhouette at 32px. No coin UI frame, no text or price, no floor shadow. This is artwork only, not a current gameplay currency.',
 map:'A wide 20:9 orthographic TOP-DOWN Seoul arena environment illustration. Reference only for camera and painterly rendering, create a different place. Readable wide continuous walkable center with detail mainly at edges. No characters, HUD, labels, gibberish signage, perspective skyline or screenshot frame.',
 facility:'Modern Seoul guild facility artwork. For rooms use orthographic FRONTAL SIDE CUTAWAY, approximately 2:1, consistent horizontal floor height, clear foreground floor for separately overlaid SD employees. No people, HUD, text, buttons or isometric room view. Equipment is a separate transparent cutout, exterior and state follow the supplied subject.',
 effect:'Reusable raster VFX artwork ONLY, no UI screenshot, icon, background or object being upgraded. Preserve colored translucent luminous edges, clean real alpha, not a black or checkerboard rectangle. No letters, numbers, labels, borders or floor shadow.'
};
await fs.mkdir(path.join(root,'prompts'),{recursive:true});
for(const brief of briefs){
 const sequence=brief.format==='sequence8';
 const prompt=['Use case: stylized-concept.',`Asset type: Seoul Hero future ${brief.category} ${sequence?'8-frame animation source sheet':'individual PNG artwork'}.`,
 'Primary request: '+brief.visualBrief,
 'Style: original crisp Korean mobile-game hand-painted raster art, strong readable silhouettes, clean navy outlines where appropriate, restrained cel shading and material highlights. Follow the specific subject palette in the brief. Create a new silhouette and object, with no copied reference subject.',
 rules[brief.category],
 sequence?'Layout: EXACTLY 8 animation frames in a strict FOUR COLUMNS by TWO ROWS grid, read left-to-right then top-to-bottom. Each frame same canvas dimensions and FIXED CENTER PIVOT. No dividing lines, no captions. One evolving effect, coherent shape progression from charging through peak to fading, isolated within each cell with safe padding; no inter-cell spill. Wide 2:1 sheet. Actual transparent background in EVERY cell. No unrelated effects.':'Composition: single subject fully inside canvas, centered with 8 percent safe padding. No contact sheet or multiple examples.',
 brief.transparent?'Background: actual transparent RGBA, no opaque backdrop, no fake checkerboard.':'Background: complete illustrated environment filling the image.',
 'Constraints: no text, logos, watermark, UI chrome, labels or numbers. Preserve the requested anatomy and view.'].join('\n');
 const destination=path.join(root,'prompts',brief.id+'.txt');
 try { await fs.writeFile(destination,prompt+'\n',{flag:process.argv.includes('--refresh')?'w':'wx'}); } catch(error) { if(error.code!=='EEXIST')throw error; }
}
console.log(JSON.stringify({promptCount:briefs.length,sequenceCount:briefs.filter(b=>b.format==='sequence8').length}));
