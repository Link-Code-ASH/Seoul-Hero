import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const briefs=[];
for(const name of ['core.json','additional.json']){try{briefs.push(...JSON.parse(await fs.readFile(path.join(root,'briefs',name),'utf8')));}catch(error){if(error.code!=='ENOENT')throw error;}}
const references=JSON.parse(await fs.readFile(path.join(root,'references.json'),'utf8'));
const id=process.argv[2];const brief=briefs.find(item=>item.id===id);
if(!brief)throw new Error('Unknown id '+id);
const promptPath=path.join(root,'prompts',id+'.txt');
let prompt=await fs.readFile(promptPath,'utf8');
prompt=prompt.replace('Style: match the supplied approved reference for crisp Korean mobile-game hand-painted raster art, strong silhouettes, clean navy outlines where appropriate, restrained teal/lilac/gold highlights. The reference is style guidance, not a subject to copy.','Style: original crisp Korean mobile-game hand-painted raster art, strong readable silhouettes, clean navy outlines where appropriate, restrained cel shading and material highlights. Follow the specific subject palette in the brief. Create a new silhouette and object, with no copied reference subject.');
if(brief.format==='sequence8'&&!prompt.includes('Registration safety:'))prompt+='\nRegistration safety: Each complete effect, including its glow and detached fragments, fits within the central 60 percent of its square cell. Leave at least 20 percent transparent clearance at EVERY cell edge. Never cut off a beam tip, ring, spark or particle. All eight cells have exactly the same fixed center.\n';
await fs.writeFile(promptPath,prompt);
const referenced_image_paths=brief.referenceIds.map(referenceId=>{
 const reference=references.find(item=>item.id===referenceId);if(!reference)throw new Error('Unknown reference '+referenceId);
 return path.join(root,reference.path);
});
const request={id,nameKo:brief.nameKo,category:brief.category,format:brief.format,inputMode:'new-from-verbal-style',styleReferenceIds:brief.referenceIds,imageInputsProvided:false,args:{prompt,transparent_background:brief.transparent}};
await fs.mkdir(path.join(root,'requests'),{recursive:true});
await fs.writeFile(path.join(root,'requests',id+'.json'),JSON.stringify(request,null,2)+'\n');
console.log(JSON.stringify(request));
