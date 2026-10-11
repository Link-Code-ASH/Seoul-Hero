extends Control

# Independent visual proposal: all facility, job and floor changes stay in memory.
# No Profile, gameplay autoloads, user saves or guild_action are referenced.
const WORLD = preload("res://world.gd")
const SIZE := Vector2(915,412)
const FACILITIES := ["office","research","expedition","production","recovery","workshop","revival","analysis"]
const NAMES := ["운영실","연구실","탐험부","생산실","회복실","장비공방","생환석 제조실","분석실"]
const EFFECTS := ["길드의 규모와 직원 정원을 늘립니다.","생산 효율과 보관량을 연구합니다.","직원을 탐험에 파견해 자재를 찾습니다.","코인과 성장 조각을 생산합니다.","각성자의 회복과 출동을 지원합니다.","아이템 강화와 조합법 연구를 진행합니다.","생환석을 제조하고 합성합니다.","각성자의 추가 옵션을 분석합니다."]
const OFFICE_LEVELS := [1,2,3]
const FACILITY_UNLOCKS := [1,1,1,1,2,3,5,7]

var _repository := ""
var _fonts: Dictionary = {}
var _textures: Dictionary = {}
var _skin: Dictionary = {}
var _data: Dictionary = {}
var _model: Dictionary = {}
var _view := "initial"
var _selected := -1
var _selected_id := ""
var _selected_floor := 1
var _panel := ""
var _tab := "management"
var _detail := ""
var _tab_memory: Dictionary = {}
var _scroll_memory: Dictionary = {}
var _pane_scroll: ScrollContainer
var _pane_key := ""
var _notice := ""
var _building: Control
var _world: Node2D
var _overlay: Control
var _pane: Control
var _scroll_y := 0.0
var _pointer := -2
var _start := Vector2.ZERO
var _previous := Vector2.ZERO
var _dragging := false
var _capture_mode := false
var _age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_repository = ProjectSettings.globalize_path("res://").path_join("../../..").simplify_path()
	_load_fonts()
	_load_skins()
	var content_file := _repository.path_join("godot/data/content.json")
	if FileAccess.file_exists(content_file):
		var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(content_file))
		_data = content.get("guildManagement",{})
	var backdrop := _load_image(_repository.path_join("godot/design/ui-premium-v5/assets/lobby-rain.png"),false)
	if not backdrop.is_empty():
		var image := _picture(self,backdrop.texture,Rect2(Vector2.ZERO,SIZE))
		image.modulate = Color(0.43,0.48,0.62,1); image.z_index = -100
	_building = Control.new(); _building.clip_contents = true
	_building.mouse_filter = Control.MOUSE_FILTER_STOP
	_building.position = Vector2(12,65); _building.size = Vector2(547,335)
	add_child(_building); _building.gui_input.connect(_on_building_input)
	_world = WORLD.new(); _building.add_child(_world)
	_world.configure(_world_assets()); _world.set_viewport_width(547)
	_capture_mode = "--capture" in OS.get_cmdline_user_args()
	set_view("expanded" if "--expanded" in OS.get_cmdline_user_args() else "initial")
	if _capture_mode: _capture.call_deferred()

func _load_fonts() -> void:
	for entry in [["body","Paperlogy-4Regular.ttf"],["control","Paperlogy-5Medium.ttf"],["heading","KMU80HaeongSans.ttf"],["brand","BMJUA.ttf"],["number","BarlowCondensed-SemiBold.ttf"]]:
		var filename := _repository.path_join("godot/assets/ui/fonts/"+str(entry[1]))
		if FileAccess.file_exists(filename):
			var face := FontFile.new(); face.data = FileAccess.get_file_as_bytes(filename)
			_fonts[entry[0]] = face

func _load_skins() -> void:
	var filename := _repository.path_join("godot/data/visuals/ui_materials.json")
	if FileAccess.file_exists(filename):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(filename))
		_skin = parsed.get("image_skin",{})

func _world_assets() -> Dictionary:
	var actors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors.json"))
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/guild.json"))
	var staff: Dictionary = actors.npcs.hanSeoa.duplicate(true)
	var awakener: Dictionary = actors.characters.awakener.duplicate(true)
	var staff_texture := _cropped_actor("staff.png",staff)
	var awk_texture := _cropped_actor("awk.png",awakener)
	staff.texture = staff_texture; awakener.texture = awk_texture
	var rows := {}
	var room_names := {}
	for index in range(FACILITIES.size()):
		rows[FACILITIES[index]] = index
		room_names[FACILITIES[index]] = _facility_name(FACILITIES[index])
	return {"rooms":_asset("rooms.png").get("texture"),"states":_asset("states.png").get("texture"),"structure":_asset("structure.png").get("texture"),"staff_texture":staff_texture,"awk_texture":awk_texture,"staff_profile":staff,"awk_profile":awakener,"roomRows":rows,"roomNames":room_names,"structure_meta":art.get("walk",{}),"font":_fonts.get("heading")}

