// Artifact-only browser inspection; never opens the game or changes game saves.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath,pathToFileURL} from 'node:url';

const require=createRequire(import.meta.url);
const packages=process.env.CODEX_ART_NODE_PACKAGES ?? 'C:/Users/geniu/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';
const {chromium}=require(path.join(packages,'playwright'));
const sharp=require(path.join(packages,'sharp'));
const library=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const output=path.join(library,'previews','recipe-review');
fs.mkdirSync(output,{recursive:true});
const url=pathToFileURL(path.join(library,'index.html')).href;
const browser=await chromium.launch({executablePath:process.env.CODEX_ART_CHROME ?? 'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--disable-background-networking','--no-first-run']});
const results=[],errors=[],requestFailures=[];
try {
  const context=await browser.newContext({viewport:{width:915,height:412},deviceScaleFactor:1});
  const page=await context.newPage();
  page.on('pageerror',error=>errors.push(error.message));
  page.on('requestfailed',request=>requestFailures.push({url:request.url(),failure:request.failure()?.errorText}));
  await page.addInitScript(()=>{
    window.__artLoadedImages={};
    window.__artDraws=[];
    const original=Object.getOwnPropertyDescriptor(HTMLImageElement.prototype,'src');
    Object.defineProperty(HTMLImageElement.prototype,'src',{...original,set(value){
      this.addEventListener('load',()=>{window.__artLoadedImages[this.src]={width:this.naturalWidth,height:this.naturalHeight,loaded:true};},{once:true});
      this.addEventListener('error',()=>{window.__artLoadedImages[this.src]={loaded:false};},{once:true});
      original.set.call(this,value);
    }});
    const draw=CanvasRenderingContext2D.prototype.drawImage;
    CanvasRenderingContext2D.prototype.drawImage=function(image,...args){
      if(this.canvas.closest('#detail')){
        const m=this.getTransform();
        window.__artDraws.push({src:image.currentSrc ?? image.src,alpha:this.globalAlpha,transform:[m.a,m.b,m.c,m.d,m.e,m.f]});
      }
      return draw.call(this,image,...args);
    };
  });
  await page.goto(url,{waitUntil:'load'});
  const catalog=await page.evaluate(()=>JSON.parse(document.querySelector('#library-data').textContent));
  if(catalog.recipes.length!==80 || catalog.recipes.some(recipe=>!recipe.ready))throw new Error('Expected all 80 recipes ready before inspection');
  await page.screenshot({path:path.join(library,'previews','04-library-final-915x412.png')});
  await page.locator('#recipes-tab').click();
  const byId=new Map(catalog.assets.map(asset=>[asset.id,asset]));
  const refs=new Map(catalog.references.map(reference=>[reference.id,reference]));
  for(const recipe of catalog.recipes){
    const result={id:recipe.id,ready:recipe.ready,expectedLayers:recipe.layers.length,speeds:[],seeks:[]};
    try {
      await page.locator('#search').fill(recipe.id);
      await page.locator('.asset-card').first().click();
      await page.waitForFunction(()=>!document.querySelector('#detail .player-controls button')?.disabled,null,{timeout:15000});
      const expected=recipe.layers.flatMap(layer=>{
        const asset=byId.get(layer.assetId);
        return asset.record.sequence?.framesExist ? asset.record.sequence.frameWebPaths : [asset.record.files.find(file=>file.exists).webPath];
      });
      const contexts=recipe.contextLayers ?? (recipe.context==='upgrade'?[{referenceId:'upgrade-icon'}]:recipe.context==='opening'?[{referenceId:'supply-crate'},{referenceId:'supply-lid'}]:[]);
      expected.push(...contexts.map(layer=>refs.get(layer.referenceId).webPath));
      const expectedUrls=[...new Set(expected.map(value=>new URL(value,url).href))];
      result.images=await page.evaluate(urls=>urls.map(src=>({src,...window.__artLoadedImages[src]})),expectedUrls);
      result.loaderNote=await page.locator('#detail p').allTextContents().then(lines=>lines.find(line=>line.includes('개 레이어 미리보기')));
      if(!result.loaderNote?.startsWith(`${recipe.layers.length}개 레이어`) || result.loaderNote.includes('실패'))throw new Error(`Layer load: ${result.loaderNote}`);
      if(result.images.some(image=>!image.loaded || !image.width || !image.height))throw new Error('Original PNG or sequence frame failed to load');
      const play=page.locator('#detail .player-controls button').first();
      const speed=page.locator('#detail .player-controls select');
      const scrub=page.locator('#detail input[type=range]');
      for(const value of ['0.5','1','2']){
        await speed.selectOption(value);
        await scrub.evaluate(input=>{input.value='0';input.dispatchEvent(new Event('input',{bubbles:true}));});
        await play.click();
        await page.waitForTimeout(75);
        const time=Number(await scrub.inputValue());
        if(await play.textContent()==='일시정지')await play.click();
        result.speeds.push({speed:Number(value),elapsed:time,advanced:time>0});
      }
      if(result.speeds.some(run=>!run.advanced))throw new Error('Playback failed to advance');
      for(const fraction of [0.5,0.85]){
        const target=recipe.duration*fraction;
        await page.evaluate(()=>{window.__artDraws=[];});
        await scrub.evaluate((input,value)=>{input.value=String(value);input.dispatchEvent(new Event('input',{bubbles:true}));},target);
        result.seeks.push(await page.evaluate(({target,fraction})=>({fraction,target,actual:Number(document.querySelector('#detail input[type=range]').value),draws:window.__artDraws}),{target,fraction}));
      }
      if(result.seeks.some(seek=>Math.abs(seek.actual-seek.target)>0.011 || seek.draws.some(draw=>draw.transform.some(value=>!Number.isFinite(value)))))throw new Error('Time seek or transform mismatch');
      await scrub.evaluate((input,value)=>{input.value=String(value);input.dispatchEvent(new Event('input',{bubbles:true}));},recipe.duration*0.5);
      await page.locator('#detail canvas').screenshot({path:path.join(output,recipe.id+'-mid.png')});
      if(['upgrade-001','opening-001','facility-001'].includes(recipe.id)){
        await page.locator('#detail').evaluate(detail=>{const surface=detail.querySelector('.preview-surface');detail.scrollTop+=surface.getBoundingClientRect().top-detail.getBoundingClientRect().top-10;});
        await page.screenshot({path:path.join(library,'previews',`05-${recipe.id}-final-915x412.png`)});
      }
      await page.locator('#detail .player-controls button').nth(1).click();
      await page.waitForTimeout(30);
      result.restartTime=Number(await scrub.inputValue());
      if(await play.textContent()==='일시정지')await play.click();
      result.status='passed';
    } catch(error){result.status='failed';result.error=error.message;}
    results.push(result);
    if(results.length%10===0)console.log(JSON.stringify({inspected:results.length,failed:results.filter(result=>result.status==='failed').length}));
  }
  const dimensions=await page.evaluate(()=>({viewport:[innerWidth,innerHeight],document:[document.documentElement.scrollWidth,document.documentElement.scrollHeight],activeCanvasCount:document.querySelectorAll('#detail canvas').length}));
  const report={artifactOnly:true,gameLoaded:false,catalogGeneratedAt:catalog.generatedAt,catalogComplete:catalog.counts?.complete,viewport:[915,412],dimensions,recipeCount:results.length,passed:results.filter(result=>result.status==='passed').length,errors,requestFailures,checkedAt:new Date().toISOString(),results};
  fs.writeFileSync(path.join(library,'previews','recipe-gallery-check.json'),JSON.stringify(report,null,2)+'\n');
  const passed=results.filter(result=>result.status==='passed');
  for(let offset=0;offset<passed.length;offset+=20){
    const subset=passed.slice(offset,offset+20);
    const inputs=await Promise.all(subset.map(async(result,index)=>({input:await sharp(path.join(output,result.id+'-mid.png')).resize(300,136,{fit:'contain',background:'#192b40'}).png().toBuffer(),left:(index%4)*300,top:Math.floor(index/4)*136})));
    await sharp({create:{width:1200,height:Math.ceil(subset.length/4)*136,channels:3,background:'#192b40'}}).composite(inputs).png().toFile(path.join(output,`sheet-${String(offset+1).padStart(2,'0')}-${String(offset+subset.length).padStart(2,'0')}.png`));
  }
  console.log(JSON.stringify({passed:report.passed,total:report.recipeCount,errors,requestFailures,dimensions,report:path.join(library,'previews','recipe-gallery-check.json')}));
  if(report.passed!==80 || errors.length || requestFailures.length)process.exitCode=1;
} finally {await browser.close();}
