extends Control
# Isolated image UI proposals: no runtime autoloads, save adapters, simulation or audio.
const CANVAS := Vector2(915,412)
const ICON_KEYS := ["maxHp","hpRegen","lifeSteal","damage","meleeDamage","rangedDamage","area","attackSpeed","critChance","critDamage","armor","dodge","speed","luck","duration","range","pickupRange","curse","projectileSpeed","currencyGain","back","next","settings","details","musicOn","musicOff","pause","reroll","lock","unlock","wave","depth"]
var _project_dir: String
var _design_dir: String
var _repo_dir: String
var _content: Dictionary
var _skins: Dictionary
var _theme: Dictionary
var _theme_id := "c"
var _textures: Dictionary = {}
var _fonts: Dictionary = {}
var _labels: Array[Label] = []
var _frames: Array[Dictionary] = []
var _report: Array[Dictionary] = []
var _output: String

func _ready() -> void:
	_project_dir = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	_design_dir = _project_dir.get_base_dir()
	_repo_dir = _design_dir.get_base_dir().get_base_dir()
	_output = _project_dir.path_join("captures")
	if not "--capture" in OS.get_cmdline_user_args():
		print("Phase2 preview prepared. Pass --capture to render six isolated proposals.")
		get_tree().quit(); return
	_content = _json(_repo_dir.path_join("godot/data/content.json"))
	_skins = _json(_design_dir.path_join("skins.json"))
	_theme = _skins.themes.c
	if _content.is_empty() or _theme.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(_output)
	await _capture_all()

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: push_error("Preview data unavailable: "+path); return {}
	return parsed