func _cropped_actor(file: String, profile: Dictionary) -> Texture2D:
	var pack := _asset(file)
	if pack.is_empty(): return null
	var image: Image = pack.image
	var region: Array = profile.get("region",[0,0,image.get_width(),image.get_height()])
	var cropped := image.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	cropped.generate_mipmaps()
	profile.region = [0,0,cropped.get_width(),cropped.get_height()]
	return ImageTexture.create_from_image(cropped)

func set_view(view: String) -> void:
	_save_panel_scroll()
	_view=view; _selected=-1; _selected_id=""; _selected_floor=1
	_panel=""; _tab="management"; _detail=""; _notice=""
	_tab_memory.clear(); _scroll_memory.clear(); _pane_key=""
	var facilities: Array = []
	if view=="initial":
		facilities=[{"id":"office","slot":0,"level":1,"construction":false},{"id":"production","slot":2,"level":0,"construction":true,"remaining":720.0,"targetLevel":1}]
	else:
		var levels := [7,4,1,7,1,4,1,1]
		for slot in range(8):
			facilities.append({"id":FACILITIES[slot],"slot":slot,"level":levels[slot],"construction":slot==6,"remaining":7200.0 if slot==6 else 0.0,"targetLevel":2})
	var staff: Array = [{"id":"staffSeoYeon","slot":0,"activity":"work","level":2},{"id":"staffMinJae","slot":0 if view=="initial" else 3,"activity":"idle" if view=="initial" else "work","level":1}]
	var jobs: Array = []
	if view!="initial":
		staff.append({"id":"staffHaEun","slot":5,"activity":"research","level":3})
		staff.append({"id":"staffJiWoo","slot":2,"activity":"expedition","level":2})
		jobs=[{"id":"recipe-research","target":"workshop","kind":"research","title":"조율 마력핵 조합법 연구","remaining":1460.0,"staff":["staffHaEun"],"done":false},{"id":"gate-survey","target":"expedition","kind":"expedition","title":"게이트 잔향 조사","remaining":4620.0,"staff":["staffJiWoo"],"done":false}]
	_model={"unlockedFloors":1 if view=="initial" else 3,"selectedSlot":-1,"facilities":facilities,"staff":staff,"jobs":jobs,"productionTarget":"송진우 조각","rewardsClaimed":false}
	_world.set_model(_model)
	_scroll_y=_max_scroll()
	if view in ["management","staff","jobs","office"]:
		_selected=6 if view=="jobs" else 0 if view=="office" else 5
		_selected_id=str(_facility_at(_selected).id); _selected_floor=floori(_selected/3.0)+1
		_panel="facility"; _tab="staff" if view=="staff" else "jobs" if view=="jobs" else "management"
		_tab_memory[_selected_id]=_tab
		_model.selectedSlot=_selected
		_scroll_y=clampf(_world.floor_center(_selected_floor).y-_building.size.y*0.5,0,_max_scroll())
	_rebuild(); _apply_scroll()

func _save_panel_scroll() -> void:
	if is_instance_valid(_pane_scroll) and not _pane_key.is_empty():
		_scroll_memory[_pane_key]=_pane_scroll.scroll_vertical

func _rebuild() -> void:
	_save_panel_scroll()
	var facility := _selected_facility()
	if not facility.is_empty():
		_selected=int(facility.slot); _selected_floor=floori(_selected/3.0)+1
	_model.selectedSlot=_selected if _panel=="facility" else -1
	_world.set_model(_model)
	_apply_scroll()
	if is_instance_valid(_overlay):
		remove_child(_overlay); _overlay.queue_free()
	_overlay=Control.new(); _overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; _overlay.z_index=10
	add_child(_overlay); _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pane=Control.new(); _pane.mouse_filter=Control.MOUSE_FILTER_STOP
	_overlay.add_child(_pane); _pane.position=Vector2(573,65); _pane.size=Vector2(330,335)
	_pane_scroll=null; _pane_key=""
	_header()
	if not _panel.is_empty(): _management()

func _max_scroll() -> float:
	return maxf(0,_world.get_content_height()-_building.size.y)

func _apply_scroll() -> void:
	_scroll_y=clampf(_scroll_y,0,_max_scroll())
	_world.position=Vector2(0,-_scroll_y)

func _header() -> void:
	_surface(_overlay,"glass","tools",Rect2(12,7,891,52),0.9)
	_button(_overlay,"‹",Rect2(20,11,44,44),_back,"secondary",25)
	_text(_overlay,"서울 길드 본부",Rect2(78,9,236,31),23,"#f5f8fa","brand")
	_text(_overlay,"%d층 · 사무실 %d칸" % [_model.unlockedFloors,int(_model.unlockedFloors)*3],Rect2(80,38,239,18),13,"#dbe6e8","body")
	for index in range(4):
		var x := 376.0+index*130.0
		_text(_overlay,["길드 코인","마력자재","연구자료","가속권"][index],Rect2(x,11,116,18),13,"#dbe6e8","body",HORIZONTAL_ALIGNMENT_RIGHT)
		_text(_overlay,["1,680","420","96","5"][index],Rect2(x,28,116,28),22,"#ffffff","number",HORIZONTAL_ALIGNMENT_RIGHT)

