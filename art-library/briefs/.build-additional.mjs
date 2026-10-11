import fs from 'node:fs';
import path from 'node:path';

const folder = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/i, '$1'));
const pad = value => String(value).padStart(3, '0');
const entries = [];
const common = (id, category, nameKo, family, tags, descriptionKo, visualBrief, useKo, motion, aspectRatio, transparent, format, referenceIds) => ({id, category, nameKo, family, tags, descriptionKo, visualBrief, useKo, motion, aspectRatio, transparent, format, referenceIds});

const motifs = {
  upgrade: [
    ['cheonbu-knot','천부 결속','three interlocking bronze knots with ivory thread and small jade wedges','연결된 매듭과 옥 쐐기'],
    ['star-iron','별무쇠 각인','a dark meteor-iron pentagonal core surrounded by small silver star splinters','오각 철핵과 별무쇠 파편'],
    ['samjogo-feather','삼족오 깃결','three curved black-gold feather strokes with warm amber barbs','검금 깃털 세 갈래'],
    ['tortoise-lattice','현무 등결','a low hexagonal jade shell lattice with four slate corner plates','육각 등껍질과 네 모서리 판'],
    ['dragon-current','청룡 흐름','two teal dragon-whisker ribbons wrapped around a pearl-white droplet','청록 수염 리본과 백색 물방울'],
    ['haechi-crown','해치 수호','a compact ivory horn crest over a navy cloud curl and turquoise sparks','상아 뿔 장식과 구름 곡선'],
    ['jangseung-carving','장승 새김','two short cedar carving blocks with simple geometric eye cuts and pale sawdust','짧은 목각 블록과 밝은 톱밥'],
    ['jade-renewal','옥결 재생','translucent mint jade crescents enclosing a small moss-green faceted seed','민트 옥 초승달과 초록 씨앗'],
    ['taegeuk-balance','태극 균형','two unequal navy and coral comma stones separated by a slender ivory arc','서로 다른 쉼표 돌과 상아색 곡선'],
    ['hangang-ripple','한강 파문','three silver-blue stepped water arcs with a single pale river pebble','세 겹 물결과 강돌']
  ],
  opening: [
    ['latch-spark','황동 봉인','chunky brass latch teeth, navy enamel fragments and short white contact sparks','황동 걸쇠와 짧은 접촉 불꽃'],
    ['paper-fold','접힌 빛','ivory folded-paper facets with sharp turquoise inner edges and tiny paper chips','접힌 종이 면과 청록 안쪽 모서리'],
    ['crystal-tether','결정 사슬','violet crystal clasps joined by thin silver links with a faceted inner glow','보라 결정 걸쇠와 은색 연결 고리'],
    ['salt-prism','소금 프리즘','milky cube-crystal fragments surrounding a champagne triangular beam','유백 결정 조각과 삼각 빛'],
    ['petal-seal','꽃잎 봉인','five thick plum petals with jade stamens and a single brass seal stud','두꺼운 자주 꽃잎과 옥 수술'],
    ['zipper-gate','틈새 개방','a staggered navy zipper-like slit with pale mint triangular teeth','엇갈린 틈새와 민트 삼각 이빨'],
    ['moon-mirror','달 거울','a chipped round silver mirror rim with a smoky indigo reflection','깨진 은색 거울 테두리와 남색 반사'],
    ['hex-package','육각 개방','ivory hexagonal locks and orange hinge blocks surrounding a cool cyan core','육각 잠금과 주황 경첩'],
    ['smoke-cask','연무 해방','rounded copper hoops and plum smoke ribbons containing clear glass flecks','구리 고리와 자주 연무'],
    ['cloud-fold','구름 주름','three scalloped pearl cloud folds tied by narrow charcoal bands','진주빛 구름 주름과 검은 띠']
  ],
  acquire: [
    ['bookmark-comet','별갈피','a copper bookmark notch trailing an ivory comet wedge and teal dust','동색 책갈피와 혜성 쐐기'],
    ['bamboo-vow','죽절 약속','jointed green bamboo arc fragments with tiny linen ties','마디 있는 대나무 조각과 아마 끈'],
    ['bell-wake','종의 여운','a bronze bell silhouette implied by separate curved sound bands','종 모양을 만드는 분리된 소리 띠'],
    ['key-window','열쇠 창','a square silver keyhole window with offset coral corner shards','사각 열쇠 창과 어긋난 모서리 파편'],
    ['thread-award','실의 보상','two braided saffron and navy threads ending in clear quartz beads','황금색 남색 땋은 실과 수정 구슬'],
    ['map-reveal','지도 펼침','navy map-fold corners with mint route dashes and pale raised contour chips','지도 접힘과 민트 경로 조각'],
    ['dew-crown','이슬 왕관','five asymmetrical glass droplets over a broad shallow jade crescent','비대칭 유리 물방울과 옥 초승달'],
    ['badge-flare','기장의 빛','an octagonal dull-gold badge edge split into eight thick clean facets','팔각 기장의 여덟 면']
  ],
  combat: [
    ['steel-impact','강철 충격','short chipped silver wedges, navy impact dust and a blunt ivory flash','짧은 은색 쐐기와 금속 충격 먼지'],
    ['arc-current','전류 갈래','three angular cyan electrical branches with small plum contact beads','각진 청록 전류와 자주 접촉 구슬'],
    ['ash-burst','재의 폭발','burnt-orange ember discs surrounded by charcoal ash curls','주황 잿불 원판과 검은 재'],
    ['frost-split','서리 균열','wide pale-blue ice fissures with opaque white chipped crystal edges','넓은 서리 균열과 흰 결정 모서리'],
    ['venom-fold','시약 파열','lime translucent fluid folds with ivory bubbles and olive droplets','연두 액체 주름과 올리브 방울'],
    ['gravity-shard','중력 파편','matte violet triangular plates pulled toward a small black oval center','보라 삼각판과 검은 타원핵'],
    ['echo-strike','메아리 타격','three offset peach crescent strokes with slender navy echo marks','엇갈린 복숭아색 초승달 타격선'],
    ['ward-break','방벽 파쇄','broken mint hexagonal shield edges and dull brass corner pegs','부서진 민트 방벽과 황동 쐐기']
  ],
  environment: [
    ['forge-steam','공방 증기','soft ivory steam spirals with copper condensation flecks','상아색 증기 나선과 동색 응결'],
    ['laboratory-signal','연구 신호','teal rectangular indicator panes connected by sparse white microdots','청록 표시 면과 작은 흰 점'],
    ['recovery-dust','회수 먼지','low slate-gray dust curls containing two amber salvage fragments','낮은 회색 먼지와 황색 회수 조각'],
    ['mana-pump','마력 펌프','violet liquid bands constrained by curved silver brackets','곡선 은색 틀 안의 보라 액체 띠'],
    ['garden-mist','온실 안개','thin moss-green mist carrying tiny pearl seed-like motes','연녹 안개와 씨앗빛 입자'],
    ['archive-motes','기록 먼지','warm ivory paper dust with a few angular navy flakes','상아색 종이 먼지와 남색 조각'],
    ['roof-wind','옥상 바람','three transparent smoky-blue wind ribbons with isolated tan leaf fragments','세 갈래 푸른 바람과 잎 조각'],
    ['harbor-haze','수변 물안개','horizontal pale silver-blue vapor folds with thin teal water beads','가로 수증기 주름과 청록 물방울']
  ]
};

