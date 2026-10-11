// Read-only alpha diagnostics and an explicitly derived viewing copy.
// Originals are never changed; previews are not counted as designs.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const sharp=require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output=path.join(root,'previews','alpha');
await fs.mkdir(output,{recursive:true});
const ids=process.argv.slice(2);
const cells=[];
for(const [index,id] of ids.entries()){
 const record=JSON.parse(await fs.readFile(path.join(root,'records',id+'.json'),'utf8'));
 const original=path.join(root,record.files[0].path);
 const {data,info}=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 let left=info.width,top=info.height,right=-1,bottom=-1,edgePixels=0;
 for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
  const a=data[(y*info.width+x)*info.channels+info.channels-1];
  if(a<32)continue;
  left=Math.min(left,x);top=Math.min(top,y);right=Math.max(right,x);bottom=Math.max(bottom,y);
  if(x===0||y===0||x===info.width-1||y===info.height-1)edgePixels++;
 }
 const margins=[left,top,info.width-1-right,info.height-1-bottom];
 const preview=`${id}-${record.revision}-light.png`;
 await sharp(original).flatten({background:'#e5ecef'}).png().toFile(path.join(output,preview));
 const result={id,revision:record.revision,dimensions:[info.width,info.height],alphaThreshold:32,margins,edgePixels,preview:`previews/alpha/${preview}`,derivedForReview:true,countsAsNewDesign:false};
 await fs.writeFile(path.join(output,`${id}-${record.revision}.json`),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify(result));
 const cell=await sharp(path.join(output,preview)).resize({width:384,height:384,fit:'contain',background:'#e5ecef'}).png().toBuffer();
 cells.push({input:cell,left:index%3*384,top:Math.floor(index/3)*384});
}
if(ids.length>1){
 const sheet=`${ids[0]}--${ids.at(-1)}-review.png`;
 await sharp({create:{width:Math.min(3,ids.length)*384,height:Math.ceil(ids.length/3)*384,channels:4,background:'#e5ecef'}}).composite(cells).png().toFile(path.join(output,sheet));
 await fs.writeFile(path.join(output,sheet.replace('.png','.json')),JSON.stringify({ids,columns:3,cellSize:[384,384],derivedForReview:true,countsAsNewDesign:false},null,2)+'\n');
 console.log(JSON.stringify({sheet:`previews/alpha/${sheet}`,ids}));
}