func _back() -> void:
	if not _panel.is_empty():
		_save_panel_scroll(); _panel=""; _selected=-1; _selected_id=""; _detail=""; _notice=""
		_model.selectedSlot=-1; _rebuild()
	else: get_tree().quit()

func _facility_at(slot: int) -> Dictionary:
	for facility in _model.facilities:
		if int(facility.slot)==slot: return facility
	return {}

func _selected_facility() -> Dictionary:
	if _selected_id.is_empty(): return _facility_at(_selected)
	for facility in _model.facilities:
		if str(facility.id)==_selected_id: return facility
	return {}

func _facility_name(id: String) -> String:
	var index := FACILITIES.find(id)
	return str(_data.get("facilities",{}).get(id,{}).get("name",NAMES[index] if index>=0 else id))

func _employee_name(id: String) -> String:
	return str(_data.get("employees",{}).get(id,{}).get("name",id))

func _select_slot(slot: int) -> void:
	_save_panel_scroll()
	_selected=slot; _selected_floor=floori(slot/3.0)+1
	var facility := _facility_at(slot)
	_selected_id=str(facility.get("id","")); _panel="facility"; _detail=""; _notice=""
	_tab=str(_tab_memory.get(_selected_id,"management")) if not _selected_id.is_empty() else "management"
	_pane_key=""; _rebuild()

func _select_at(point: Vector2) -> void:
	var local := point+Vector2(0,_scroll_y)
	var floor_number: int = _world.floor_at(local)
	if floor_number<=0: return
	if floor_number>int(_model.unlockedFloors):
		_save_panel_scroll(); _selected_floor=floor_number; _selected=-1; _selected_id=""; _panel="locked"; _detail=""; _notice=""; _pane_key=""; _rebuild(); return
	var slot: int = _world.slot_at(local)
	if slot>=0: _select_slot(slot)

func _change_tab(tab: String) -> void:
	_save_panel_scroll(); _tab=tab; _tab_memory[_selected_id]=tab; _detail=""; _notice=""; _pane_key=""; _rebuild()

func _open_detail(detail: String) -> void:
	_save_panel_scroll(); _detail=detail; _notice=""; _pane_key=""; _rebuild()

func _on_building_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_y-=52; _apply_scroll(); _building.accept_event()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_y+=52; _apply_scroll(); _building.accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and _pointer==-2: _begin_pointer(-1,event.position)
			elif _pointer==-1: _end_pointer(event.position,false)
			_building.accept_event()
	elif event is InputEventMouseMotion and _pointer==-1:
		_drag_pointer(event.position); _building.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and _pointer==-2: _begin_pointer(event.index,event.position)
		elif event.index==_pointer: _end_pointer(event.position,event.canceled)
		_building.accept_event()
	elif event is InputEventScreenDrag and event.index==_pointer:
		_drag_pointer(event.position); _building.accept_event()

func _begin_pointer(index: int, point: Vector2) -> void:
	_pointer=index; _start=point; _previous=point; _dragging=false

func _drag_pointer(point: Vector2) -> void:
	if not _dragging and point.distance_to(_start)>=8: _dragging=true
	if _dragging:
		_scroll_y-=point.y-_previous.y; _apply_scroll()
	_previous=point

func _end_pointer(point: Vector2, canceled: bool) -> void:
	var select := not _dragging and not canceled and Rect2(Vector2.ZERO,_building.size).has_point(point)
	_pointer=-2; _dragging=false
	if select: _select_at(point)

func _input(event: InputEvent) -> void:
	if _pointer==-2 or not is_instance_valid(_building): return
	var global_bounds := _building.get_global_rect()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _pointer==-1:
		if not global_bounds.has_point(event.position): _pointer=-2; _dragging=false
	elif event is InputEventScreenTouch and event.index==_pointer and not event.pressed:
		if event.canceled or not global_bounds.has_point(event.position): _pointer=-2; _dragging=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pointer=-2; _dragging=false

