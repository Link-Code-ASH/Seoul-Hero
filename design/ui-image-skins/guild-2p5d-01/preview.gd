extends Control

# This is an independent visual proposal. All controls change memory only.
# It does not load the gameplay project, Profile, guild_action or user saves.
const SIZE := Vector2(915,412)
const FACILITIES := ["office","research","expedition","production","recovery","workshop","revival","analysis"]
const NAMES := ["운영실","연구실","탐험부","생산실","회복실","장비공방","생환석 제조실","분석실"]
const EFFECTS := ["길드의 규모와 직원 수를 늘립니다.","경영 효율과 오프라인 보관량을 연구합니다.","직원을 탐험에 파견해 자재와 설계도를 찾습니다.","길드 코인과 성장 조각을 생산합니다.","각성자의 회복과 다음 출동을 지원합니다.","아이템을 강화하고 새로운 조합법을 해금합니다.","생환석을 제조하고 높은 등급으로 합성합니다.","각성자의 추가 옵션을 분석합니다."]
const DEFAULT_ANCHORS := [[0.17,0.70],[0.39,0.725],[0.61,0.75],[0.83,0.775],[0.21,0.42],[0.43,0.445],[0.65,0.47],[0.87,0.495]]

var _repository := ""
var _fonts: Dictionary = {}
var _textures: Dictionary = {}
var _layout: Dictionary = {}
var _view := "initial"
var _selected := -1
var _panel := ""
var _notice := "시설을 누르면 바로 관리합니다."
var _stage: Control
var _scene: Control
var _detail: Control
var _floor_rect := Rect2()
var _hit_regions: Array[Dictionary] = []
var _staff: Array[Dictionary] = []
var _age := 0.0
var _sd_textures: Array = []
var _levels: Array = [1,1,1,0,0,0,0,0]
var _jobs := {3:"construction"}
var _wallet := ["1,680","420","96","5"]
var _skin: Dictionary = {}
var _capture_mode := false

func _ready() -> void:
	_repository = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	var layout_file := ProjectSettings.globalize_path("res://assets/layout.json")
	if FileAccess.file_exists(layout_file):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(layout_file))
		if parsed is Dictionary: _layout = parsed
	_load_fonts()
	_load_skins()
	_load_sd()
	_capture_mode = "--capture" in OS.get_cmdline_user_args()
	set_view("expanded" if "--expanded" in OS.get_cmdline_user_args() else "initial")
	if _capture_mode: _capture.call_deferred()

func _load_fonts() -> void:
	for entry in [["body","Paperlogy-4Regular.ttf"],["control","Paperlogy-5Medium.ttf"],["heading","KMU80HaeongSans.ttf"],["brand","BMJUA.ttf"],["number","BarlowCondensed-SemiBold.ttf"]]:
		var filename := _repository.path_join("godot/assets/ui/fonts/"+str(entry[1]))
		if not FileAccess.file_exists(filename): continue
		var face := FontFile.new(); face.data = FileAccess.get_file_as_bytes(filename)
		_fonts[entry[0]] = face

func _load_skins() -> void:
	var filename := _repository.path_join("godot/data/visuals/ui_materials.json")
	if FileAccess.file_exists(filename):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(filename))
		_skin = parsed.get("image_skin",{})

func _load_sd() -> void:
	var filename := _repository.path_join("godot/data/visuals/actors.json")
	if not FileAccess.file_exists(filename): return
	var actors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(filename))
	for visual in [actors.npcs.hanSeoa,actors.characters.awakener]:
		var file := _repository.path_join("godot/"+str(visual.sprite).trim_prefix("res://"))
		var image := Image.new()
		if image.load(file)!=OK: continue
		var bounds: Array = visual.region
		var cut := image.get_region(Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])))
		_sd_textures.append(ImageTexture.create_from_image(cut))

