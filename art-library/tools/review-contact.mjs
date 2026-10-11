import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const sharp=require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const ids=process.argv.slice(2);
if(!ids.length)throw new Error('Usage: node review-contact.mjs <id> ...');
const columns=Math.min(3,ids.length),size=560,rows=Math.ceil(ids.length/columns);
const layers=[];const entries=[];
for(let index=0;index<ids.length;index++){
 const id=ids[index];const record=JSON.parse(await fs.readFile(path.join(root,'records',id+'.json'),'utf8'));
 const source=record.files[0].path;
 const buffer=await sharp(path.join(root,source)).resize({width:size-40,height:size-65,fit:'inside'}).png().toBuffer();
 const meta=await sharp(buffer).metadata();
 const left=index%columns*size+Math.round((size-meta.width)/2),top=Math.floor(index/columns)*size+20;
 layers.push({input:buffer,left,top});entries.push({id,source,revision:record.revision});
 const label=Buffer.from(`<svg width="${size}" height="28"><text x="16" y="21" font-family="sans-serif" font-size="20" fill="#24344b">${id} · ${record.revision}</text></svg>`);
 layers.push({input:label,left:index%columns*size,top:Math.floor(index/columns)*size+size-32});
}
const name='review-'+ids[0]+'-'+ids.at(-1);
const png=path.join(root,'previews',name+'.png');
await sharp({create:{width:columns*size,height:rows*size,channels:4,background:'#dce5ed'}}).composite(layers).png().toFile(png);
await fs.writeFile(path.join(root,'previews',name+'.json'),JSON.stringify({purpose:'actual-alpha visual review derivative; excluded from design count',entries},null,2)+'\n');
console.log(JSON.stringify({preview:png,ids}));