func _management() -> void:
	_surface(_pane,"cstore","card",Rect2(Vector2.ZERO,_pane.size))
	var facility := _selected_facility()
	var title := "%d층 증축" % _selected_floor if _panel=="locked" else "빈 사무실" if facility.is_empty() else _facility_name(str(facility.id))
	_text(_pane,title,Rect2(16,8,232,31),20,"#243448","heading")
	_button(_pane,"닫기",Rect2(258,8,58,44),_back,"secondary",13)
	var subtitle := "운영실 성장으로 사무실 3칸 개방" if _panel=="locked" else "%d층 · 사무실 %d" % [_selected_floor,_selected%3+1]
	if not facility.is_empty(): subtitle+=" · Lv.%d / 10" % int(facility.level)
	_text(_pane,subtitle,Rect2(17,40,293,20),13,"#597081","body")
	var has_tabs := not facility.is_empty() and int(facility.level)>0
	var content_top := 68.0
	if has_tabs:
		for index in range(3):
			var key: String = ["management","staff","jobs"][index]
			_button(_pane,["관리","직원","작업"][index],Rect2(16+index*101,67,97,44),_change_tab.bind(key),"primary" if _tab==key else "secondary")
		content_top=120
	_pane_scroll=ScrollContainer.new(); _pane.add_child(_pane_scroll)
	_pane_scroll.position=Vector2(16,content_top); _pane_scroll.size=Vector2(300,319-content_top)
	_pane_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	var box:=VBoxContainer.new(); box.custom_minimum_size.x=280; box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",10); _pane_scroll.add_child(box)
	var identity := _selected_id if not _selected_id.is_empty() else "locked:%d" % _selected_floor if _panel=="locked" else "empty:%d" % _selected
	_pane_key=identity+":"+_tab+":"+_detail
	if not _notice.is_empty(): _copy(box,_notice,true)
	if _panel=="locked":
		var level: int = OFFICE_LEVELS[mini(_selected_floor-1,OFFICE_LEVELS.size()-1)]
		_copy(box,"운영실 Lv.%d에서 개방" % level,true)
		_copy(box,"운영실을 강화하면 위층의 사무실 세 칸을 사용할 수 있습니다.")
		_action(box,"운영실 관리",_select_slot.bind(0))
	elif _detail=="move": _move_panel(box,facility)
	elif _detail=="assign": _assignment_panel(box,facility)
	elif _detail=="production": _production_panel(box)
	elif _detail=="hire": _hire_panel(box)
	elif _detail.begins_with("employee:"): _employee_panel(box,_detail.trim_prefix("employee:"))
	elif _detail=="item": _item_panel(box,facility)
	elif has_tabs and _tab=="staff": _staff_panel(box,facility)
	elif has_tabs and _tab=="jobs": _jobs_panel(box,facility)
	else: _facility_panel(box,facility)
	_pane_scroll.set_deferred("scroll_vertical",int(_scroll_memory.get(_pane_key,0)))

func _level_definition(id: String, target_level: int) -> Dictionary:
	var levels: Array = _data.get("facilities",{}).get(id,{}).get("levels",[])
	return levels[target_level-1] if target_level>0 and target_level<=levels.size() else {}

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for pair in [["coins","코인"],["materials","자재"],["researchData","연구자료"]]:
		if int(cost.get(pair[0],0))>0: parts.append(str(pair[1])+" "+str(int(cost[pair[0]])))
	return " · ".join(parts) if not parts.is_empty() else "추가 비용 없음"

func _duration_text(seconds: float) -> String:
	var minutes := maxi(1,ceili(seconds/60.0))
	return "%d시간 %d분" % [minutes/60,minutes%60] if minutes>=60 else "%d분" % minutes

