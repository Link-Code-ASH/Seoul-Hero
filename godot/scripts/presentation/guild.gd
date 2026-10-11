class_name HeroGuild
extends Node2D

# Presentation only: walking never changes a guild job, cost or production clock.
signal arrived(slot: int, panel: String)
signal enter_gate
signal hint_changed(caption: String)

const ROOM_WIDTH := 320.0
const WORLD_WIDTH := 1456.0
const ROOM_LEFT := 80.0
const LIFT_X := 1408.0
const GATE_X := 28.0
const FLOOR_Y := [428.0,212.0]
const WALK_SPEED := 210.0
const LIFT_SPEED := 260.0
const FOLLOW_ZOOM := 1.1

var blocked := false
var overview := false
var player_position: Vector2:
	get: return _player_pos

var _profile: Dictionary = {}
var _art: Dictionary = {}
var _ui: Dictionary = {}
var _actor_id := "awakener"
var _viewport_size := Vector2(891,268)
var _player := HeroSDVisual.new()
var _player_pos := Vector2(GATE_X,428)
var _player_floor := 0
var _facing := 1.0
var _manual := Vector2.ZERO
var _manual_lift := -1
var _lift_latched := false
var _route: Array[Vector2] = []
var _destination_slot := -1
var _destination_panel := "facility"
var _destination_gate := false
var _age := 0.0
var _camera_center := Vector2.ZERO
var _camera_zoom := FOLLOW_ZOOM
var _camera_initialized := false
var _room_count := 4
var _last_hint := ""
var _rooms: Array[Dictionary] = []
var _floor_art: Array[Dictionary] = []
var _roof_art: Array[TextureRect] = []
var _npcs: Dictionary = {}
var _workers: Dictionary = {}
var _structure_regions: Dictionary = {}

func configure(profile: Dictionary, art: Dictionary, ui: Dictionary, actor_id: String = "awakener") -> void:
	_profile = profile; _art = art; _ui = ui; _actor_id = actor_id
	if not Content.visuals.characters.has(_actor_id): _actor_id = "awakener"
	var state: Dictionary = _ui.get("walk",{})
	_player_floor = clampi(int(state.get("floor",0)),0,1)
	_player_pos = Vector2(clampf(float(state.get("x",GATE_X)),GATE_X,LIFT_X),float(FLOOR_Y[_player_floor]))

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_create_building()
	_player.z_index = 12
	add_child(_player)
	_player.configure(_actor_id,Content.visuals.characters[_actor_id])
	_label("나 · "+str(Content.data.characters[_actor_id].name),Rect2(-72,-89,144,22),13,_player)
	sync_state()
	_player.update_state({"pos":_player_pos,"facing":_facing,"age":0.0,"action":"idle"},0.0,72.0)
	snap_camera()

func set_viewport_size(size: Vector2) -> void:
	_viewport_size = Vector2(maxf(1,size.x),maxf(1,size.y))
	if not _camera_initialized: snap_camera()

func set_manual_input(axis: Vector2) -> void:
	_manual = axis.limit_length(1.0)
	if blocked: _manual = Vector2.ZERO
	if _manual.length_squared() > 0.01:
		if not _route.is_empty() and absf(_player_pos.y-float(FLOOR_Y[_player_floor]))>1.0:
			_manual_lift = 1 if _room_count>4 and _player_pos.y<320.0 else 0
		_cancel_route()
		set_overview(false)

func go_to(slot: int, panel: String = "facility") -> void:
	if blocked or slot<0 or slot>=_room_count: return
	_manual = Vector2.ZERO; _manual_lift = -1
	set_overview(false)
	_destination_slot = slot; _destination_panel = panel; _destination_gate = false
	_route = _path_to(_player_pos,_player_floor,_slot_point(slot),floori(slot/4.0))

func go_to_gate() -> void:
	if blocked: return
	_manual = Vector2.ZERO; _manual_lift = -1
	set_overview(false)
	_destination_slot = -1; _destination_gate = true
	_route = _path_to(_player_pos,_player_floor,Vector2(GATE_X,FLOOR_Y[0]),0)