const effectForms = {
  upgrade: [
    ['응축 핵','a compact centered core made of three nested irregular masses; negative space stays inside the silhouette','중심 응축','condense'],
    ['상승 기둥','a narrow ascending column with three staggered side fins and a rounded base flare','수직 상승','rise'],
    ['결속 고리','a broken circular clasp assembled from four unequal thick segments with visible gaps','외곽 결속','bind'],
    ['쐐기 폭발','an eight-point asymmetric burst with broad short blades and two detached large fragments','단발 폭발','burst'],
    ['잔광 리본','two broad trailing ribbons crossing once, with tapering ends and empty center','잔광 소멸','drift'],
    ['부유 조각','five separated chunky fragments on a loose diagonal S path, each visibly different in size','주변 입자','float']
  ],
  opening: [
    ['봉인 균열','a low horizontal broken seal with a central jagged seam and two heavy end caps','봉인 해제','crack'],
    ['안쪽 빛','a squat trapezoid fan of three thick light wedges opening from one common lower origin','내부 광원','fan'],
    ['솟는 연무','a tall soft plume split into two large lobes with small hard-edge fragments near the base','개봉 연무','rise'],
    ['벌어진 고리','an open horseshoe-shaped rim with offset end pieces pulled visibly apart','입구 확장','expand'],
    ['쏟는 조각','seven distinct wide fragments spilling down a curved path with a large opening above','내용물 분출','spill'],
    ['환영 잔광','three nested shallow roof-shaped bands with uneven tips and a clean central viewing area','결과 등장','fade']
  ],
  acquire: [
    ['예고 점','three chunky diagonal marks converging on a small lower-right diamond','선택 예고','converge'],
    ['확인 둘레','a broad incomplete octagonal border with two thick tabs and no center fill','획득 확인','trace'],
    ['해금 파편','four locked-looking bars breaking into seven differently shaped flying chips','잠금 해제','break'],
    ['등장 후광','an off-center scalloped halo with a shallow notch and separated triangular gleams','보상 등장','pulse'],
    ['정착 잔광','two low sweeping curves ending in three beads, leaving the upper canvas empty','확인 후 잔광','settle']
  ],
  combat: [
    ['충격 핵','a short broad strike core with a wedge-shaped entry side and three blunt outward lobes','적중 중심','impact'],
    ['퍼지는 파동','a thick irregular shock ring broken into six clean sections, viewed face-on','범위 타격','expand'],
    ['흩날린 파편','five hard-edged fragments and two soft dust curls arranged outward from a clear center','파편 분산','scatter'],
    ['가는 흔적','a curved tapered streak with a blunt bright leading end and two distinct trailing marks','이동 흔적','trail'],
    ['늦는 잔무','a broad low smoke lobe with one small curl and sparse opaque splinters at its edge','후속 잔무','fade']
  ],
  environment: [
    ['작동 숨결','two alternating low rounded plumes above a flat empty lower strip; sparse, calm silhouette','설비 작동','breathe'],
    ['점등 순환','five separate block-like glints in a shallow curved line, no baked text or gauge face','설비 점등','cycle'],
    ['흐르는 띠','three thin horizontal bands with offset breaks and one gently curling end','재료 흐름','flow'],
    ['분산 입자','six distinct small motes on a wide, sparse arc with no central flash','주변 입자','float'],
    ['완료 여운','a low open crest with three outward curls and a small quiet afterglow underneath','작업 완료','settle']
  ]
};