func set_view(view: String) -> void:
	_view = view; _selected = 3 if view=="management" else -1
	_panel = "facility" if view=="management" else ""
	_notice = "시설을 누르면 바로 관리합니다."
	_levels = [1,0,0,0,0,0,0,0] if view=="initial" else [4,1,1,3,1,4,1,1]
	_jobs = {3:"construction"} if view=="initial" else {6:"upgrade"}
	_build()

func _build() -> void:
	if is_instance_valid(_stage):
		remove_child(_stage); _stage.queue_free()
	_hit_regions.clear(); _staff.clear()
	_stage = Control.new(); _stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage); _stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background(_stage)
	_scene = Control.new(); _scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.z_index = -1000
	_stage.add_child(_scene); _scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_floor()
	_header()
	_footer()
	if not _panel.is_empty(): _management()

func _background(parent: Node) -> void:
	var file := _repository.path_join("godot/design/ui-premium-v5/assets/lobby-rain.png")
	var pack := _load_image(file,false)
	if not pack.is_empty():
		var image := _picture(parent,pack.texture,Rect2(Vector2.ZERO,SIZE))
		image.modulate = Color(0.37,0.48,0.50,1); image.z_index = -2000

func _draw_floor() -> void:
	var space := Rect2(8,35,899,340)
	var floor_definition: Dictionary = _layout.get("floor",{})
	var floor := _asset(str(floor_definition.get("file","floor.png")))
	_floor_rect = space
	if not floor.is_empty():
		var factor := minf(space.size.x/floor.size.x,space.size.y/floor.size.y)
		var extent: Vector2 = floor.size*factor
		_floor_rect = Rect2(space.position+(space.size-extent)*0.5,extent)
		_picture(_scene,floor.texture,_floor_rect)
	var order := [4,5,6,7,0,1,2,3]
	for slot in order: _draw_facility(slot)
	if _view=="initial":
		var lock_point := _point(Vector2(0.54,0.40))
		var badge := _text(_scene,"운영실 Lv.3 · 추가 4구역 개방",Rect2(lock_point-Vector2(132,15),Vector2(264,30)),14,"#f5f8fa","control",HORIZONTAL_ALIGNMENT_CENTER)
		badge.z_index = 700
		badge.add_theme_color_override("font_outline_color",Color("#243448")); badge.add_theme_constant_override("outline_size",4)
	_add_staff()

func _slot_definition(slot: int) -> Dictionary:
	var authored: Array = _layout.get("slots",[])
	return authored[slot] if slot<authored.size() else {}

func _anchor(slot: int) -> Vector2:
	var config := _slot_definition(slot)
	var pair: Array = config.get("anchor",DEFAULT_ANCHORS[slot])
	return Vector2(float(pair[0]),float(pair[1]))

func _point(normalized: Vector2) -> Vector2:
	return _floor_rect.position+normalized*_floor_rect.size

func _draw_facility(slot: int) -> void:
	var locked := _view=="initial" and slot>=4
	var config := _slot_definition(slot)
	var anchor := _point(_anchor(slot))
	var width := float(config.get("width",148.0))*_floor_rect.size.x/855.0
	var polygon := PackedVector2Array()
	var authored: Array = config.get("polygon",[])
	if authored.is_empty():
		for offset in [Vector2(-0.105,0),Vector2(0,-0.055),Vector2(0.105,0),Vector2(0,0.065)]: polygon.append(_point(_anchor(slot)+offset))
	else:
		for pair in authored: polygon.append(_point(Vector2(float(pair[0]),float(pair[1]))))
	var hit := {"slot":slot,"polygon":polygon,"rect":Rect2(),"image":null,"locked":locked}
	if not locked and int(_levels[slot])==0 and _jobs.get(slot,"")!="construction":
		var marker := _text(_scene,"+ 건설",Rect2(anchor-Vector2(39,27),Vector2(78,44)),15,"#385e65","control",HORIZONTAL_ALIGNMENT_CENTER)
		marker.z_index = 10+floori(anchor.y)
	elif not locked:
		var file: String = "construction.png" if _jobs.get(slot,"")=="construction" else str(FACILITIES[slot])+".png"
		var pack := _asset(file)
		if not pack.is_empty():
			var contacts: Dictionary = _layout.get("assetAnchors",{})
			var pair: Array = contacts.get(FACILITIES[slot],config.get("contact",[0.5,0.86]))
			if file=="construction.png": pair = contacts.get("construction",[0.5,0.86])
			var contact := Vector2(float(pair[0]),float(pair[1]))
			var extent := Vector2(width,width*pack.size.y/pack.size.x)
			var rect := Rect2(anchor-contact*extent,extent)
			var image := _picture(_scene,pack.texture,rect)
			image.z_index = 10+floori(anchor.y)
			hit.rect = rect; hit.image = pack.image
			_draw_modules(slot,anchor,width)
			if _jobs.get(slot,"")=="upgrade":
				var progress := _text(_scene,"강화 중",Rect2(anchor-Vector2(34,29),Vector2(68,24)),14,"#dba957","control")
				progress.z_index = 40+floori(anchor.y)
	_hit_regions.append(hit)

