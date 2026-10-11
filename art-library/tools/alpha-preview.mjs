import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const sharp=require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const id=process.argv[2];
if(!id)throw new Error('Usage: node alpha-preview.mjs <asset-id>');
const record=JSON.parse(await fs.readFile(path.join(root,'records',id+'.json'),'utf8'));
const source=path.join(root,record.files[0].path);
const meta=await sharp(source).metadata();
const scale=Math.min(1,1600/meta.width,1100/meta.height);
const width=Math.round(meta.width*scale),height=Math.round(meta.height*scale);
const transparent=await sharp(source).resize(width,height).png().toBuffer();
const bg={create:{width,height,channels:4,background:'#dce5ed'}};
const destination=path.join(root,'previews',id+'-alpha-review.png');
await sharp(bg).composite([{input:transparent}]).png().toFile(destination);
const {data,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
let zero=0,nonzero=0,minX=info.width,minY=info.height,maxX=-1,maxY=-1;
for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++){
 const a=data[(y*info.width+x)*4+3];
 if(a===0)zero++;
 if(a>8){nonzero++;minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);}
}
console.log(JSON.stringify({id,preview:destination,zeroAlphaFraction:zero/(info.width*info.height),visibleBounds:nonzero?[minX,minY,maxX,maxY]:null}));
