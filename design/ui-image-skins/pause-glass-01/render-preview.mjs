// Render the standalone UI layout from raster surfaces and native font text.
// Does not edit source artwork, run the game, or access player saves.
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { writeFileSync } from 'node:fs';

const require = createRequire(import.meta.url);
const { createCanvas, loadImage, GlobalFonts } = require(process.argv[2] || '@napi-rs/canvas');
const folder = dirname(fileURLToPath(import.meta.url));
const repo = resolve(folder, '../../..');
const fonts = resolve(repo, 'godot/assets/ui/fonts');
for (const [file, name] of [
  ['Paperlogy-8ExtraBold.ttf', 'PauseTitle'],
  ['Paperlogy-6SemiBold.ttf', 'PauseControl'],
  ['Paperlogy-4Regular.ttf', 'PauseBody'],
  ['BarlowCondensed-Bold.ttf', 'PauseNumber'],
]) GlobalFonts.registerFromPath(resolve(fonts, file), name);

const approved = resolve(repo, 'design/ui-image-skins/office-day-01/menu-unified-01/assets');
const [background, panel, row, primary, secondary] = await Promise.all([
  loadImage(resolve(repo, 'design/ui-image-skins/vfx-reborn-01/slash.png')),
  loadImage(resolve(folder, 'pause-panel.png')),
  loadImage(resolve(approved, 'glass_row.png')),
  loadImage(resolve(folder, 'continue-soft-blue-02.png')),
  loadImage(resolve(approved, 'glass_button.png')),
]);

function render(scale) {
  const canvas = createCanvas(915 * scale, 412 * scale);
  const ctx = canvas.getContext('2d');
  ctx.scale(scale, scale);
  ctx.drawImage(background, 0, 0, 915, 412);
  ctx.fillStyle = 'rgba(15,25,42,.48)';
  ctx.fillRect(0, 0, 915, 412);
  ctx.drawImage(panel, 252, 52, 410, 308);

  function surface(image, x, y, w, h, sx, sy, dx, dy) {
    const xs = [0, sx, image.width - sx, image.width];
    const ys = [0, sy, image.height - sy, image.height];
    const xd = [x, x + dx, x + w - dx, x + w];
    const yd = [y, y + dy, y + h - dy, y + h];
    for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
      ctx.drawImage(image, xs[i], ys[j], xs[i+1]-xs[i], ys[j+1]-ys[j],
        xd[i], yd[j], xd[i+1]-xd[i], yd[j+1]-yd[j]);
    }
  }
  function text(value, x, y, font, size, color, align = 'left') {
    ctx.font = `${size}px ${font}`;
    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = 'middle';
    ctx.fillText(value, x, y);
  }
  surface(row, 280, 126, 354, 66, 24, 24, 6, 6);
  surface(primary, 280, 212, 354, 48, primary.width * 72 / 512, primary.height * 20 / 160, 18, 5);
  surface(secondary, 280, 269, 354, 44, 72, 20, 18, 5);

  text('일시정지', 282, 93, 'PauseTitle', 26, '#243448');
  text('PAUSED', 632, 94, 'PauseNumber', 16, '#C64F5F', 'right');
  text('광화문 광장', 298, 151, 'PauseControl', 16, '#243448');
  text('6층', 298, 173, 'PauseBody', 14, '#657787');
  text('1 / 20', 616, 151, 'PauseNumber', 26, '#243448', 'right');
  text('웨이브', 616, 174, 'PauseBody', 12, '#657787', 'right');
  text('계속하기', 457, 237, 'PauseControl', 16, '#FFFFFF', 'center');
  text('출동 종료', 457, 292, 'PauseControl', 16, '#C64F5F', 'center');
  return canvas.toBuffer('image/png');
}

writeFileSync(resolve(folder, 'preview-02-915x412.png'), render(1));
writeFileSync(resolve(folder, 'preview-02-1830x824.png'), render(2));
console.log('Pause UI mockup rendered: 915x412 and 1830x824.');
