import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const sharp=require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const catalog=JSON.parse(await fs.readFile(path.join(root,'catalog.json'),'utf8'));
const representative=['weapon-001','weapon-002','character-001','character-002','monster-001','monster-002','blessing-001','blessing-002','staff-001','staff-002','map-001','map-002','effect-001','effect-013','facility-001','facility-002','currency-001','currency-002'];
const cells=[];const ids=[];const missing=[];
for(let index=0;index<representative.length;index++){
 const id=representative[index];const asset=catalog.assets.find(item=>item.id===id);
 if(!asset?.thumbnail||asset.status!=='complete'){missing.push(id);continue;}
 const image=await sharp(path.join(root,asset.thumbnail)).resize({width:240,height:150,fit:'contain',background:{r:227,g:235,b:237,alpha:1}}).png().toBuffer();
 cells.push({input:image,left:index%6*256+8,top:Math.floor(index/6)*180+8});ids.push(id);
}
await fs.mkdir(path.join(root,'contact-sheets'),{recursive:true});
await sharp({create:{width:1536,height:540,channels:4,background:{r:227,g:235,b:237,alpha:1}}}).composite(cells).png().toFile(path.join(root,'contact-sheets','representative-18.png'));
await fs.writeFile(path.join(root,'contact-sheets','representative-18.json'),JSON.stringify({rows:3,columns:6,cells:representative.map((id,index)=>({id,row:Math.floor(index/6),column:index%6,nameKo:catalog.assets.find(asset=>asset.id===id)?.nameKo??id})),included:ids,missing,countsAsNewDesign:false},null,2)+'\n');
console.log(JSON.stringify({included:ids.length,missing,path:'contact-sheets/representative-18.png'}));
