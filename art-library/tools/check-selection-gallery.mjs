// Inspects only the offline art library in an isolated browser context.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';
const require=createRequire(import.meta.url);
const packages=process.env.CODEX_ART_NODE_PACKAGES ?? 'C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=require(path.join(packages,'playwright'));
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output=path.join(root,'previews','selection-review');
fs.mkdirSync(output,{recursive:true});
const browser=await chromium.launch({executablePath:process.env.CODEX_ART_CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe',downloadsPath:output,headless:true,args:['--disable-background-networking','--no-first-run','--allow-file-access-from-files']});
try {
  const context=await browser.newContext({viewport:{width:915,height:412},deviceScaleFactor:1,acceptDownloads:true});
  const page=await context.newPage();
  const errors=[];
  page.on('pageerror',error=>errors.push(error.message));
  await page.goto(pathToFileURL(path.join(root,'index.html')).href,{waitUntil:'load'});
  const exportPath=path.join(output,'example-selection.json');
  const importOnly=process.argv.includes('--import-only');
  const note='라이브러리 기능 확인용 메모: 실제 사용자 선택이 아닙니다.';
  let exported;
  if (!importOnly) {
  await page.locator('#search').fill('monster-158');
  await page.locator('.asset-card').first().click();
  await page.locator('#detail .detail-actions button').first().click();
  await page.locator('#detail .detail-actions button').nth(1).click();
  await page.locator('#detail textarea').fill(note);
  await page.waitForTimeout(250);
  const downloadPromise=page.waitForEvent('download');
  await page.locator('#export-selection').click();
  const download=await downloadPromise;
  const downloadPath=await download.path();
  if(process.argv.includes('--export-only')){
    const result={downloadPath,suggestedFilename:download.suggestedFilename(),failure:await download.failure(),artifactOnly:true,checkedAt:new Date().toISOString()};
    fs.writeFileSync(path.join(output,'download-result.json'),JSON.stringify(result,null,2)+'\n');
    await browser.close();
    console.log(JSON.stringify(result));
    process.exit(0);
  }
  fs.writeFileSync(exportPath,fs.readFileSync(downloadPath));
  exported=JSON.parse(fs.readFileSync(exportPath,'utf8'));
  await page.locator('#detail .detail-actions button').first().click();
  await page.locator('#detail .detail-actions button').nth(1).click();
  await page.locator('#detail textarea').fill('');
  await page.waitForTimeout(250);
  } else exported=JSON.parse(fs.readFileSync(exportPath,'utf8'));
  const exportPassed=exported.favorites.includes('monster-158') && exported.candidates.includes('monster-158') && exported.notes['monster-158']===note;
  await page.locator('#import-file').setInputFiles(exportPath);
  await page.waitForFunction(()=>document.querySelector('#notice')?.textContent.includes('선택을 합쳤'));
  const imported=await page.evaluate(()=>JSON.parse(localStorage.getItem('seoulHero.artLibrary.selection.v1')));
  const importPassed=imported.favorites.includes('monster-158') && imported.candidates.includes('monster-158') && imported.notes['monster-158']===note;
  await page.reload({waitUntil:'load'});
  await page.locator('#only-candidates').check();
  const reloadPassed=(await page.locator('.asset-card').count())===1 && (await page.locator('.asset-card').first().textContent()).includes('monster-158');
  await page.locator('#only-candidates').uncheck();
  await page.locator('#search').fill('map-060');
  await page.locator('.asset-card').first().click();
  await page.locator('#detail .preview-surface img').first().waitFor({state:'visible'});
  await page.waitForFunction(()=>{const image=document.querySelector('#detail .preview-surface img');return image?.complete && image.naturalWidth>0;});
  await page.locator('#detail').evaluate(detail=>{const preview=detail.querySelector('.preview-surface');detail.scrollTop+=preview.getBoundingClientRect().top-detail.getBoundingClientRect().top-10;});
  await page.screenshot({path:path.join(root,'previews','06-map-final-915x412.png')});
  const mapState=await page.locator('#detail .preview-surface img').first().evaluate(image=>({loaded:image.complete && image.naturalWidth>0,dimensions:[image.naturalWidth,image.naturalHeight]}));
  const result={artifactOnly:true,gameLoaded:false,isolatedBrowserContext:true,exportPassed,importPassed,reloadPassed,mapState,errors,exportPath,checkedAt:new Date().toISOString()};
  fs.writeFileSync(path.join(root,'previews','selection-gallery-check.json'),JSON.stringify(result,null,2)+'\n');
  console.log(JSON.stringify(result));
  if(!exportPassed || !importPassed || !reloadPassed || !mapState.loaded || errors.length)process.exitCode=1;
} finally {await browser.close();}
