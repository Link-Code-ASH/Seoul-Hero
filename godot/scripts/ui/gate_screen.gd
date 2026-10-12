class_name HeroGateScreen
extends RefCounted

const STARTER_ORDER := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard","manaShotgun"]
const TITLES := ["맵 선택","층 선택","각성자 선택","시작 무기 선택","단군의 축복 선택","편성 확인"]
const SUBTITLES := ["서울에서 진행할 작전 구역을 고르세요.","높은 층일수록 침식체가 강해집니다.","함께 서울의 게이트로 들어갈 각성자를 고르세요.","선택한 무기 1종으로 시작합니다. 전투 보유 한도는 6종입니다.","이번 작전에 적용할 축복을 하나 고르세요.","선택한 구역과 편성을 확인하고 출동하세요."]
const STAT_NAMES := HeroUI.STAT_NAMES
const DEPTH_PAGE := 20
const RATIO_STATS := ["damage","attackSpeed","meleeDamage","rangedDamage","criticalChance","criticalDamage","range","area","duration","projectileSpeed","dodge","lifesteal","currencyGain"]

# Office desk layout (915x412). Header owns y 0..56; every screen leaves y 344..406 to the
# footer slip and the orange deploy key. plain_paper.png carries transparent margins
# (25px sides, 18px top/bottom at the kit's 0.5 scale), so content insets below include them.
const FOOTER_SLIP := Rect2(8,344,694,62)
const FOOTER_TEXT := Rect2(34,355,644,40)
const PRIMARY_KEY := Rect2(711,350,180,46)
const SLIP_SCALE := 0.25 # small index-card paper: 12.5px side / 9px top-bottom transparent margin
const PAPER_INSET := Vector4(37,31,37,30) # paper(): visible edge + 12px padding (left, top, right, bottom)

# Inspection and scroll offsets belong to the transient UI, never the run setup.
static func build(draft: Dictionary, step: int, change: Callable, navigate: Callable, deploy: Callable, ui_state: Dictionary = {}) -> Control:
	if not ui_state.has("inspected"): ui_state.inspected = {}
	if not ui_state.has("scroll"): ui_state.scroll = {}
	var root := HeroImageSkin.root()
	_background(root)
	_header(root,step,navigate)
	match step:
		0: _maps(root,draft,change,navigate,ui_state)
		1: _depths(root,draft,change,navigate)
		2: _selection(root,"character",draft,change,navigate,ui_state)
		3: _selection(root,"weapon",draft,change,navigate,ui_state)
		4: _selection(root,"blessing",draft,change,navigate,ui_state)
		5: _formation(root,draft,navigate,deploy)
	if HeroDesk.presentation: _presentation_progress(root,step)
	return root

static func _background(parent: Control) -> void:
	HeroDesk.backdrop(parent,"gate" if HeroDesk.presentation else "")

static func _header(root: Control, step: int, navigate: Callable) -> void:
	HeroDesk.header(root,TITLES[step],func(): navigate.call(-1),"이전","%02d / 06" % [step+1])
	if HeroDesk.presentation: return
	HeroDesk.text(root,SUBTITLES[step],Rect2(120,46,660,20),"body",13,HeroDesk.BODY).name = "GateSubtitle"

# Office profiles place content below the shared 56px header without scaling native text.
static func _body_rect(rect: Rect2) -> Rect2:
	if not HeroDesk.presentation: return rect
	var ratio := 268.0/290.0
	return Rect2(rect.position.x,72.0+(rect.position.y-56.0)*ratio,rect.size.x,rect.size.y*ratio)

static func _touch_body_rect(rect: Rect2) -> Rect2:
	var placed := _body_rect(rect)
	if HeroDesk.presentation:
		placed.size.x = maxf(44.0,placed.size.x)
		placed.size.y = maxf(44.0,placed.size.y)
	return placed

static func _surface(parent: Node, rect: Rect2, node_name: String) -> Control:
	return HeroDesk.panel(parent,rect,node_name) if HeroDesk.presentation else HeroDesk.paper(parent,rect,node_name)

static func _presentation_progress(root: Control, step: int) -> void:
	var captions := ["맵","층","각성자","무기","축복","편성"]
	for index in range(captions.size()):
		var color := HeroDesk.accent(root) if index == step else HeroDesk.INK if index < step else HeroDesk.MUTED
		var label := HeroDesk.text(root,"%02d %s" % [index+1,captions[index]],Rect2(26+index*110,366,104,18),"control",12,color,HORIZONTAL_ALIGNMENT_CENTER)
		label.name = "GateProgress_%d" % index

# --- Desk pieces ----------------------------------------------------------------

# A small index-card slip of plain paper (the kit's paper at a smaller art scale).
static func _slip(parent: Node, rect: Rect2, node_name: String = "GateSlip") -> Control:
	if HeroDesk.presentation: return HeroDesk.panel(parent,rect,node_name)
	HeroDesk.shadow(parent,Rect2(rect.position+Vector2(14,10),rect.size-Vector2(28,20)),4.0,0.32)
	var holder := Control.new()
	holder.name = node_name
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	HeroDesk.nine(holder,HeroDesk.OFFICE+"paper_plain.png",Rect2(Vector2.ZERO,rect.size),Vector4(48,48,48,48),SLIP_SCALE).name = "SlipArt"
	return holder