func _facility_panel(box: VBoxContainer, facility: Dictionary) -> void:
	if facility.is_empty():
		_copy(box,"건설할 시설",true)
		var available:=0
		for index in range(FACILITIES.size()):
			var id: String = FACILITIES[index]
			var exists:=false
			for built in _model.facilities:
				if str(built.id)==id: exists=true
			if exists: continue
			available+=1
			var definition := _level_definition(id,1)
			_copy(box,_facility_name(id),true)
			_copy(box,str(_data.get("facilities",{}).get(id,{}).get("description",EFFECTS[index])))
			_copy(box,_cost_text(definition.get("cost",{}))+"\n공사 "+_duration_text(float(definition.get("durationMs",60000))/1000.0))
			var unlocked := int(_facility_at(0).get("level",1))>=int(FACILITY_UNLOCKS[index])
			var action := _action(box,"건설 시작" if unlocked else "운영실 Lv.%d 필요" % FACILITY_UNLOCKS[index],_construct.bind(id,_selected))
			action.disabled=not unlocked
			if not unlocked: action.modulate.a=0.55
		if available==0: _copy(box,"모든 시설을 건설했습니다. 새로운 시설을 위한 여유 사무실입니다.")
		return
	var id:=str(facility.id)
	var level:=int(facility.level)
	var config: Dictionary = _data.get("facilities",{}).get(id,{})
	_copy(box,str(config.get("description",EFFECTS[FACILITIES.find(id)])))
	_copy(box,"시설 효과",true)
	_copy(box,"Lv.2 · 2층, 사무실 6칸\nLv.3 · 3층, 사무실 9칸\nLv.4 · 공사 2개 동시 진행" if id=="office" else str(config.get("effect",EFFECTS[FACILITIES.find(id)])))
	if bool(facility.get("construction",false)):
		_copy(box,"신규 건설 중" if level==0 else "Lv.%d → %d 강화 중" % [level,int(facility.targetLevel)],true)
		_construction_detail(box,facility)
		return
	if level<10:
		var definition := _level_definition(id,level+1)
		_copy(box,"다음 강화 · Lv.%d → %d" % [level,level+1],true)
		_copy(box,_cost_text(definition.get("cost",{}))+"\n공사 "+_duration_text(float(definition.get("durationMs",60000))/1000.0))
		_action(box,"시설 강화 시작",_upgrade.bind(facility))
	else: _copy(box,"최대 레벨에 도달했습니다.",true)
	if id!="office": _action(box,"시설 이동",_open_detail.bind("move"))
	match id:
		"office":
			_copy(box,"길드 운영",true)
			_action(box,"보관 보상 모두 수령",_claim)
			_action(box,"작전 투입",func(): _notice="출동 준비 화면으로 이동합니다."; _rebuild(),"primary")
			_action(box,"전체 직원 채용·배치·교육",_change_tab.bind("staff"))
			_action(box,"전체 진행 작업",_change_tab.bind("jobs"))
		"research":
			_copy(box,"경영 연구",true)
			_copy(box,"심도 성과 정산 · Lv.0 / 5\n첫 클리어 협회 코인 보상 +10%")
			_copy(box,"코인 30 · 자재 10 · 연구자료 5\n연구 5분")
			_action(box,"심도 성과 정산 연구",_start_job.bind("research",id,"심도 성과 정산 연구",300.0))
		"expedition":
			_copy(box,"직원 탐험",true)
			_copy(box,"게이트 잔향 조사 · 2시간\n코인 25 · 자재 60 / 연구자료 15 발견")
			_action(box,"탐험 직원 선택",_open_detail.bind("assign"))
			_action(box,"게이트 잔향 조사 파견",_start_job.bind("expedition",id,"게이트 잔향 조사",7200.0))
		"production":
			_copy(box,"현재 생산 대상",true)
			_copy(box,str(_model.productionTarget)+"\n보관량 · 4.2 / 24시간")
			_action(box,"생산 대상 선택",_open_detail.bind("production"))
			_action(box,"보관 보상 모두 수령",_claim)
			_action(box,"마력 정제 연구",_start_job.bind("research",id,"마력 정제 연구",300.0))
		"recovery":
			_copy(box,"미접속 보상과 보관",true)
			_copy(box,"현장 회수 효율 · 보상 +10%\n장기 보관 · 최대 누적 시간 확대")
			_action(box,"현장 회수 효율 연구",_start_job.bind("research",id,"현장 회수 효율 연구",300.0))
			_action(box,"장기 보관 연구",_start_job.bind("research",id,"장기 보관 연구",300.0))
		"workshop":
			_copy(box,"아이템 영구 강화",true)
			_action(box,"강화할 아이템 선택",_open_detail.bind("item"))
			_copy(box,"조합 설계도",true)
			_copy(box,"조율 마력핵 · 마력 렌즈 + 에너지 드링크\n코인 100 · 자재 40 · 연구자료 10\n연구 30분")
			_action(box,"조율 마력핵 조합법 연구",_start_job.bind("research",id,"조율 마력핵 조합법 연구",1800.0))
		"revival":
			_copy(box,"생환석 제조 · 30분",true)
			_copy(box,"코인 100 · 자재 60 · 연구자료 5")
			_action(box,"생환석 제조 시작",_start_job.bind("manufacture",id,"생환석 제조",1800.0))
			_copy(box,"같은 등급 생환석 3개 합성\n코인 50 · 자재 30")
			_action(box,"하급 3개 → 중급 합성",func(): _notice="중급 생환석을 합성했습니다."; _rebuild())
		"analysis":
			_copy(box,"송진우 잠재력 분석",true)
			_copy(box,"기존 옵션 · 피해량 +2%\n코인 100 · 자재 60 · 연구자료 20")
			_action(box,"새 옵션 분석",func(): _notice="신규 옵션 · 공격 속도 +3%"; _rebuild())
			_action(box,"새 옵션으로 교체",func(): _notice="송진우의 분석 옵션을 교체했습니다."; _rebuild())

func _construction_detail(box: VBoxContainer, facility: Dictionary) -> void:
	_copy(box,_duration_text(float(facility.get("remaining",720.0)))+" 남음 · 관리 중에도 진행")
	_action(box,"가속권 1장 · 15분 단축",_speed_construction.bind(facility,900.0))
	_action(box,"코인으로 15분 단축",_speed_construction.bind(facility,900.0))
	_action(box,"공사 완료 보기",_finish.bind(facility))

func _staff_panel(box: VBoxContainer, facility: Dictionary) -> void:
	var is_office := str(facility.id)=="office"
	_copy(box,"전체 직원 · %d명" % _model.staff.size() if is_office else "이 사무실의 직원",true)
	var count:=0
	for employee in _model.staff:
		if not is_office and int(employee.slot)!=int(facility.slot): continue
		count+=1
		_copy(box,_employee_name(str(employee.id))+" · Lv.%d" % int(employee.get("level",1)),true)
		var location := _facility_at(int(employee.slot))
		var activity: Dictionary = {"idle":"대기","work":"근무","research":"연구","training":"교육","expedition":"탐험 중"}
		_copy(box,_facility_name(str(location.get("id","office")))+" · "+str(activity.get(employee.activity,employee.activity)))
		_action(box,"배치·교육 관리",_open_detail.bind("employee:"+str(employee.id)))
	if count==0: _copy(box,"배치된 직원이 없습니다.")
	_action(box,"직원 배치 선택",_open_detail.bind("assign"))
	if is_office: _action(box,"신규 직원 채용",_open_detail.bind("hire"))

