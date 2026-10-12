class_name HeroArchive
extends RefCounted

const GROUPS := {"characters":"각성자","weapons":"무기","enemies":"몬스터","items":"아이템","weeklyRules":"주간 규칙","blessings":"단군의 축복"}
const STATS := HeroUI.STAT_NAMES
const MULTIPLIERS := ["damage","attackSpeed","meleeDamage","rangedDamage","range","area","duration","projectileSpeed","currencyGain"]
const PROBABILITIES := ["criticalChance","criticalDamage","dodge","lifesteal"]
const RARITIES := {"COMMON":"일반","UNCOMMON":"고급","RARE":"희귀","EPIC":"영웅","LEGENDARY":"전설"}
const BEHAVIORS := {"chase":"근거리","skirmish":"측면 추적","charge":"돌진","tank":"땅울림","ranged":"원거리","swarm":"군집 추적","bomber":"자폭","splitter":"분열","support":"지원","summoner":"소환","defender":"방어 지원","ambush":"기습","boss":"보스"}

# Bright office desk: every surface is a painted art piece; Controls only own input and text.
const ART := "res://assets/ui/office-day-01/archive/"
const OFFICE := "res://assets/ui/office-day-01/"
const INK := Color(0.141,0.224,0.361) # #24395c headings
const BODY_INK := Color(0.290,0.333,0.408) # #4a5568 body copy
const ACCENT_INK := Color(0.118,0.510,0.463) # #1e8276 values and accents
const NAVY_TINT := Color(0.17,0.26,0.40) # multiplies the cream office plate into a navy plate
const SHEET_RECT := Rect2(442,10,462,396)
const SHEET_SCALE := 0.55 # 840x720 sheet art shown at 462x396, its native proportion
const TAB_ART := {"characters":"tab_characters","weapons":"tab_weapons","enemies":"tab_enemies","items":"tab_items","weeklyRules":"tab_weekly","blessings":"tab_blessings"}
const DOCUMENTS := {"characters":"각성자 인사 기록부","weapons":"무기 지급 대장","enemies":"몬스터 현장 목격 보고서","items":"아이템 비품 목록","weeklyRules":"주간 규칙 협회 공문","blessings":"단군의 축복 고문서"}
const FOLDER_TITLES := {"characters":["인사 기록","명"],"weapons":["지급 장비","종"],"enemies":["목격 기록","건"],"items":["비품 목록","개"],"weeklyRules":["주간 공문","건"],"blessings":["고문서","점"]}
const NOTES := {"characters":"신규 각성자 모집 예정!","weapons":"무기 반납 기한 엄수!","enemies":"목격 즉시 보고!","items":"비품 아껴 쓰기","weeklyRules":"이번 주 규칙 꼭 확인","blessings":"고문서 취급 주의"}

static func build(view: Dictionary, back: Callable, select: Callable) -> Control:
	if HeroDesk.presentation: return _presentation(view,back,select)
	var root := HeroImageSkin.root()
	var desk := TextureRect.new()
	desk.name = "ArchiveDesk"
	desk.texture = load(ART+"desk_background.png")
	desk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	desk.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	desk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk.set_meta("full_bleed",true)
	root.add_child(desk); HeroUI.place(desk,Rect2(0,0,915,412))
	var group := str(view.group)
	var ids := entries(view)
	if not ids.is_empty() and view.id not in ids: view.id = ids[0]; view.page = 0; view.growthPage = 0
	# A mug resting below the category tabs, clear of every control.
	_art(root,ART+"deco_coffee_mug.png",Rect2(30,336,72,72)).name = "ArchiveMug"
	_header(root,back)
	_category_tabs(root,group,select)
	_folder(root,view,ids,select)
	if not ids.is_empty(): _sheet(root,view,select)
	_postit(root,group)
	return root

# Approval-stage office presentation; production remains on the existing desk until the
# shared kit is explicitly enabled by the isolated preview tool.
static func _presentation(view: Dictionary, back: Callable, select: Callable) -> Control:
	var root := HeroImageSkin.root()
	HeroDesk.backdrop(root,"archive")
	_header(root,back)
	HeroDesk.panel(root,Rect2(12,64,891,338),"ArchiveOfficeShell")
	var group := str(view.group)
	var ids := entries(view)
	if not ids.is_empty() and view.id not in ids: view.id = ids[0]; view.page = 0; view.growthPage = 0
	_category_tabs(root,group,select)
	_folder(root,view,ids,select)
	if not ids.is_empty(): _sheet(root,view,select)
	_art(root,ART+"deco_coffee_mug.png",Rect2(46,360,44,44)).name = "ArchiveMug"
	return root

static func entries(view: Dictionary) -> Array:
	var source: Dictionary = Content.data[view.group]
	var ids: Array = source.keys()
	var field: String = {"weapons":"weaponIds","enemies":"enemyIds","items":"itemIds"}.get(view.group,"")
	var roster: Dictionary = Content.data.maps.get(view.get("map","seoul"),{}).get("archiveContent",{})
	if roster.has(field): ids = ids.filter(func(id): return id in roster[field])
	if view.group == "items":
		var rarity_order := RARITIES.keys()
		ids.sort_custom(func(a,b): return rarity_order.find(source[a].rarity) < rarity_order.find(source[b].rarity))
	return ids