const sequences = new Set([...Array.from({length:12},(_,i)=>i+1),...Array.from({length:16},(_,i)=>i+61),...Array.from({length:12},(_,i)=>i+161),...Array.from({length:8},(_,i)=>i+201)]);
let effectNumber = 0;
for (const [group, familyMotifs] of Object.entries(motifs)) {
  for (const [slug, motifKo, appearance, appearanceKo] of familyMotifs) {
    for (const [formKo, shape, stageKo, motion] of effectForms[group]) {
      const n = ++effectNumber;
      const sequence = sequences.has(n);
      let brief = `ONE reusable transparent 2D raster effect for Seoul Hero, ${shape}. Design language: ${appearance}. Thick readable silhouette, limited cel-painted texture, clean alpha, no background, ground shadow, frame, letters, numbers, interface, character or item illustration. Keep the origin registered at the same central anchor and include safe margin. This asset is an isolated ${motion} layer, not a complete screen.`;
      if (sequence) brief += ' Deliver an aligned eight-frame sequence in EXACTLY FOUR COLUMNS by TWO ROWS, eight identical square cells. Read frames 1-4 left-to-right on the top row and frames 5-8 left-to-right on the bottom row. Preserve the same camera, registration, scale and outer safe margin in all cells; transparent background between and inside cells. Exactly eight frames at 12 fps: 1 quiet precursor (10% opacity), 2 gather narrow fragments inward, 3 concentrate the core, 4 rapid outward reveal, 5 strongest fully readable silhouette, 6 separate the broad fragments, 7 sparse soft afterglow, 8 transparent end with only two faint residue marks. Shape morphing must be continuous; do not redraw unrelated effects between cells. No frame borders or frame labels.';
      else brief += ' Show the fully readable peak phase as a SINGLE PNG; animate later through position, scale, rotation and opacity. Do not generate a contact sheet or motion trail made of repeated full copies.';
      const entry = common(`effect-${pad(n)}`, 'effect', `${motifKo} · ${formKo}`, `${group}/${slug}`,[group,slug,motion,sequence?'8프레임':'단일 원화'],`${appearanceKo}을 ${formKo} 형태로 구성한 ${stageKo} 원화.`,brief,group==='combat'?'향후 공격·적중·방벽 효과 후보':'향후 강화·개봉·획득·시설 연출의 독립 레이어 후보',motion,sequence?[4,2]:[1,1],true,sequence?'sequence8':'png',['effect-style']);
      if (sequence) entry.sequence = {frames:8,columns:4,rows:2,grid:[4,2],fps:12,frameAspectRatio:[1,1],registration:'center',duration:8/12};
      if (n === 213) {
        entry.nameKo = '공사 용접 · 흐르는 불꽃';
        entry.family = 'facility/welding-sparks';
        entry.tags = ['facility','용접','건설','flow','단일 원화'];
        entry.descriptionKo = '청백색 용접점에서 가느다란 동색 불꽃과 회색 연기가 옆으로 퍼지는 독립 소재.';
        entry.visualBrief = 'ONE isolated compact welding spark VFX layer for Seoul Hero: a brilliant blue-white pin-point arc at the lower left, an asymmetric fan of thin copper-orange sparks sweeping up and right, with a small translucent slate-gray smoke curl. No welding torch, tool, worker, metal plate, room or ground. Strong readable asymmetrical silhouette, hand-painted cel shading and clean real alpha. SINGLE PNG peak phase, no frame, text or repeated examples. Keep the complete spark fan and smoke inside the central 75 percent of the canvas with transparent clearance at every edge.';
        entry.useKo = '향후 시설 공사·장비 수리·제조 가동 연출 후보';
      }
      entries.push(entry);
    }
  }
}

