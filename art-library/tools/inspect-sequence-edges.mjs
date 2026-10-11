import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const sharp = require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
for (const id of process.argv.slice(2)) {
  if (!/^effect-\d{3}$/.test(id)) throw new Error(`Invalid ID ${id}`);
  const record = JSON.parse(fs.readFileSync(path.join(root,'records',`${id}.json`),'utf8'));
  const frames = [];
  for (const [index, file] of record.sequence.framePaths.entries()) {
    const {data,info} = await sharp(path.join(root,file)).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let minX=info.width,minY=info.height,maxX=-1,maxY=-1,opaqueEdgePixels=0;
    for (let y=0;y<info.height;y++) for (let x=0;x<info.width;x++) {
      const alpha=data[(y*info.width+x)*info.channels+info.channels-1];
      if (alpha>=32) {minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);}
      if (alpha>=64&&(x===0||y===0||x===info.width-1||y===info.height-1)) opaqueEdgePixels++;
    }
    frames.push({frame:index+1,canvas:[info.width,info.height],visibleBounds:[minX,minY,maxX,maxY],opaqueEdgePixels});
  }
  console.log(JSON.stringify({id,frames}));
}