func _draw_modules(slot: int, anchor: Vector2, width: float) -> void:
	var level := int(_levels[slot])
	var step := 3 if level>=10 else 2 if level>=7 else 1 if level>=4 else 0
	for index in range(step):
		var pack := _asset(["module-cabinet.png","module-monitor.png","module-core.png"][index])
		if pack.is_empty(): continue
		var extent := Vector2(width*0.22,width*0.22*pack.size.y/pack.size.x)
		var image := _picture(_scene,pack.texture,Rect2(anchor+Vector2(-width*0.43+index*width*0.2,-extent.y*0.95),extent))
		image.z_index = 30+floori(anchor.y)

func _add_staff() -> void:
	if _sd_textures.is_empty(): return
	var paths: Array = _layout.get("staffPaths",[])
	if paths.is_empty(): paths = [[[0.16,0.59],[0.38,0.615],[0.60,0.64],[0.82,0.665]],[[0.23,0.54],[0.43,0.57]],[[0.61,0.56],[0.83,0.59]]]
	for index in range(3 if _view!="initial" else 2):
		var path := PackedVector2Array()
		for pair in paths[index%paths.size()]: path.append(_point(Vector2(float(pair[0]),float(pair[1]))))
		var texture: Texture2D = _sd_textures[index%_sd_textures.size()]
		var height := 34.0*_floor_rect.size.x/855.0
		var extent := Vector2(height*texture.get_width()/float(texture.get_height()),height)
		var node := _picture(_scene,texture,Rect2(path[0]-Vector2(extent.x*0.5,extent.y),extent))
		node.z_index = 20+floori(path[0].y)
		_staff.append({"node":node,"path":path,"next":1 if path.size()>1 else 0,"pos":path[0],"size":extent,"phase":float(index)*1.7})

func _process(dt: float) -> void:
	_age += dt
	for actor in _staff:
		var route: PackedVector2Array = actor.path
		if route.is_empty(): continue
		var target: Vector2 = route[int(actor.next)]
		var previous: Vector2 = actor.pos
		actor.pos = previous.move_toward(target,dt*21.0*_floor_rect.size.x/855.0)
		if (actor.pos as Vector2).distance_to(target)<0.1: actor.next = (int(actor.next)+1)%route.size()
		var beat := absf(sin(_age*10.0+float(actor.phase)))*1.1
		actor.node.position = actor.pos-Vector2(actor.size.x*0.5,actor.size.y+beat)
		actor.node.rotation = sin(_age*10.0+float(actor.phase))*0.009
		actor.node.z_index = 20+floori(actor.pos.y)