# --- Desk pieces -------------------------------------------------------------

static func _header(root: Control, back: Callable) -> void:
	HeroDesk.header(root,"자료집",back)

static func _category_tabs(root: Control, group: String, select: Callable) -> void:
	if HeroDesk.presentation:
		HeroDesk.text(root,"분류",Rect2(20,66,112,20),"heading",14,HeroDesk.accent(root)).name = "ArchiveCategoryTitle"
		var category_index := 0
		for key in GROUPS:
			var category := str(key)
			var chosen := category == group
			var choice := HeroDesk.key(root,str(GROUPS[category]),Rect2(20,88+category_index*46,112,44),func(): select.call("group",category),"row_selected" if chosen else "row",14,"control",Vector2(10,0))
			choice.name = "ArchiveTab_"+category
			var face := choice.get_node("Face") as Control
			var tint := _art(face,ART+str(TAB_ART[category])+".png",Rect2(5,8,8,24))
			tint.modulate.a = 0.32
			category_index += 1
		return
	var index := 0
	for key in GROUPS:
		var tab_group := str(key)
		var selected := tab_group == group
		# The open drawer tab slides out to the right; the others stay tucked in.
		var tab_rect := Rect2(16.0 if selected else 2.0,56.0+index*46.0,118,44)
		var tab := HeroImageSkin.button(root,"",tab_rect,func(): select.call("group",tab_group),"plain")
		tab.name = "ArchiveTab_"+tab_group
		# Paper tabs lie on the desk: a soft shadow under each, deeper under the pulled-out one.
		var tab_shadow := _drop_shadow(tab,Rect2(3,4,113,35),6.0 if selected else 3.0,0.42 if selected else 0.3)
		var tab_art := _art(tab,ART+str(TAB_ART[tab_group])+".png",Rect2(0,2,118,40))
		tab_art.name = "TabArt"
		if selected:
			var glow := _art(tab,ART+"tab_selected_glow.png",Rect2(0,2,118,40))
			glow.name = "TabGlow"
			glow.modulate.a = 0.35
		var caption := str(GROUPS[tab_group])
		_text(tab,caption,Rect2(19,9,88,26),"brand",_fit(caption,"brand",18,88.0),"#24395c")
		# Pressing pushes the tab flat onto the desk: the paper sinks and its shadow tightens.
		tab.button_down.connect(func(): tab.modulate = Color(0.94,0.94,0.94); tab_shadow.modulate.a = 0.5)
		tab.button_up.connect(func(): tab.modulate = Color.WHITE; tab_shadow.modulate.a = 1.0)
		index += 1

static func _folder(root: Control, view: Dictionary, ids: Array, select: Callable) -> void:
	var group := str(view.group)
	_drop_shadow(root,Rect2(146,90,282,308) if HeroDesk.presentation else Rect2(146,64,282,340),7.0,0.38).name = "ArchiveFolderShadow"
	_nine(root,ART+"folder_open.png",Rect2(138,66,296,334) if HeroDesk.presentation else Rect2(138,40,296,368),Vector4(40,145,40,35),0.5).name = "ArchiveFolder"
	var noun: Array = FOLDER_TITLES.get(group,["기록","건"])
	var heading := "%s · %d%s" % [str(noun[0]),ids.size(),str(noun[1])]
	_text(root,heading,Rect2(164,116,250,26) if HeroDesk.presentation else Rect2(164,90,150,26),"brand",_fit(heading,"brand",17,250.0 if HeroDesk.presentation else 150.0),"#24395c").name = "ArchiveFolderTitle"
	var maps: Array = Content.data.maps.keys()
	var bottom := 352.0 if maps.size() > 1 else 390.0
	if HeroDesk.presentation and maps.size() > 1: bottom = 342.0
	var list_top := 146.0 if HeroDesk.presentation else 120.0
	var list := HeroImageSkin.scroll(root,Rect2(162,list_top,250,bottom-list_top),view,"scroll")
	list.name = "ArchiveCollection"
	if HeroDesk.presentation: HeroDesk.scrollbar(list)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation",5)
	grid.add_theme_constant_override("v_separation",6)
	list.add_child(grid)
	for id in ids:
		var entry_id := str(id)
		var card := _polaroid(grid,group,entry_id,entry_id == str(view.id))
		card.name = "Archive_"+entry_id
		_guard(card,func(): select.call("id",entry_id))
	if maps.size() > 1: _map_navigation(root,view,select)