const roomTypes = [
  ['operations','작전 운영실','a navy wall map table, ivory scheduling board and copper communication hub','전술 지도 책상·통신 허브'],
  ['research','마력 연구실','teal circuit benches, a violet core microscope and glass containment hoops','회로 작업대·결정 현미경'],
  ['expedition','탐험 준비실','ochre locker bays, coiled climbing tethers and a compact jade route projector','탐험 수납장·경로 투영기'],
  ['production','마력 생산실','a copper refining vat, slate feed hoppers and turquoise pressure piping','구리 정제통·공급 호퍼'],
  ['recovery','회수 분류실','an ivory sorting conveyor, navy parcel cubbies and amber scanner arch','분류 컨베이어·검색 아치'],
  ['workshop','장비 공방','a silver forging table, charcoal tool racks and orange articulated clamp','단조 작업대·공구 선반'],
  ['revival','생환 제조실','lime reagent reservoirs, pale medical assembly trays and purple crystal incubator','시약 저장조·생환 결정 배양기'],
  ['analysis','각성 분석실','three narrow cyan observation screens, a plum resonance chair and ivory sensor arms','관측 화면·공명 의자'],
  ['training','직원 교육실','an ivory teaching console, round plum padded practice targets, mint holographic skill-demo panels and modular training stations with slate safety mats','교육 단말·훈련 표적·기술 실습 모듈'],
  ['refinery','마력 정제실','sealed violet catalyst distillation columns, copper filtration vessels, ivory crystal grading trays and stepped teal coolant pipes','촉매 증류탑·정제 여과기·결정 선별대']
];
const roomStages = [
  ['초기','one compact bench against the rear wall, low open shelves on one side, exposed rear pipes, a large open staff walking strip across the front','낮은 작업대와 열린 선반'],
  ['증설','a large central machine supported by two side cabinets, an overhead rail aligned behind the staff strip, raised rear utility racks','중앙 설비와 천장 레일'],
  ['전문','two physically separate workstations connected by a narrow rear conveyor, a reinforced overhead gantry, tiered back-wall storage and one enclosed processing bay','분리 작업구역과 상부 구조'],
  ['통합','three distinct work bays with a wide rear processing tower, enclosed transparent conduit bridge, ceiling crane and built-in control balcony entirely behind the clear staff strip','세 작업구역과 후면 제어층']
];
const equipment = [
  ['mana-smelter','마력 제련기','a squat charcoal crucible with a large violet core chamber and copper pouring spout','생산·정제'],
  ['coil-winder','코일 권선기','a silver U-shaped coil spindle with three teal wire reels and a broad orange clamp','전자 제작'],
  ['prism-analyzer','프리즘 분석기','a low ivory triangular prism cradle beneath a navy arch and three offset sensor tubes','연구'],
  ['reagent-mixer','시약 혼합기','two unequal lime glass reservoirs connected by a thick white Y-shaped mixer body','생환 제조'],
  ['parcel-sorter','회수 분류기','a navy rectangular short conveyor with one tilted amber scan plate and two ivory collection bins','회수'],
  ['rune-press','각인 프레스','an ochre square press head over a broad silver slate die and violet side accumulator','장비 공방'],
  ['seed-incubator','결정 배양기','three pale capsule pods arranged around a moss-green central pillar on a low hexagonal base','결정 배양'],
  ['route-projector','탐험 투영기','a round jade route lens nested in a navy folding tripod console, no actual map text','탐험'],
  ['archive-drum','기록 드럼','an ivory drum-shaped archive cabinet with brass segment doors and a small cedar feeder','보관'],
  ['gate-antenna','게이트 안테나','two thick silver half-rings raised from a small navy pedestal and offset purple receiver disc','관측'],
  ['forge-bellows','공방 송풍기','a chunky charcoal fan housing beside a ribbed amber bellows and copper vent hood','단조'],
  ['water-still','마력 증류기','a pale cylindrical glass still with three stepped silver condensers and teal liquid pipe','정제'],
  ['staff-terminal','직원 단말','a slanted ivory desk module with a wide blank cyan glass display and short navy card slot','직원 관리'],
  ['training-simulator','교육 시뮬레이터','a small navy octagonal training pod with peach padded arms and a mint status lamp','교육'],
  ['coolant-pump','냉각 순환기','a squat silver double-piston pump with thick teal coolant bends and a black ribbed tank','냉각'],
  ['shield-battery','방벽 축전기','three stepped ivory capacitor plates braced by a navy cage and small gold crystal sockets','방벽'],
  ['bio-filter','생체 여과기','a broad white rectangular filter cassette with lime mesh windows and two asymmetrical glass tubes','시약'],
  ['fragment-separator','조각 분리기','a copper shallow bowl centrifuge with six uneven ivory teeth and a violet receiving tray','조각 분리'],
  ['spectral-camera','공명 촬영기','a chunky navy twin-lens camera on a silver low stand with a translucent plum side box','분석'],
  ['cargo-lift','화물 승강기','an orange compact hoist column with a navy fork tray and exposed silver chain wheel','운반'],
  ['thread-loom','결속 직조기','a cedar miniature loom with two ivory rollers, teal threads and heavy brass side knobs','제조'],
  ['seal-assembler','봉인 조립기','a low silver star-shaped assembly jig surrounded by three movable navy vice jaws','봉인'],
  ['vault-lock','금고 잠금기','a thick navy circular vault wheel inside an ivory rectangular frame with two amber lock bars','보관'],
  ['mist-extractor','안개 포집기','a wide pearl-gray hood above two teal collection cones and a short transparent capture jar','환경 연구']
];
let facilityNumber = 0;
function addFacility(nameKo,family,shape,description,useKo,aspect=[2,1],transparent=false,motion='none') {
  const id=`facility-${pad(++facilityNumber)}`;
  entries.push(common(id,'facility',nameKo,family,['시설',family.split('/')[0],useKo],description,`ONE Seoul Hero facility illustration. ${shape.replace(/\.$/,'')}. Match the chunky SD urban-fantasy environment language: bold clean outlines, simple painted materials, pale ivory and navy structure with restrained teal/purple/orange indicators. No characters, baked labels, logos, UI frames, buttons or floor shadows on equipment. Clearly separate major silhouettes and retain generous safe margins. ${transparent?'Real transparent background and one isolated complete object.':'A complete fixed-view room/environment illustration; rear-wall depth only, no top-down/isometric alternative view.'}`,useKo,motion,aspect,transparent,'png',['facility-style']));
}
const roomQueue=[];
for(const [slug,name,props,propsKo] of roomTypes) for(let stage=0;stage<4;stage++) roomQueue.push({slug,name,props,propsKo,stage});
function writeRoom(r){const s=roomStages[r.stage];addFacility(`${r.name} · ${s[0]}형`,`room/${r.slug}`,`Strict FRONT CUTAWAY view of a 2:1 wide room. The room contains ${r.props}. Structural stage ${r.stage+1}: ${s[1]}. The front 20 percent is an unobstructed continuous staff walking strip, all machines and furniture stand behind it; no front walls, pillars or floating text obscure this area.`,`${r.propsKo}를 사용하는 ${s[2]}의 정면 단면 방. 단계마다 공간 구조가 달라짐.`,`길드 방 배경 · 시각 단계 ${r.stage+1}`);}
function writeEquipment(e){addFacility(e[1],`equipment/${e[0]}`,`A single isolated three-quarter front-view machine: ${e[2]}. Keep the broad low base stable, controls blank, no detached background scenery.`,`${e[3]}용 독립 설비. 방 배경과 조합할 수 있는 단일 장비.`,e[3],[1,1],true,'indicator-pulse');}
writeRoom(roomQueue.shift());
writeEquipment(equipment[0]);
for(const r of roomQueue)writeRoom(r);
for(const e of equipment.slice(1))writeEquipment(e);
const exteriors=[
 ['dispatch-annex','서울 출동 별관','a small navy civic annex with an offset mint glass entrance, low rooftop receiver and broad ivory awning','출동 거점'],
 ['canal-lab','수로 연구동','a silver laboratory block with stepped teal window bays, a tall narrow rooftop condenser and low canal-side railing','연구 거점'],
 ['cargo-hangar','회수 화물동','a squat orange-gray loading hangar with two unequal roll-up doors, one navy crane rail and ivory parcel platforms','회수 거점'],
 ['rooftop-observatory','옥상 관측동','a low cedar-and-navy rooftop building with a single split silver telescope dome and exposed mint receiver fins','관측 거점'],
 ['guild-clinic','생환 진료동','an ivory two-storey clinic with lime frosted windows, a recessed porch and purple crystal condenser chimney','생환 거점'],
 ['industrial-workshop','도심 공방동','a charcoal brick workshop with asymmetrical sawtooth roof, copper exhaust stack and two broad amber work windows','공방 거점'],
 ['archive-vault','기록 금고동','a thick navy stepped archive building with narrow ivory slit windows and a circular brass door mechanism','보관 거점'],
 ['expedition-depot','탐험 보급동','a teal concrete depot with three stepped locker wings, one orange folding gate and a large cream route antenna','탐험 거점']
];
for(const e of exteriors)addFacility(e[1],`exterior/${e[0]}`,`A single isolated front three-quarter exterior building: ${e[2]}. Modern fictional Seoul urban-fantasy architecture, readable entrance and rooftop silhouette, no adjacent street or people.`,`${e[3]}의 외관 후보. 정면 단면 방과 별도 원화.`,e[3],[1,1],true);
const states=[
 ['empty','빈 방 구조','an entirely empty ivory 2:1 frontal room interior with only navy rear service sockets, simple bare walls and a completely clear foreground floor. The painted rear wall, side walls, ceiling and floor fill the entire rectangular image edge to edge; there is no space outside the room and no isolated outer frame. No checkerboard pattern, cutout backdrop, shelves, cabinets, tools, workbench, tanks or loose equipment'],
 ['construction','공사 비계','an open 2:1 transparent overlay of silver back-wall scaffolds, two amber support struts and stacked flat boards kept away from the front walking strip'],
 ['sealed','봉인된 방','a 2:1 navy closed back-wall service gate with two copper diagonal locking bars and pale dust along the upper seam'],
 ['repair','설비 수리','an open 2:1 transparent overlay of one low silver repair stand, two loose charcoal conduit coils and a small orange tool tray at the rear'],
 ['decontamination','시약 정화','a sparse OPEN 2:1 transparent state overlay consisting ONLY of three small ivory disinfectant nozzle heads on one narrow navy horizontal crossbar in the upper third, two short lime containment strips at the left and right upper corners, and wispy translucent vapor confined to the upper quarter. At least the bottom 70 percent and most central space remain empty transparent pixels. No booth, room, rear wall, floor, platform, large side pillars, enclosing frame or full-width panel; no architecture behind the nozzle heads'],
 ['renovation','방 증설','an open 2:1 transparent overlay of stacked ivory wall panels and a compact navy rear crane, leaving the entire front strip clear'],
 ['completed','완료 장식','a sparse 2:1 transparent overlay consisting ONLY of two small matte brass corner caps at the far upper left and upper right, with short pearl streamers and ivory fabric ribbons hanging beside each cap. The middle 65 percent and the entire lower 70 percent are completely empty transparent pixels. No badges, labels, room, architecture, wall, floor, stage, furniture, instruments, enclosing frame or central object'],
 ['overload','마력 과부하','a sparse 2:1 transparent overlay consisting ONLY of two small isolated ivory broken corner fragments at the far upper left and upper right, purple mana fissures across each fragment, one disconnected teal elbow pipe joint at each corner, and a few white sparks. The middle 65 percent and the entire lower 70 percent remain completely empty transparent pixels. No rear wall connecting the corners, room, architecture, floor, platform, large frame, reactor, tanks or central machinery']
];
for(const [slug,name,shape] of states)addFacility(name,`state/${slug}`,shape,`모든 시설 방에 재사용 가능한 ${name} 상태 원화. 직원 영역을 가리지 않음.`,`시설 상태 후보`,[2,1],slug!=='empty'&&slug!=='sealed',slug==='overload'?'flicker':'none');