func _header() -> void:
	_surface(_stage,"glass","tools",Rect2(12,7,891,52),0.88)
	_button(_stage,"‹",Rect2(20,11,44,44),func():
		if not _panel.is_empty(): _panel=""; _selected=-1; _build()
		else: get_tree().quit()
	,"secondary",25)
	_text(_stage,"서울 길드 본부",Rect2(78,10,262,30),23,"#f5f8fa","brand")
	_text(_stage,"사무소 · 운영실 Lv."+str(_levels[0]),Rect2(80,38,246,18),13,"#dbe6e8","body")
	for index in range(4):
		var x := 376.0+index*130.0
		_text(_stage,["길드 코인","마력자재","연구자료","가속권"][index],Rect2(x,11,116,18),13,"#dbe6e8","body",HORIZONTAL_ALIGNMENT_RIGHT)
		_text(_stage,_wallet[index],Rect2(x,28,116,28),22,"#ffffff","number",HORIZONTAL_ALIGNMENT_RIGHT)

func _footer() -> void:
	_surface(_stage,"glass","tools",Rect2(12,349,891,55),0.88)
	var actions := [["직원",func(): _open_panel("staff")],["작업",func(): _open_panel("jobs")],["수령",func(): _notice="생산 보상을 수령했습니다."; _build()],["작전 투입",func(): _notice="출동 화면으로 연결할 위치입니다."; _build()]]
	for index in range(4): _button(_stage,str(actions[index][0]),Rect2(22+index*220,355,210,44),actions[index][1],"primary" if index==3 else "secondary")
	var help := _text(_stage,_notice,Rect2(29,324,514 if not _panel.is_empty() else 852,20),13,"#eef4f1","body",HORIZONTAL_ALIGNMENT_CENTER)
	help.add_theme_color_override("font_outline_color",Color("#263d42")); help.add_theme_constant_override("outline_size",3)

func _open_panel(id: String) -> void:
	_panel = id; _selected = -1; _build()