func _assignment_panel(box: VBoxContainer, facility: Dictionary) -> void:
	_copy(box,_facility_name(str(facility.id))+"에 배치",true)
	for employee in _model.staff:
		var action := _action(box,_employee_name(str(employee.id))+" · Lv.%d" % int(employee.get("level",1)),_assign_employee.bind(str(employee.id),facility))
		action.disabled=str(employee.activity)=="expedition"
		if action.disabled: _copy(box,"탐험 중인 직원은 복귀 후 배치할 수 있습니다.")
	_action(box,"직원 목록으로",func(): _detail=""; _change_tab("staff"))

func _employee_panel(box: VBoxContainer, employee_id: String) -> void:
	var employee := _employee_by_id(employee_id)
	if employee.is_empty(): return
	_copy(box,_employee_name(employee_id)+" · Lv.%d / 5" % int(employee.get("level",1)),true)
	_copy(box,"교육 · 2시간\n코인 60 · 자재 20 · 연구자료 5")
	var training := _action(box,"직원 교육 시작",_train.bind(employee))
	training.disabled=str(employee.activity)=="expedition"
	_copy(box,"근무 장소 선택",true)
	for facility in _model.facilities:
		if int(facility.level)<=0: continue
		var button := _action(box,_facility_name(str(facility.id))+"에 배치",_assign_employee.bind(employee_id,facility))
		button.disabled=str(employee.activity)=="expedition"
	_action(box,"직원 목록으로",func(): _detail=""; _change_tab("staff"))

func _hire_panel(box: VBoxContainer) -> void:
	_copy(box,"직원 채용",true)
	var hired: Array[String] = []
	for employee in _model.staff: hired.append(str(employee.id))
	for employee_id in ["staffJiWoo","staffHaEun","staffDoYoon","staffSiWoo","staffSuBin"]:
		if employee_id in hired: continue
		var definition: Dictionary = _data.get("employees",{}).get(employee_id,{})
		_copy(box,_employee_name(employee_id)+" · "+str(definition.get("role","길드 직원")),true)
		_copy(box,str(definition.get("description",""))+"\n"+_cost_text(definition.get("hireCost",{})))
		_action(box,"채용",_hire.bind(employee_id))
	_action(box,"직원 목록으로",func(): _detail=""; _change_tab("staff"))

func _jobs_panel(box: VBoxContainer, facility: Dictionary) -> void:
	var is_office := str(facility.id)=="office"
	_copy(box,"전체 진행 작업" if is_office else "이 사무실의 작업",true)
	var count:=0
	for entry in _model.facilities:
		if not bool(entry.get("construction",false)): continue
		if not is_office and str(entry.id)!=str(facility.id): continue
		count+=1
		_copy(box,_facility_name(str(entry.id))+" · "+("건설" if int(entry.level)==0 else "Lv.%d 강화" % int(entry.targetLevel)),true)
		_construction_detail(box,entry)
	for job in _model.jobs:
		if not is_office and str(job.target)!=str(facility.id): continue
		if bool(job.done): continue
		count+=1; _copy(box,str(job.title),true)
		_copy(box,_duration_text(float(job.remaining))+" 남음")
		_action(box,"가속권 1장 · 15분 단축",_speed_job.bind(job,900.0))
		_action(box,"코인으로 15분 단축",_speed_job.bind(job,900.0))
		_action(box,"작업 완료 보기",_finish_job.bind(job))
	if count==0: _copy(box,"진행 중인 작업이 없습니다.")
	var done:=false
	for job in _model.jobs:
		if bool(job.done) and (is_office or str(job.target)==str(facility.id)): done=true
	if done: _action(box,"완료한 보상 모두 수령",_claim)

func _move_panel(box: VBoxContainer, facility: Dictionary) -> void:
	_copy(box,"이동할 사무실",true)
	var count:=0
	for slot in range(int(_model.unlockedFloors)*3):
		if not _facility_at(slot).is_empty(): continue
		count+=1
		_action(box,"%d층 · 사무실 %d로 이동" % [floori(slot/3.0)+1,slot%3+1],_move_facility.bind(facility,slot))
	if count==0: _copy(box,"비어 있는 사무실이 없습니다.")
	_action(box,"시설 관리로",_open_detail.bind(""))

func _production_panel(box: VBoxContainer) -> void:
	_copy(box,"조각 생산 대상",true)
	for target in ["송진우 조각","성유나 조각","마력탄 무기 조각","공격 축복 조각"]:
		_action(box,target+" 생산",_choose_production.bind(target))
	_action(box,"시설 관리로",_open_detail.bind(""))