const currencyFamilies=[
 ['construction','차세대 건축재','blue-gray load-bearing alloy','rivets, broad bolted edges and a restrained amber enamel insert','금속 계열 · 건설·증축·금속 가공'],
 ['electronic','차세대 전자재','teal printed ceramic and gold contacts','sparse raised circuit paths and navy chip sockets','전자 계열 · 제어 장치·회로 연구·정밀 장비'],
 ['catalyst','정제 촉매','violet mineral and frosted laboratory glass','faceted powder clusters and silver sealed edges','마력 계열 · 마력 정제·촉매 제조·생환석 제작'],
 ['biological','의료 시약','lime reagent and ivory medical polymer','translucent liquid compartments and pale sealing collars','생체 계열 · 생환·직원 교육·생체 분석'],
 ['logistics','탐험 보급재','saffron canvas and graphite composite','stitched ridges, broad buckles and blue route tabs','탐험 계열 · 탐험 준비·원정 보급·운송 장비'],
 ['archive','기록 매체','cedar, ivory paper and bronze','clean layered edges, geometric seal impressions and navy binding bands','연구 계열 · 연구 기록·분석 자료·조합법 보관'],
 ['energy','동력 축전재','cyan luminous resin and dark brushed metal','thick heat-sink ribs and copper power terminals','동력 계열 · 시설 가동·축전 장치·생산 동력'],
 ['ritual','의식 재료','mint jade, braided flax and matte gold','rounded engraved cavities and black cord joins','각성 계열 · 각성 의식·축복 공명·옵션 분석'],
 ['survey','관측 매체','smoky indigo optical glass and silver','clear beveled apertures and subtle plum polarization seams','증표 계열 · 게이트 관측 인증 기록·지역 조사 완료 증표'],
 ['salvage','이계 회수재','rust-red alien stone and gunmetal','asymmetric worn facets, pale cracks and teal embedded residues','유물 계열 · 이계 유물 회수·감정·복원']
];
const currencySearchTags={construction:['금속','합금','건축'],electronic:['전자','회로','제어'],catalyst:['마력','촉매','정제'],biological:['생체','시약','의료'],logistics:['탐험','보급','운송'],archive:['연구','자료','기록'],energy:['동력','축전','생산'],ritual:['각성','의식','축복'],survey:['증표','관측 인증','광학 기록'],salvage:['유물','이계 회수','감정']};
const currencyForms=[
 ['solid','괴','a single asymmetrical trapezoid block with one deeply notched corner and a short stepped underside','단일 굵은 괴'],
 ['coil','권선','a thick open spiral coil standing diagonally with one flat inner tail and broad separated turns','비어 있는 나선 코일'],
 ['plate','분절판','three unequal flat plates joined into a shallow zigzag bundle, the upper plate has a large round cutout','절단면이 다른 판 세 장'],
 ['capsule','캡슐','a short double-chamber capsule with one domed cap, a broad vertical center bridge and a small side lug','두 구획 캡슐'],
 ['shard','파편','five unlike chunky shards in a tight pile, including one crescent, one fork and one thick hexagonal chip','크고 서로 다른 파편 묶음'],
 ['canister','용기','a squat hexagonal canister with an offset handle, one broad flat window and a thick rectangular locking cap','육각 낮은 용기'],
 ['module','모듈','a wide U-shaped compact module surrounding a suspended round center, with three unequal lower contact tabs','중앙이 빈 U자 모듈'],
 ['roll','묶음','a pair of unequal short rolled sleeves tied by one broad clasp, with visibly different open end cross-sections','단면이 다른 짧은 두 묶음']
];
let currencyNumber=0;
for(const [slug,name,material,detail,use]of currencyFamilies)for(const [formSlug,formKo,shape,shapeKo]of currencyForms){
 const id=`currency-${pad(++currencyNumber)}`;
 entries.push(common(id,'currency',`${name} · ${formKo}`,slug,['미래 재화',slug,formSlug,...currencySearchTags[slug],use],`${shapeKo}에 ${name}의 고유 재질을 적용한 미래 재료 후보.`, `ONE transparent isolated inventory icon for Seoul Hero: ${shape}. Material identity is ${material}, with ${detail}. Build the silhouette from this physical material rather than recoloring a generic coin or gem. Three-quarter view, upper-left soft lighting, chunky painted edges, simplified large surfaces that read at 32 px, equal clear margin, no floor shadow, backdrop, frame, text, numbers, logos, rarity badge or glow cloud. SINGLE complete object group, not a sheet.`,`${use}의 재료 후보 · 현행 지갑/가격/보상에 미연결`,'none',[1,1],true,'png',['currency-style']));
}