func _management() -> void:
	_detail = Control.new(); _detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_detail); _detail.position = Vector2(559,65); _detail.size = Vector2(344,279)
	_surface(_detail,"cstore","card",Rect2(Vector2.ZERO,_detail.size))
	var title := "직원 관리" if _panel=="staff" else "진행 작업" if _panel=="jobs" else "잠긴 구역" if _selected>=4 and _view=="initial" else "빈 구역 · 건설" if _selected>=0 and int(_levels[_selected])==0 and not _jobs.has(_selected) else str(NAMES[_selected]) if _selected>=0 else "길드 관리"
	_text(_detail,title,Rect2(18,11,246,34),21,"#243448","heading")
	_button(_detail,"닫기",Rect2(270,8,58,44),func(): _panel=""; _selected=-1; _build(),"secondary",13)
	var detail_top := 58.0
	if _panel=="facility" and _selected>=0 and int(_levels[_selected])>0 and not (_selected>=4 and _view=="initial"):
		var selected_art := _asset(str(FACILITIES[_selected])+".png")
		if not selected_art.is_empty():
			var box := Rect2(18,51,108,51)
			var factor := minf(box.size.x/selected_art.size.x,box.size.y/selected_art.size.y)
			var extent: Vector2 = selected_art.size*factor
			_picture(_detail,selected_art.texture,Rect2(box.position+(box.size-extent)*0.5,extent))
			_text(_detail,"Lv.%d / 10" % _levels[_selected],Rect2(148,52,166,26),20,"#267f75","heading")
			_text(_detail,"운영 중",Rect2(148,79,166,22),14,"#657787","body")
			detail_top = 109.0
	var scroll := ScrollContainer.new(); _detail.add_child(scroll)
	scroll.position = Vector2(18,detail_top); scroll.size = Vector2(310,262.0-detail_top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new(); box.custom_minimum_size.x = 290; box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10); scroll.add_child(box)
	if _panel=="staff":
		_copy(box,"직원 3명 · 대기 1명",true)
		_copy(box,"한서아 · 운영실 근무\n길드 업무와 신입 직원 교육을 돕습니다.")
		_memory_button(box,"시설 배치 변경","직원 배치를 변경했습니다.")
		_copy(box,"지원자 채용 · 남은 정원 3명")
		_memory_button(box,"신규 직원 채용","새 직원을 채용했습니다.")
		_memory_button(box,"직원 교육 · 2시간","직원 교육을 시작했습니다.")
	elif _panel=="jobs":
		_copy(box,"진행 중인 작업 1개",true)
		_copy(box,"생산실 건설 · 12분 남음" if _view=="initial" else "생환석 제조실 강화 · 2시간 남음")
		_memory_button(box,"15분 가속권 사용","작업 시간을 단축했습니다.")
		_memory_button(box,"코인으로 즉시 완료","작업을 완료했습니다.")
	elif _selected>=4 and _view=="initial":
		_copy(box,"운영실 Lv.3에서 개방",true)
		_copy(box,"추가 구역도 같은 층에 이어집니다. 운영실을 강화하면 4곳에 시설을 더 지을 수 있습니다.")
		_memory_button(box,"운영실 강화 보기","운영실 강화 조건을 확인합니다.")
	elif _selected>=0:
		if int(_levels[_selected])==0 and not _jobs.has(_selected):
			_copy(box,"이 구역에 시설을 건설합니다.",true)
			_copy(box,str(NAMES[_selected])+" · "+str(EFFECTS[_selected]))
			_memory_button(box,"건설 · 180 코인 · 60 자재","시안에서 건설 버튼을 선택했습니다.")
			return
		if detail_top<100.0: _copy(box,"Lv.%d / 10" % _levels[_selected],true)
		_copy(box,str(EFFECTS[_selected]))
		if _jobs.get(_selected,"")=="construction":
			_copy(box,"건설 중 · 12분 남음")
			_memory_button(box,"15분 가속권 사용","건설을 완료했습니다.")
		else:
			_memory_button(box,"시설 강화 · 180 코인 · 60 자재","시설 강화를 시작했습니다.")
			_memory_button(box,"직원 배치","직원을 시설에 배치했습니다.")
			if _selected==3:
				_copy(box,"성장 조각 생산",true)
				_copy(box,"캐릭터 조각 · 송진우\n무기 조각 · 마력탄\n축복 조각 · 운영실 Lv.5에서 해금")
				_memory_button(box,"생산 대상 변경","생산 대상을 변경했습니다.")
				_copy(box,"코인과 조각은 동시에 생산됩니다.\n보관 4.2 / 24시간")
			elif _selected==5:
				_copy(box,"조합법 연구 · 전투 상점에서 사용",true)
				_memory_button(box,"조합법 연구 시작","조합법 연구를 시작했습니다.")
			else: _memory_button(box,"시설 업무 시작","시설 업무를 시작했습니다.")

func _copy(parent: Node, caption: String, accent: bool = false) -> Label:
	var label := Label.new(); label.text = caption; label.custom_minimum_size.x = 290
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_constant_override("line_spacing",4)
	_apply_font(label,"heading" if accent else "body",16 if accent else 14)
	label.add_theme_color_override("font_color",Color("#267f75" if accent else "#243448"))
	parent.add_child(label); return label

func _memory_button(parent: Node, caption: String, result: String) -> Button:
	var button := _button(parent,caption,Rect2(0,0,290,44),func(): _notice=result; _build(),"secondary",14)
	button.custom_minimum_size = Vector2(290,44)
	return button

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_select_at(event.position); accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_select_at(event.position); accept_event()

func _select_at(point: Vector2) -> void:
	if is_instance_valid(_detail) and _detail.get_rect().has_point(point) and not _panel.is_empty(): return
	for index in range(_hit_regions.size()-1,-1,-1):
		var region: Dictionary = _hit_regions[index]
		var hit := Geometry2D.is_point_in_polygon(point,region.polygon)
		if not hit and region.image is Image and region.rect.has_point(point):
			var local: Vector2 = (point-region.rect.position)/region.rect.size*(region.image as Image).get_size()
			var pixel := Vector2i(clampi(int(local.x),0,region.image.get_width()-1),clampi(int(local.y),0,region.image.get_height()-1))
			hit = region.image.get_pixelv(pixel).a>=0.28
		if hit:
			_selected = int(region.slot); _panel = "facility"; _build(); return