static func _polaroid(parent: Node, group: String, id: String, selected: bool) -> Button:
	# Polaroids use the tall-strip art (220x280) at 76/220 so the caption sits inside the paper.
	var card := HeroDesk.key(parent,"",Rect2(0,0,76,97),Callable(),"row") if HeroDesk.presentation else HeroImageSkin.button(parent,"",Rect2(0,0,76,97),Callable(),"plain")
	card.custom_minimum_size = Vector2(76,97)
	card.size = Vector2(76,97)
	var canvas: Control = card.get_node("Face") as Control if HeroDesk.presentation else card
	if HeroDesk.presentation: card.get_node("Plate").hide()
	var card_shadow := _drop_shadow(canvas,Rect2(4,4,68,90),4.0,0.34)
	_art(canvas,ART+("photo_frame_selected_tall.png" if selected else "photo_frame_tall.png"),Rect2(0,0,76,97))
	# Photo windows from the README, scaled 76/220.
	var photo := Rect2(13,15,51,50) if selected else Rect2(12,11,53,53)
	var art := HeroUI.fixed_art(canvas,illustration(group,id),photo.grow(-2))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var definition: Dictionary = Content.data[group][id]
	var caption := str(definition.get("name",id))
	_text(canvas,caption,Rect2(5,68,66,22),"control",_fit(caption,"control",12,66.0,9),"#24395c",HORIZONTAL_ALIGNMENT_CENTER)
	card.button_down.connect(func(): card.modulate = Color(0.94,0.94,0.94); card_shadow.modulate.a = 0.5)
	card.button_up.connect(func(): card.modulate = Color.WHITE; card_shadow.modulate.a = 1.0)
	return card

static func _map_navigation(root: Control, view: Dictionary, select: Callable) -> void:
	var maps: Array = Content.data.maps.keys()
	var current := maxi(0,maps.find(view.get("map","seoul")))
	var previous := _paper_button(root,"‹",Rect2(166,350,44,44) if HeroDesk.presentation else Rect2(166,356,36,30),func(): select.call("map",maps[current-1]),false,18)
	previous.name = "ArchiveMapPrevious"
	previous.disabled = current == 0
	var map_name := str(Content.data.maps[maps[current]].name)
	_text(root,map_name,Rect2(210,350,152,44) if HeroDesk.presentation else Rect2(206,356,160,30),"brand",_fit(map_name,"brand",14,152.0 if HeroDesk.presentation else 160.0),"#24395c",HORIZONTAL_ALIGNMENT_CENTER).name = "ArchiveMapName"
	var following := _paper_button(root,"›",Rect2(362,350,44,44) if HeroDesk.presentation else Rect2(370,356,36,30),func(): select.call("map",maps[current+1]),false,18)
	following.name = "ArchiveMapNext"
	following.disabled = current == maps.size()-1

static func _postit(root: Control, group: String) -> void:
	# 한서아's sticky note, slightly askew, over the folder corner but clear of its title and grid.
	var note := Control.new()
	note.name = "ArchiveNote"
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(note); HeroUI.place(note,Rect2(320,8,112,86))
	note.pivot_offset = Vector2(56,43)
	note.rotation = deg_to_rad(-5.0)
	var mint := group in ["characters","enemies","weeklyRules"]
	_drop_shadow(note,Rect2(8,6,96,74),5.0,0.3)
	_art(note,ART+("postit_mint.png" if mint else "postit_yellow.png"),Rect2(0,0,112,86))
	var caption := str(NOTES.get(group,""))
	_text(note,caption,Rect2(13,21,84,45),"brand",14,"#24395c",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})

# --- Document sheet -----------------------------------------------------------

# Sheet-local rectangles at SHEET_SCALE, taken from the README text areas.
static func _sheet_spec(group: String) -> Dictionary:
	match group:
		"characters": return {"file":"sheet_personnel","margins":Vector4(65,130,230,50),"title":Rect2(41,22,250,32),"body":Rect2(41,85,374,272)}
		"weapons": return {"file":"sheet_ledger","margins":Vector4(40,155,40,45),"title":Rect2(36,32,390,34),"body":Rect2(36,94,390,272)}
		"enemies": return {"file":"sheet_incident","margins":Vector4(75,235,235,65),"title":Rect2(40,24,300,34),"body":Rect2(38,137,385,214),"slot":Rect2(349,27,83,83),"title_color":"#fffaf0"}
		"items": return {"file":"sheet_inventory","margins":Vector4(105,225,65,50),"title":Rect2(41,44,368,40),"body":Rect2(60,129,349,228)}
		"weeklyRules": return {"file":"sheet_notice","margins":Vector4(55,165,55,50),"title":Rect2(47,93,368,36),"body":Rect2(41,140,380,217),"seal":Rect2(215,39,32,32),"centered":true}
		_: return {"file":"sheet_ancient","margins":Vector4(65,65,65,65),"title":Rect2(47,47,368,36),"body":Rect2(47,96,368,247),"centered":true}

static func _presentation_sheet_spec(group: String) -> Dictionary:
	var spec := _sheet_spec(group)
	var body: Rect2 = spec.body
	var bottom := body.end.y-58.0
	if group == "enemies": body.position.y = 107.0
	elif group == "items": body.position.y = 105.0
	elif group == "weeklyRules": body.position.y = 130.0
	body.size.y = bottom-body.position.y
	spec.body = body
	return spec

static func _field_names(group: String) -> Array:
	match group:
		"characters": return ["이름","특성"]
		"weapons": return ["품명","분류"]
		"enemies": return ["개체","분류"]
		"items": return ["품명","등급"]
		"weeklyRules": return ["제목",""]
		_: return ["명칭",""]