# A strip of tape laid across a point, rotated.
static func _tape(parent: Node, center: Vector2, width: float, angle_degrees: float) -> Control:
	var tape_size := Vector2(width,width*40.0/140.0)
	var holder := Control.new()
	holder.name = "GateTape"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,Rect2(center-tape_size*0.5,tape_size))
	holder.pivot_offset = tape_size*0.5
	holder.rotation = deg_to_rad(angle_degrees)
	HeroDesk.art(holder,HeroDesk.ART+"tape_strip.png",Rect2(Vector2.ZERO,tape_size))
	return holder

# A printed photo lying on paper, held by tape across both top corners.
static func _pinned_photo(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	HeroDesk.shadow(parent,rect,3.0,0.3)
	var photo := HeroUI.fixed_art(parent,texture,rect)
	photo.name = "GateMapPhoto"
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.clip_contents = true
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if HeroDesk.presentation:
		_tape(parent,rect.position+Vector2(12,12),44.0,-24.0)
		_tape(parent,Vector2(rect.end.x-12,rect.position.y+12),44.0,24.0)
	else:
		_tape(parent,rect.position+Vector2(6,4),84.0,-36.0)
		_tape(parent,Vector2(rect.end.x-6,rect.position.y+4),84.0,36.0)
	return photo

# A small square polaroid (photo_frame.png, 220x250) with a picture in its window.
static func _snapshot(parent: Node, texture: Texture2D, rect: Rect2, angle_degrees: float = 0.0) -> TextureRect:
	var holder := Control.new()
	holder.name = "GateSnapshot"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	holder.pivot_offset = rect.size*0.5
	holder.rotation = deg_to_rad(angle_degrees)
	HeroDesk.shadow(holder,Rect2(Vector2(3,3),rect.size-Vector2(6,6)),3.0,0.3)
	HeroDesk.art(holder,HeroDesk.ART+"photo_frame.png",Rect2(Vector2.ZERO,rect.size))
	if texture == null: return null
	var k := rect.size.x/220.0
	var window := Rect2(Vector2(37,34)*k,Vector2(147,144)*k)
	var picture := HeroUI.fixed_art(holder,texture,window.grow(-1))
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return picture

# A scrolling text column inside a paper piece, kept 12px inside the visible paper edge.
static func _paper_column(paper: Control, inset: Vector4, state: Dictionary = {}, key: String = "") -> VBoxContainer:
	var scroll := HeroImageSkin.scroll(paper,Rect2(inset.x,inset.y,paper.size.x-inset.x-inset.z,paper.size.y-inset.y-inset.w),state,key)
	HeroDesk.scrollbar(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(column)
	return column

static func _footer_note(root: Control, caption: String, color: String = HeroDesk.INK, font_size: int = 14) -> Label:
	_slip(root,Rect2(12,348,690,54) if HeroDesk.presentation else FOOTER_SLIP,"GateFooterSlip")
	if HeroDesk.presentation: return null
	var note := HeroDesk.text(root,caption,FOOTER_TEXT,"body",font_size,color,HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	note.name = "GateFooterText"
	return note

static func _primary(root: Control, caption: String, action: Callable) -> Button:
	var target := HeroDesk.key(root,caption,Rect2(716,352,180,46) if HeroDesk.presentation else PRIMARY_KEY,action,"orange",17,"brand")
	target.name = "GatePrimary"
	return target

static func _footer(root: Control, caption: String, next_caption: String, action: Callable, reason: String = "") -> void:
	_footer_note(root,caption if reason.is_empty() else reason,HeroDesk.INK if reason.is_empty() else HeroDesk.DANGER)
	var target := _primary(root,next_caption,action)
	target.disabled = not reason.is_empty()

# --- 01 맵 선택 --------------------------------------------------------------------

static func _maps(root: Control, draft: Dictionary, change: Callable, navigate: Callable, ui_state: Dictionary) -> void:
	var ids: Array = Content.data.maps.keys()
	var chosen: Dictionary = Content.data.maps[draft.map]
	var tabs := ids.size() > 1
	# Left: the area photo taped onto a sheet of paper.
	_surface(root,_body_rect(Rect2(8,56,516,166 if tabs else 212)),"GateMapPaper")
	if HeroDesk.presentation: HeroDesk.text(root,"작전 구역",Rect2(26,78,460,24),"heading",16,HeroDesk.accent(root)).name = "GateMapSection"
	var photo_rect := _body_rect(Rect2(46,87,440,105 if tabs else 151))
	_pinned_photo(root,_map_texture(draft.map),photo_rect)
	if tabs:
		var selector := HeroImageSkin.scroll(root,_touch_body_rect(Rect2(16,212,500,46)),ui_state.scroll,"map")
		selector.name = "GateMapTabs"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		selector.add_child(row)
		for map_id in ids:
			var id: String = str(map_id)
			var unlocked: bool = id in Profile.meta.account.unlockedMapIds
			var choice := HeroDesk.key(row,str(Content.data.maps[id].name),Rect2(0,0,156,44 if HeroDesk.presentation else 40),func(): change.call("map",id),"navy" if draft.map == id else "cream",15)
			choice.name = "GateMap_"+id
			choice.disabled = not unlocked
	_appearances(root,draft,_body_rect(Rect2(8,262,516,84)))
	# Right: the area brief on its own sheet, clipped at the top.
	var brief := _surface(root,_body_rect(Rect2(530,56,378,290)),"GateMapBrief")
	if not HeroDesk.presentation: HeroDesk.art(root,HeroDesk.ART+"clip_paper.png",Rect2(856,46,19,44)).name = "GateMapClip"
	var detail := _paper_column(brief,Vector4(20,16,20,16) if HeroDesk.presentation else PAPER_INSET)
	_copy(detail,str(chosen.name),"brand",22,HeroDesk.INK)
	_copy(detail,"%d 웨이브 · 마지막 보스 전투" % int(chosen.totalWaves),"body",14,HeroDesk.ACCENT)
	_copy(detail,str(chosen.description),"body",14,HeroDesk.BODY)
	_copy(detail,"모든 지형을 이동할 수 있습니다.","body",14,HeroDesk.BODY)
	_weekly(detail,draft)
	_footer(root,"현재 구역 · "+str(chosen.name),"층 선택",func(): navigate.call(1))

# 이번 주 몬스터: the one monster that leads six Waves on every map until Sunday 05:00.
# An index card on the desk with the monster's snapshot clipped to it.
static func _appearances(root: Control, draft: Dictionary, rect: Rect2) -> void:
	var id := HeroRoster.weekly_monster(Content.data,int(draft.get("week",-1)))
	if id.is_empty(): return
	var definition: Dictionary = Content.data.enemies[id]
	var strip := _slip(root,rect,"WeeklyAppearances")
	var art := _snapshot(strip,Content.actor_preview("enemies",id,definition.visual.sprite),Rect2(24,11,54,61),-4.0)
	if art != null:
		art.name = "WeeklyAppearance_0"
		art.set_meta("content_id",id)
	var top := 21.0
	HeroDesk.text(strip,"이번 주 몬스터",Rect2(92,top,116,22),"heading",15,HeroDesk.ACCENT).name = "WeeklyTitle"
	HeroDesk.text(strip,"일요일 05:00 교체",Rect2(92,top+24,116,18),"body",12,HeroDesk.MUTED)
	HeroDesk.text(strip,str(definition.name),Rect2(214,top,140,22),"heading",HeroDesk.fit(str(definition.name),"heading",15,140.0,11),HeroDesk.INK).name = "WeeklyName"
	HeroDesk.text(strip,str(HeroArchive.BEHAVIORS.get(definition.behavior,definition.behavior)),Rect2(214,top+24,140,18),"body",12,HeroDesk.BODY)
	var waves: Array = Content.data.weeklyMonster.waves.map(func(number): return str(int(number)))
	HeroDesk.text(strip,"웨이브 %s\n선두로 출현" % "·".join(waves),Rect2(358,top-2,128,46),"body",12,HeroDesk.INK,HORIZONTAL_ALIGNMENT_RIGHT,true,{"valign":VERTICAL_ALIGNMENT_CENTER}).name = "WeeklyWaves"

# --- 02 층 선택 ---------------------------------------------------------------------

# Twenty depths per page; the page always follows the chosen depth.
# Each depth is a chunky index-card key: cream when open, navy when chosen, faded when locked.
static func _depths(root: Control, draft: Dictionary, change: Callable, navigate: Callable) -> void:
	var progress: Dictionary = Profile.meta.gateProgression.characters.get(draft.character,{})
	var highest := int(Profile.meta.gateProgression.highestUnlockedDepth)
	var first := floori((int(draft.depth)-1)/float(DEPTH_PAGE))*DEPTH_PAGE+1
	var last_first := floori((highest-1)/float(DEPTH_PAGE))*DEPTH_PAGE+1
	if HeroDesk.presentation: HeroDesk.panel(root,_body_rect(Rect2(8,56,900,212)),"GateDepthPanel")
	for index in range(DEPTH_PAGE):
		var depth := first+index
		var x := 18.0+float(index%10)*88.0
		var y := 66.0+floorf(index/10.0)*102.0
		var locked := depth > highest
		var cleared := depth <= int(progress.get("highestClearedDepth",0))
		var selected := depth == int(draft.depth)
		var target := HeroDesk.key(root,"",_body_rect(Rect2(x,y,82,96)),func(): change.call("depth",depth),"navy" if selected else "cream")
		target.name = "GateDepth_%d" % depth
		target.disabled = locked
		var face := target.get_node("Face") as Control
		var number := "%02d" % depth
		var number_color := HeroDesk.ON_DARK if selected else HeroDesk.MUTED if locked else HeroDesk.INK
		HeroDesk.text(face,number,Rect2(5,6,72,44),"number",HeroDesk.fit(number,"number",34 if depth < 1000 else 26,70.0,16),number_color,HORIZONTAL_ALIGNMENT_CENTER).name = "DepthNumber"
		var best := int(progress.get("bestWaveByDepth",{}).get(str(depth),0))
		var status := "선택" if selected else "잠금" if locked else "클리어" if cleared else "도전" if best == 0 else "%d/20" % best
		var status_color := HeroDesk.ON_DARK if selected else HeroDesk.MUTED if locked else HeroDesk.REWARD if cleared else HeroDesk.BODY
		HeroDesk.text(face,status,Rect2(5,52,72,24),"control",13,status_color,HORIZONTAL_ALIGNMENT_CENTER).name = "DepthStatus"
	var paged := last_first > 1
	var difficulty := HeroStats.difficulty(Content.data,int(draft.depth),Content.data.maps[draft.map],draft.weekly)
	var info := _slip(root,_body_rect(Rect2(8,270,536 if paged else 900,70)),"GateDepthInfo")
	HeroDesk.text(info,"%d층" % int(draft.depth),Rect2(26,14,104,42),"brand",HeroDesk.fit("%d층" % int(draft.depth),"brand",22,104.0,14),HeroDesk.INK).name = "DepthChosen"
	HeroDesk.text(info,"적 체력 ×%.2f  피해 ×%.3f  생성 ×%.2f" % [difficulty.hp,difficulty.damage,difficulty.spawn],Rect2(134,14,(536 if paged else 900)-134-26,42),"body",14,HeroDesk.BODY).name = "DepthDifficulty"
	if paged:
		# Shown only once depth 21 is unlocked; earlier profiles keep the single page.
		var previous := HeroDesk.key(root,"이전",_touch_body_rect(Rect2(552,282,64,44)),func(): change.call("depth",first-1),"cream",14)
		previous.name = "DepthPagePrevious"; previous.disabled = first <= 1
		HeroDesk.text(root,"%d–%d" % [first,first+DEPTH_PAGE-1],_body_rect(Rect2(618,282,80,38)),"number",HeroDesk.fit("%d–%d" % [first,first+DEPTH_PAGE-1],"number",18,78.0,11),HeroDesk.INK,HORIZONTAL_ALIGNMENT_CENTER).name = "DepthPageRange"
		var following := HeroDesk.key(root,"다음",_touch_body_rect(Rect2(700,282,64,44)),func(): change.call("depth",first+DEPTH_PAGE),"cream",14)
		following.name = "DepthPageNext"; following.disabled = first >= last_first
		var top := HeroDesk.key(root,"최고 %d" % highest,_touch_body_rect(Rect2(772,282,128,44)),func(): change.call("depth",highest),"cream",14)
		top.name = "DepthHighest"; top.disabled = int(draft.depth) == highest
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	_footer_note(root,str(weekly.get("name",""))+" · "+str(weekly.get("penaltyLabel","")),HeroDesk.BODY,13)
	_primary(root,"각성자 선택",func(): navigate.call(2))

# --- 03-05 각성자 / 무기 / 축복 ------------------------------------------------------

# Choices are polaroids in an open folder; the inspected one is written up on a sheet.
static func _selection(root: Control, kind: String, draft: Dictionary, change: Callable, navigate: Callable, ui_state: Dictionary) -> void:
	var ids := _ids(kind,draft)
	var inspected: String = str(ui_state.inspected.get(kind,draft[kind]))
	if inspected not in ids: inspected = str(draft[kind])
	if HeroDesk.presentation:
		HeroDesk.panel(root,_body_rect(Rect2(8,56,560,290)),"GateSelectionFolder")
		HeroDesk.text(root,{"character":"각성자 기록","weapon":"시작 장비","blessing":"단군의 축복"}[kind],Rect2(28,82,520,26),"heading",18,HeroDesk.accent(root)).name = "GateSelectionHeading"
	else:
		HeroDesk.folder(root,Rect2(8,56,560,290),"GateSelectionFolder")
	var scroll := HeroImageSkin.scroll(root,_body_rect(Rect2(30,108,526,226)),ui_state.scroll,kind)
	scroll.name = "GateSelectionScroll"
	HeroDesk.scrollbar(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.add_child(grid)
	for entry in ids:
		var id: String = str(entry)
		var locked := not _unlocked(kind,id,draft)
		var pick := func():
			change.call("uiInspect",{"kind":kind,"id":id})
			if not locked: change.call(kind,id)
		var target := HeroDesk.polaroid(grid,_texture(kind,id),_name(kind,id),id == str(draft[kind]),pick,locked)
		target.name = "GateChoice_"+id
		target.set_meta("content_id",id)
		target.set_meta("choice_kind",kind)
		if kind == "blessing" and not id.is_empty():
			var tag := "미해금" if locked else ("Lv.%d" % int(Profile.meta.blessings[id].level) if Content.enabled("blessingLevels") else "")
			if not tag.is_empty(): _card_tag(target,tag,locked)
	_selection_detail(root,_body_rect(Rect2(572,56,336,290)),kind,inspected,draft,ui_state)
	var labels := {"character":"시작 무기 선택","weapon":"단군의 축복 선택","blessing":"편성 확인"}
	var steps := {"character":3,"weapon":4,"blessing":5}
	var reason := "" if _unlocked(kind,inspected,draft) else _lock_reason(kind,inspected,draft)
	_footer(root,"현재 선택 · "+_name(kind,str(draft[kind])),str(labels[kind]),func(): navigate.call(steps[kind]),reason)

# Blessing level (or 미해금) on a strip of tape across the top of its polaroid.
static func _card_tag(card: Control, caption: String, locked: bool) -> void:
	var holder := Control.new()
	holder.name = "GateChoiceTag"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(holder); HeroUI.place(holder,Rect2(14,0,48,16))
	holder.pivot_offset = Vector2(24,8)
	holder.rotation = deg_to_rad(-3.0)
	HeroDesk.art(holder,HeroDesk.ART+"tape_strip.png",Rect2(-2,-3,52,22))
	HeroDesk.text(holder,caption,Rect2(0,0,48,16),"control",HeroDesk.fit(caption,"control",11,46.0,11),HeroDesk.MUTED if locked else HeroDesk.INK,HORIZONTAL_ALIGNMENT_CENTER).name = "GateChoiceTagText"

static func _selection_detail(root: Control, rect: Rect2, kind: String, id: String, draft: Dictionary, ui_state: Dictionary) -> void:
	var panel := _surface(root,rect,"GateSelectionPanel")
	# Content box: 12px inside the visible paper edge.
	var inset := Vector4(20,16,20,16) if HeroDesk.presentation else PAPER_INSET
	var content := Rect2(inset.x,inset.y,rect.size.x-inset.x-inset.z,rect.size.y-inset.y-inset.w)
	var title := _name(kind,id)
	var title_label := HeroDesk.text(panel,title,Rect2(content.position,Vector2(content.size.x,28)),"brand",HeroDesk.fit(title,"brand",22,content.size.x,14),HeroDesk.INK)
	title_label.name = "GateDetailTitle"
	var texture := _texture(kind,id)
	var frame_size := Vector2(76,97)
	var copy_width := content.size.x - 88 if texture != null else content.size.x
	var core := _profile_core(kind,id)
	var copy_height := 0.0
	for line in core:
		copy_height += _text_height(str(line.text),copy_width,str(line.role),int(line.size))
	copy_height += 6 * maxi(0,core.size()-1)
	var profile_height := maxf(frame_size.y if texture != null else 0.0,copy_height)
	var profile_position := content.position + Vector2(0,36)
	if texture != null:
		# The inspected entry as a clipped photo, like the archive's personnel sheet.
		HeroDesk.shadow(panel,Rect2(profile_position+Vector2(4,4),frame_size-Vector2(8,7)),4.0,0.32)
		HeroDesk.art(panel,HeroDesk.ART+"photo_frame_tall.png",Rect2(profile_position,frame_size)).name = "GateDetailFrame"
		var art := HeroUI.fixed_art(panel,texture,Rect2(profile_position+Vector2(12,11),Vector2(53,53)).grow(-2))
		art.name = "GateDetailArt"
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if not _unlocked(kind,id,draft): art.modulate = Color(0.35,0.37,0.42,0.75)
		HeroDesk.art(panel,HeroDesk.ART+"clip_paper.png",Rect2(profile_position.x+52,profile_position.y-12,19,44)).name = "GateDetailClip"
	var profile := VBoxContainer.new()
	profile.name = "GateSelectionProfile_"+kind
	profile.position = profile_position + Vector2(88 if texture != null else 0,0)
	profile.size = Vector2(copy_width,profile_height)
	profile.custom_minimum_size.x = copy_width
	profile.add_theme_constant_override("separation",6)
	profile.alignment = BoxContainer.ALIGNMENT_CENTER
	profile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(profile)
	for line in core:
		var label := _copy(profile,str(line.text),str(line.role),int(line.size),str(line.color))
		label.custom_minimum_size = Vector2(copy_width,_text_height(str(line.text),copy_width,str(line.role),int(line.size)))
		label.set_meta("fixed_profile",true)
	var body_top := profile_position.y + profile_height + 8
	var scroll := HeroImageSkin.scroll(panel,Rect2(content.position.x,body_top,content.size.x,maxf(0.0,content.end.y-body_top)),ui_state.scroll,"detail:"+kind+":"+id)
	scroll.name = "GateDetailScroll"
	HeroDesk.scrollbar(scroll)
	var detail := VBoxContainer.new()
	detail.name = "GateSelectionDetail"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",7)
	scroll.add_child(detail)
	if not _unlocked(kind,id,draft):
		var reason := _copy(detail,_lock_reason(kind,id,draft),"body",14,HeroDesk.DANGER)
		if HeroDesk.presentation: reason.name = "GateSelectionReason"
	match kind:
		"character":
			var definition: Dictionary = Content.data.characters[id]
			_copy(detail,str(definition.description),"body",14,HeroDesk.BODY)
			_copy(detail,"기본 스탯","heading",16,HeroDesk.INK)
			for stat in definition.baseStats:
				_pair(detail,str(STAT_NAMES.get(stat,stat)),_stat_value(stat,float(definition.baseStats[stat])))
		"weapon":
			var definition: Dictionary = Content.data.weapons[id]
			_copy(detail,secondary_traits(definition.capabilities),"body",13,HeroDesk.ACCENT)
			_copy(detail,str(definition.description),"body",14,HeroDesk.BODY)
			_copy(detail,"기초 공격 · Lv.1","heading",16,HeroDesk.INK)
			var base: Dictionary = definition.base
			_pair(detail,"사거리",_number(float(base.range)))
			_pair(detail,"투사체 / 타격 수",str(int(base.projectileCount)))
			_copy(detail,"적용 스탯","heading",16,HeroDesk.INK)
			_copy(detail,applied_stats(definition.capabilities),"body",14,HeroDesk.BODY)
		"blessing":
			if id.is_empty():
				_copy(detail,"축복을 해금하면 이 목록에서 선택할 수 있습니다.","body",14,HeroDesk.BODY)
			else:
				var definition: Dictionary = Content.data.blessings[id]
				var level := HeroMeta.blessing_level(Content.data,Profile.meta.blessings.get(id,{}))
				_copy(detail,str(definition.description),"body",14,HeroDesk.BODY)
				if definition.modifiers.size() > 1:
					_copy(detail,"추가 적용 효과" if level > 0 else "해금 시 추가 효과","heading",16,HeroDesk.INK)
					for modifier in definition.modifiers.slice(1):
						_copy(detail,_modifier_text(modifier,maxi(1,level)),"body",14,HeroDesk.BODY)
				if definition.has("structureLimitAtLevel"):
					var threshold := int(definition.structureLimitAtLevel)
					_copy(detail,"Lv.%d부터 설치 한도 +1%s" % [threshold," 적용" if level >= threshold else ""],"body",14,HeroDesk.ACCENT if level >= threshold else HeroDesk.MUTED)

static func _profile_core(kind: String, id: String) -> Array:
	match kind:
		"character":
			var definition: Dictionary = Content.data.characters[id]
			return [
				{"text":str(definition.trait.name),"role":"heading","size":16,"color":HeroDesk.ACCENT},
				{"text":str(definition.trait.description),"role":"body","size":14,"color":HeroDesk.BODY}
			]
		"weapon":
			var definition: Dictionary = Content.data.weapons[id]
			return [
				{"text":primary_family(definition.capabilities)+" · Lv.1","role":"heading","size":16,"color":HeroDesk.ACCENT},
				{"text":"피해 "+_number(float(definition.base.damage)),"role":"body","size":14,"color":HeroDesk.BODY},
				{"text":"공격 간격 %.2f초" % float(definition.base.cooldown),"role":"body","size":14,"color":HeroDesk.BODY}
			]
		"blessing":
			if id.is_empty(): return [{"text":"축복을 적용하지 않고 출동합니다.","role":"body","size":14,"color":HeroDesk.BODY}]
			var definition: Dictionary = Content.data.blessings[id]
			var level := HeroMeta.blessing_level(Content.data,Profile.meta.blessings.get(id,{}))
			var status := "보유 레벨 · Lv.%d" % level if Content.enabled("blessingLevels") else ("해금 완료" if level > 0 else "미해금")
			var result: Array = [{"text":status,"role":"body","size":13,"color":HeroDesk.ACCENT if level > 0 else HeroDesk.MUTED}]
			if level == 0:
				result.append({"text":"해금 시 Lv.1 효과","role":"body","size":14,"color":HeroDesk.MUTED})
			if not definition.modifiers.is_empty():
				result.append({"text":_modifier_text(definition.modifiers[0],maxi(1,level)),"role":"body","size":14,"color":HeroDesk.BODY})
			if definition.has("weaponDamageBonus"):
				result.append({"text":"%s 무기 피해 +%s%%" % [primary_family([definition.get("weaponCapability","STRUCTURE")]),_number(float(definition.weaponDamageBonus)*100.0)],"role":"body","size":14,"color":HeroDesk.BODY})
			return result
	return []

static func _text_height(caption: String, width: float, role: String, font_size: int) -> float:
	var face: Font = HeroDesk.font(role) if HeroDesk.presentation else HeroImageSkin.font(role)
	var measured := face.get_multiline_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,width,font_size)
	var line_count := maxi(1,ceili(measured.y/face.get_height(font_size)))
	var spacing := 2 * maxi(0,line_count-1)
	return maxf(ceilf(face.get_height(font_size)*line_count)+spacing+2,ceilf(measured.y)+spacing+2)

# --- 06 편성 확인 -------------------------------------------------------------------

# One sheet like a dispatch request: the area photo taped on the left, a stamp across its
# corner, and one index card per line of the formation (each opens its step again).
static func _formation(root: Control, draft: Dictionary, navigate: Callable, deploy: Callable) -> void:
	_surface(root,_body_rect(Rect2(8,56,900,290)),"GateFormationSheet")
	var map: Dictionary = Content.data.maps[draft.map]
	_pinned_photo(root,_map_texture(draft.map),_body_rect(Rect2(48,90,300,168)))
	var map_name := "%s · %d층" % [str(map.name),int(draft.depth)] if HeroDesk.presentation else str(map.name)
	HeroDesk.text(root,map_name,_body_rect(Rect2(48,266,300,30)),"brand",HeroDesk.fit(map_name,"brand",20,300.0,14),HeroDesk.INK,HORIZONTAL_ALIGNMENT_CENTER).name = "GateFormationMap"
	HeroDesk.stamp(root,"출동",_body_rect(Rect2(298,222,62,62)),-0.2).name = "GateFormationStamp"
	var character: Dictionary = Content.data.characters[draft.character]
	_formation_row(root,_body_rect(Rect2(364,82,506,76)),_texture("character",draft.character),str(character.name),str(character.trait.description),func(): navigate.call(2),"character")
	var weapon: Dictionary = Content.data.weapons[draft.weapon]
	_formation_row(root,_body_rect(Rect2(364,158,506,76)),_texture("weapon",draft.weapon),str(weapon.name),primary_family(weapon.capabilities)+" · "+secondary_traits(weapon.capabilities),func(): navigate.call(3),"weapon")
	var blessing_id: String = str(draft.blessing)
	var blessing_name := _name("blessing",blessing_id)
	var blessing_note := "축복을 적용하지 않습니다." if blessing_id.is_empty() else ("보유 Lv.%d · 이번 작전에 적용" % int(Profile.meta.blessings[blessing_id].level) if Content.enabled("blessingLevels") else "이번 작전에 적용")
	_formation_row(root,_body_rect(Rect2(364,234,506,76)),_texture("blessing",blessing_id),blessing_name,blessing_note,func(): navigate.call(4),"blessing")
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	_footer_note(root,str(weekly.get("name",""))+" · "+str(weekly.get("penaltyLabel",""))+" · "+str(weekly.get("benefitLabel","")),HeroDesk.BODY,13)
	_primary(root,"작전 투입",deploy)

static func _formation_row(root: Control, rect: Rect2, texture: Texture2D, title: String, description: String, action: Callable, kind: String = "") -> void:
	if HeroDesk.presentation:
		var target := HeroDesk.key(root,"",rect,action,"row",16)
		target.name = "GateFormationEdit_"+kind
		var face := target.get_node("Face") as Control
		_snapshot(face,texture,Rect2(22,6,50,57),-3.0)
		var content := Rect2(86,10,rect.size.x-112,48)
		var title_label := HeroDesk.text(face,title,Rect2(content.position,Vector2(content.size.x,22)),"heading",HeroDesk.fit(title,"heading",16,content.size.x,12),HeroDesk.INK)
		var body_label := HeroDesk.text(face,description,Rect2(content.position+Vector2(0,24),Vector2(content.size.x,24)),"body",HeroDesk.fit(description,"body",13,content.size.x,11),HeroDesk.BODY,HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
		for label in [title_label,body_label]:
			label.set_meta("formation_row",rect)
			label.set_meta("formation_content",Rect2(rect.position+content.position,content.size))
		return
	var card := _slip(root,rect,"GateFormationRow")
	_snapshot(card,texture,Rect2(22,9,50,57),-3.0)
	var content := Rect2(rect.position+Vector2(86,14),Vector2(rect.size.x-86-26,48))
	var title_label := HeroDesk.text(root,title,Rect2(content.position,Vector2(content.size.x,22)),"heading",HeroDesk.fit(title,"heading",16,content.size.x,12),HeroDesk.INK)
	var body_label := HeroDesk.text(root,description,Rect2(content.position+Vector2(0,24),Vector2(content.size.x,24)),"body",HeroDesk.fit(description,"body",13,content.size.x,11),HeroDesk.BODY,HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	for label in [title_label,body_label]:
		label.set_meta("formation_row",rect)
		label.set_meta("formation_content",content)
	var target := HeroImageSkin.button(root,"",rect,action,"plain")
	target.button_down.connect(func(): card.modulate = Color(0.94,0.94,0.94))
	target.button_up.connect(func(): card.modulate = Color.WHITE)

# --- Text helpers ------------------------------------------------------------------

static func _copy(parent: Node, caption: String, role: String = "body", font_size: int = 14, color: String = HeroDesk.BODY, centered: bool = false) -> Label:
	if HeroDesk.presentation:
		var preview_label := HeroDesk.text(parent,caption,Rect2(),role,font_size,color,HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT,true)
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_label.add_theme_constant_override("line_spacing",2)
		preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return preview_label
	var label := Label.new()
	label.text = caption
	HeroImageSkin.apply_font(label,role,font_size)
	label.add_theme_color_override("font_color",HeroImageSkin.color(color))
	label.add_theme_constant_override("line_spacing",2)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func _pair(parent: Node, caption: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var name_label := _copy(row,caption,"body",14,HeroDesk.BODY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := _copy(row,value,"number",18,HeroDesk.ACCENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 70

static func _weekly(parent: Node, draft: Dictionary) -> void:
	var weekly: Dictionary = Content.data.weeklyRules.get(draft.weekly,{})
	_copy(parent,str(weekly.get("name","")),"heading",16,HeroDesk.INK)
	_copy(parent,str(weekly.get("penaltyLabel","")),"body",14,HeroDesk.DANGER)
	_copy(parent,str(weekly.get("benefitLabel","")),"body",14,HeroDesk.ACCENT)

# --- Data (unchanged) ----------------------------------------------------------------

static func _ids(kind: String, draft: Dictionary) -> Array:
	if kind == "character": return Content.data.characters.keys()
	if kind == "blessing": return [""]+Content.data.blessings.keys()
	var ids: Array = []
	var order: Array = STARTER_ORDER.duplicate()
	for id in Content.data.weapons:
		if id not in order: order.append(id)
	for id in order:
		var definition: Dictionary = Content.data.weapons.get(id,{})
		if definition.is_empty() or definition.has("structure"): continue
		# Signature-only future equipment belongs to its owner; all seven common starters remain visible.
		if definition.get("signatureOwnerId",draft.character) != draft.character: continue
		ids.append(id)
	return ids

static func _unlocked(kind: String, id: String, draft: Dictionary) -> bool:
	if kind == "blessing" and id.is_empty(): return true
	var collection: Dictionary = Profile.meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[kind]]
	if not collection.get(id,{}).get("unlocked",false): return false
	return kind != "weapon" or Content.data.weapons[id].get("signatureOwnerId",draft.character) == draft.character

static func _lock_reason(kind: String, id: String, draft: Dictionary) -> String:
	if kind == "weapon" and Content.data.weapons[id].get("signatureOwnerId",draft.character) != draft.character: return "이 각성자가 사용할 수 없는 시작 무기입니다."
	return "미해금 각성자입니다. 해금 후 선택할 수 있습니다." if kind == "character" else "미해금 무기입니다. 해금 후 선택할 수 있습니다." if kind == "weapon" else "미해금 축복입니다. 영구 성장에서 해금 후 선택할 수 있습니다."

static func _name(kind: String, id: String) -> String:
	if kind == "blessing" and id.is_empty(): return "축복 없음"
	return str(Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]][id].name)

static func _texture(kind: String, id: String) -> Texture2D:
	if kind == "blessing": return null if id.is_empty() else Content.trimmed_texture(Content.data.blessings[id].image)
	if kind == "weapon": return Content.weapon_icon(id)
	return Content.actor_preview("characters",id,Content.data.characters[id].portraitSprite)

static func _map_texture(id: String) -> Texture2D:
	return Content.texture(Content.visuals.maps.get(id,{}).get("texture",Content.data.maps[id].thumbnail))

static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value,roundf(value)) else "%.1f" % value

static func _stat_value(stat: String, value: float) -> String:
	return _number(value*100.0)+"%" if stat in RATIO_STATS else _number(value)

static func _modifier_text(modifier: Dictionary, level: int) -> String:
	var stat: String = modifier.stat
	var amount := (float(modifier.value)-1.0)*100.0*level if modifier.operation == "multiply" else float(modifier.value)*level
	var percent: bool = modifier.operation == "multiply" or stat in ["criticalChance","criticalDamage","dodge","lifesteal"]
	if modifier.operation == "add" and percent: amount *= 100.0
	return str(STAT_NAMES.get(stat,stat))+" "+("+" if amount >= 0 else "")+_number(amount)+("%" if percent else "")

static func primary_family(caps: Array) -> String:
	if "STRUCTURE" in caps: return "설치물"
	return "근접" if "MELEE" in caps else "원거리" if "RANGED" in caps else "마력"

static func secondary_traits(caps: Array) -> String:
	return capabilities(caps.filter(func(cap): return cap not in ["MELEE","RANGED","STRUCTURE"]))

static func applied_stats(caps: Array) -> String:
	var names: Array = ["공통 피해","공격 속도"]
	var links := {"MELEE":"근접 피해","RANGED":"원거리 피해","AREA":"범위","PROJECTILE":"투사체 속도","DURATION":"지속시간","HAS_RANGE":"사거리","CAN_CRIT":"치명타 확률·피해"}
	for cap in caps:
		if links.has(cap): names.append(links[cap])
	return " · ".join(names)

static func capabilities(caps: Array) -> String:
	var names := {"MELEE":"근접","RANGED":"원거리","PROJECTILE":"투사체","AREA":"범위","ORBIT":"회전","CHAIN":"연쇄","EXPLOSIVE":"폭발","PIERCING":"관통","STRUCTURE":"설치물","TURRET":"포탑","MINE":"지뢰","AURA":"마력장","TRAP":"함정","BEAM":"광선","SUMMON":"소환","DURATION":"지속","HAS_RANGE":"사거리","CAN_CRIT":"치명타"}
	var result: Array = []
	for cap in caps:
		if names.has(cap): result.append(names[cap])
	return " · ".join(result)