func _apply_font(control: Control, role: String, font_size: int) -> void:
	if _fonts.has(role): control.add_theme_font_override("font",_fonts[role])
	control.add_theme_font_size_override("font_size",font_size)

func _text(parent: Node, caption: String, rect: Rect2, font_size: int = 14, color: String = "#243448", role: String = "body", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new(); label.text = caption; _apply_font(label,role,font_size)
	label.position = rect.position; label.size = rect.size; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color",Color(color))
	parent.add_child(label); return label

func _picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new(); result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.texture = texture; result.position = rect.position; result.size = rect.size
	result.stretch_mode = TextureRect.STRETCH_SCALE; result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result); return result

func _surface(parent: Node, family: String, role: String, rect: Rect2, opacity: float = 1.0) -> NinePatchRect:
	var group: Dictionary = _skin.get(family,{})
	var entry: Dictionary = group.get("roles",{}).get(role,{})
	var image_id := str(entry.get("image_id",group.get("image_id","")))
	var files := {"imageSkinButtons":"godot/assets/ui/image-skin/buttons_01.png","imageSkinPanels":"godot/assets/ui/image-skin/panels_01.png","runtimeUiGlass1":"godot/assets/ui/image-skin/enamel-glass/glass_01.png","imageSkinLobbyGlass":"godot/assets/ui/image-skin/lobby_glass_01.png"}
	files.runtimeUiCStore2 = "godot/assets/ui/image-skin/enamel-glass/cstore_surfaces_02.png"
	files.runtimeUiCStoreControls2 = "godot/assets/ui/image-skin/enamel-glass/cstore_controls_02.png"
	var pack := _load_image(_repository.path_join(str(files.get(image_id,""))),false)
	var patch := NinePatchRect.new(); patch.mouse_filter = Control.MOUSE_FILTER_IGNORE; patch.show_behind_parent = true
	patch.position = rect.position; patch.size = rect.size*4.0; patch.scale = Vector2.ONE*0.25; patch.modulate.a = opacity
	if not pack.is_empty():
		patch.texture = pack.texture
		var bounds: Array = entry.get("rect",[0,0,pack.size.x,pack.size.y])
		patch.region_rect = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
		var slices: Array = entry.get("slice",[0,0,0,0])
		patch.patch_margin_left = int(slices[0]); patch.patch_margin_top = int(slices[1]); patch.patch_margin_right = int(slices[2]); patch.patch_margin_bottom = int(slices[3])
	parent.add_child(patch)
	return patch

func _button(parent: Node, caption: String, rect: Rect2, command: Callable, role: String = "secondary", font_size: int = 14) -> Button:
	var button := Button.new(); button.text = caption; _apply_font(button,"control",font_size)
	button.position = rect.position; button.size = rect.size; button.custom_minimum_size = Vector2(rect.size.x,44)
	button.add_theme_color_override("font_color",Color("#ffffff" if role=="primary" else "#243448"))
	button.add_theme_color_override("font_hover_color",Color("#ffffff" if role=="primary" else "#243448"))
	button.add_theme_color_override("font_pressed_color",Color("#ffffff" if role=="primary" else "#243448"))
	for state in ["normal","hover","pressed","focus"]:
		var blank := StyleBoxEmpty.new(); blank.set_content_margin(SIDE_LEFT,10); blank.set_content_margin(SIDE_RIGHT,10)
		button.add_theme_stylebox_override(state,blank)
	parent.add_child(button)
	var surface := _surface(button,"cstore","next" if role=="primary" else "secondary",Rect2(Vector2.ZERO,button.size))
	button.move_child(surface,0)
	button.resized.connect(func(): surface.size=button.size*4.0)
	button.pressed.connect(command)
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F1: set_view("initial")
		KEY_F2: set_view("expanded")
		KEY_F3: set_view("management")
		KEY_ESCAPE:
			if not _panel.is_empty(): _panel=""; _selected=-1; _build()
			else: get_tree().quit()

