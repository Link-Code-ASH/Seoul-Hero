// Prepare approved PNG surfaces for Godot without altering the source artwork.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const require = createRequire(import.meta.url);
const { createCanvas, loadImage } = require(process.argv[2] || '@napi-rs/canvas');
const folder = dirname(fileURLToPath(import.meta.url));
const runtime = resolve(folder, '../../../godot/assets/ui/pause-glass-01');
const primary = await loadImage(resolve(folder, 'continue-soft-blue-02.png'));
const scale = 4;
const width = 354;
const height = 48;
const canvas = createCanvas(width * scale, height * scale);
const ctx = canvas.getContext('2d');
ctx.scale(scale, scale);

// Preserve the approved preview's source cuts and 18px/5px displayed borders.
const sx = primary.width * 72 / 512;
const sy = primary.height * 20 / 160;
const xs = [0, sx, primary.width - sx, primary.width];
const ys = [0, sy, primary.height - sy, primary.height];
const xd = [0, 18, width - 18, width];
const yd = [0, 5, height - 5, height];
for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
  ctx.drawImage(primary, xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j],
    xd[i], yd[j], xd[i + 1] - xd[i], yd[j + 1] - yd[j]);
}

mkdirSync(runtime, { recursive: true });
copyFileSync(resolve(folder, 'pause-panel.png'), resolve(runtime, 'pause-panel.png'));
writeFileSync(resolve(runtime, 'continue-button.png'), canvas.toBuffer('image/png'));
for (const name of ['pause-panel.png', 'continue-button.png']) {
  const path = resolve(runtime, name);
  const image = await loadImage(path);
  const sha256 = createHash('sha256').update(readFileSync(path)).digest('hex');
  console.log(`${name}: ${image.width}x${image.height}, SHA256 ${sha256}`);
}
