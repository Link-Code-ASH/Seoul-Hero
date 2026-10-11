import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [id,mode,...extra]=process.argv.slice(2);
if(!['background','framing','redesign'].includes(mode))throw new Error('Usage: edit-request.mjs <id> background|framing|redesign [specific correction]');
const record=JSON.parse(await fs.readFile(path.join(root,'records',id+'.json'),'utf8'));
const target=record.files[0].path;
const sequence=!!record.sequence;
const prompt=[
 `Use case: ${mode==='background'?'background-extraction':'precise-object-edit'}.`,
 `Asset type: Seoul Hero ${sequence?'eight-frame animation source sheet':'individual transparent PNG'} correction.`,
 'Input image is the exact existing EDIT TARGET, not merely a style reference.',
 mode==='background'?'Change ONLY the background: remove every opaque gray, brown, black, white or colored backdrop and all background lighting panels. Keep only the intended character, weapon or illustrated subject. Use genuine transparent RGBA outside the subject, including all holes and gaps. Do not add a replacement background, checkerboard, shadow or vignette. Preserve subject identity, pose, face, costume, geometry, palette, linework and details exactly.':mode==='redesign'?'Revise the subject to the specific design described below. Its silhouette and materials may change; retain the crisp hand-painted raster style, readable shapes and clean alpha. Replace the old motif completely when instructed.':'Keep the same design, palette and phase order. Repair the clipped tips and shrink the ENTIRE intended effect including rays, glow and particles to a compact central footprint with ample transparent space. Every tip must be fully visible. Do not add a background or change the motif.',
 sequence?'Preserve EXACTLY FOUR COLUMNS by TWO ROWS, eight equal cells. Fixed center pivot in every cell. Reconstruct any clipped beam tips before shrinking. EACH complete frame must fit inside the CENTRAL FIFTY PERCENT of its cell, leaving at least a quarter-cell transparent border on all four sides. Keep continuous shape evolution, no cell borders, labels or rearrangement.':'One complete isolated subject, centered, all tips inside canvas and at least fifteen percent transparent margin on all sides.',
 extra.join(' '),
 'Output: real transparent PNG. No text, logo, watermark, matte color or simulated transparency.'
 ].join('\n');
await fs.writeFile(path.join(root,'prompts',id+'.txt'),prompt+'\n');
const imagePath=path.join(root,target);
const data=await fs.readFile(imagePath);
const request={id,inputMode:`edit-${mode}`,imageInputsProvided:true,imageInputs:[{path:target,role:'edit-target',sha256:crypto.createHash('sha256').update(data).digest('hex')}],args:{prompt,transparent_background:true,referenced_image_paths:[imagePath]}};
await fs.mkdir(path.join(root,'requests'),{recursive:true});await fs.writeFile(path.join(root,'requests',id+'.json'),JSON.stringify(request,null,2)+'\n');
console.log(JSON.stringify(request));
