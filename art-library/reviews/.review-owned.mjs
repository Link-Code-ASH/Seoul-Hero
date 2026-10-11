import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const sharp = require('C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');

const root = path.resolve('art-library');
const [name, ...ids] = process.argv.slice(2);
if (!name || !ids.length) throw new Error('Expected output name and asset IDs');
const tile = 220, columns = Math.min(12, ids.length * 2), cells = [];
for (const id of ids) {
  const record = JSON.parse(await fs.readFile(path.join(root, 'records', id + '.json'), 'utf8'));
  const subject = await sharp(path.join(root, record.files[0].path)).resize(tile - 20, tile - 38, { fit: 'inside' }).png().toBuffer();
  const meta = await sharp(subject).metadata();
  for (const bg of ['#f1ece3', '#152137']) {
    const label = Buffer.from(`<svg width="220" height="220"><text x="10" y="212" font-size="13" font-family="Arial" fill="${bg === '#152137' ? '#ffffff' : '#152137'}">${id}</text></svg>`);
    const cell = await sharp({create:{width:tile,height:tile,channels:4,background:bg}}).composite([{input:subject,left:Math.round((tile-meta.width)/2),top:Math.round((tile-24-meta.height)/2)},{input:label}]).png().toBuffer();
    const i = cells.length;
    cells.push({input:cell,left:(i % columns)*tile,top:Math.floor(i/columns)*tile});
  }
}
const output = path.join(root, 'reviews', name + '.png');
await sharp({create:{width:columns*tile,height:Math.ceil(cells.length/columns)*tile,channels:4,background:'#202833'}}).composite(cells).png().toFile(output);
console.log(output);
