import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
const require=createRequire(import.meta.url);
const sharp=require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [id,generatedPath,...flags]=process.argv.slice(2);
if(!id||!generatedPath) throw new Error('Usage: node ingest.mjs <asset-id> <generated-image-path> [--reviewed]');
const briefs=[];
for(const name of ['core.json','additional.json']){try{briefs.push(...JSON.parse(await fs.readFile(path.join(root,'briefs',name),'utf8')));}catch(error){if(error.code!=='ENOENT')throw error;}}
const brief=briefs.find(b=>b.id===id);if(!brief)throw new Error('Unknown asset '+id);
const recordPath=path.join(root,'records',id+'.json');
let previous=null;try{previous=JSON.parse(await fs.readFile(recordPath,'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
let version=previous?Number(previous.revision.slice(1))+1:1;
let revision,directory;
await fs.mkdir(path.join(root,'originals',brief.category,id),{recursive:true});
while(true){revision='v'+String(version).padStart(2,'0');directory=`originals/${brief.category}/${id}/${revision}`;try{await fs.mkdir(path.join(root,directory));break;}catch(error){if(error.code!=='EEXIST')throw error;version++;}}
const data=await fs.readFile(generatedPath);
const preservedPrompt=`${directory}/prompt.txt`;
await fs.copyFile(path.join(root,'prompts',id+'.txt'),path.join(root,preservedPrompt));
const original=`${directory}/${brief.format==='sequence8'?'source-sheet':'original'}.png`;
await fs.writeFile(path.join(root,original),data);
async function details(relative){const buffer=await fs.readFile(path.join(root,relative));const meta=await sharp(buffer).metadata();const stats=await sharp(buffer).stats();return{path:relative,width:meta.width,height:meta.height,sha256:crypto.createHash('sha256').update(buffer).digest('hex'),alphaChannel:!!meta.hasAlpha,hasTransparency:!!meta.hasAlpha&&stats.channels.at(-1).min<255};}
const files=[await details(original)];let sequence;
if(brief.format==='sequence8'){
 const {width,height}=files[0];
 const frameWidth=Math.ceil(width/4),frameHeight=Math.ceil(height/2);
 const framePaths=[];
 for(let index=0;index<8;index++){
  const relative=`${directory}/frame-${String(index+1).padStart(2,'0')}.png`;
  const column=index%4,row=Math.floor(index/4);
  const left=Math.round(column*width/4),top=Math.round(row*height/2);
  const cellWidth=Math.round((column+1)*width/4)-left,cellHeight=Math.round((row+1)*height/2)-top;
  await sharp(data).extract({left,top,width:cellWidth,height:cellHeight}).extend({left:0,top:0,right:frameWidth-cellWidth,bottom:frameHeight-cellHeight,background:{r:0,g:0,b:0,alpha:0}}).png().toFile(path.join(root,relative));
  framePaths.push(relative);files.push(await details(relative));
 }
 sequence={framePaths,fps:12,frameCount:8,aligned:false,sheetPath:original,grid:[4,2],frameSize:[frameWidth,frameHeight],sourceSheetPreserved:true,extraction:'rounded equal grid boundaries, transparent right/bottom padding only, source unmodified'};
}
const thumbnail=`thumbnails/${id}-${revision}.png`;
await sharp(path.join(root,sequence?sequence.framePaths[3]:original)).resize({width:240,height:160,fit:'inside',withoutEnlargement:true}).png().toFile(path.join(root,thumbnail));
const reviewed=flags.includes('--reviewed');
let generationInput=null;try{generationInput=JSON.parse(await fs.readFile(path.join(root,'requests',id+'.json'),'utf8'));}catch(error){if(error.code!=='ENOENT')throw error;}
const errors=[];if(brief.transparent&&!files[0].hasTransparency)errors.push('Expected real transparency is missing');
const record={id,status:errors.length?'needs-revision':reviewed?'complete':'generated-unreviewed',revision,files,thumbnail,source:{tool:'built-in image_gen',generatedPath,promptPath:preservedPrompt,referenceIds:brief.referenceIds,createdAt:new Date().toISOString()},review:{userApproval:'pending',notes:errors.join('; '),visualChecked:reviewed},...(sequence?{sequence:{...sequence,aligned:reviewed}}:{})};
if(generationInput){record.source.inputMode=generationInput.inputMode;record.source.imageInputsProvided=generationInput.imageInputsProvided;record.source.imageInputs=generationInput.imageInputs??[];}
await fs.writeFile(path.join(root,directory,'provenance.json'),JSON.stringify(record,null,2)+'\n');
await fs.writeFile(recordPath+'.tmp',JSON.stringify(record,null,2)+'\n');
await fs.rename(recordPath+'.tmp',recordPath);
if(sequence)execFileSync(process.execPath,[path.join(root,'tools','pack-sequence.mjs'),id],{stdio:'pipe'});
console.log(JSON.stringify({id,status:record.status,revision,original,files:files.length,dimensions:[files[0].width,files[0].height],hasTransparency:files[0].hasTransparency}));
