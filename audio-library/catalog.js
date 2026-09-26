'use strict';
(() => {
  const sounds = window.AUDIO_LIBRARY || [];
  const $ = id => document.getElementById(id);
  const player = $('player');
  const categories = {ui:'UI · 보상',weapons:'무기 · 설치물',impacts:'적중 · 폭발',magic:'마법 · 게이트',creatures:'적 · 경고',ambience:'환경 루프'};
  let selected = null;
  let playRequest = 0;
  player.volume = .65;
  const searchable = new Map(sounds.map(sound => [sound.id, [sound.id,sound.label,...sound.tags,...sound.active_events,...sound.layers.map(l => l.source)].join(' ').toLocaleLowerCase()]));
  const node = (tag, text, className) => {
    const result = document.createElement(tag);
    if (text !== undefined) result.textContent = text;
    if (className) result.className = className;
    return result;
  };
  async function play(file, label) {
    const request = ++playRequest;
    player.pause();
    player.src = file;
    player.loop = $('loop').checked;
    $('playing').textContent = label;
    try { await player.play(); }
    catch (error) {
      if (request === playRequest && error.name !== 'AbortError') $('playing').textContent = '재생 실패 · 파일 경로와 브라우저 재생 허용을 확인하세요';
    }
  }
  player.addEventListener('error', () => { $('playing').textContent = '오디오 파일을 읽지 못했습니다'; });
  $('loop').addEventListener('change', () => { player.loop = $('loop').checked; });
  function select(sound) {
    selected = sound.id;
    for (const button of $('list').children) {
      const active = button.dataset.id === selected;
      button.classList.toggle('selected', active);
      button.setAttribute('aria-pressed', String(active));
    }
    const detail = $('detail');
    detail.replaceChildren(node('h2', sound.label), node('div', sound.id, 'detail-id'));
    const pills = node('div', undefined, 'pills');
    [categories[sound.category], `${sound.duration.toFixed(2)}초`, sound.channels === 1 ? '모노' : '스테레오', sound.loop ? '루프' : '단발', sound.active_events.length ? '게임 적용' : '미래용'].forEach(t => pills.append(node('span', t)));
    detail.append(pills);
    const edited = node('button', '▶ 편집본 재생', 'primary');
    edited.onclick = () => play(sound.file, sound.label);
    detail.append(edited, node('p', '청취 평가 대기 · 파일 분석 및 편집 완료', 'muted'));
    if (sound.active_events.length) detail.append(node('p', '연결: ' + sound.active_events.join(', ')));
    sound.layers.forEach((layer, index) => {
      const source = node('section', undefined, 'source');
      source.append(node('strong', index === 0 ? '주 재료' : '보조 질감'));
      source.append(node('p', layer.source));
      source.append(node('p', `${layer.start.toFixed(3)}–${(layer.start + layer.duration).toFixed(3)}초 · 속도 ${layer.speed}× · 레이어 ${layer.mix_gain} · 지연 ${Math.round(layer.delay_seconds * 1000)}ms`));
      const original = node('button', '▷ 사용한 원본 구간');
      original.onclick = () => play(layer.preview, `원본 구간 ${index + 1} · ${sound.label}`);
      source.append(original);
      detail.append(source);
    });
    detail.append(node('p', '원본 구간은 비교를 위해 음량·샘플레이트·끝단 페이드만 정리했습니다. 게임에서는 개별 gain과 버스 설정이 추가 적용됩니다.', 'muted'));
    detail.scrollTop = 0;
  }
  function render() {
    const query = $('search').value.trim().toLocaleLowerCase();
    const category = $('category').value, usage = $('usage').value;
    const filtered = sounds.filter(s => (!category || category === s.category) && (!query || searchable.get(s.id).includes(query)) && (!usage || Boolean(s.active_events.length) === (usage === 'active')));
    $('count').textContent = `${filtered.length}개`;
    const fragment = document.createDocumentFragment();
    for (const sound of filtered) {
      const button = node('button', undefined, 'sound');
      button.dataset.id = sound.id;
      button.classList.toggle('selected', selected === sound.id);
      button.setAttribute('aria-pressed', String(selected === sound.id));
      const title = node('div');
      title.append(node('strong', sound.label), node('small', `${categories[sound.category]} / ${sound.id}`));
      const meta = node('div', undefined, 'meta');
      meta.append(node('div', `${sound.duration.toFixed(2)}s${sound.loop ? ' ↻' : ''}`), node('div', sound.active_events.length ? '● 게임 적용' : '미래용', sound.active_events.length ? 'active-dot' : ''));
      button.append(title, meta);
      button.onclick = () => { select(sound); play(sound.file, sound.label); };
      fragment.append(button);
    }
    if (!filtered.length) fragment.append(node('p', '검색 결과가 없습니다.', 'empty'));
    $('list').replaceChildren(fragment);
  }
  $('search').addEventListener('input', render);
  $('category').addEventListener('change', render);
  $('usage').addEventListener('change', render);
  $('compare').onclick = () => $('comparison-dialog').showModal();
  $('close-dialog').onclick = () => $('comparison-dialog').close();
  for (const [file, label] of [['shot-then-hit','발사 → 170ms 뒤 적중 · 12회'],['dense-combat-warning','전투 겹침 → 보스 경고 → 플레이어 피격'],['ui-sequence','클릭 → 구매 → 리롤 → 보급 → 보상']]) {
    const button = node('button', `▶ ${label}`);
    button.onclick = () => { $('loop').checked = false; play(`comparisons/${file}.wav`, label); $('comparison-dialog').close(); };
    $('comparisons').append(button);
  }
  $('total').textContent = `${sounds.length} SOUNDS / ${sounds.filter(s => s.active_events.length).length} IN GAME`;
  render();
  if (sounds.length) select(sounds.find(s => s.id === 'weapons/mana_bolt_01') || sounds[0]);
})();
