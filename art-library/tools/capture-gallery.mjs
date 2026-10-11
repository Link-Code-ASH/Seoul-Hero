// Optional artifact preview capture. Opens this library only; no game is run.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const runtimePackages = process.env.CODEX_ART_NODE_PACKAGES ?? 'C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const { chromium } = require(path.join(runtimePackages,'playwright'));
const library = path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output = path.join(library,'previews');
fs.mkdirSync(output,{recursive:true});
const browser = await chromium.launch({executablePath:process.env.CODEX_ART_CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--disable-background-networking','--no-first-run']});
try {
  const context = await browser.newContext({viewport:{width:915,height:412},deviceScaleFactor:1});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror',error => errors.push(error.message));
  await page.goto(pathToFileURL(path.join(library,'index.html')).href,{waitUntil:'load'});
  const catalog = await page.evaluate(() => JSON.parse(document.querySelector('#library-data').textContent));
  if (catalog.counts.complete !== 1000 || catalog.counts.generated !== 1000) throw new Error('Final capture requires 1,000 generated and complete original assets');
  await page.screenshot({path:path.join(output,'04-library-final-915x412.png')});
  await page.locator('#search').fill('effect-001');
  await page.locator('.asset-card').first().click();
  const player = page.locator('#detail .player-controls button').first();
  if (await player.count()) {
    await page.waitForFunction(() => !document.querySelector('#detail .player-controls button')?.disabled,{},{timeout:10000});
    await player.click();
    await page.waitForTimeout(150);
    await player.click();
    await page.locator('#detail input[type=range]').evaluate(input => {input.value='0.3';input.dispatchEvent(new Event('input',{bubbles:true}));});
  }
  await page.locator('#detail').evaluate(detail => {
    const surface = detail.querySelector('.preview-surface');
    if (surface) detail.scrollTop += surface.getBoundingClientRect().top - detail.getBoundingClientRect().top - 12;
  });
  await page.screenshot({path:path.join(output,'07-sequence-final-915x412.png')});
  await page.locator('#recipes-tab').click();
  await page.locator('#search').fill('open-001');
  await page.locator('.asset-card').first().click();
  if (await page.locator('#detail input[type=range]').count()) {
    await page.waitForFunction(() => !document.querySelector('#detail .player-controls button')?.disabled,{},{timeout:10000});
    await page.locator('#detail input[type=range]').evaluate(input => {input.value=String(Number(input.max)*0.5);input.dispatchEvent(new Event('input',{bubbles:true}));});
  }
  await page.locator('#detail').evaluate(detail => {
    const surface = detail.querySelector('.preview-surface');
    if (surface) detail.scrollTop += surface.getBoundingClientRect().top - detail.getBoundingClientRect().top - 12;
  });
  await page.screenshot({path:path.join(output,'08-open-final-915x412.png')});
  const dimensions = await page.evaluate(() => ({viewport:[innerWidth,innerHeight],documentWidth:document.documentElement.scrollWidth,documentHeight:document.documentElement.scrollHeight,canvasCount:document.querySelectorAll('#detail canvas').length}));
  fs.writeFileSync(path.join(output,'final-gallery-check.json'),JSON.stringify({artifactOnly:true,gameLoaded:false,viewport:[915,412],catalogCounts:catalog.counts,errors,dimensions,capturedAt:new Date().toISOString()},null,2)+'\n');
  console.log(JSON.stringify({generated:catalog.counts.generated,complete:catalog.counts.complete,readyRecipes:catalog.counts.readyRecipes,errors,dimensions,output},null,2));
} finally {
  await browser.close();
}