func _item_panel(box: VBoxContainer, facility: Dictionary) -> void:
	_copy(box,"강화할 아이템",true)
	_copy(box,"코인 60 · 자재 20 · 연구자료 5\n강화 1분 · 아이템 효과 +5%")
	for item in ["마력 렌즈","에너지 드링크","방탄 조끼"]:
		_action(box,item+" · Lv.0 → 1",_start_job.bind("itemUpgrade",str(facility.id),item+" 강화",60.0))
	_action(box,"시설 관리로",_open_detail.bind(""))

func _construct(id: String, slot: int) -> void:
	var definition := _level_definition(id,1)
	_model.facilities.append({"id":id,"slot":slot,"level":0,"construction":true,"remaining":float(definition.get("durationMs",60000))/1000.0,"targetLevel":1})
	_selected_id=id; _detail=""; _notice=_facility_name(id)+" 건설을 시작했습니다."
	_rebuild()

func _upgrade(facility: Dictionary) -> void:
	var target := int(facility.level)+1
	var definition := _level_definition(str(facility.id),target)
	facility.construction=true; facility.remaining=float(definition.get("durationMs",60000))/1000.0; facility.targetLevel=target
	_notice=_facility_name(str(facility.id))+" 강화를 시작했습니다."
	_rebuild()

func _finish(facility: Dictionary) -> void:
	var anchor_slot := maxi(_selected,0)
	var old_y: float = _world.slot_center(anchor_slot).y
	facility.level=int(facility.get("targetLevel",int(facility.level)+1)); facility.construction=false; facility.remaining=0.0
	if str(facility.id)=="office": _model.unlockedFloors=maxi(int(_model.unlockedFloors),mini(3,int(facility.level)))
	_world.set_model(_model)
	_scroll_y+=_world.slot_center(anchor_slot).y-old_y
	_notice=_facility_name(str(facility.id))+" 공사를 완료했습니다."
	_rebuild()

func _speed_construction(facility: Dictionary, seconds: float) -> void:
	facility.remaining=maxf(0,float(facility.remaining)-seconds)
	if float(facility.remaining)<=0: _finish(facility)
	else: _notice="공사 시간을 15분 단축했습니다."; _rebuild()

func _employee_by_id(employee_id: String) -> Dictionary:
	for employee in _model.staff:
		if str(employee.id)==employee_id: return employee
	return {}

func _assign_employee(employee_id: String, facility: Dictionary) -> void:
	var employee := _employee_by_id(employee_id)
	if employee.is_empty() or facility.is_empty(): return
	employee.slot=int(facility.slot); employee.activity="work"
	_detail=""; _notice=_employee_name(employee_id)+" · "+_facility_name(str(facility.id))+" 배치 완료"
	_rebuild()

func _hire(employee_id: String) -> void:
	if not _employee_by_id(employee_id).is_empty(): return
	_model.staff.append({"id":employee_id,"slot":0,"activity":"idle","level":1})
	_notice=_employee_name(employee_id)+"을 채용했습니다."; _rebuild()

func _train(employee: Dictionary) -> void:
	_begin_job("training","office",_employee_name(str(employee.id))+" 교육",7200.0,[str(employee.id)])

func _start_job(kind: String, target: String, title: String, remaining: float) -> void:
	var assigned: Array[String] = []
	var facility := _selected_facility()
	for employee in _model.staff:
		if int(employee.slot)==int(facility.get("slot",-1)) and str(employee.activity) in ["idle","work"]:
			assigned.append(str(employee.id)); break
	if assigned.is_empty():
		_notice="근무 가능한 직원을 먼저 배치해 주세요."; _rebuild(); return
	_begin_job(kind,target,title,remaining,assigned)

func _begin_job(kind: String, target: String, title: String, remaining: float, assigned: Array) -> void:
	_model.jobs.append({"id":title+str(_age),"target":target,"kind":kind,"title":title,"remaining":remaining,"staff":assigned,"done":false})
	for employee_id in assigned:
		var employee := _employee_by_id(str(employee_id))
		if not employee.is_empty(): employee.activity="expedition" if kind=="expedition" else "training" if kind=="training" else "research"
	_detail=""; _notice=title+" 시작"; _rebuild()

func _speed_job(job: Dictionary, seconds: float) -> void:
	job.remaining=maxf(0,float(job.remaining)-seconds)
	if float(job.remaining)<=0: _finish_job(job)
	else: _notice="작업 시간을 15분 단축했습니다."; _rebuild()

func _finish_job(job: Dictionary) -> void:
	job.remaining=0.0; job.done=true
	for employee_id in job.staff:
		var employee := _employee_by_id(str(employee_id))
		if not employee.is_empty():
			employee.activity="work"
			if str(job.kind)=="training": employee.level=mini(5,int(employee.get("level",1))+1)
	_notice=str(job.title)+" 완료"; _rebuild()

func _choose_production(target: String) -> void:
	_model.productionTarget=target; _detail=""; _notice="생산 대상을 변경했습니다."; _rebuild()