func _asset(file: String, trim: bool = true) -> Dictionary:
	return _load_image(ProjectSettings.globalize_path("res://assets/"+file),trim)

func _load_image(file: String, trim: bool = true) -> Dictionary:
	var key := file+str(trim)
	if _textures.has(key): return _textures[key]
	if not FileAccess.file_exists(file): return {}
	var image := Image.new()
	if image.load(file)!=OK: return {}
	var source_size := image.get_size()
	var used := image.get_used_rect() if trim else Rect2i(Vector2i.ZERO,source_size)
	if used.size.x<=0 or used.size.y<=0: return {}
	if trim: image=image.get_region(used)
	image.generate_mipmaps()
	var result := {"texture":ImageTexture.create_from_image(image),"image":image,"size":Vector2(image.get_size()),"sourceSize":source_size,"bounds":used}
	_textures[key] = result; return result

func _capture() -> void:
	var output := ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(output)
	for view in ["initial","expanded","management"]:
		set_view(view)
		await get_tree().process_frame; await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(output.path_join(str(view)+".png"))
	await _capture_board(output)
	get_tree().quit()

func _capture_board(output: String) -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(1536,1100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; viewport.transparent_bg = false
	add_child(viewport)
	var board := Control.new(); board.size=Vector2(1536,1100); viewport.add_child(board)
	_text(board,"길드 본부 · 원화와 시설 단계",Rect2(32,18,1472,42),30,"#edf5f3","heading")
	var floor := _asset("floor.png")
	if not floor.is_empty():
		var ratio := minf(800.0/floor.size.x,310.0/floor.size.y)
		var extent: Vector2 = floor.size*ratio
		_picture(board,floor.texture,Rect2(Vector2(34,74)+(Vector2(800,310)-extent)*0.5,extent))
	var construction := _asset("construction.png")
	if not construction.is_empty():
		var slot := Rect2(850,77,280,273)
		var factor := minf(slot.size.x/construction.size.x,slot.size.y/construction.size.y)
		var extent: Vector2 = construction.size*factor
		_picture(board,construction.texture,Rect2(slot.position+(slot.size-extent)*0.5,extent))
		_text(board,"공사 상태",Rect2(850,350,280,32),19,"#edf5f3","body",HORIZONTAL_ALIGNMENT_CENTER)
	for index in range(3):
		var pack := _asset(["module-cabinet.png","module-monitor.png","module-core.png"][index])
		if pack.is_empty(): continue
		var slot := Rect2(1160+index*117,82,108,252)
		var factor := minf(slot.size.x/pack.size.x,slot.size.y/pack.size.y)
		var extent: Vector2 = pack.size*factor
		_picture(board,pack.texture,Rect2(slot.position+(slot.size-extent)*0.5,extent))
	_text(board,"Lv.4 · Lv.7 · Lv.10 추가 모듈",Rect2(1150,350,368,32),18,"#edf5f3","body",HORIZONTAL_ALIGNMENT_CENTER)
	for index in range(8):
		var pack := _asset(str(FACILITIES[index])+".png")
		var slot := Rect2(24+(index%4)*378,425+floori(index/4.0)*318,354,264)
		if not pack.is_empty():
			var factor := minf(slot.size.x/pack.size.x,slot.size.y/pack.size.y)
			var extent: Vector2 = pack.size*factor
			_picture(board,pack.texture,Rect2(slot.position+(slot.size-extent)*0.5,extent))
		_text(board,str(NAMES[index]),Rect2(slot.position+Vector2(0,slot.size.y+8),Vector2(slot.size.x,30)),22,"#edf5f3","heading",HORIZONTAL_ALIGNMENT_CENTER)
	await get_tree().process_frame; await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("assets-board.png"))
	viewport.queue_free()
