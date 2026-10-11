/* Offline bitmap catalog. Selection is local; game state is never accessed. */
'use strict';
(() => {
  const catalog = JSON.parse(document.getElementById('library-data').textContent);
  const assets = catalog.assets ?? [];
  const recipes = catalog.recipes ?? [];
  const byId = new Map(assets.map(asset => [asset.id, asset]));
  const references = new Map((catalog.references ?? []).map(reference => [reference.id,reference]));
  const names = new Map((catalog.categories ?? []).map(category => [category.id,category.nameKo]));
  const statusNames = {complete:'제작 완료',planned:'제작 계획','generated-unreviewed':'검토 전','needs-revision':'수정 필요',failed:'생성 실패'};
  const state = {mode:'assets',category:'all',status:'all',family:'all',query:'',page:0,selected:null,background:'checker'};
  const pageSize = 48;
  const storageKey = 'seoulHero.artLibrary.selection.v1';
  let selection = {schemaVersion:1,favorites:[],candidates:[],notes:{}};
  let memoryOnly = false;
  let activePlayer = null;
  let noticeTimer = null;
  let noteTimer = null;
  const $ = id => document.getElementById(id);
  const element = (tag, text = '', className = '') => {
    const node = document.createElement(tag);
    if (text !== '') node.textContent = text;
    if (className) node.className = className;
    return node;
  };
  const assetUrl = value => String(value ?? '').replaceAll('\\','/').split('/').map(encodeURIComponent).join('/');
  const notify = text => {
    clearTimeout(noticeTimer);
    $('notice').textContent = text;
    $('notice').hidden = false;
    noticeTimer = setTimeout(() => { $('notice').hidden = true; }, 3500);
  };
  const normalSelection = value => {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('선택 JSON 형식이 아닙니다.');
    if (value.schemaVersion && value.schemaVersion !== 1) throw new Error('지원하지 않는 선택 JSON 버전입니다.');
    const validIds = values => [...new Set((Array.isArray(values) ? values : []).filter(id => typeof id === 'string' && id.length > 0 && id.length <= 160))];
    const notes = Object.fromEntries(Object.entries(value.notes ?? {}).filter(([id,text]) => id.length <= 160 && typeof text === 'string').map(([id,text]) => [id,text.slice(0,10000)]));
    return {schemaVersion:1,favorites:validIds(value.favorites),candidates:validIds(value.candidates),notes};
  };
  try {
    const saved = localStorage.getItem(storageKey);
    if (saved) selection = normalSelection(JSON.parse(saved));
  } catch (_error) {
    memoryOnly = true;
  }
  const storageMessage = () => {
    $('storage-notice').textContent = memoryOnly ? '브라우저 저장을 사용할 수 없어 이번 창에서만 선택을 보관합니다. JSON으로 내보내면 보존됩니다.' : '즐겨찾기·선택 후보·메모는 이 브라우저에만 저장됩니다.';
  };
  const persist = () => {
    try { localStorage.setItem(storageKey,JSON.stringify(selection)); }
    catch (_error) { memoryOnly = true; storageMessage(); }
  };
  const isMarked = (kind,id) => selection[kind].includes(id);
  const mark = (kind,id) => {
    selection[kind] = isMarked(kind,id) ? selection[kind].filter(value => value !== id) : [...selection[kind],id];
    persist();
    renderResults();
    renderDetail();
  };
  const imageNode = (file, caption, lazy = false) => {
    const image = element('img');
    image.src = assetUrl(file);
    image.alt = caption;
    image.decoding = 'async';
    image.loading = lazy ? 'lazy' : 'eager';
    image.addEventListener('error',() => {
      image.replaceWith(element('span','이미지 파일을 열 수 없습니다.','small muted'));
    },{once:true});
    return image;
  };
  const badge = (text, status = '') => element('span',text,`badge ${status}`);
  const button = (text, handler, selected = false) => {
    const result = element('button',text,selected ? 'selected' : '');
    result.type = 'button';
    result.addEventListener('click',handler);
    return result;
  };
  const warning = (text, error = false) => element('div',text,`warning${error ? ' error' : ''}`);
  const link = (caption, file) => {
    const result = element('a',caption);
    result.href = assetUrl(file);
    result.target = '_blank';
    result.rel = 'noopener';
    return result;
  };
  const progress = $('progress');
  const count = catalog.counts ?? {};
  for (const [label,value,style] of [['설계',`${count.briefs ?? assets.length} / ${count.plannedTarget ?? 1000}`, ''],['실제 파일 생성',count.generated ?? 0,''],['제작 완료',count.complete ?? 0,''],['시각 확인',count.visuallyChecked ?? 0,''],['사용자 승인',count.userApproved ?? 0,'approved'],['레시피 준비',`${count.readyRecipes ?? 0} / ${count.recipes ?? recipes.length}`,'']]) {
    const item = element('span',label+' ',style);
    item.append(element('strong',String(value)));
    progress.append(item);
  }
  const searchable = entry => [entry.id,entry.nameKo,entry.family,entry.descriptionKo,entry.useKo,entry.visualBrief,...(entry.tags ?? []),...(entry.layers ?? []).map(layer => layer.assetId)].join(' ').toLocaleLowerCase();
  const entries = () => state.mode === 'assets' ? assets : recipes;
  function filtered() {
    const words = state.query.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
    return entries().filter(entry => {
      if (state.mode === 'assets' && state.category !== 'all' && entry.category !== state.category) return false;
      const status = state.mode === 'assets' ? entry.status : entry.ready ? 'complete' : 'planned';
      if (state.status !== 'all' && status !== state.status) return false;
      if (state.family !== 'all' && entry.family !== state.family) return false;
      if ($('only-favorites').checked && !isMarked('favorites',entry.id)) return false;
      if ($('only-candidates').checked && !isMarked('candidates',entry.id)) return false;
      return words.every(word => searchable(entry).includes(word));
    });
  }
  function renderCategories() {
    const categories = $('categories');
    categories.replaceChildren();
    const values = [{id:'all',nameKo:'전체'},...(state.mode === 'assets' ? catalog.categories ?? [] : [])];
    for (const category of values) {
      const total = category.id === 'all' ? entries().length : assets.filter(asset => asset.category === category.id).length;
      const item = button('',() => { state.category = category.id; state.page = 0; renderCategories(); renderResults(); },state.category === category.id);
      item.append(element('strong',category.nameKo),element('span',String(total)));
      categories.append(item);
    }
  }
  function renderFamilies() {
    const family = $('family');
    family.replaceChildren();
    family.append(new Option('모든 계열','all'));
    const families = [...new Set(entries().map(entry => entry.family).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b),'ko'));
    for (const value of families) family.append(new Option(String(value),String(value)));
    if (!families.includes(state.family)) state.family = 'all';
    family.value = state.family;
  }
  function setMode(mode) {
    activePlayer?.dispose();
    activePlayer = null;
    state.mode = mode;
    state.page = 0;
    state.selected = null;
    state.category = 'all';
    state.status = 'all';
    $('status').value = 'all';
    for (const [id,active] of [['assets-tab',mode === 'assets'],['recipes-tab',mode === 'recipes']]) {
      $(id).classList.toggle('selected',active);
      $(id).setAttribute('aria-selected',String(active));
    }
    renderCategories();
    renderFamilies();
    renderResults();
    renderDetail();
  }
  function renderResults() {
    const values = filtered();
    const pages = Math.max(1,Math.ceil(values.length/pageSize));
    state.page = Math.min(state.page,pages-1);
    $('result-count').textContent = `${values.length}개 ${state.mode === 'assets' ? '원화 후보' : '연출 레시피'}`;
    $('page-label').textContent = `${state.page+1} / ${pages} 페이지`;
    $('previous-page').disabled = state.page === 0;
    $('next-page').disabled = state.page >= pages-1;
    const grid = $('grid');
    grid.replaceChildren();
    for (const entry of values.slice(state.page*pageSize,(state.page+1)*pageSize)) {
      const card = element('button','','asset-card');
      card.type = 'button';
      card.setAttribute('aria-selected',String(state.selected === entry.id));
      const thumb = element('div','','thumb checker');
      const previewAsset = state.mode === 'assets' ? entry : (entry.layers ?? []).map(layer => byId.get(layer.assetId)).find(asset => asset?.thumbnail);
      if (previewAsset?.thumbnail) thumb.append(imageNode(previewAsset.thumbnail,entry.nameKo,true));
      else {
        thumb.classList.remove('checker');
        const plan = element('div','','planned-thumb');
        plan.append(element('strong',state.mode === 'assets' ? names.get(entry.category) ?? entry.category : '연출 레시피'),element('span',state.mode === 'assets' ? '원화 미제작' : `${entry.missingLayers ?? entry.layers?.length ?? 0}개 레이어 미완료`));
        thumb.append(plan);
      }
      const copy = element('div','','card-copy');
      copy.append(element('span',entry.nameKo ?? entry.id,'card-title'),element('span',entry.id,'card-id'));
      const footer = element('div','','card-footer');
      footer.append(badge(state.mode === 'assets' ? statusNames[entry.status] ?? entry.status : entry.ready ? '레시피 준비' : '원화 부족',state.mode === 'assets' ? entry.status : entry.ready ? 'ready' : 'planned'));
      const marks = [isMarked('favorites',entry.id) ? '★' : '',isMarked('candidates',entry.id) ? '후보' : ''].filter(Boolean).join(' ');
      footer.append(element('span',marks,'marks'));
      copy.append(footer);
      card.append(thumb,copy);
      card.addEventListener('click',() => { state.selected = entry.id; renderResults(); renderDetail(); });
      grid.append(card);
    }
    if (!values.length) grid.append(element('div','조건에 맞는 자료가 없습니다. 검색어 또는 필터를 바꿔보세요.','empty-results'));
  }
  function detailHeader(parent,entry) {
    const head = element('div','','detail-header');
    const title = element('div');
    title.append(element('h2',entry.nameKo ?? entry.id),element('div',entry.id,'detail-id'));
    head.append(title);
    parent.append(head);
    const tags = element('div','','tag-list');
    for (const text of [entry.family,...(entry.tags ?? [])].filter(Boolean)) tags.append(element('span',String(text),'tag'));
    parent.append(tags);
    const actions = element('div','','detail-actions');
    actions.append(button(isMarked('favorites',entry.id) ? '★ 즐겨찾기' : '☆ 즐겨찾기',() => mark('favorites',entry.id),isMarked('favorites',entry.id)),button(isMarked('candidates',entry.id) ? '선택 후보에서 빼기' : '선택 후보에 넣기',() => mark('candidates',entry.id),isMarked('candidates',entry.id)));
    parent.append(actions);
  }
  function backgroundControls(parent,surface) {
    const controls = element('div','','background-controls');
    const set = background => {
      state.background = background;
      surface.classList.remove('checker','light','dark');
      surface.classList.add(background);
      for (const child of controls.children) child.classList.toggle('selected',child.dataset.background === background);
      $('zoom-surface').classList.remove('checker','light','dark');
      $('zoom-surface').classList.add(background);
    };
    for (const [id,name] of [['checker','투명 바둑판'],['light','밝게'],['dark','어둡게']]) {
      const choice = button(name,() => set(id),state.background === id);
      choice.dataset.background = id;
      controls.append(choice);
    }
    parent.append(controls);
    set(state.background);
  }
  function notes(parent,id) {
    parent.append(element('h3','내 메모'));
    const area = element('textarea');
    area.value = selection.notes[id] ?? '';
    area.placeholder = '사용하고 싶은 곳, 수정할 점, 비교할 후보를 적으세요.';
    area.maxLength = 10000;
    area.addEventListener('input',() => {
      selection.notes[id] = area.value;
      clearTimeout(noteTimer);
      noteTimer = setTimeout(persist,200);
    });
    parent.append(area,element('p','메모와 선택은 라이브러리 원본이나 게임을 변경하지 않습니다.','small muted'));
  }
  function metadata(parent,items) {
    const list = element('dl','','meta-list');
    for (const [title,value] of items) {
      list.append(element('dt',title),element('dd',String(value ?? '기록 없음')));
    }
    parent.append(list);
  }
  function smallPreviews(parent,asset) {
    if (!asset.thumbnail) return;
    const previewFile = asset.record?.sequence?.frameWebPaths?.[3] || asset.record?.files?.find(file => file.exists && !file.derived)?.webPath || asset.thumbnail;
    parent.append(element('h3',asset.category === 'map' ? '915×412 화면 기준' : '작게 보이는 모습'));
    if (asset.category === 'map') {
      const preview = element('div','','preview-surface map');
      preview.append(imageNode(previewFile,asset.nameKo));
      preview.style.background = '#edf2f4';
      parent.append(preview,element('p','가로 화면의 915×412 비율로 축소합니다.','small muted'));
    } else {
      const preview = element('div','','mini-previews checker');
      for (const size of [24,48,96]) {
        const figure = element('figure');
        const image = imageNode(previewFile,`${size}px 크기의 ${asset.nameKo}`);
        image.width = size;
        image.height = size;
        figure.append(image,element('figcaption',`${size}px`));
        preview.append(figure);
      }
      parent.append(preview);
    }
  }
  function renderAsset(parent,asset) {
    detailHeader(parent,asset);
    parent.append(badge(statusNames[asset.status] ?? asset.status,asset.status));
    if (asset.record?.review?.userApproval !== 'approved' && asset.thumbnail) parent.append(badge('사용자 승인 대기','pending'));
    if (asset.descriptionKo) parent.append(element('p',asset.descriptionKo));
    const sequence = asset.record?.sequence;
    if (sequence?.framesExist) {
      createPlayer(parent,{id:asset.id,duration:(sequence.frameCount ?? 8)/(sequence.fps ?? 12),loop:true,canvas:[915,412],anchor:[457.5,206],context:'none',standalone:true,layers:[{assetId:asset.id,start:0,end:(sequence.frameCount ?? 8)/(sequence.fps ?? 12),z:0,blend:'normal',keyframes:[{t:0,x:0,y:0,scale:1,rotation:0,opacity:1,easing:'linear'}]}]});
      parent.append(element('p',`${sequence.frameCount}프레임 · ${sequence.fps}fps · 정렬 ${sequence.aligned ? '기록 확인' : '미확인'}`,'small muted'));
    } else {
      const preview = element('div','',`preview-surface ${state.background}${asset.category === 'map' ? ' map' : ''}`);
      if (asset.thumbnail) {
        const image = imageNode(asset.record?.files?.find(file => file.exists && !file.derived)?.webPath || asset.thumbnail,asset.nameKo);
        image.addEventListener('click',() => zoom(asset));
        preview.append(image);
      } else preview.append(element('div','이 후보의 원화는 아직 제작되지 않았습니다.','planned-thumb'));
      parent.append(preview);
      backgroundControls(parent,preview);
      if (asset.thumbnail) parent.append(button('원본 크기로 보기',() => zoom(asset)));
    }
    if (asset.warnings?.length) parent.append(warning(asset.warnings.join('\n'),true));
    if (asset.record?.review?.notes) parent.append(warning(asset.record.review.notes));
    smallPreviews(parent,asset);
    parent.append(element('h3','용도와 제작 설계'));
    metadata(parent,[['분류',names.get(asset.category) ?? asset.category],['사용처',asset.useKo],['공용 모션',asset.motion],['캔버스 비율',Array.isArray(asset.aspectRatio) ? asset.aspectRatio.join(' : ') : asset.aspectRatio],['배경',asset.transparent ? '투명 배경 요청' : '불투명 배경'],['형식',asset.format === 'sequence8' ? 'PNG 8프레임 시퀀스' : 'PNG'],['참조',asset.referenceIds?.join(', ') || '없음']]);
    if (asset.visualBrief) {
      const draft = element('details');
      draft.append(element('summary','미술 제작 지시'),element('pre',asset.visualBrief));
      parent.append(draft);
    }
    if (asset.record) {
      const record = asset.record;
      parent.append(element('h3','실제 파일과 출처'));
      metadata(parent,[['개정',record.revision],['생성 도구',record.source?.tool],['생성 시각',record.source?.createdAt],['시각 확인',record.review?.visualChecked ? '확인 기록 있음' : '아직 확인되지 않음'],['사용자 승인',record.review?.userApproval === 'approved' ? '승인' : '대기'],['원본 경로',record.source?.generatedPath]]);
      const files = element('ul','','file-list');
      for (const file of record.files ?? []) {
        const row = element('li');
        row.append(link(file.path,file.webPath),element('div',`${file.actualWidth ?? file.width} × ${file.actualHeight ?? file.height} · 알파 ${file.alphaChannel ? '있음' : '없음'} · 투명 픽셀 ${file.hasTransparency ? '있음' : '없음'}`,'small muted'));
        const hashDetails = element('details');
        hashDetails.append(element('summary','SHA-256'),element('pre',file.actualSha256 ?? file.sha256 ?? '기록 없음'));
        row.append(hashDetails);
        files.append(row);
      }
      if (sequence?.sheetWebPath) {
        const row = element('li');
        row.append(link('파생 스프라이트시트',sequence.sheetWebPath));
        files.append(row);
      }
      parent.append(files);
      const prompt = element('details');
      prompt.append(element('summary','전체 생성 프롬프트'),element('pre',record.prompt || '프롬프트 파일을 아직 불러오지 못했습니다.'));
      if (record.source?.promptWebPath) prompt.append(link('프롬프트 파일',record.source.promptWebPath));
      parent.append(prompt);
    }
    notes(parent,asset.id);
  }
  function renderRecipe(parent,recipe) {
    detailHeader(parent,recipe);
    parent.append(badge(recipe.ready ? '전체 레이어 제작 완료' : '미완성 레시피',recipe.ready ? 'ready' : 'planned'));
    if (!recipe.ready) parent.append(warning(`부족한 레이어 ${recipe.missingLayers}개 · 원화 ${recipe.missingAssets?.length ?? 0}종. ${recipe.missingAssets?.join(', ') ?? ''}`));
    metadata(parent,[['시간',`${recipe.duration}초`],['반복',recipe.loop ? '반복' : '1회'],['캔버스',recipe.canvas?.join(' × ')],['기준점',recipe.anchor?.join(', ')],['장면',recipe.context === 'upgrade' ? '강화 아이콘' : recipe.context === 'opening' ? '보급 상자' : '효과만']]);
    createPlayer(parent,recipe);
    parent.append(element('h3','레이어 구성'));
    const list = element('ul','','layer-list');
    for (const layer of recipe.layers ?? []) {
      const asset = byId.get(layer.assetId);
      const available = asset?.status === 'complete' && asset.fileReady;
      const item = element('li',`${asset?.nameKo ?? layer.assetId} · ${layer.start}~${layer.end}초 · ${layer.blend === 'add' ? '가산' : '일반'} 합성${available ? '' : ' · 원화 미완료'}`,available ? '' : 'missing');
      item.append(button('원화 보기',() => {
        setMode('assets');
        state.selected = layer.assetId;
        renderResults();
        renderDetail();
      }));
      list.append(item);
    }
    parent.append(list);
    const json = element('details');
    json.append(element('summary','타임라인 원본 JSON'),element('pre',JSON.stringify(recipe,null,2)));
    parent.append(json,element('p','키프레임 시간은 각 레이어 시작 시점부터의 초입니다. 위치는 기준점 상대 픽셀, 회전은 도입니다. 크기 1은 긴 변 256px(레이어 displaySize 기본값) 기준이며 원본 파일은 그대로 보존합니다.','small muted'));
    notes(parent,recipe.id);
  }
  function renderDetail() {
    activePlayer?.dispose();
    activePlayer = null;
    const parent = $('detail');
    parent.replaceChildren();
    const entry = entries().find(value => value.id === state.selected);
    if (!entry) {
      const empty = element('div','','empty-detail');
      empty.append(element('h2','원화나 레시피를 선택하세요'),element('p','제작된 이미지와 아직 없는 계획을 구분해 표시합니다.'));
      parent.append(empty);
      return;
    }
    parent.scrollTop = 0;
    if (state.mode === 'assets') renderAsset(parent,entry);
    else renderRecipe(parent,entry);
  }
  function zoom(asset) {
    const file = asset.record?.sequence?.frameWebPaths?.[0] || asset.record?.files?.find(file => file.exists)?.webPath || asset.thumbnail;
    if (!file) return;
    $('zoom-title').textContent = `${asset.nameKo} · 원본 크기`;
    $('zoom-image').src = assetUrl(file);
    $('zoom-image').alt = asset.nameKo;
    $('zoom-dialog').showModal();
  }
  const imageCache = new Map();
  function loadImage(file) {
    if (!imageCache.has(file)) imageCache.set(file,new Promise((resolve,reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error(`이미지 로드 실패: ${file}`));
      image.src = assetUrl(file);
    }));
    if (imageCache.size > 32) imageCache.delete(imageCache.keys().next().value);
    return imageCache.get(file);
  }
  const ease = (name,t) => {
    const normalized = String(name ?? 'linear').toLowerCase().replaceAll('-','').replaceAll('_','');
    if (['easein','quadin','easeinquad'].includes(normalized)) return t*t;
    if (['easeout','quadout','easeoutquad'].includes(normalized)) return 1-(1-t)*(1-t);
    if (['easeinout','quadinout','easeinoutquad'].includes(normalized)) return t<0.5 ? 2*t*t : 1-((-2*t+2)**2)/2;
    if (['cubicin','easeincubic'].includes(normalized)) return t**3;
    if (['cubicout','easeoutcubic'].includes(normalized)) return 1-(1-t)**3;
    if (['cubicinout','easeinoutcubic'].includes(normalized)) return t<0.5 ? 4*t**3 : 1-((-2*t+2)**3)/2;
    if (['sinein','easeinsine'].includes(normalized)) return 1-Math.cos(t*Math.PI/2);
    if (['sineout','easeoutsine'].includes(normalized)) return Math.sin(t*Math.PI/2);
    if (['sineinout','easeinoutsine'].includes(normalized)) return -(Math.cos(Math.PI*t)-1)/2;
    return t;
  };
  function keyframe(layer,time) {
    const values = [...(layer.keyframes ?? [])].sort((a,b) => a.t-b.t);
    const defaults = {x:0,y:0,scale:1,rotation:0,opacity:1};
    if (!values.length) return defaults;
    const before = values.filter(value => value.t <= time).at(-1) ?? values[0];
    const after = values.find(value => value.t > time) ?? before;
    const ratio = after === before ? 0 : ease(before.easing,Math.max(0,Math.min(1,(time-before.t)/(after.t-before.t))));
    return Object.fromEntries(Object.entries(defaults).map(([key,value]) => {
      const a = Number(before[key] ?? value);
      const b = Number(after[key] ?? a);
      return [key,a+(b-a)*ratio];
    }));
  }
  function createPlayer(parent,recipe) {
    const surface = element('div','',`preview-surface player ${state.background}`);
    const canvas = element('canvas');
    const size = recipe.canvas ?? [915,412];
    canvas.width = size[0];
    canvas.height = size[1];
    canvas.setAttribute('aria-label','실제 PNG로 합성하는 연출 미리보기');
    surface.append(canvas);
    parent.append(surface);
    backgroundControls(parent,surface);
    const controls = element('div','','player-controls');
    const row = element('div','','player-row');
    const play = button('재생',() => player.toggle());
    const restart = button('처음부터',() => player.restart());
    const speed = element('select');
    speed.setAttribute('aria-label','재생 속도');
    for (const value of [0.5,1,2]) speed.append(new Option(`${value}배`,String(value),value===1,value===1));
    const timeLabel = element('span','','player-time');
    row.append(play,restart,speed,timeLabel);
    const scrub = element('input');
    scrub.type = 'range';
    scrub.min = '0';
    scrub.max = String(recipe.duration ?? 1);
    scrub.step = '0.01';
    scrub.value = '0';
    scrub.setAttribute('aria-label','재생 시점');
    controls.append(row,scrub);
    parent.append(controls);
    const loaderNote = element('p','실제 이미지를 불러오는 중입니다.','small muted');
    parent.append(loaderNote);
    const player = new BitmapPlayer(canvas,recipe,() => {
      const seconds = player.time;
      scrub.value = String(seconds);
      timeLabel.textContent = `${seconds.toFixed(2)} / ${player.duration.toFixed(2)}초`;
      play.textContent = player.playing ? '일시정지' : '재생';
    });
    activePlayer = player;
    play.disabled = true;
    restart.disabled = true;
    scrub.addEventListener('input',() => player.seek(Number(scrub.value)));
    speed.addEventListener('change',() => { player.speed = Number(speed.value); });
    player.load().then(() => {
      if (player.disposed) return;
      play.disabled = player.layers.length === 0;
      restart.disabled = player.layers.length === 0;
      const failed = player.failed.length;
      loaderNote.textContent = player.layers.length ? `${player.layers.length}개 레이어 미리보기${failed ? ` · 로드 실패 ${failed}개` : ''}` : '효과 원화가 없어 타임라인을 재생할 수 없습니다.';
      if (failed) parent.append(warning(player.failed.join('\n'),true));
      player.paint();
    });
  }
  class BitmapPlayer {
    constructor(canvas,recipe,update) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.recipe = recipe;
      this.duration = Math.max(0.01,Number(recipe.duration ?? 1));
      this.time = 0;
      this.speed = 1;
      this.playing = false;
      this.disposed = false;
      this.layers = [];
      this.contextImages = [];
      this.failed = [];
      this.update = update;
      this.frame = null;
    }
    async load() {
      const work = (this.recipe.layers ?? []).map(async layer => {
        const asset = byId.get(layer.assetId);
        if (!asset?.thumbnail) return;
        const sequence = asset.record?.sequence;
        try {
          const paths = sequence?.framesExist ? sequence.frameWebPaths : [asset.record?.files?.find(file => file.exists)?.webPath ?? asset.thumbnail];
          const frames = await Promise.all(paths.map(loadImage));
          this.layers.push({layer,frames,fps:Number(layer.fps ?? sequence?.fps ?? 12)});
        } catch (error) { this.failed.push(error.message); }
      });
      const defaults = this.recipe.context === 'upgrade' ? [{referenceId:'upgrade-icon',displaySize:76,keyframes:[{t:0,x:0,y:0,scale:1,rotation:0,opacity:1}]}] : this.recipe.context === 'opening' ? ['supply-crate','supply-lid'].map(id=>({referenceId:id,displaySize:160,keyframes:[{t:0,x:0,y:id==='supply-crate'?48:8,scale:1,rotation:0,opacity:1}]})) : [];
      const contexts = this.recipe.contextLayers ?? defaults;
      work.push(...contexts.map(async layer => {
        const id=layer.referenceId;
        const reference = references.get(id);
        if (!reference?.exists) { this.failed.push(`장면 참조 이미지 없음: ${id}`); return; }
        try { this.contextImages.push({id,layer,image:await loadImage(reference.webPath)}); }
        catch (error) { this.failed.push(error.message); }
      }));
      await Promise.allSettled(work);
      this.layers.sort((a,b) => Number(a.layer.z ?? 0)-Number(b.layer.z ?? 0));
      this.contextImages.sort((a,b) => Number(a.layer.z ?? 0)-Number(b.layer.z ?? 0));
    }
    paint() {
      if (this.disposed || !this.ctx) return;
      const ctx = this.ctx;
      const [x,y] = this.recipe.anchor ?? [this.canvas.width/2,this.canvas.height/2];
      ctx.clearRect(0,0,this.canvas.width,this.canvas.height);
      for (const entry of this.contextImages) {
        const state=keyframe(entry.layer,Math.max(0,this.time-Number(entry.layer.start ?? 0)));
        const width = Number(entry.layer.displaySize ?? 160);
        const height = width*entry.image.naturalHeight/entry.image.naturalWidth;
        ctx.save();
        ctx.globalAlpha=Math.max(0,Math.min(1,state.opacity));
        ctx.translate(x+state.x,y+state.y);
        ctx.rotate(state.rotation*Math.PI/180);
        ctx.scale(state.scale,state.scale);
        ctx.drawImage(entry.image,-width/2,-height/2,width,height);
        ctx.restore();
      }
      for (const entry of this.layers) {
        const start = Number(entry.layer.start ?? 0);
        const end = Number(entry.layer.end ?? this.duration);
        if (this.time < start || this.time > end) continue;
        const local = this.time-start;
        const state = keyframe(entry.layer,local);
        const frameIndex = Math.floor(local*entry.fps);
        const index = entry.layer.frameLoop ? frameIndex % entry.frames.length : Math.min(entry.frames.length-1,frameIndex);
        const frame = entry.frames[index];
        if (!frame) continue;
        const fit = Number(entry.layer.displaySize ?? 256)/Math.max(frame.naturalWidth,frame.naturalHeight);
        const width = frame.naturalWidth*fit;
        const height = frame.naturalHeight*fit;
        ctx.save();
        ctx.globalCompositeOperation = entry.layer.blend === 'add' ? 'lighter' : 'source-over';
        ctx.globalAlpha = Math.max(0,Math.min(1,state.opacity));
        ctx.translate(x+state.x,y+state.y);
        ctx.rotate(state.rotation*Math.PI/180);
        ctx.scale(state.scale,state.scale);
        ctx.drawImage(frame,-width/2,-height/2,width,height);
        ctx.restore();
      }
      this.update();
    }
    toggle() {
      this.playing = !this.playing;
      if (this.playing) {
        if (this.time >= this.duration) this.time = 0;
        this.lastTick = performance.now();
        this.tick();
      } else cancelAnimationFrame(this.frame);
      this.paint();
    }
    tick() {
      if (this.disposed || !this.playing) return;
      const now = performance.now();
      this.time += Math.min(0.1,(now-this.lastTick)/1000)*this.speed;
      this.lastTick = now;
      if (this.time >= this.duration) {
        if (this.recipe.loop) this.time %= this.duration;
        else { this.time = this.duration; this.playing = false; }
      }
      this.paint();
      if (this.playing) this.frame = requestAnimationFrame(() => this.tick());
    }
    seek(time) { this.time = Math.max(0,Math.min(this.duration,time)); this.lastTick = performance.now(); this.paint(); }
    restart() { this.time = 0; if (!this.playing) this.toggle(); else { this.lastTick = performance.now(); this.paint(); } }
    dispose() { this.disposed = true; this.playing = false; cancelAnimationFrame(this.frame); }
  }
  $('assets-tab').addEventListener('click',() => setMode('assets'));
  $('recipes-tab').addEventListener('click',() => setMode('recipes'));
  $('search').addEventListener('input',() => { state.query = $('search').value; state.page = 0; renderResults(); });
  $('status').addEventListener('change',() => { state.status = $('status').value; state.page = 0; renderResults(); });
  $('family').addEventListener('change',() => { state.family = $('family').value; state.page = 0; renderResults(); });
  for (const id of ['only-favorites','only-candidates']) $(id).addEventListener('change',() => { state.page = 0; renderResults(); });
  $('previous-page').addEventListener('click',() => { state.page--; renderResults(); $('grid').scrollIntoView({block:'start'}); });
  $('next-page').addEventListener('click',() => { state.page++; renderResults(); $('grid').scrollIntoView({block:'start'}); });
  $('close-zoom').addEventListener('click',() => $('zoom-dialog').close());
  $('zoom-dialog').addEventListener('click',event => { if (event.target === $('zoom-dialog')) $('zoom-dialog').close(); });
  $('export-selection').addEventListener('click',() => {
    persist();
    const contents = {...selection,exportedAt:new Date().toISOString(),libraryCatalogGeneratedAt:catalog.generatedAt};
    const blob = new Blob([JSON.stringify(contents,null,2)],{type:'application/json'});
    const url = URL.createObjectURL(blob);
    const download = element('a');
    download.href = url;
    download.download = 'seoul-hero-art-selection.json';
    download.hidden = true;
    document.body.append(download);
    download.click();
    download.remove();
    setTimeout(() => URL.revokeObjectURL(url),30000);
    notify('즐겨찾기·선택 후보·메모를 JSON으로 내보냈습니다.');
  });
  $('import-selection').addEventListener('click',() => $('import-file').click());
  $('import-file').addEventListener('change',async () => {
    const file = $('import-file').files?.[0];
    if (!file) return;
    try {
      if (file.size > 5*1024*1024) throw new Error('선택 JSON은 5MB 이하로 가져오세요.');
      const imported = normalSelection(JSON.parse(await file.text()));
      selection = {schemaVersion:1,favorites:[...new Set([...selection.favorites,...imported.favorites])],candidates:[...new Set([...selection.candidates,...imported.candidates])],notes:{...selection.notes,...imported.notes}};
      persist();
      renderResults();
      renderDetail();
      notify('선택을 합쳤습니다. 같은 원화의 메모는 가져온 메모를 사용합니다.');
    } catch (error) { notify(error.message); }
    $('import-file').value = '';
  });
  window.addEventListener('pagehide',() => { persist(); activePlayer?.dispose(); });
  storageMessage();
  renderCategories();
  renderFamilies();
  renderResults();
})();