static func _field_value(group: String, definition: Dictionary) -> String:
	match group:
		"characters":
			var character_trait: Dictionary = definition.get("trait",{})
			return str(character_trait.get("name",""))
		"weapons":
			var caps: Array = definition.get("capabilities",[])
			return HeroGateScreen.primary_family(caps)
		"enemies":
			var tags: Array = definition.get("tags",[])
			var behavior := str(definition.get("behavior",""))
			return ("보스" if "BOSS" in tags else "일반") + " · " + str(BEHAVIORS.get(behavior,behavior))
		"items":
			var rarity := str(definition.get("rarity",""))
			return str(RARITIES.get(rarity,rarity))
		_: return ""

static func _sheet(root: Control, view: Dictionary, select: Callable) -> void:
	var group := str(view.group)
	var id := str(view.id)
	var definition: Dictionary = Content.data[group][view.id]
	var spec := _presentation_sheet_spec(group) if HeroDesk.presentation else _sheet_spec(group)
	var sheet_rect := Rect2(442,64,462,338) if HeroDesk.presentation else SHEET_RECT
	_drop_shadow(root,sheet_rect.grow(-6),8.0,0.4).name = "ArchiveSheetShadow"
	var sheet := Control.new()
	sheet.name = "ArchiveDetails"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sheet); HeroUI.place(sheet,sheet_rect)
	var margins: Vector4 = spec.margins
	_nine(sheet,ART+str(spec.file)+".png",Rect2(Vector2.ZERO,sheet_rect.size),margins,SHEET_SCALE).name = "SheetPaper"
	var title_rect: Rect2 = spec.title
	var body: Rect2 = spec.body
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if bool(spec.get("centered",false)) else HORIZONTAL_ALIGNMENT_LEFT
	var document := str(DOCUMENTS.get(group,""))
	_text(sheet,document,title_rect,"brand",_fit(document,"brand",24,title_rect.size.x),str(spec.get("title_color","#24395c")),align).name = "ArchiveDocumentTitle"
	if group == "characters":
		_text(sheet,"서울 각성자 협회 · 현장 지원팀",Rect2(41,64,250,16),"body",12,"#4a5568").name = "ArchiveDocumentOffice"
		_approvals(sheet)
	if spec.has("seal"):
		var seal: Rect2 = spec.seal
		_stamp(sheet,"협회",seal,-0.1)
	# Clipped photo of the selected entry.
	var info := body
	if spec.has("slot"):
		var slot: Rect2 = spec.slot
		_detail_art(sheet,illustration(group,id),slot.grow(-6))
		_art(sheet,ART+"clip_paper.png",Rect2(slot.end.x-26,slot.position.y-12,19,44)).name = "ArchiveClip"
	else:
		var frame_rect := Rect2(body.position.x,body.position.y+8,84,95)
		_art(sheet,ART+"photo_frame.png",frame_rect).name = "ArchivePhotoFrame"
		_detail_art(sheet,illustration(group,id),Rect2(frame_rect.position+Vector2(14,13),Vector2(56,55)))
		_art(sheet,ART+"clip_paper.png",Rect2(frame_rect.position.x+56,frame_rect.position.y-12,19,44)).name = "ArchiveClip"
		info = Rect2(body.position.x+96,body.position.y,body.size.x-96,body.size.y)
	# Field rows: entry name first and largest, then one group-specific fact.
	var names := _field_names(group)
	var value_x := info.position.x+44
	var value_width := info.size.x-44
	_text(sheet,str(names[0]),Rect2(info.position.x,info.position.y+4,40,24),"body",13,"#4a5568").name = "ArchiveNameField"
	var entry_name := str(definition.name)
	_text(sheet,entry_name,Rect2(value_x,info.position.y,value_width,28),"brand",_fit(entry_name,"brand",24,value_width),"#24395c").name = "ArchiveEntryName"
	var top := info.position.y+36
	var fact := _field_value(group,definition)
	if not fact.is_empty():
		_text(sheet,str(names[1]),Rect2(info.position.x,top+1,40,20),"body",13,"#4a5568").name = "ArchiveFactField"
		_text(sheet,fact,Rect2(value_x,top,value_width,22),"heading",_fit(fact,"heading",15,value_width),"#1e8276").name = "ArchiveFact"
		top += 26
	# Page tabs sit along the bottom of the sheet body.
	var tabs_y := body.end.y-(50.0 if HeroDesk.presentation else 30.0)
	var labels := detail_tabs(group,definition)
	view.page = clampi(int(view.page),0,labels.size()-1)
	_button_row(sheet,labels,Rect2(body.position.x,tabs_y,body.size.x,44 if HeroDesk.presentation else 28),int(view.page),func(index: int): select.call("page",index))
	root.set_meta("archive_body_rect",Rect2(sheet_rect.position+Vector2(info.position.x,top),Vector2(info.size.x,tabs_y-6.0-top)))
	root.set_meta("archive_growth_row",Rect2(info.position.x,tabs_y-(50.0 if HeroDesk.presentation else 34.0),info.size.x,44 if HeroDesk.presentation else 28))
	if group == "weapons":
		if int(view.page) == 0: _weapon_overview(root,definition)
		else: _weapon_growth(root,definition,view,select)
	else: _details(root,view,definition)