const byId=new Map(entries.map(entry=>[entry.id,entry]));
import {buildContextLayers} from '../tools/recipe-context.mjs';
const recipes=[];
const ease=(t,x,y,scale,rotation,opacity,easing='easeOutCubic')=>({t,x,y,scale,rotation,opacity,easing});
const rounded=n=>Math.round(n*1000)/1000;
function recipeFamily(family,count,offset,span,context,baseDuration,loop=false){
 for(let i=0;i<count;i++){
  const duration=rounded(baseDuration+(i%5)*0.08);
  const name={upgrade:'강화',open:'개봉',acquire:'획득·해금',facility:'시설 작동'}[family];
  const r={id:`${family}-${pad(i+1)}`,nameKo:`${name} · ${['응축 후 확산','상승 후 정착','엇갈린 결속','주변 파편','완만한 잔광'][i%5]} ${Math.floor(i/5)+1}`,family,duration,loop,canvas:[915,412],anchor:[457.5,206],context,keyframeTime:'relative-to-layer-start',rotationUnit:'degrees',positionUnit:'px-offset-from-anchor',layers:[]};
  const layerCount=3+(i%3);
  for(let j=0;j<layerCount;j++){
   const number=offset+1+((i*3+j*11)%span);
   const assetId=`effect-${pad(number)}`;
   const asset=byId.get(assetId);
   const plannedStart=j===0?0:j===1?duration*0.16:j===2?duration*0.30:duration*(0.36+j*0.055);
   const start=rounded(asset.format==='sequence8'?Math.min(plannedStart,duration-0.667):plannedStart);
   const end=asset.format==='sequence8'?rounded(start+0.667):rounded(j===0?duration*0.70:duration);
   const life=rounded(end-start);
   const side=(i+j)%2===0?1:-1;
   const x=j===0?0:side*(10+j*6);
   const y=j===1?-14:j===2?8:j>=3?-22:0;
   const layer={assetId,start,end,z:j,blend:j===0?'normal':'add',keyframes:[ease(0,x,y,0.25,side*-8,0,'linear'),ease(rounded(life*0.23),x*0.4,y*0.5,0.62,side*-3,0.48),ease(rounded(life*0.48),0,j===1?-22:0,1+0.05*(i%3),side*6,0.88),ease(rounded(life*0.78),side*(j*8),y-12,1.17,side*12,0.30,'easeInOutSine'),ease(life,side*(j*12),y-22,1.23,side*15,0,'easeInQuad')]};
   layer.displaySize=256;
   if(asset.format==='sequence8')Object.assign(layer,{fps:12,frameCount:8,frameLoop:false});
   r.layers.push(layer);
  }
  r.contextLayers=buildContextLayers(r);
  recipes.push(r);
 }
}
recipeFamily('upgrade',30,0,60,'upgrade',1.2);
recipeFamily('open',30,60,60,'opening',1.3);
recipeFamily('acquire',10,120,40,'none',0.9);
recipeFamily('facility',10,200,40,'none',2.4,true);

fs.mkdirSync(folder,{recursive:true});
fs.writeFileSync(path.join(folder,'additional.json'),JSON.stringify(entries,null,2)+'\n');
fs.writeFileSync(path.join(folder,'recipes.json'),JSON.stringify(recipes,null,2)+'\n');
console.log(JSON.stringify({assets:entries.length,effects:entries.filter(e=>e.category==='effect').length,sequence8:entries.filter(e=>e.format==='sequence8').length,facilities:entries.filter(e=>e.category==='facility').length,currencies:entries.filter(e=>e.category==='currency').length,recipes:recipes.length,facilityTypes:Object.fromEntries(['room','equipment','exterior','state'].map(type=>[type,entries.filter(e=>e.category==='facility'&&e.family.startsWith(type+'/')).length]))}));
