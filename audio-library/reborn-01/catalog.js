'use strict';
(() => {
  const catalog = window.REBORN_CATALOG || {};
  const cues = Array.isArray(catalog.cues) ? catalog.cues : [];
  const sources = Array.isArray(catalog.sources) ? catalog.sources : [];
  const mixes = Array.isArray(catalog.mixes) ? catalog.mixes : [];
  const $ = id => document.getElementById(id);
  const player = $('player');
  const feedbackKey = 'seoul-hero:audio-review:reborn-01:v1';
  const categoryNames = { ui: 'UI · 보상', weapons: '무기 · 설치물', impacts: '적중 · 폭발', magic: '마법 · 게이트', creatures: '적 · 경고', ambience: '로비 환경', combat: '전투', rewards: '보상', warning: '경고', enemy: '몬스터' };
  let view = 'cues';
  let selected = null;
  let variant = 0;
  let playRequest = 0;
  let feedback = {};
  let storageAvailable = true;
  try { feedback = JSON.parse(localStorage.getItem(feedbackKey) || '{}'); }
  catch { storageAvailable = false; }
  if (!feedback || typeof feedback !== 'object' || Array.isArray(feedback)) feedback = {};
  player.volume = 0.5;

  function node(tag, text, className) {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = text;
    if (className) element.className = className;
    return element;
  }
  function fileOf(value) { return typeof value === 'string' ? value : value?.file || value?.preview || null; }
  function number(value, places = 2) { return Number.isFinite(Number(value)) ? Number(value).toFixed(places) : '—'; }
  function textOf(value) { return Array.isArray(value) ? value.join(' · ') : typeof value === 'object' && value ? JSON.stringify(value) : String(value ?? ''); }
  function statusOf(value) {
    const status = String(value || '').toLowerCase();
    if (/candidate|selected|use|사용|채택/.test(status)) return 'candidate';
    if (/exclude|reject|skip|제외/.test(status)) return 'excluded';
    return 'hold';
  }
  const statusNames = { candidate: '사용 재료', hold: '보류', excluded: '이번 작업에서 제외' };
  function categoryOf(cue) { return categoryNames[cue.category] || cue.category || '효과음'; }
  function sourceId(source, index) { return source.id || source.path || source.source || `source-${index}`; }
  function identity(item) { return view === 'sources' ? sourceId(item, sources.indexOf(item)) : item.id; }
  function searchable(item) { return JSON.stringify(item).toLocaleLowerCase(); }
  function appendPills(parent, labels) {
    const pills = node('div', undefined, 'pills');
    labels.filter(Boolean).forEach(label => pills.append(node('span', label)));
    parent.append(pills);
  }
  function appendFacts(parent, entries) {
    const facts = node('dl', undefined, 'facts');
    for (const [label, value] of entries) if (value !== undefined && value !== null && value !== '') facts.append(node('dt', label), node('dd', textOf(value)));
    parent.append(facts);
  }
  function appendReport(parent, label, report) {
    if (!report) return;
    const details = node('details', undefined, 'report');
    details.append(node('summary', label), node('pre', typeof report === 'string' ? report : JSON.stringify(report, null, 2)));
    parent.append(details);
  }
  async function play(file, label, loop = false) {
    if (!file) return;
    const request = ++playRequest;
    player.pause();
    player.src = file;
    $('loop').checked = loop;
    player.loop = loop;
    $('playing').textContent = label;
    try { await player.play(); }
    catch (error) { if (request === playRequest && error.name !== 'AbortError') $('playing').textContent = '재생 실패 · 파일 또는 브라우저 재생 허용을 확인하세요'; }
  }
  function playButton(label, file, nowPlaying, accent = false, loop = false) {
    const button = node('button', label, `play-button${accent ? ' accent' : ''}`);
    button.disabled = !file;
    button.addEventListener('click', () => play(file, nowPlaying || label, loop));
    return button;
  }
  function markSelection() {
    for (const button of $('list').querySelectorAll('button[data-id]')) {
      const active = button.dataset.id === String(selected);
      button.classList.toggle('selected', active);
      button.setAttribute('aria-pressed', String(active));
    }
  }
  function appendFeedback(parent, cue) {
    const section = node('section', undefined, 'feedback');
    const saved = feedback[cue.id] || {};
    section.append(node('h3', '이 소리에 대한 의견'));
    const choice = node('select');
    choice.id = 'feedback-choice';
    [['', '청취 후 선택'], ['keep', '이 방향이 좋음'], ['revise', '다듬으면 좋겠음'], ['replace', '다른 재료로 교체']].forEach(([value, label]) => {
      const option = node('option', label); option.value = value; choice.append(option);
    });
    choice.value = saved.choice || '';
    const choiceLabel = node('label', '방향'); choiceLabel.htmlFor = choice.id;
    const comment = node('textarea');
    comment.id = 'feedback-comment';
    comment.placeholder = '예: 2번 변형이 좋음 / 끝 울림이 길음 / 피격이 더 잘 들렸으면';
    comment.value = saved.comment || '';
    const commentLabel = node('label', '메모'); commentLabel.htmlFor = comment.id;
    const saveState = node('p', storageAvailable ? '의견은 이 브라우저에 저장됩니다. 아래 버튼으로 파일을 내려받을 수 있습니다.' : '브라우저 저장이 제한되어 있습니다. 의견 저장파일을 내려받아 보관하세요.', 'muted');
    const save = () => {
      feedback[cue.id] = { label: cue.label, choice: choice.value, comment: comment.value, variant: variant + 1, updatedAt: new Date().toISOString() };
      try { localStorage.setItem(feedbackKey, JSON.stringify(feedback)); saveState.textContent = '이 브라우저에 저장했습니다. 의견 저장파일로도 보관할 수 있습니다.'; }
      catch { storageAvailable = false; saveState.textContent = '의견은 현재 페이지에 있습니다. 의견 저장파일을 내려받아 보관하세요.'; }
      updateCount();
    };
    choice.addEventListener('change', save);
    comment.addEventListener('input', save);
    section.append(choiceLabel, choice, commentLabel, comment, saveState);
    parent.append(section);
  }
  function selectCue(cue, keepScroll = false) {
    const detail = $('detail');
    const previousScroll = detail.scrollTop;
    selected = cue.id;
    markSelection();
    const variants = Array.isArray(cue.variants) ? cue.variants : [];
    variant = Math.min(variant, Math.max(0, variants.length - 1));
    const edited = variants[variant];
    detail.replaceChildren(node('h2', cue.label || cue.id), node('div', cue.id, 'detail-id'));
    appendPills(detail, [categoryOf(cue), `${variants.length}개 변형`, cue.loop || cue.category === 'ambience' ? '스테레오 환경 루프' : '48kHz · 16bit · 모노', '청취 평가 대기']);
    const comparison = cue.comparisons?.variants?.[variant] || cue.comparisons || {};
    const currentCompare = fileOf(comparison.current);
    const newCompare = fileOf(comparison.new);
    detail.append(node('h3', currentCompare || newCompare ? '이전 / 적용본 · 음량을 맞춘 비교' : '이전 / 적용본'));
    const comparisons = node('div', undefined, 'comparison');
    const current = Array.isArray(cue.current) ? cue.current : cue.current ? [cue.current] : [];
    comparisons.append(playButton(currentCompare ? '▶ 이전 · 음량 맞춤' : current.length ? '▶ 이전 게임 소리' : '이전 대응 소리 없음', currentCompare || fileOf(current[0]), `이전 · ${cue.label}`), playButton(newCompare ? '▶ 적용본 · 음량 맞춤' : '▶ 적용본', newCompare || fileOf(edited), `적용본 · ${cue.label}`, true, Boolean(cue.loop)));
    detail.append(comparisons, node('p', currentCompare && newCompare ? '개별 비교는 음량을 맞췄습니다. 적용 gain의 차이는 장면 믹스에서 확인하세요.' : '이 비교는 편집 파일의 음량을 그대로 사용합니다. 이전 대응 소리가 없는 신규 cue도 포함됩니다.', 'muted'));
    if (cue.description || cue.notes) detail.append(node('p', textOf(cue.description || cue.notes)));
    if (cue.currentRole && cue.currentRole !== cue.id) {
      const roleNames = { weaponFired: '마력탄 발사', bombardAttack: '마력 폭격 착탄', chainAttack: '연쇄번개 첫 방전' };
      const role = roleNames[cue.currentRole] || cues.find(entry => entry.id === cue.currentRole)?.label || cue.currentRole;
      detail.append(node('div', `이 역할은 이번에 새로 연결했습니다. ‘이전’ 비교에는 기존 ${role} 재료를 사용했습니다.`, 'callout'));
    }
    if (variants.length) {
      const row = node('div', undefined, 'variant-row');
      const label = node('label', '적용본 변형'); label.htmlFor = 'variant';
      const select = node('select'); select.id = 'variant';
      variants.forEach((entry, index) => { const option = node('option', `${index + 1} · ${number(entry.duration)}초${entry.label ? ` · ${entry.label}` : ''}`); option.value = index; select.append(option); });
      select.value = variant;
      select.addEventListener('change', () => { variant = Number(select.value); selectCue(cue, true); });
      row.append(label, select); detail.append(row);
      detail.append(playButton(`▶ ${variant + 1}번 편집본 · 원래 음량`, fileOf(edited), `${cue.label} · 변형 ${variant + 1}`, true, Boolean(cue.loop)));
      appendFacts(detail, [['길이', `${number(edited?.duration)}초`], ['연결 역할', cue.events || cue.active_events || cue.role], ['편집 방향', edited?.notes || cue.editingIntent], ['미터', edited?.measurements || edited?.metrics ? '아래 편집 기록에서 확인' : undefined]]);
      const layers = edited?.layers || [];
      layers.forEach((layer, index) => {
        const source = node('section', undefined, 'source');
        const start = Number(layer.start || 0), duration = Number(layer.duration || 0);
        source.append(node('strong', index === 0 ? '사용한 원본 구간 · 주 재료' : `사용한 원본 구간 · 레이어 ${index + 1}`), node('p', layer.source || layer.path || '원본 경로'), node('p', `${number(start, 3)}–${number(start + duration, 3)}초${layer.speed !== undefined ? ` · 속도 ${layer.speed}×` : ''}`), playButton('▷ 원본 구간 비교', fileOf(layer.preview), `원본 ${index + 1} · ${cue.label}`, false, Boolean(cue.loop)));
        if (layer.preview_note) source.append(node('p', layer.preview_note, 'muted'));
        appendReport(source, '원본·편집 기록', layer);
        detail.append(source);
      });
      appendReport(detail, '이 편집본의 분석·출처', edited);
    }
    if (current.length > 1) {
      const previous = node('details', undefined, 'report'); previous.append(node('summary', `이전 대응 편집본 ${current.length}개`));
      current.forEach((entry, index) => previous.append(playButton(`▶ 현재 ${index + 1}${entry.label ? ` · ${entry.label}` : ''}`, fileOf(entry), `현재 ${index + 1} · ${cue.label}`)));
      detail.append(previous);
    }
    appendFeedback(detail, cue);
    detail.scrollTop = keepScroll ? previousScroll : 0;
  }
  function selectMix(mix) {
    selected = mix.id; markSelection();
    const detail = $('detail');
    detail.replaceChildren(node('h2', mix.label || mix.id), node('div', mix.id, 'detail-id'));
    appendPills(detail, [`${number(mix.duration, 1)}초`, '실제 적용 gain', '시뮬레이션 편집 믹스']);
    const buttons = node('div', undefined, 'comparison');
    buttons.append(playButton(mix.current ? '▶ 이전 소리 믹스' : '이전 대응 믹스 없음', fileOf(mix.current), `이전 믹스 · ${mix.label}`), playButton('▶ 적용본 믹스', fileOf(mix.new), `새 믹스 · ${mix.label}`, true));
    detail.append(buttons, node('p', textOf(mix.notes || '게임에서 사용할 gain과 동시 재생 정책으로 구성한 청취 장면입니다. 실제 플레이 녹음은 아닙니다.')), node('div', '믹스는 개별 비교처럼 음량을 다시 맞추지 않았습니다. 기존 BGM과 적용 gain·voice 정책이 함께 반영됩니다.', 'callout'));
    appendReport(detail, '동시 재생·우선순위 적용 기록', mix.policyReport || mix.policy_report);
    appendReport(detail, '장면 구성', mix.events || mix.timeline);
    detail.scrollTop = 0;
  }
  function selectSource(source) {
    selected = sourceId(source, sources.indexOf(source)); markSelection();
    const detail = $('detail');
    const path = source.path || source.source || source.id || '';
    detail.replaceChildren(node('h2', path.split(/[\\/]/).pop() || '원본 검토'), node('div', path, 'detail-id'));
    const status = statusOf(source.status);
    appendPills(detail, [statusNames[status], source.pack, '직접 청취 미실시']);
    detail.append(node('div', '원본은 파일·파형 분석으로 검토했습니다. 전체 적용은 승인됐으며 직접 청감 검증은 수행하지 않았습니다.', 'callout'), node('p', textOf(source.reason || '검토 사유는 분석 기록에 보존됩니다.')));
    const stats = source.analysis || source.metrics || source;
    appendFacts(detail, [['길이', `${number(source.duration ?? stats.duration, 2)}초`], ['채널', source.channels ?? stats.channels], ['샘플레이트', source.sample_rate ?? stats.sample_rate], ['피크', source.peak_dbfs ?? stats.peak_dbfs], ['잡음·무음', source.noise_note || source.silence_note || stats.noise_note], ['검토 방식', source.audition_state || source.listening_review || 'not_auditioned'], ['원본 SHA256', source.sha256]]);
    const segments = source.segments || source.candidate_segments || source.analysis?.segments || [];
    if (segments.length) {
      detail.append(node('h3', '원본 청취용 발췌 구간'));
      if (source.analysis?.segments) detail.append(node('p', `전체 파형 동작 구간 ${source.analysis.segments.length}개는 아래 파일 분석 기록에 보존했습니다.`, 'muted'));
      const list = node('ul', undefined, 'review-list');
      segments.forEach(segment => { const start = Number(segment.start || 0), end = Number(segment.end ?? start + Number(segment.duration || 0)); const item = node('li', `${number(start, 3)}–${number(end, 3)}초${segment.reason || segment.label ? ` · ${segment.reason || segment.label}` : ''}`); if (segment.preview) item.append(playButton('▷ 구간 재생', fileOf(segment.preview), `원본 · ${path}`)); list.append(item); });
      detail.append(list);
    }
    const uses = source.uses || cues.flatMap(cue => (cue.variants || []).flatMap((edited, index) => (edited.layers || []).filter(layer => (layer.source || layer.path) === path).map(() => `${cue.label} · 변형 ${index + 1}`)));
    if (uses.length) { detail.append(node('h3', '이 원본을 사용한 편집본')); const list = node('ul', undefined, 'review-list'); [...new Set(uses)].forEach(use => list.append(node('li', textOf(use)))); detail.append(list); }
    appendReport(detail, '파일 분석·검토 전체 기록', source);
    detail.scrollTop = 0;
  }
  function showPolicy() {
    selected = null;
    const detail = $('detail');
    detail.replaceChildren(node('h2', '새 소리를 비교하는 기준'), node('div', '전체 채택본 실제 적용 · 기존 소리와 원본 보존', 'callout'));
    const list = node('ul', undefined, 'note-list');
    ['짧고 탄력 있는 타격, 산뜻한 마력, 명확한 보상. 장난감 같은 삑삑 소리와 과한 코믹 효과는 줄입니다.', '전투 BGM gain은 0.12. 개별 비교는 음량을 맞추고, 장면 믹스는 실제 적용 gain을 사용합니다.', '총 16voice, 일반음 최대 12voice. 피격·위험 경고·결과음은 중요한 소리로 보호합니다.', '같은 변형의 연속 재생을 막고 반복 적중·획득의 간격을 조정합니다. 번개 후속음은 공격당 최대 2회입니다.', '로비 환경 루프는 배경에 맞춰 동시에 하나만 낮게 재생합니다. 전투 상시 환경층은 추가하지 않습니다.', '원본은 변경하지 않았습니다. 파일 분석·편집 완료와 청취 만족을 구분하며 사용자의 전체 적용 승인으로 게임에 연결했습니다.'].forEach(text => list.append(node('li', text)));
    detail.append(list);
    if (catalog.notes) detail.append(node('p', textOf(catalog.notes), 'muted'));
    appendReport(detail, '공용 믹스 데이터', catalog.policy);
    appendReport(detail, '전체 검토 요약', catalog.summary);
    detail.scrollTop = 0;
  }
  function items() { return view === 'cues' ? cues : view === 'mixes' ? mixes : view === 'sources' ? sources : []; }
  function filteredItems() {
    const query = $('search').value.trim().toLocaleLowerCase();
    const category = $('category').value;
    const status = $('source-status').value;
    return items().filter(item => (!query || searchable(item).includes(query)) && (view !== 'cues' || !category || category === item.category) && (view !== 'sources' || !status || status === statusOf(item.status)));
  }
  function updateCount() { $('count').textContent = `${filteredItems().length}개 · 의견 ${Object.keys(feedback).filter(id => feedback[id].choice || feedback[id].comment).length}개`; }
  function render() {
    const filtered = filteredItems();
    updateCount();
    const fragment = document.createDocumentFragment();
    for (const item of filtered) {
      const button = node('button', undefined, 'sound');
      const id = identity(item); button.dataset.id = id;
      button.classList.toggle('selected', id === selected); button.setAttribute('aria-pressed', String(id === selected));
      const title = node('div');
      let name, subtitle, meta;
      if (view === 'sources') { name = (item.path || item.source || item.id || '').split(/[\\/]/).pop(); subtitle = item.pack || (item.path || '').split(/[\\/]/).slice(-2, -1)[0]; meta = statusNames[statusOf(item.status)]; }
      else if (view === 'mixes') { name = item.label || item.id; subtitle = '실제 적용 gain · 이전 / 적용본'; meta = `${number(item.duration, 1)}초`; }
      else { name = item.label || item.id; subtitle = `${categoryOf(item)} · ${item.id}`; meta = `${(item.variants || []).length}개 변형${feedback[item.id]?.choice || feedback[item.id]?.comment ? '\n의견 작성' : ''}`; }
      title.append(node('strong', name), node('small', subtitle));
      button.append(title, node('div', meta, `meta${view === 'sources' ? ` ${statusOf(item.status) === 'candidate' ? 'done' : 'hold'}` : ''}`));
      button.addEventListener('click', () => { variant = 0; if (view === 'cues') selectCue(item); else if (view === 'mixes') selectMix(item); else selectSource(item); });
      fragment.append(button);
    }
    if (!filtered.length) fragment.append(node('p', view === 'policy' ? '오른쪽에서 기준과 분석 요약을 확인하세요. 적용본와 원본을 듣고 의견을 남겨주세요.' : catalog.cues ? '검색 결과가 없습니다.' : '후보 데이터를 준비 중입니다. catalog-data.js가 완성되면 목록이 표시됩니다.', 'empty'));
    $('list').replaceChildren(fragment);
  }
  function changeView(next) {
    view = next; selected = null; variant = 0;
    $('search').value = ''; $('category').value = ''; $('source-status').value = '';
    $('category').hidden = view !== 'cues'; $('source-status').hidden = view !== 'sources';
    $('search').disabled = view === 'policy';
    $('search').placeholder = view === 'sources' ? '원본 이름 · 번들 · 검토 사유 검색' : '이름 · 용도 · 원본 검색';
    for (const button of document.querySelectorAll('nav [data-view]')) { const active = button.dataset.view === view; button.classList.toggle('active', active); button.setAttribute('aria-pressed', String(active)); }
    render();
    const first = items()[0];
    if (view === 'policy') showPolicy();
    else if (first) { if (view === 'cues') selectCue(first); else if (view === 'mixes') selectMix(first); else selectSource(first); }
    else $('detail').replaceChildren(node('p', '표시할 데이터가 없습니다.', 'muted'));
    $('list').parentElement.scrollTop = 0;
  }
  [...new Set(cues.map(cue => cue.category).filter(Boolean))].forEach(category => { const option = node('option', categoryNames[category] || category); option.value = category; $('category').append(option); });
  $('search').addEventListener('input', render);
  $('category').addEventListener('change', render);
  $('source-status').addEventListener('change', render);
  document.querySelectorAll('nav [data-view]').forEach(button => button.addEventListener('click', () => changeView(button.dataset.view)));
  $('loop').addEventListener('change', () => { player.loop = $('loop').checked; });
  player.addEventListener('error', () => { $('playing').textContent = '오디오 파일을 읽지 못했습니다. 파일 경로를 확인하세요.'; });
  $('export').addEventListener('click', () => {
    const output = { project: '서울 히어로', revision: 'reborn-01', exportedAt: new Date().toISOString(), listening: 'user_feedback', feedback };
    const url = URL.createObjectURL(new Blob([JSON.stringify(output, null, 2)], { type: 'application/json' }));
    const link = node('a'); link.href = url; link.download = `seoul-hero-audio-feedback-${new Date().toISOString().slice(0, 10)}.json`; document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  });
  const environmentCount = cues.filter(cue => cue.loop || cue.category === 'ambience').length;
  $('total').textContent = `${cues.length - environmentCount} 효과음 + ${environmentCount} 환경 / ${sources.length} 원본`;
  changeView('cues');
})();