func interact() -> void:
	if blocked: return
	if _player_floor == 0 and absf(_player_pos.x-GATE_X)<54.0:
		_cancel_route(); enter_gate.emit(); return
	if absf(_player_pos.x-LIFT_X)<62.0:
		if _room_count>4: _begin_lift(1-_player_floor)
		return
	var slot := _nearby_slot()
	if slot>=0:
		_cancel_route(); arrived.emit(slot,"facility")

func set_overview(value: bool) -> void:
	overview = value

func slot_at(world_pos: Vector2) -> int:
	if world_pos.x<ROOM_LEFT or world_pos.x>=ROOM_LEFT+ROOM_WIDTH*4.0: return -1
	var selected_floor := -1
	var closest := INF
	for floor_index in range(2 if _room_count>4 else 1):
		var y := float(FLOOR_Y[floor_index])
		var distance := absf(world_pos.y-y)
		if world_pos.y>=y-196.0 and world_pos.y<=y+28.0 and distance<closest:
			selected_floor = floor_index; closest = distance
	return selected_floor*4+clampi(floori((world_pos.x-ROOM_LEFT)/ROOM_WIDTH),0,3) if selected_floor>=0 else -1

func world_point(screen_global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse()*screen_global_pos

func snap_camera() -> void:
	var goal := _camera_goal()
	_camera_center = goal.center; _camera_zoom = goal.zoom
	_camera_initialized = true
	_apply_camera()

func sync_state() -> void:
	if _profile.is_empty() or not is_inside_tree(): return
	var guild: Dictionary = _profile.guild
	_room_count = HeroGuildRules.rooms(Content.data,guild)
	if _player_floor>0 and _room_count<=4:
		_player_floor = 0; _player_pos.y = FLOOR_Y[0]
		_cancel_route(); _manual_lift = -1
	for floor_index in range(_floor_art.size()):
		var floor_visible := floor_index == 0 or _room_count>4
		for node in _floor_art[floor_index].nodes: node.visible = floor_visible
	for column in range(_roof_art.size()):
		_roof_art[column].position.y = float(FLOOR_Y[1 if _room_count>4 else 0])-228.0
	for slot in range(_rooms.size()):
		var room: Dictionary = _rooms[slot]
		var unlocked := slot<_room_count
		for key in ["picture","title","status"]: room[key].visible = unlocked
		room.scaffolding.visible = false
		if not unlocked: continue
		var id := _facility_at(slot)
		var job := _construction_at(slot)
		var level := 0 if id.is_empty() else int(guild.facilities[id].level)
		var signature := id+":"+str(level)+":"+str(job.get("id",""))
		if room.signature != signature:
			room.signature = signature
			room.picture.texture = _state_texture(0) if id.is_empty() else _room_texture(id,level)
			room.scaffolding.texture = _state_texture(1)
			room.scaffolding.modulate.a = 1.0 if id.is_empty() else 0.32
			var display_id := str(job.get("targetId",id)) if id.is_empty() else id
			room.title.text = "빈 방 · 건설" if display_id.is_empty() else str(Content.data.guildManagement.facilities[display_id].name)
		room.scaffolding.visible = not job.is_empty()
		room.status.text = "공사 중 · %d분" % ceili(maxf(0.0,float(job.endsAt)-Time.get_unix_time_from_system())/60.0) if not job.is_empty() else "Lv.%d · 운영 중" % level if level>0 else "빈 방"
	_sync_employees(guild)
	_sync_workers(guild)
	_remember_position()
	_update_hint()

func _process(dt: float) -> void:
	if not is_visible_in_tree() or _profile.is_empty(): return
	_age += dt
	var previous := _player_pos
	if not blocked:
		if _manual_lift>=0: _move_lift(dt)
		elif not _route.is_empty(): _move_route(dt)
		else: _move_manual(dt)
	if absf(_player_pos.x-previous.x)>0.01: _facing = signf(_player_pos.x-previous.x)
	_player.update_state({"pos":_player_pos,"facing":_facing,"age":_age,"action":"move" if previous.distance_squared_to(_player_pos)>0.01 else "idle"},dt,72.0)
	_update_employees(dt)
	_update_workers(dt)
	_remember_position()
	_update_hint()
	var camera_goal := _camera_goal()
	var weight := 1.0-exp(-dt*7.0)
	_camera_center = _camera_center.lerp(camera_goal.center,weight)
	_camera_zoom = lerpf(_camera_zoom,float(camera_goal.zoom),weight)
	_apply_camera()

func _move_manual(dt: float) -> void:
	_player_pos.x = clampf(_player_pos.x+_manual.x*WALK_SPEED*dt,GATE_X,LIFT_X)
	if absf(_manual.y)<0.35: _lift_latched = false
	if absf(_manual.y)>=0.5 and not _lift_latched and absf(_player_pos.x-LIFT_X)<62.0:
		_lift_latched = true
		var next_floor := 1 if _manual.y<0.0 else 0
		if next_floor!=_player_floor and (next_floor==0 or _room_count>4): _begin_lift(next_floor)

func _begin_lift(floor_index: int) -> void:
	_cancel_route()
	_manual_lift = floor_index

func _move_lift(dt: float) -> void:
	_player_pos.x = move_toward(_player_pos.x,LIFT_X,WALK_SPEED*dt)
	if absf(_player_pos.x-LIFT_X)>0.1: return
	_player_pos.y = move_toward(_player_pos.y,float(FLOOR_Y[_manual_lift]),LIFT_SPEED*dt)
	if absf(_player_pos.y-float(FLOOR_Y[_manual_lift]))<0.1:
		_player_floor = _manual_lift; _manual_lift = -1

func _move_route(dt: float) -> void:
	var target: Vector2 = _route[0]
	var speed := LIFT_SPEED if absf(target.y-_player_pos.y)>0.1 else WALK_SPEED
	_player_pos = _player_pos.move_toward(target,speed*dt)
	if _player_pos.distance_squared_to(target)>0.01: return
	_player_pos = target; _route.pop_front()
	if absf(_player_pos.y-float(FLOOR_Y[0]))<0.1: _player_floor = 0
	elif absf(_player_pos.y-float(FLOOR_Y[1]))<0.1: _player_floor = 1
	if not _route.is_empty(): return
	var slot := _destination_slot
	var panel := _destination_panel
	var gate := _destination_gate
	_cancel_route()
	if gate: enter_gate.emit()
	elif slot>=0 and slot<_room_count: arrived.emit(slot,panel)

func _cancel_route() -> void:
	_route.clear(); _destination_slot = -1; _destination_gate = false

func _path_to(from: Vector2, floor_index: int, target: Vector2, target_floor: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if absf(from.y-float(FLOOR_Y[floor_index]))>0.1:
		points.append(Vector2(LIFT_X,float(FLOOR_Y[floor_index])))
	if floor_index!=target_floor:
		points.append(Vector2(LIFT_X,float(FLOOR_Y[floor_index])))
		points.append(Vector2(LIFT_X,float(FLOOR_Y[target_floor])))
	points.append(target)
	return points

func _slot_point(slot: int) -> Vector2:
	return Vector2(ROOM_LEFT+(slot%4+0.5)*ROOM_WIDTH,float(FLOOR_Y[floori(slot/4.0)]))

func _nearby_slot() -> int:
	if absf(_player_pos.y-float(FLOOR_Y[_player_floor]))>1.0: return -1
	var column := floori((_player_pos.x-ROOM_LEFT)/ROOM_WIDTH)
	if column<0 or column>=4: return -1
	return _player_floor*4+column

func _facility_at(slot: int) -> String:
	for id in _profile.guild.facilities:
		var facility: Dictionary = _profile.guild.facilities[id]
		if int(facility.level)>0 and int(facility.slot)==slot: return str(id)
	return ""

func _facility_slot(id: String) -> int:
	var facility: Dictionary = _profile.guild.facilities.get(id,{})
	return int(facility.get("slot",0)) if int(facility.get("level",0))>0 else 0

func _construction_at(slot: int) -> Dictionary:
	for job in _profile.guild.jobs:
		if job.type=="construction" and int(job.slot)==slot: return job
	return {}

func _update_hint() -> void:
	var caption := "방을 눌러 이동 · A/D 또는 좌우 방향키"
	if _manual_lift>=0 or absf(_player_pos.y-float(FLOOR_Y[_player_floor]))>1.0:
		caption = "엘리베이터 이동 중"
	elif _player_floor==0 and absf(_player_pos.x-GATE_X)<54.0:
		caption = "출입구 · E / 이용으로 작전 투입"
	elif absf(_player_pos.x-LIFT_X)<62.0:
		caption = "엘리베이터 · 위/아래 또는 E / 이용" if _room_count>4 else "운영실 Lv.3 · 2층 개방"
	else:
		var slot := _nearby_slot()
		if slot>=0:
			var id := _facility_at(slot)
			caption = ("빈 방 · 건설" if id.is_empty() else str(Content.data.guildManagement.facilities[id].name))+" · E / 이용"
	if caption!=_last_hint:
		_last_hint = caption; hint_changed.emit(caption)

func _remember_position() -> void:
	_ui["walk"] = {"x":_player_pos.x,"floor":_player_floor}

func _camera_goal() -> Dictionary:
	var top := float(FLOOR_Y[1 if _room_count>4 else 0])-228.0
	var bottom := float(FLOOR_Y[0])+36.0
	if overview:
		var fit := minf(_viewport_size.x/WORLD_WIDTH,_viewport_size.y/(bottom-top))
		return {"center":Vector2(WORLD_WIDTH*0.5,(top+bottom)*0.5),"zoom":fit*0.96}
	var half := _viewport_size/(FOLLOW_ZOOM*2.0)
	var center := Vector2(_player_pos.x,_player_pos.y-92.0)
	center.x = clampf(center.x,minf(half.x,WORLD_WIDTH*0.5),maxf(WORLD_WIDTH-half.x,WORLD_WIDTH*0.5))
	center.y = clampf(center.y,top+half.y,bottom-half.y) if bottom-top>half.y*2.0 else (top+bottom)*0.5
	return {"center":center,"zoom":FOLLOW_ZOOM}

func _apply_camera() -> void:
	scale = Vector2.ONE*_camera_zoom
	position = _viewport_size*0.5-_camera_center*_camera_zoom

func _create_building() -> void:
	var structure: Texture2D = _art.get("structure")
	if structure!=null:
		var source := structure.get_image()
		var regions: Array = _art.get("structureRegions",[])
		var cell_size := structure.get_size()/Vector2(4,2)
		for index in range(8):
			var cell := Rect2i(Vector2(index%4,floori(index/4.0))*cell_size,cell_size)
			if index<regions.size():
				var authored: Array = regions[index]
				cell = Rect2i(int(authored[0]),int(authored[1]),int(authored[2]),int(authored[3]))
			var bounds := source.get_region(cell).get_used_rect()
			var atlas := AtlasTexture.new(); atlas.atlas = structure
			atlas.region = Rect2(Rect2i(cell.position+bounds.position,bounds.size)) if bounds.size.x>0 else Rect2(cell)
			atlas.filter_clip = true; _structure_regions[index] = atlas
	for floor_index in range(2):
		var y := float(FLOOR_Y[floor_index])
		var floor_nodes: Array = []
		for column in range(4):
			var x := ROOM_LEFT+column*ROOM_WIDTH
			for piece in [[0,Rect2(x,y-12.0,ROOM_WIDTH,40)],[1,Rect2(x,y-208.0,ROOM_WIDTH,32)],[6,Rect2(x,y+12.0,ROOM_WIDTH,20)]]:
				var tile := _picture(self,_structure_regions.get(piece[0]),piece[1])
				tile.z_index = 20 if piece[0]==6 else 4
				floor_nodes.append(tile)
		var wall := _picture(self,_structure_regions.get(2),Rect2(0,y-176.0,80,208)); wall.z_index = 3; floor_nodes.append(wall)
		var lift := _picture(self,_structure_regions.get(4),Rect2(1360,y-176.0,96,208)); lift.z_index = 3; floor_nodes.append(lift)
		var right_wall := _picture(self,_structure_regions.get(3),Rect2(1440,y-176.0,16,208)); right_wall.z_index = 4; floor_nodes.append(right_wall)
		_floor_art.append({"nodes":floor_nodes})
	var entrance := _picture(self,_structure_regions.get(7),Rect2(0,FLOOR_Y[0]-176.0,80,208)); entrance.z_index = 5
	for column in range(4):
		var roof := _picture(self,_structure_regions.get(5),Rect2(ROOM_LEFT+column*ROOM_WIDTH,200,ROOM_WIDTH,52)); roof.z_index = 5; _roof_art.append(roof)
	for slot in range(8):
		var point := _slot_point(slot)
		var rect := Rect2(point.x-ROOM_WIDTH*0.5,point.y-176.0,ROOM_WIDTH,160)
		var picture := _picture(self,null,rect)
		var scaffolding := _picture(self,null,rect); scaffolding.z_index = 2
		var title := _label("",Rect2(rect.position+Vector2(12,-28),Vector2(296,24)),19)
		var status := _label("",Rect2(rect.position+Vector2(12,-4),Vector2(296,20)),14)
		_rooms.append({"picture":picture,"scaffolding":scaffolding,"title":title,"status":status,"signature":""})

func _picture(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var result := TextureRect.new()
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture = texture
	result.position = rect.position; result.size = rect.size
	result.stretch_mode = TextureRect.STRETCH_SCALE
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func _label(caption: String, rect: Rect2, font_size: int, parent: Node = null) -> Label:
	var label := Label.new(); label.text = caption; label.position = rect.position; label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 25
	HeroImageSkin.apply_font(label,"heading" if font_size>14 else "body",font_size)
	label.add_theme_color_override("font_color",HeroImageSkin.color("scene"))
	label.add_theme_color_override("font_outline_color",Color("#243448"))
	label.add_theme_constant_override("outline_size",4)
	if parent==null: add_child(label)
	else: parent.add_child(label)
	return label

func _room_texture(id: String, level: int) -> Texture2D:
	var texture: Texture2D = _art.get("rooms")
	if texture==null: return null
	var ids: Array = _art.get("facilityOrder",Content.data.guildManagement.facilities.keys())
	var row := ids.find(id)
	if row<0: return null
	var tiers: Array = _art.get("tiers",[1,4,7,10])
	var column := 0
	for index in range(tiers.size()):
		if level>=int(tiers[index]): column = index
	var cell := texture.get_size()/Vector2(4,8)
	var atlas := AtlasTexture.new(); atlas.atlas = texture; atlas.region = Rect2(Vector2(column,row)*cell,cell); atlas.filter_clip = true
	return atlas

func _state_texture(row: int) -> Texture2D:
	var texture: Texture2D = _art.get("states")
	if texture==null: return null
	var cell := texture.get_size()/Vector2(1,3)
	var atlas := AtlasTexture.new(); atlas.atlas = texture; atlas.region = Rect2(Vector2(0,row)*cell,cell); atlas.filter_clip = true
	return atlas

func _new_avatar(actor: String) -> HeroSDVisual:
	var node := HeroSDVisual.new(); node.z_index = 11; add_child(node)
	node.configure(actor,Content.visuals.npcs.hanSeoa if actor=="hanSeoa" else Content.visuals.characters[actor])
	return node

func _sync_employees(guild: Dictionary) -> void:
	var present: Array[String] = []
	for index in range(guild.employees.size()):
		var employee: Dictionary = guild.employees[index]
		var id := str(employee.id); present.append(id)
		var activity := str(employee.assignment)
		var task: Dictionary = {}
		for job in guild.jobs:
			if id in job.employeeIds: task = job; break
		if not task.is_empty(): activity = "away" if task.type=="expedition" else "research" if task.type in ["research","recipe"] else "office"
		var slot := _facility_slot("office" if activity in ["","away"] else activity)
		var goal := _slot_point(slot)+Vector2((index%3-1)*43.0,0)
		if not _npcs.has(id):
			var actor: String = ["hanSeoa","awakener","kangTaehoon","parkDojun","yoonHarin"][index%5]
			var origin := Vector2(GATE_X,FLOOR_Y[0]) if activity=="away" else _slot_point(0)
			_npcs[id] = {"node":_new_avatar(actor),"pos":origin,"floor":0,"facing":1.0,"route":[],"activity":"unset","slot":-1,"phase":float(index)*1.73,"away":activity=="away","wander_at":0.0}
		var npc: Dictionary = _npcs[id]
		if npc.activity!=activity or int(npc.slot)!=slot:
			npc.activity = activity; npc.slot = slot
			if activity=="away":
				if not npc.away:
					var expedition_slot := _facility_slot("expedition")
					var staging := _slot_point(expedition_slot)
					npc.route = _path_to(npc.pos,int(npc.floor),staging,floori(expedition_slot/4.0))
					var exit_route := _path_to(staging,floori(expedition_slot/4.0),Vector2(GATE_X,FLOOR_Y[0]),0)
					npc.route.append_array(exit_route)
			else:
				npc.away = false; npc.node.visible = true
				npc.route = _path_to(npc.pos,int(npc.floor),goal,floori(slot/4.0))
			npc.wander_at = _age+3.0+float(index)
		if npc.away: npc.node.visible = false
	for id in _npcs.keys():
		if id not in present:
			_npcs[id].node.queue_free(); _npcs.erase(id)

func _update_employees(dt: float) -> void:
	for id in _npcs:
		var npc: Dictionary = _npcs[id]
		if npc.away: continue
		var previous: Vector2 = npc.pos
		if not npc.route.is_empty():
			var target: Vector2 = npc.route[0]
			var speed := 175.0 if absf(target.y-npc.pos.y)>0.1 else 100.0
			npc.pos = (npc.pos as Vector2).move_toward(target,dt*speed)
			if (npc.pos as Vector2).distance_squared_to(target)<0.01:
				npc.pos = target; npc.route.pop_front()
				if absf(target.y-float(FLOOR_Y[0]))<0.1: npc.floor = 0
				elif absf(target.y-float(FLOOR_Y[1]))<0.1: npc.floor = 1
		elif npc.activity=="away":
			npc.away = true; npc.node.visible = false; continue
		elif npc.activity=="" and _age>=float(npc.wander_at):
			var wander := _slot_point(int(npc.slot))+Vector2(sin(_age*0.25+float(npc.phase))*86.0,0)
			npc.route = [wander]; npc.wander_at = _age+4.5
		if absf(npc.pos.x-previous.x)>0.01: npc.facing = signf(npc.pos.x-previous.x)
		npc.node.update_state({"pos":npc.pos,"facing":npc.facing,"age":_age+float(npc.phase),"action":"move" if previous.distance_squared_to(npc.pos)>0.01 else "idle"},dt,64.0)

func _sync_workers(guild: Dictionary) -> void:
	var present: Array[String] = []
	for job in guild.jobs:
		if job.type!="construction": continue
		var id := str(job.id); present.append(id)
		if not _workers.has(id): _workers[id] = {"node":_new_avatar("hanSeoa"),"slot":int(job.slot),"phase":float(job.slot)*1.39}
	for id in _workers.keys():
		if id not in present:
			_workers[id].node.queue_free(); _workers.erase(id)

func _update_workers(dt: float) -> void:
	for id in _workers:
		var worker: Dictionary = _workers[id]
		var pos := _slot_point(int(worker.slot))+Vector2(sin(_age*0.65+float(worker.phase))*68.0,0)
		worker.node.update_state({"pos":pos,"facing":1.0 if cos(_age*0.65+float(worker.phase))>=0.0 else -1.0,"age":_age+float(worker.phase),"action":"move"},dt,62.0)