func _claim() -> void:
	_model.rewardsClaimed=true
	_notice="생산·탐험·제조 보상을 모두 수령했습니다."; _rebuild()

func _move_facility(facility: Dictionary, slot: int) -> void:
	var old_slot:=int(facility.slot); facility.slot=slot
	for employee in _model.staff:
		if int(employee.slot)==old_slot: employee.slot=slot
	_selected=slot; _selected_floor=floori(slot/3.0)+1; _detail=""
	_notice=_facility_name(str(facility.id))+" · %d층 사무실 %d로 이동" % [_selected_floor,slot%3+1]
	_rebuild()

func _process(dt: float) -> void:
	_age+=dt
	if _model.is_empty(): return
	for facility in _model.facilities:
		if bool(facility.get("construction",false)):
			facility.remaining=maxf(0,float(facility.get("remaining",720.0))-dt)
			if float(facility.remaining)<=0: _finish(facility)
	for job in _model.jobs:
		if not bool(job.done):
			job.remaining=maxf(0,float(job.remaining)-dt)
			if float(job.remaining)<=0: _finish_job(job)

func _copy(parent: Node, caption: String, accent: bool=false) -> Label:
	var label:=Label.new(); label.text=caption; label.custom_minimum_size.x=280
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_constant_override("line_spacing",4)
	_apply_font(label,"heading" if accent else "body",16 if accent else 14)
	label.add_theme_color_override("font_color",Color("#267f75" if accent else "#243448"))
	parent.add_child(label); return label

func _action(parent: Node, caption: String, command: Callable, role: String="secondary") -> Button:
	var button:=_button(parent,caption,Rect2(0,0,280,44),command,role,14)
	button.custom_minimum_size=Vector2(280,44); button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return button

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_F1: set_view("initial")
		KEY_F2: set_view("expanded")
		KEY_F3: set_view("management")
		KEY_F4: set_view("staff")
		KEY_F5: set_view("jobs")
		KEY_F6: set_view("office")
		KEY_ESCAPE: _back()

func _asset(file: String) -> Dictionary:
	return _load_image(ProjectSettings.globalize_path("res://assets/"+file),false)

func _load_image(file: String, trim: bool=false) -> Dictionary:
	var key:=file+str(trim)
	if _textures.has(key): return _textures[key]
	if not FileAccess.file_exists(file): return {}
	var image:=Image.new()
	if image.load(file)!=OK: return {}
	var bounds:=image.get_used_rect() if trim else Rect2i(Vector2i.ZERO,image.get_size())
	if trim: image=image.get_region(bounds)
	image.generate_mipmaps()
	var result: Dictionary = {"texture":ImageTexture.create_from_image(image),"image":image,"size":Vector2(image.get_size()),"bounds":bounds}
	_textures[key]=result; return result

func _capture() -> void:
	var output:=ProjectSettings.globalize_path("res://captures")
	DirAccess.make_dir_recursive_absolute(output)
	for preset in ["initial","expanded","management","staff","jobs","office"]:
		set_view(preset)
		if preset=="expanded": _scroll_y=55.0; _apply_scroll()
		await get_tree().process_frame; await get_tree().process_frame
		if preset=="office":
			_pane_scroll.scroll_vertical = 235
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(preset)+".png"))
	await _capture_building(output)
	get_tree().quit()

func _capture_building(output: String) -> void:
	set_view("expanded")
	var viewport:=SubViewport.new(); viewport.size=Vector2i(915,650)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.transparent_bg=false
	add_child(viewport)
	var board:=Control.new(); board.size=Vector2(915,650); viewport.add_child(board)
	var backdrop := _load_image(_repository.path_join("godot/design/ui-premium-v5/assets/lobby-rain.png"),false)
	if not backdrop.is_empty():
		var image:=_picture(board,backdrop.texture,Rect2(0,0,915,650)); image.modulate=Color(0.43,0.48,0.62,1)
	_text(board,"길드 본부 · 층당 사무실 세 칸",Rect2(20,10,875,36),25,"#f5f8fa","brand",HORIZONTAL_ALIGNMENT_CENTER)
	var building:=WORLD.new(); board.add_child(building); building.position=Vector2(12,49)
	building.configure(_world_assets()); building.set_viewport_width(891)
	var overview: Dictionary = _model.duplicate(true); overview.selectedSlot=-1
	building.set_model(overview)
	await get_tree().process_frame; await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("04-building.png"))
	viewport.queue_free()

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
	button.add_theme_color_override("font_disabled_color",Color("#657787"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var blank := StyleBoxEmpty.new(); blank.set_content_margin(SIDE_LEFT,10); blank.set_content_margin(SIDE_RIGHT,10)
		button.add_theme_stylebox_override(state,blank)
	parent.add_child(button)
	var surface := _surface(button,"cstore","next" if role=="primary" else "secondary",Rect2(Vector2.ZERO,button.size))
	button.move_child(surface,0)
	button.resized.connect(func(): surface.size=button.size*4.0)
	button.pressed.connect(command)
	return button