func _capture_all() -> void:
	var screens := ["01-deployment-depth","02-character-weapon","03-growth","04-archive-item","05-settings","06-hud-pause"]
	for screen in screens:
		_labels.clear(); _frames.clear()
		var surface := Control.new(); surface.size = CANVAS; add_child(surface)
		match screen:
			"01-deployment-depth": _deployment(surface)
			"02-character-weapon": _selection(surface)
			"03-growth": _growth(surface)
			"04-archive-item": _archive(surface)
			"05-settings": _settings(surface)
			"06-hud-pause": _hud_pause(surface)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_output.path_join(screen+".png"))
		_report.append(_layout_report("c",screen))
		surface.queue_free(); await get_tree().process_frame
	var issues := 0
	for screen in _report: issues += screen.fitIssues.size()
	var file := FileAccess.open(_output.path_join("font-fit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[915,412],"skin":"c","previewOnly":true,"productionLoaded":false,"saveAdaptersLoaded":false,"simulation":false,"audioPlayback":false,"contentSha256":FileAccess.get_sha256(_repo_dir.path_join("godot/data/content.json")),"screens":_report,"issueCount":issues},"	"))
	print("Phase2 six PNG captures: ",_output,"; fitIssues=",issues)
	get_tree().quit(0 if issues == 0 else 3)

func _font(role: String) -> Font:
	var key := _theme_id+":"+role
	if _fonts.has(key): return _fonts[key]
	var relative := "design/ui-image-skins/fonts/Paperlogy-4Regular.ttf"
	match role:
		"control": relative = "design/ui-image-skins/fonts/Paperlogy-5Medium.ttf"
		"number": relative = "design/ui-image-skins/fonts/BarlowCondensed-SemiBold.ttf"
		"brand": relative = "design/ui-image-skins/fonts/SFSsaraknun.ttf" if _theme_id == "a" else "design/ui-image-skins/fonts/BMJUA.ttf"
		"heading": relative = "design/ui-image-skins/fonts/KMU80SungkokSerif.ttf" if _theme_id == "a" else "design/ui-image-skins/fonts/KMU80HaeongSans.ttf"
	var native := FontFile.new()
	var error := native.load_dynamic_font(_repo_dir.path_join(relative))
	if error != OK: push_error("Preview font unavailable: "+relative); get_tree().quit(2)
	if role != "body": native.fallbacks = [_font("body")]
	_fonts[key] = native
	return native

func _color(role: String) -> Color:
	var defaults := {"ink":"#20354b","muted":"#5d6b7a","accent":"#287b79","reward":"#99631e","danger":"#a23e4c","scene":"#f4f7fa"}
	return Color(str(_theme.get("colors",{}).get(role,defaults.get(role,defaults.ink))))

func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): push_error("Preview image unavailable: "+path); get_tree().quit(2); return null
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture

func _content_texture(id: String, trim: bool = true) -> Texture2D:
	var entry: Dictionary = _content.images[id]
	var path := _repo_dir.path_join("godot/"+str(entry.url).trim_prefix("res://"))
	var cache_key := path+":"+JSON.stringify(entry.get("region",[]))+":"+str(trim)
	if _textures.has(cache_key): return _textures[cache_key]
	var image := Image.load_from_file(path)
	if entry.has("region"):
		var region: Array = entry.region
		image = image.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	if trim and image.get_format() == Image.FORMAT_RGBA8:
		var used := image.get_used_rect()
		if used.has_area(): image = image.get_region(used)
	var texture := ImageTexture.create_from_image(image)
	_textures[cache_key] = texture
	return texture

func _art(parent: Control, texture: Texture2D, rect: Rect2, cover: bool = false) -> TextureRect:
	var image := TextureRect.new(); image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position; image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(image)
	return image

func _skin(parent: Control, pack_name: String, role: String, rect: Rect2) -> NinePatchRect:
	var pack: Dictionary = _theme[pack_name]
	var definition: Dictionary = pack.roles[role]
	var texture := _texture(_design_dir.path_join(str(pack.file)))
	var region := Rect2(Vector2.ZERO,texture.get_size())
	if definition.has("rect"):
		var bounds: Array = definition.rect
		region = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
	elif definition.has("cell"):
		var cell: Array = definition.cell
		var cell_size := texture.get_size()/Vector2(int(pack.columns),int(pack.rows))
		region = Rect2(Vector2(float(cell[0]),float(cell[1]))*cell_size,cell_size)
	var scale_factor := float(definition.get("asset_scale",pack.get("asset_scale",2.0)))
	var slices: Array = definition.get("slice",pack.get("slice",[24,24,24,24]))
	var frame := NinePatchRect.new()
	frame.texture = texture; frame.region_rect = region
	frame.patch_margin_left = int(slices[0]); frame.patch_margin_top = int(slices[1])
	frame.patch_margin_right = int(slices[2]); frame.patch_margin_bottom = int(slices[3])
	frame.position = rect.position; frame.size = rect.size*scale_factor
	frame.scale = Vector2.ONE/scale_factor
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_frames.append({"pack":pack_name,"role":role,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"source":[region.position.x,region.position.y,region.size.x,region.size.y],"slices":slices,"assetScale":scale_factor})
	return frame

func _text(parent: Control, text: String, rect: Rect2, role: String = "body", size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var label := Label.new(); label.text = text
	label.position = rect.position; label.size = rect.size
	label.add_theme_font_override("font",_font(role)); label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",_color(color_role))
	label.add_theme_constant_override("line_spacing",2)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("allocated_rect",rect); label.set_meta("font_role",role)
	parent.add_child(label)
	# Assign the box after font/wrap properties; Label otherwise retains an early
	# minimum computed with the default font before the selected face is applied.
	label.position = rect.position; label.size = rect.size
	_labels.append(label)
	return label

func _button(parent: Control, text: String, rect: Rect2, role: String = "secondary", size: int = 16) -> void:
	_skin(parent,"buttons",role,rect)
	_text(parent,text,Rect2(rect.position+Vector2(12,4),rect.size-Vector2(24,8)),"control",size,"scene" if role == "primary" else "muted" if role == "disabled" else "ink",HORIZONTAL_ALIGNMENT_CENTER)

func _icon(parent: Control, key: String, rect: Rect2) -> void:
	var index := ICON_KEYS.find(key)
	var texture := _content_texture("urbanIconsAtlas",false)
	var cell := texture.get_size()/Vector2(8,4)
	var atlas := AtlasTexture.new(); atlas.atlas = texture
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell); atlas.filter_clip = true
	_art(parent,atlas,rect)

func _layout_report(variant: String, screen: String) -> Dictionary:
	var labels: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	for label in _labels:
		var rect: Rect2 = label.get_meta("allocated_rect")
		var font := label.get_theme_font("font")
		var size := label.get_theme_font_size("font_size")
		var lines := label.get_line_count()
		var needed_height := font.get_height(size)*lines+2*maxi(0,lines-1)
		var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x if label.autowrap_mode == TextServer.AUTOWRAP_OFF else label.size.x
		var logical_line_width := 0.0
		for line in label.text.split("\n"):
			logical_line_width = maxf(logical_line_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
		var entry := {"text":label.text,"font":str(label.get_meta("font_role")),"size":size,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"actualBox":[label.position.x,label.position.y,label.size.x,label.size.y],"lines":lines,"fontHeight":font.get_height(size),"requiredHeight":needed_height,"requiredWidth":width,"unwrappedLineWidth":logical_line_width,"align":label.horizontal_alignment}
		labels.append(entry)
		if needed_height > rect.size.y+1 or width > rect.size.x+1: issues.append(entry)
	return {"variant":variant,"screen":screen,"labels":labels,"frames":_frames.duplicate(true),"fitIssues":issues}

func _base(parent: Control, title: String, background: String = "metaGrowthLab") -> void:
	_art(parent,_content_texture(background,false),Rect2(Vector2.ZERO,CANVAS),true)
	_skin(parent,"panels","cabinet",Rect2(10,10,895,392))
	_skin(parent,"panels","header",Rect2(20,20,875,52))
	_button(parent,"이전",Rect2(28,24,80,44),"secondary",16)
	_text(parent,title,Rect2(125,25,600,42),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"화면 시안",Rect2(767,29,108,32),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)

func _deployment(parent: Control) -> void:
	_base(parent,"출동 · 웨이브 심도","seoulIntersection")
	var map: Dictionary = _content.maps.seoul
	_skin(parent,"panels","info",Rect2(20,84,282,257))
	_art(parent,_content_texture(map.thumbnail,false),Rect2(32,96,258,130),true)
	_text(parent,map.name,Rect2(35,232,252,30),"heading",21,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"%d 웨이브 · 마지막 보스" % int(map.totalWaves),Rect2(35,267,252,25),"body",14,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"전체 지형 이동 가능",Rect2(35,305,252,23),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_skin(parent,"panels","info",Rect2(314,84,581,257))
	_text(parent,"웨이브 심도",Rect2(329,90,551,31),"heading",21,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var depths := [1,2,5,10,20]
	var highest := int(_content.defaultMeta.gateProgression.highestUnlockedDepth)
	for i in range(depths.size()):
		var depth: int = depths[i]
		var x := 326+i*112
		_skin(parent,"panels","card",Rect2(x,130,104,126))
		var gate := _art(parent,_content_texture("gate"),Rect2(x+31,138,42,42)); gate.modulate.a = 0.84 if depth <= highest else 0.4
		_text(parent,str(depth),Rect2(x+8,183,88,34),"number",28,"accent" if depth == 1 else "ink",HORIZONTAL_ALIGNMENT_CENTER)
		_text(parent,"선택" if depth == 1 else "잠김",Rect2(x+8,222,88,22),"control",14,"accent" if depth == 1 else "muted",HORIZONTAL_ALIGNMENT_CENTER)
		var hp := 1.0+(depth-1)*float(_content.gate.hpPerDepth)
		var spawn := 1.0+(depth-1)*float(_content.gate.spawnPerDepth)
		for milestone in _content.milestones:
			if depth >= int(milestone.depth): spawn *= float(milestone.get("spawnMultiplier",1))
		spawn = minf(spawn,float(_content.gate.spawnMultiplierCap))
		_text(parent,"체력 ×%.2f" % hp,Rect2(x+3,270,98,27),"number",17,"ink",HORIZONTAL_ALIGNMENT_CENTER)
		_text(parent,"생성 ×%.2f" % spawn,Rect2(x+3,306,98,24),"number",16,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"체력 / 생성 배율 · 기본 지도 기준",Rect2(32,356,526,32),"body",14,"muted")
	_button(parent,"각성자 선택",Rect2(620,352,275,44),"primary",18)

func _selection(parent: Control) -> void:
	_base(parent,"각성자 · 시작 무기 선택","metaAssociationOffice")
	var ids := ["awakener","kangTaehoon","parkDojun","yoonHarin"]
	for i in range(ids.size()):
		var character: Dictionary = _content.characters[ids[i]]
		var x := 20+i*222
		_skin(parent,"panels","card",Rect2(x,82,214,145))
		_art(parent,_content_texture(character.portraitSprite),Rect2(x+9,89,91,102))
		_text(parent,character.name,Rect2(x+104,94,101,30),"heading",20,"accent" if i == 0 else "ink",HORIZONTAL_ALIGNMENT_CENTER)
		_text(parent,character.trait.description,Rect2(x+104,132,101,57),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
		_text(parent,character.trait.name,Rect2(x+10,195,194,22),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var weapons := ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]
	for i in range(weapons.size()):
		var id: String = weapons[i]
		var x := 20+i*149
		_skin(parent,"panels","card",Rect2(x,239,140,103))
		_art(parent,_content_texture(_content.weaponArt[id]),Rect2(x+13,245,114,42))
		var label := _text(parent,_content.weapons[id].name,Rect2(x+9,290,122,38),"control",15,"accent" if id == "manaBolt" else "ink",HORIZONTAL_ALIGNMENT_CENTER,true)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text(parent,"송진우 · 마력탄",Rect2(32,359,266,31),"heading",17,"accent")
	_text(parent,"다른 시작 무기 1종",Rect2(316,359,248,31),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_button(parent,"축복 선택으로",Rect2(620,352,275,44),"primary",18)

func _growth(parent: Control) -> void:
	_base(parent,"전략지원 · 성장","metaGrowthLab")
	var tabs := ["각성자","공용 무기","단군 축복"]
	for i in range(tabs.size()): _button(parent,tabs[i],Rect2(20+i*188,85,180,44),"selected" if i == 2 else "tab",16)
	_skin(parent,"panels","info",Rect2(20,142,211,200))
	var ids := ["cheonbuOath","unyieldingJangseung","samjogoWing","harvestKnot"]
	for i in range(ids.size()): _button(parent,_content.blessings[ids[i]].name,Rect2(31,151+i*46,189,44),"selected" if ids[i] == "harvestKnot" else "secondary",15)
	var blessing: Dictionary = _content.blessings.harvestKnot
	_skin(parent,"panels","card",Rect2(243,142,341,200))
	_art(parent,_content_texture(blessing.image),Rect2(259,153,309,170))
	_skin(parent,"panels","info",Rect2(596,85,299,257))
	_text(parent,blessing.name,Rect2(612,92,267,34),"heading",22,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,blessing.description,Rect2(612,132,267,44),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_text(parent,"단계 / 보유 조각",Rect2(612,184,167,27),"body",14,"muted")
	_text(parent,"0 / %d · 0" % int(_content.growth.maxLevel),Rect2(780,182,99,31),"number",19,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(blessing.modifiers.size()):
		var modifier: Dictionary = blessing.modifiers[i]
		var key := "currencyGain" if modifier.stat == "currencyGain" else "pickupRange"
		var name := "단계당 마력석 획득" if key == "currencyGain" else "단계당 획득 범위"
		_icon(parent,key,Rect2(613,219+i*32,22,24))
		_text(parent,name,Rect2(643,218+i*32,168,27),"body",14,"ink")
		_text(parent,"+%s%%" % str(snappedf((float(modifier.value)-1.0)*100.0,0.1)),Rect2(816,218+i*32,63,27),"number",18,"accent",HORIZONTAL_ALIGNMENT_RIGHT)
	var costs: Array = _content.growth.blessingCosts
	_text(parent,"해금 %d · 성장 %d / %d / %d / %d" % [costs[0],costs[1],costs[2],costs[3],costs[4]],Rect2(612,291,267,35),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER,true)
	_text(parent,"조각을 모아 해금하고 단계별로 성장",Rect2(32,358,536,30),"body",14,"muted")
	_button(parent,"해금 %d조각" % int(costs[0]),Rect2(620,352,275,44),"disabled",17)

func _archive(parent: Control) -> void:
	_base(parent,"자료집 · 아이템 상세","metaAssociationOffice")
	var groups := ["각성자","무기","몬스터","아이템","단군 축복"]
	for i in range(groups.size()): _button(parent,groups[i],Rect2(20,85+i*52,119,44),"selected" if i == 3 else "tab",16)
	_skin(parent,"panels","info",Rect2(150,85,204,257))
	var ids := ["phoenixMatch","vaultLedger","revengeFuse","ionConductor"]
	for i in range(ids.size()): _button(parent,_content.items[ids[i]].name,Rect2(162,96+i*52,180,44),"selected" if ids[i] == "vaultLedger" else "secondary",15)
	var item: Dictionary = _content.items.vaultLedger
	_skin(parent,"panels","info",Rect2(367,85,528,257))
	_text(parent,item.name,Rect2(386,92,490,34),"heading",23,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_art(parent,_content_texture(item.icon),Rect2(389,142,112,113))
	_text(parent,"희귀 · 고유 효과",Rect2(389,265,112,46),"body",14,"reward",HORIZONTAL_ALIGNMENT_CENTER,true)
	var description: String = str(item.description).replace(". ",".\n").replace(" · ","\n")
	_text(parent,description,Rect2(518,144,352,103),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_text(parent,"정확한 가격",Rect2(518,266,94,27),"body",14,"muted")
	_art(parent,_content_texture("magicStone"),Rect2(641,264,24,28))
	_text(parent,str(int(item.basePrice)),Rect2(675,263,66,31),"number",22,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_text(parent,"보유 상한",Rect2(758,264,86,29),"body",14,"muted")
	_text(parent,str(int(item.maxStacks)),Rect2(851,263,24,31),"number",22,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_text(parent,"구매처 · 게이트24",Rect2(518,307,357,25),"body",14,"muted")
	_text(parent,"조건 · 결과 · 패널티를 전체 문장으로 표시",Rect2(32,358,551,30),"body",14,"muted")
	_button(parent,"이전 화면",Rect2(620,352,275,44),"secondary",18)

func _settings(parent: Control) -> void:
	_base(parent,"설정","metaOfflineTerminal")
	_skin(parent,"panels","info",Rect2(20,85,541,257))
	_text(parent,"사운드",Rect2(35,92,511,35),"heading",22,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var fields := [["masterVolume","전체"],["musicVolume","배경음악"],["combatVolume","전투 효과음"],["uiVolume","UI 효과음"]]
	for i in range(fields.size()):
		var y := 136+i*48
		_text(parent,fields[i][1],Rect2(38,y,136,44),"body",15,"ink")
		_skin(parent,"buttons","tab",Rect2(184,y+15,286,14))
		var slider := HSlider.new(); slider.position = Vector2(184,y); slider.size = Vector2(286,44)
		slider.min_value = 0; slider.max_value = 100; slider.step = 1
		slider.value = round(float(_content.defaultMeta.settings[fields[i][0]])*100)
		for style in ["slider","grabber_area","grabber_area_highlight"]: slider.add_theme_stylebox_override(style,StyleBoxEmpty.new())
		var button_def: Dictionary = _theme.buttons.roles.selected
		var rect: Array = button_def.rect
		var image := Image.load_from_file(_design_dir.path_join(_theme.buttons.file)).get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3])))
		image.resize(28,18,Image.INTERPOLATE_LANCZOS)
		var knob := ImageTexture.create_from_image(image)
		for icon in ["grabber","grabber_highlight","grabber_disabled"]: slider.add_theme_icon_override(icon,knob)
		parent.add_child(slider)
		var value := _text(parent,str(int(slider.value)),Rect2(482,y,57,44),"number",20,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
		slider.value_changed.connect(func(number: float) -> void: value.text = str(int(number)))
	_skin(parent,"panels","info",Rect2(575,85,320,257))
	_text(parent,"음악 · 저장",Rect2(591,92,288,35),"heading",21,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"전투 배경음악은 낮게,\n효과음은 선명하게.",Rect2(597,143,276,49),"body",15,"ink",HORIZONTAL_ALIGNMENT_CENTER,true)
	_button(parent,"음악 사용 허용",Rect2(594,207,282,44),"selected",16)
	_button(parent,"백업 저장",Rect2(594,260,136,44),"secondary",15)
	_button(parent,"백업 가져오기",Rect2(740,260,136,44),"secondary",14)
	_text(parent,"설정 기본값 시안 · 오디오 재생과 저장 없음",Rect2(32,358,551,30),"body",14,"muted")
	_button(parent,"이전 화면",Rect2(620,352,275,44),"secondary",18)

func _hud_pause(parent: Control) -> void:
	_art(parent,_content_texture(_content.maps.seoul.thumbnail,false),Rect2(Vector2.ZERO,CANVAS),true)
	_art(parent,_content_texture(_content.characters.awakener.portraitSprite),Rect2(212,180,40,57))
	var positions := [Vector2(158,263),Vector2(478,321),Vector2(680,222),Vector2(769,319)]
	for i in range(positions.size()):
		var enemy: Dictionary = _content.enemies.crawler if i % 2 == 0 else _content.enemies.swarm
		_art(parent,_content_texture(enemy.visual.sprite),Rect2(positions[i],Vector2(38,38)))
	_skin(parent,"panels","header",Rect2(12,8,248,55))
	_art(parent,_content_texture(_content.characters.awakener.portraitSprite),Rect2(22,14,35,41))
	_text(parent,_content.characters.awakener.name,Rect2(67,11,88,29),"heading",17,"ink")
	_text(parent,"100 / 100",Rect2(153,12,94,28),"number",16,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_skin(parent,"buttons","selected",Rect2(67,47,179,8))
	_skin(parent,"panels","header",Rect2(383,8,148,55))
	_text(parent,"1 / %d" % int(_content.maps.seoul.totalWaves),Rect2(395,12,124,24),"number",19,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"웨이브 준비",Rect2(395,36,124,23),"control",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_skin(parent,"panels","header",Rect2(650,8,197,55))
	_art(parent,_content_texture("magicStone"),Rect2(667,17,26,32))
	_text(parent,"0",Rect2(710,14,120,38),"number",24,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_skin(parent,"buttons","secondary",Rect2(859,12,44,44)); _icon(parent,"pause",Rect2(869,22,24,24))
	_skin(parent,"panels","footer",Rect2(12,350,355,50))
	_text(parent,"장비 1 / 6",Rect2(23,360,70,28),"control",14,"ink")
	for i in range(6):
		_skin(parent,"buttons","selected" if i == 0 else "tab",Rect2(100+i*43,357,38,36))
		if i == 0: _art(parent,_content_texture(_content.weaponArt.manaBolt),Rect2(104,361,30,28))
	var scrim := ColorRect.new(); scrim.color = Color(0,0,0,0.5); scrim.size = CANVAS; parent.add_child(scrim)
	_skin(parent,"panels","popup",Rect2(287,90,341,246))
	_text(parent,"일시정지",Rect2(307,108,301,37),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_text(parent,"광화문 광장 · 심도 1",Rect2(307,153,301,29),"body",15,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_button(parent,"계속하기",Rect2(313,194,289,48),"primary",18)
	_button(parent,"출동 종료",Rect2(313,256,289,48),"secondary",17)