static func _approvals(sheet: Control) -> void:
	# 결재란: three printed boxes in the personnel art; 서아 and the team lead have signed.
	var captions := ["담당","팀장","협회장"]
	var stamps := ["서아","승인",""]
	var centers := [353.0,382.0,411.0]
	for i in range(captions.size()):
		var center: float = centers[i]
		_text(sheet,str(captions[i]),Rect2(center-15,19,30,12),"control",9,"#4a5568",HORIZONTAL_ALIGNMENT_CENTER)
		if not str(stamps[i]).is_empty(): _stamp(sheet,str(stamps[i]),Rect2(center-14,31,28,28),-0.14+0.12*i)

static func _stamp(parent: Control, caption: String, rect: Rect2, angle: float) -> void:
	var holder := Control.new()
	holder.name = "ArchiveStamp"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder); HeroUI.place(holder,rect)
	holder.pivot_offset = rect.size*0.5
	holder.rotation = angle
	_art(holder,ART+"stamp_round_red.png",Rect2(Vector2.ZERO,rect.size))
	var label := _text(holder,caption,Rect2(Vector2.ZERO,rect.size),"brand",9,"#d23b3b",HORIZONTAL_ALIGNMENT_CENTER)
	label.modulate.a = 0.9

static func _detail_art(parent: Control, texture: Texture2D, rect: Rect2) -> TextureRect:
	var art := HeroUI.fixed_art(parent,texture,rect)
	art.name = "ArchiveDetailArt"
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return art

static func detail_tabs(group: String, definition: Dictionary) -> Array:
	match group:
		"weapons":
			var labels: Array = ["특징","기본 성장"]
			for branch in definition.branches: labels.append("분기 " + branch.id)
			return labels
		"characters": return ["배경","성격","공격","생존·회수"]
		"enemies": return ["특징","능력치","행동","공격 패턴"] if not definition.get("bossPatterns",[]).is_empty() else ["특징","능력치","행동"]
		"items": return ["특징","효과","구매 정보"]
		"weeklyRules": return ["특징","패널티","베네핏"]
		_: return ["특징","성장","운용"]

static func illustration(group: String, id: String) -> Texture2D:
	var definition: Dictionary = Content.data[group][id]
	match group:
		"characters": return Content.actor_preview(group,id,definition.portraitSprite)
		"weapons": return Content.weapon_icon(id)
		"enemies": return Content.actor_preview(group,id,definition.visual.sprite)
		"items": return Content.item_icon(id)
		_: return Content.trimmed_texture(definition.image)

# --- Sheet body copy ----------------------------------------------------------

static func _weapon_overview(root: Control, definition: Dictionary) -> void:
	var note: Dictionary = Content.data.premiumUI.weaponNotes.get(definition.id,{})
	var content := _content(root)
	_copy(content,HeroGateScreen.primary_family(definition.capabilities) + "  전투 장비",15,INK)
	var copy := "%s\n\n%s\n\n%s\n\n“%s”" % [definition.description,HeroGateScreen.secondary_traits(definition.capabilities),note.get("note",definition.description),note.get("quote","현장의 기록은 다음 출동을 지킵니다.")]
	_copy(content,copy,14,BODY_INK)
	_copy(content,"적용 능력 · " + HeroGateScreen.applied_stats(definition.capabilities),13,ACCENT_INK)

static func _weapon_growth(root: Control, definition: Dictionary, view: Dictionary, select: Callable) -> void:
	var branch: Dictionary = definition.branches[int(view.page)-2] if int(view.page) >= 2 else {}
	var first := int(definition.branchAtLevel) if not branch.is_empty() else 1
	var last := int(definition.maxLevel) if not branch.is_empty() else int(definition.branchAtLevel)-1
	var count := maxi(1,ceili((last-first+1)/3.0))
	var page := clampi(int(view.get("growthPage",0)),0,count-1)
	var content := _content(root,_body_rect(root,50.0 if HeroDesk.presentation else 34.0))
	_copy(content,str(branch.get("name","공통 성장")),15,INK)
	_copy(content,str(branch.get("description","분기 전 기본 강화 · 증감은 직전 레벨 대비")),13,BODY_INK)
	var extra_key := "attackAngle" if definition.behavior == "slash" else "blastRadius" if "EXPLOSIVE" in definition.capabilities or "AURA" in definition.capabilities else "projectileCount"
	var extra_title := "공격 각도 °" if extra_key == "attackAngle" else "공격 반경" if extra_key == "blastRadius" else "투사체 개수"
	var keys := ["damage","cooldown","range",extra_key,"repeatCount"]
	var headers := ["피해","공격 주기 · 초","사거리",extra_title,"반복 타격"]
	for row in range(3):
		var level := first+page*3+row
		if level > last: break
		var owned := {"level":level,"branch":branch.get("id","")}
		var stats := HeroStats.resolve_weapon(definition,owned,Content.data.stats,[],Content.data.weaponConfig,{})
		var previous := HeroStats.resolve_weapon(definition,{"level":maxi(1,level-1),"branch":branch.get("id","") if level-1 >= definition.branchAtLevel else ""},Content.data.stats,[],Content.data.weaponConfig,{})
		var level_label := _copy(content,"Lv. %d" % level,15,ACCENT_INK)
		HeroImageSkin.apply_font(level_label,"number",15)
		for i in range(keys.size()):
			var key: String = keys[i]
			var value := float(stats.get(key,0))
			var delta := value-float(previous.get(key,0)) if level > 1 else 0.0
			if key == "attackAngle": value = rad_to_deg(value); delta = rad_to_deg(delta)
			var text := number(value)+("  (%s%s)" % ["+" if delta > 0 else "",number(delta)] if absf(delta)>0.001 else "")
			var pair := HBoxContainer.new()
			pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_theme_constant_override("separation",6)
			content.add_child(pair)
			var title := _copy(pair,headers[i],13,BODY_INK)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var value_label := _copy(pair,text,15,ACCENT_INK if absf(delta)>0.001 else INK)
			HeroImageSkin.apply_font(value_label,"number",14)
			value_label.size_flags_horizontal = Control.SIZE_SHRINK_END
			value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.custom_minimum_size.x = 104
	var captions: Array = []
	for i in range(count):
		var start := first+i*3
		captions.append("Lv.%d–%d" % [start,mini(last,start+2)])
	var sheet := root.get_node("ArchiveDetails") as Control
	var growth_row: Rect2 = root.get_meta("archive_growth_row",Rect2(132,302,294,28))
	_button_row(sheet,captions,growth_row,page,func(index: int): select.call("growthPage",index),true)

static func _details(root: Control, view: Dictionary, definition: Dictionary) -> void:
	var group: String = view.group
	var page: int = view.page
	if group == "characters" and page >= 2:
		var keys: Array = STATS.keys().slice(0,10) if page == 2 else STATS.keys().slice(10)
		var pairs: Array = []
		for key in keys: pairs.append([STATS[key],stat_value(key,definition.baseStats[key]),key])
		_pairs(root,pairs,"기본 능력치 · 추가 보정 전")
		return
	if group == "enemies" and page == 1:
		_pairs(root,[["최대 체력",number(definition.maxHp)],["이동 속도",number(definition.moveSpeed)],["접촉 피해",number(definition.contactDamage)],["크기 · 반경",number(definition.radius)],["마력석",number(definition.magicStoneDrop)]],"광화문 · 1층 기준")
		return
	if group == "enemies" and page == 3:
		var pattern_content := _content(root)
		_copy(pattern_content,"보스 공격 패턴",15,INK)
		var patterns: Array = definition.get("bossPatterns",[])
		var lines := PackedStringArray()
		for pattern in patterns: lines.append(_pattern(pattern))
		_copy(pattern_content,"\n\n".join(lines),14,BODY_INK)
		return
	var content := _content(root)
	var heading := ""
	var text := ""
	var footer := ""
	match group:
		"characters":
			heading = "배경" if page == 0 else "성격"
			text = definition.get("background",definition.description) if page == 0 else definition.get("personality","")
			footer = "%s · %s" % [definition.trait.name,definition.trait.description]
		"enemies":
			heading = "보스" if "BOSS" in definition.tags else "일반"
			text = definition.get("description",definition.get("archiveRole","")) if page == 0 else BEHAVIORS.get(definition.behavior,definition.behavior)
			if page == 2:
				text += "\n" + definition.get("archiveBehavior",definition.get("description",""))
		"items":
			heading = RARITIES.get(definition.rarity,definition.rarity)
			if page == 0: text = definition.description
			elif page == 1:
				text = definition.description.replace(" · ","\n")
			else:
				text = "가격  %d 마력석\n최대 중첩  %d\n구매 위치  게이트24" % [definition.basePrice,definition.maxStacks]
			footer = "능력치 증가는 기준값에서 합산됩니다."
		"weeklyRules":
			heading = ["주간 게이트 규칙","패널티","베네핏"][page]
			text = definition.description if page == 0 else definition.penaltyLabel if page == 1 else definition.benefitLabel
			footer = "패널티와 베네핏은 함께 자동 적용 · 일요일 05:00 갱신"
		"blessings":
			heading = ["단군의 축복","단계당 효과" if Content.enabled("blessingLevels") else "적용 효과","출동 전 편성"][page]
			if page == 0: text = definition.description
			elif page == 1:
				for modifier in definition.modifiers: text += _modifier(modifier) + "\n"
				if definition.has("weaponDamageBonus"): text += "%s 무기 피해 +%s%%\n" % [HeroGateScreen.primary_family([definition.get("weaponCapability","STRUCTURE")]),number(float(definition.weaponDamageBonus)*100.0)]
				if definition.has("structureLimitAtLevel"): text += "%d단계 설치물 한도 +1" % definition.structureLimitAtLevel
			elif Content.enabled("blessingLevels"):
				var costs: Array = Content.data.growth.blessingCosts
				var steps: Array = costs.slice(1).map(func(cost): return str(int(cost)))
				text = "%d조각으로 해금\n성장 비용  %s\n최대 %d단계\n해금한 축복 1개만 Run에 적용" % [int(costs[0])," / ".join(steps),costs.size()]
			else:
				text = "협회에서 미해금 축복을 추첨해 계승\n해금한 축복 1개를 출동 전에 선택\n1단계 효과로 고정 적용"
			footer = "성장 단계는 보유 조각을 사용해 올립니다." if Content.enabled("blessingLevels") else "축복은 계정 공용 · 출동마다 선택 가능"
	_copy(content,heading,15,INK)
	_copy(content,text.strip_edges(),14,BODY_INK)
	if not footer.is_empty(): _copy(content,footer,12,ACCENT_INK)

static func _pairs(root: Control, pairs: Array, heading: String) -> void:
	var content := _content(root)
	_copy(content,heading,15,INK)
	for pair in pairs:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 24
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",6)
		content.add_child(row)
		if pair.size() >= 3: HeroUI.icon(row,str(pair[2]),18,20)
		var name_label := _copy(row,str(pair[0]),14,BODY_INK)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var value := _copy(row,str(pair[1]),15,INK)
		value.size_flags_horizontal = Control.SIZE_SHRINK_END
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.custom_minimum_size.x = 72
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		HeroImageSkin.apply_font(value,"number",15)

# Root-space rectangle of the sheet body column; `trim` reserves rows at its bottom.
static func _body_rect(parent: Node, trim: float = 0.0) -> Rect2:
	var result: Rect2 = parent.get_meta("archive_body_rect",Rect2(574,149,278,182))
	result.size.y = maxf(44,result.size.y-trim)
	return result

static func _content(root: Control, rect: Rect2 = Rect2()) -> VBoxContainer:
	if rect.size == Vector2.ZERO: rect = _body_rect(root)
	var panel := root.get_node("ArchiveDetails") as Control
	var scroll := HeroImageSkin.scroll(panel,Rect2(rect.position-panel.position,rect.size))
	scroll.name = "ArchiveBody"
	if HeroDesk.presentation: HeroDesk.scrollbar(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",6)
	scroll.add_child(content)
	return content

static func _copy(parent: Node, caption: String, font_size: int, color: Color, centered: bool = false) -> Label:
	if HeroDesk.presentation:
		var preview_label := HeroDesk.text(parent,caption,Rect2(),"heading" if font_size >= 15 else "body",font_size,"#"+color.to_html(false),HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT,true)
		preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_label.add_theme_constant_override("line_spacing",2)
		return preview_label
	var label := Label.new()
	label.text = caption
	HeroImageSkin.apply_font(label,"heading" if font_size >= 15 else "body",font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",color)
	label.add_theme_constant_override("line_spacing",2)
	parent.add_child(label)
	return label

# --- Office art helpers ---------------------------------------------------------

static func _text(parent: Node, caption: String, rect: Rect2, role: String = "body", font_size: int = 14, color: String = "#24395c", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false, options: Dictionary = {}) -> Label:
	return HeroDesk.text(parent,caption,rect,role,font_size,color,align,wrap,options) if HeroDesk.presentation else HeroImageSkin.text(parent,caption,rect,role,font_size,color,align,wrap,options)

# 9-slice margins stay in source pixels; the node is scaled down as one piece.
static func _nine(parent: Node, path: String, rect: Rect2, margins: Vector4, art_scale: float) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = load(path)
	patch.patch_margin_left = int(margins.x); patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z); patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(patch)
	patch.position = rect.position
	patch.size = rect.size/art_scale
	patch.scale = Vector2(art_scale,art_scale)
	return patch

static func _art(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var result := HeroUI.fixed_art(parent,load(path),rect)
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result

# Soft contact shadow under a desk piece: a blurred warm-brown patch, `depth` px lower than
# the piece. soft_shadow.png is a 64px rounded square blurred inside a 128px canvas, so the
# patch extends 32 source px past the piece on every side.
static func _drop_shadow(parent: Node, rect: Rect2, depth: float, strength: float) -> NinePatchRect:
	var blur := clampf(depth*0.09,0.12,0.6)
	var patch := _nine(parent,OFFICE+"soft_shadow.png",Rect2(rect.position+Vector2(0,depth)-Vector2(32,32)*blur,rect.size+Vector2(64,64)*blur),Vector4(48,48,48,48),blur)
	patch.name = "Shadow"
	patch.self_modulate = Color(0.24,0.13,0.05,strength)
	return patch

# Cream office key (navy when selected). The art has a thick bottom lip, so the caption is a
# Label centred on the key face above the lip instead of the Button's own text, which would
# centre on the 44px touch box and sink below the plate. Pressing swaps in the pressed art and
# lowers the face with it.
static func _paper_button(parent: Node, caption: String, rect: Rect2, action: Callable, selected: bool, font_size: int = 13, role: String = "control", caption_offset: Vector2 = Vector2.ZERO) -> Button:
	if HeroDesk.presentation: return HeroDesk.key(parent,caption,rect,action,"row_selected" if selected else "row",font_size,role,caption_offset)
	var result := HeroImageSkin.button(parent,caption,rect,action,"plain",font_size)
	result.custom_minimum_size = Vector2(rect.size.x,maxf(rect.size.y,result.custom_minimum_size.y))
	result.autowrap_mode = TextServer.AUTOWRAP_OFF
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_hover_pressed_color"]:
		result.add_theme_color_override(state,Color(0,0,0,0))
	var file := "button_deploy_navy" if selected else "button_secondary"
	var source_height := 144.0 if selected else 128.0
	var lip := (16.0 if selected else 12.0)/source_height
	var plate_height := rect.size.y
	var shadow := _drop_shadow(result,Rect2(2,3,rect.size.x-4,plate_height-4),3.0,0.32)
	shadow.show_behind_parent = true
	var margin := 40.0 if selected else 26.0
	var plate := _nine(result,OFFICE+file+"_normal.png",Rect2(0,0,rect.size.x,plate_height),Vector4(margin,margin,margin,margin),plate_height/source_height)
	plate.name = "Plate"
	plate.show_behind_parent = true
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(face); HeroUI.place(face,Rect2(0,0,rect.size.x,plate_height*(1.0-lip)))
	var label := _text(face,caption,Rect2(caption_offset,Vector2(rect.size.x-caption_offset.x,plate_height*(1.0-lip))),role,font_size,"#fffcf5" if selected else "#24395c",HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "Caption"
	var normal: Texture2D = plate.texture
	var pressed: Texture2D = load(OFFICE+file+"_pressed.png")
	var sink := maxf(1.0,plate_height*lip*0.5)
	result.button_down.connect(func(): plate.texture = pressed; face.position.y = sink; shadow.modulate.a = 0.5)
	result.button_up.connect(func(): plate.texture = normal; face.position.y = 0.0; shadow.modulate.a = 1.0)
	result.draw.connect(func():
		plate.modulate.a = 0.45 if result.disabled else 1.0
		face.modulate.a = 0.45 if result.disabled else 1.0
		shadow.visible = not result.disabled
	)
	return result

static func _button_row(parent: Node, captions: Array, row: Rect2, selected: int, pick: Callable, equal: bool = false) -> void:
	var count := captions.size()
	if count == 0: return
	var gap := 6.0
	var face := HeroDesk.font("control") if HeroDesk.presentation else HeroImageSkin.font("control")
	var font_size := 13
	var widths: Array[float] = []
	while true:
		widths.clear()
		var widest := 0.0
		var needed := gap*(count-1)
		for caption in captions:
			var natural := ceilf(face.get_string_size(str(caption),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+18.0
			if HeroDesk.presentation: natural = maxf(natural,44.0)
			widths.append(natural)
			widest = maxf(widest,natural)
			needed += natural
		if equal: needed = widest*count+gap*(count-1)
		if needed <= row.size.x or font_size <= 9: break
		font_size -= 1
	if equal:
		var each := (row.size.x-gap*(count-1))/count
		for i in range(count): widths[i] = each
	else:
		var used := gap*(count-1)
		for natural_width in widths: used += natural_width
		var spare := maxf(0.0,row.size.x-used)/count
		for i in range(count): widths[i] = maxf(widths[i],minf(widths[i]+spare,100.0))
	var x := row.position.x
	for i in range(count):
		var index := i
		var page_button := _paper_button(parent,str(captions[i]),Rect2(x,row.position.y,widths[i],row.size.y),func(): pick.call(index),i == selected,font_size)
		page_button.name = ("ArchiveGrowth_%d" if equal else "ArchivePage_%d") % i
		x += widths[i]+gap

# Largest size (down to `smallest`) at which a single line fits `width`.
static func _fit(caption: String, role: String, largest: int, width: float, smallest: int = 9) -> int:
	if HeroDesk.presentation: return HeroDesk.fit(caption,role,largest,width,smallest)
	var face := HeroImageSkin.font(role)
	var result := largest
	while result > smallest and face.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x > width: result -= 1
	return result

# Grid entries live in a drag-scroll: a drag never counts as a tap.
static func _guard(control: BaseButton, action: Callable) -> void:
	control.pressed.connect(func():
		var ancestor: Node = control.get_parent()
		while ancestor != null:
			if ancestor is HeroImageSkin.DragScroll and (ancestor as HeroImageSkin.DragScroll).suppress_click: return
			ancestor = ancestor.get_parent()
		HeroUI.ui_reaction(control)
		Sound.prime(); Sound.cue("buttonClick"); action.call()
	)

static func stat_value(key: String, value: float) -> String:
	return number(value*100)+"%" if key in MULTIPLIERS or key in PROBABILITIES else number(value)

static func _modifier(modifier: Dictionary) -> String:
	var value := float(modifier.value)
	var percent: bool = modifier.operation == "multiply" or modifier.stat in MULTIPLIERS or modifier.stat in PROBABILITIES
	if modifier.operation == "multiply": value -= 1.0
	if percent: value *= 100
	return "%s  %s%s%s" % [STATS.get(modifier.stat,modifier.stat),"+" if value>0 else "",number(value),"%" if percent else ""]

static func _special_effect(effect: Dictionary) -> String:
	var names := {"structureLimit":"설치물 추가 한도","projectileCount":"투사체 추가","indirectLifesteal":"설치물 흡혈","structureDuration":"설치물 지속시간","structureDamage":"설치물 피해","structureInterval":"설치 주기","chainCount":"연쇄 추가"}
	return "%s  %s" % [names.get(effect.type,effect.type),number(effect.get("value",0))]

static func _pattern(pattern: Dictionary) -> String:
	var name: String = {"charge":"돌진","aoe":"범위 공격","summon":"소환","volley":"일제 사격","spiral":"회전 탄막"}.get(pattern.type,pattern.type)
	return "%s · 예고 %s초 / 주기 %s초" % [name,number(pattern.get("warning",0)),number(pattern.get("cooldown",0))]

static func number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
