class_name HeroGuildOfficeWorld
extends Node2D

# Approved front-view room art and stable inhabitants. UI owns clipping, scroll and taps.
const STAFF_ACTORS := ["hanSeoa","awakener","kangTaehoon","parkDojun","yoonHarin"]
const COLUMNS := 3
const LEFT := 24.0
const GAP := 8.0
const TOP := 30.0
const BOTTOM := 22.0
const FACILITY_NAMES := {
	"office":"운영실", "research":"연구실", "expedition":"탐험부", "production":"생산실",
	"recovery":"회복실", "workshop":"장비공방", "revival":"생환석 제조실", "analysis":"분석실"
}
const DEFAULT_STRUCTURE := [
	[20,224,590,96], [620,204,537,82], [1184,34,132,397], [1536,34,136,399],
	[82,460,280,384], [443,631,464,80], [916,680,424,90], [1407,456,314,387]
]

var _assets: Dictionary = {}
var _model: Dictionary = {"unlockedFloors":1,"selectedSlot":-1,"facilities":[],"staff":[]}
var _width := 891.0
var _room_width := 275.0
var _room_height := 137.5
var _floor_step := 177.5
var _display_floors := 2
var _age := 0.0
var _people: Dictionary = {}
var _builders: Dictionary = {}
var _structure: Array[Texture2D] = []
var _rails: Array[TextureRect] = []
var _font: Font

func configure(assets: Dictionary) -> void:
	_assets = assets
	_font = HeroImageSkin.font("heading")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_prepare_structure()
	_sync_people()
	_sync_rails()
	queue_redraw()

func sync_state(profile: Dictionary, selected_slot: int = -1) -> void:
	var guild: Dictionary = profile.get("guild",{})
	if guild.is_empty(): return
	var facilities: Array = []
	var jobs: Array = guild.get("jobs",[])
	for id in Content.data.guildManagement.facilities:
		var facility: Dictionary = guild.facilities.get(id,{})
		var level := int(facility.get("level",0))
		var slot := int(facility.get("slot",-1))
		var construction := false
		for job in jobs:
			if str(job.type)=="construction" and str(job.targetId)==str(id):
				construction = true
				if level==0: slot = int(job.slot)
				break
		if level>0 or construction:
			facilities.append({"id":str(id),"level":level,"slot":slot,"construction":construction})
	var staff: Array = []
	var employees: Array = guild.get("employees",[])
	for index in range(employees.size()):
		var employee: Dictionary = employees[index]
		var id := str(employee.id)
		var activity := str(employee.get("assignment",""))
		var destination := "office" if activity.is_empty() else activity
		for job in jobs:
			if id not in job.get("employeeIds",[]): continue
			match str(job.type):
				"expedition": activity = "away"; destination = "office"
				"research", "recipe": activity = "research"; destination = "research"
				"training": activity = "training"; destination = "office"
				"manufacture": activity = "manufacture"; destination = "revival"
				"itemUpgrade": activity = "itemUpgrade"; destination = "workshop"
			break
		if activity.is_empty(): activity = "idle"
		var target: Dictionary = guild.facilities.get(destination,{})
		var target_slot := int(target.get("slot",0)) if int(target.get("level",0))>0 else 0
		staff.append({"id":id,"slot":target_slot,"actor":STAFF_ACTORS[index%STAFF_ACTORS.size()],"activity":activity})
	set_model({"unlockedFloors":HeroGuildState.floors(Content.data,guild),"selectedSlot":selected_slot,"facilities":facilities,"staff":staff})

func _max_floors() -> int:
	return maxi(1,Content.data.guildManagement.balance.floorUnlockOfficeLevels.size())

func _unlock_level(floor_number: int) -> int:
	var levels: Array = Content.data.guildManagement.balance.floorUnlockOfficeLevels
	return int(levels[clampi(floor_number-1,0,levels.size()-1)])

func set_model(model: Dictionary) -> void:
	var old_floors := _display_floors
	_model = model.duplicate(true)
	_model["unlockedFloors"] = clampi(int(_model.get("unlockedFloors",1)),1,_max_floors())
	_display_floors = mini(int(_model.unlockedFloors)+1,_max_floors())
	if old_floors != _display_floors:
		for collection in [_people,_builders]:
			for id in collection:
				var person: Dictionary = collection[id]
				var shift := (_display_floors-old_floors)*_floor_step
				person.pos.y += shift
				person.goal.y += shift
	_sync_people()
	_sync_rails()
	queue_redraw()

func set_viewport_width(width: float) -> void:
	if is_equal_approx(_width,maxf(width,350.0)): return
	var old_width := _room_width
	var old_step := _floor_step
	_width = maxf(width,350.0)
	_room_width = (_width-LEFT*2.0-GAP*(COLUMNS-1))/COLUMNS
	_room_height = minf(_room_width*0.5,138.0)
	_floor_step = clampf(_room_height+40.0,124.0,178.0)
	for collection in [_people,_builders]:
		for id in collection:
			var person: Dictionary = collection[id]
			var slot := int(person.get("position_slot",person.slot))
			var column := slot%COLUMNS
			var old_left := LEFT+column*(old_width+GAP)
			var ratio := clampf((float(person.pos.x)-old_left)/old_width,0.07,0.93)
			var new_rect := _room_rect(slot)
			person.pos.x = new_rect.position.x+new_rect.size.x*ratio
			person.pos.y += (_display_floors-floori(slot/float(COLUMNS))-1)*(_floor_step-old_step)+(_room_height-minf(old_width*0.5,138.0))
			person.goal = person.pos
	_sync_rails()
	queue_redraw()

func get_content_height() -> float:
	return TOP+_display_floors*_floor_step+BOTTOM

func floor_at(point: Vector2) -> int:
	if point.x<0.0 or point.x>_width or point.y<TOP or point.y>=TOP+_display_floors*_floor_step:
		return 0
	return _display_floors-floori((point.y-TOP)/_floor_step)

func floor_center(floor_number: int) -> Vector2:
	return Vector2(_width*0.5,TOP+(_display_floors-floor_number+0.5)*_floor_step)

func slot_at(point: Vector2) -> int:
	var floor_number := floor_at(point)
	if floor_number<1 or floor_number>int(_model.unlockedFloors): return -1
	for column in range(COLUMNS):
		var slot := (floor_number-1)*COLUMNS+column
		var rect := _room_rect(slot)
		if Rect2(rect.position-Vector2(0,18),Vector2(rect.size.x,_floor_step)).has_point(point): return slot
	return -1

func slot_center(slot: int) -> Vector2:
	var rect := _room_rect(slot)
	return Vector2(rect.get_center().x,rect.end.y-8.0)

func _room_rect(slot: int) -> Rect2:
	var floor_number := floori(slot/float(COLUMNS))+1
	return Rect2(LEFT+(slot%COLUMNS)*(_room_width+GAP),TOP+(_display_floors-floor_number)*_floor_step+18.0,_room_width,_room_height)

func _facility_at(slot: int) -> Dictionary:
	for item in _model.get("facilities",[]):
		if int(item.get("slot",-1))==slot: return item
	return {}

func _prepare_structure() -> void:
	_structure.clear()
	var atlas: Texture2D = _assets.get("structure")
	if atlas==null: return
	var metadata: Dictionary = _assets.get("structure_meta",{})
	var regions: Array = _assets.get("structureRegions",metadata.get("regions",DEFAULT_STRUCTURE))
	for raw in regions:
		var cropped := AtlasTexture.new()
		cropped.atlas = atlas
		cropped.region = Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
		cropped.filter_clip = true
		_structure.append(cropped)

func _piece(index: int, rect: Rect2, color: Color = Color.WHITE) -> void:
	if index<_structure.size(): draw_texture_rect(_structure[index],rect,false,color)

func _draw() -> void:
	if _assets.is_empty(): return
	for floor_number in range(_display_floors,0,-1):
		var unlocked := floor_number<=int(_model.unlockedFloors)
		var floor_color := Color.WHITE if unlocked else Color(0.64,0.72,0.78,0.7)
		var first := _room_rect((floor_number-1)*COLUMNS)
		var top_y := first.position.y
		_piece(2,Rect2(LEFT-12,top_y,18,_room_height+15),floor_color)
		_piece(3,Rect2(_width-LEFT-6,top_y,18,_room_height+15),floor_color)
		for column in range(COLUMNS):
			var slot := (floor_number-1)*COLUMNS+column
			var rect := _room_rect(slot)
			var facility := _facility_at(slot)
			var id := str(facility.get("id",""))
			var level := int(facility.get("level",0))
			var construction := bool(facility.get("construction",false))
			var art := _state_texture(2 if not unlocked else 0)
			if unlocked and level>0: art = _room_texture(id,level)
			if unlocked and construction and level==0: art = _state_texture(1)
			if art!=null: draw_texture_rect(art,rect,false,floor_color)
			_piece(1,Rect2(rect.position-Vector2(0,9),Vector2(rect.size.x,15)),floor_color)
			_piece(0,Rect2(rect.position.x,rect.end.y-6,rect.size.x,17),floor_color)
			if unlocked and construction and level>0:
				var overlay := _state_texture(1)
				if overlay!=null: draw_texture_rect(overlay,rect,false,Color(1,1,1,0.34))
			var selected: Texture2D = _assets.get("selected")
			if int(_model.get("selectedSlot",-1))==slot and selected!=null:
				draw_texture_rect(selected,rect.grow(3),false)
			var caption := "빈 사무실 · 건설" if id.is_empty() else _facility_name(id)+" · Lv.%d"%level
			if construction: caption = _facility_name(id)+" · "+("신규 공사" if level==0 else "강화 중")
			if not unlocked: caption = "확장 예정"
			if int(_model.get("selectedSlot",-1))==slot: caption = "선택 · "+caption
			_text(caption,Vector2(rect.position.x,rect.position.y+22),rect.size.x,13,Color("#3dd6b5") if int(_model.get("selectedSlot",-1))==slot else Color("#e6f0f4") if unlocked else Color("#93a7b5"),true)
		if not unlocked:
			_text("%d층 · 운영실 Lv.%d에 개방"%[floor_number,_unlock_level(floor_number)],Vector2(LEFT,top_y+_room_height*0.52),_width-LEFT*2,17,Color("#f4dcc0"))
		_text("%dF"%floor_number,Vector2(0,top_y+16),LEFT-2,14,Color("#f9eacb"))
	var roof_rect := _room_rect((_display_floors-1)*COLUMNS)
	_piece(5,Rect2(LEFT-8,roof_rect.position.y-29,_width-LEFT*2+16,25))
	# Contact shadows and feet are separate child nodes; this façade never bobs.

func _sync_rails() -> void:
	if _structure.size()<7: return
	while _rails.size()<_display_floors*COLUMNS:
		var rail := TextureRect.new()
		rail.texture = _structure[6]
		rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rail.stretch_mode = TextureRect.STRETCH_SCALE
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.z_index = 8
		add_child(rail)
		_rails.append(rail)
	for slot in range(_rails.size()):
		var rail := _rails[slot]
		rail.visible = slot<_display_floors*COLUMNS
		if not rail.visible: continue
		var rect := _room_rect(slot)
		rail.position = Vector2(rect.position.x,rect.end.y+1)
		rail.size = Vector2(rect.size.x,9)
		rail.modulate = Color.WHITE if slot<int(_model.unlockedFloors)*COLUMNS else Color(0.64,0.72,0.78,0.7)

func _text(caption: String, at: Vector2, width: float, font_size: int, color: Color, plate: bool = false) -> void:
	if _font==null: return
	var text_width := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var baseline := at+Vector2(maxf(0,(width-text_width)*0.5),0)
	# Room names sit on a night-ops nameplate at the top of the room so neither the floor rail nor walking staff cover them.
	if plate: draw_rect(Rect2(baseline.x-8,at.y-font_size-2,minf(text_width,width)+16,font_size+8),Color(0.035,0.07,0.11,0.82))
	draw_string_outline(_font,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,3,Color("#14283b"))
	draw_string(_font,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _facility_name(id: String) -> String:
	return str(Content.data.guildManagement.facilities.get(id,{}).get("name",FACILITY_NAMES.get(id,id)))

func _room_texture(id: String, level: int) -> Texture2D:
	var texture: Texture2D = _assets.get("rooms")
	if texture==null: return null
	var ids: Array = _assets.get("facilityOrder",Content.data.guildManagement.facilities.keys())
	var row := ids.find(id)
	if row<0: return _state_texture(0)
	var column := 0
	var tiers: Array = _assets.get("tiers",[1,4,7,10])
	for index in range(tiers.size()):
		if level>=int(tiers[index]): column = index
	var cell := texture.get_size()/Vector2(4,8)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(column,row)*cell,cell)
	atlas.filter_clip = true
	return atlas

func _state_texture(row: int) -> Texture2D:
	var texture: Texture2D = _assets.get("states")
	if texture==null: return null
	var cell := texture.get_size()/Vector2(1,3)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2(0,row)*cell,cell)
	atlas.filter_clip = true
	return atlas

func _new_person(id: String, slot: int, index: int, actor: String = "hanSeoa") -> Dictionary:
	var visual: Dictionary = Content.visuals.npcs.get(actor,Content.visuals.characters.get(actor,Content.visuals.characters.awakener))
	var node := HeroSDVisual.new()
	add_child(node)
	node.z_index = 6
	node.configure(actor,visual)
	var pos := slot_center(slot)+Vector2((index%3-1)*minf(20.0,_room_width*0.1),0)
	return {"node":node,"slot":slot,"position_slot":slot,"pos":pos,"goal":pos,"facing":1.0,"activity":"","phase":float(index)*1.61,"wander_at":0.0,"departed":false,"transit":0.0}

func _sync_people() -> void:
	if _assets.is_empty(): return
	var present: Array[String] = []
	var index := 0
	for employee in _model.get("staff",[]):
		var id := str(employee.get("id","staff%d"%index))
		present.append(id)
		var slot := clampi(int(employee.get("slot",0)),0,int(_model.unlockedFloors)*COLUMNS-1)
		var is_new := not _people.has(id)
		if is_new: _people[id] = _new_person(id,slot,index,str(employee.get("actor",STAFF_ACTORS[index%STAFF_ACTORS.size()])))
		var person: Dictionary = _people[id]
		var activity := str(employee.get("activity","idle"))
		if is_new and activity in ["away","expedition"]:
			person.pos = _exit_point(1)
			person.position_slot = 0
			person.departed = true
			person.node.visible = false
		if int(person.slot)!=slot or str(person.activity)!=activity:
			person.slot = slot
			person.activity = activity
			person.goal = slot_center(slot)
			person.wander_at = _age+1.4+index*0.3
			if activity not in ["away","expedition"]:
				person.departed = false
				person.node.visible = true
		index+=1
	for id in _people.keys():
		if id not in present:
			_people[id].node.queue_free()
			_people.erase(id)
	var construction_slots: Array[int] = []
	for facility in _model.get("facilities",[]):
		if not bool(facility.get("construction",false)): continue
		var slot := int(facility.get("slot",0))
		construction_slots.append(slot)
		if not _builders.has(slot):
			var person := _new_person("builder%d"%slot,slot,index,"hanSeoa")
			person.activity = "construction"
			person.node.modulate = Color(1,0.91,0.69)
			_builders[slot] = person
	for slot in _builders.keys():
		if slot not in construction_slots:
			_builders[slot].node.queue_free()
			_builders.erase(slot)

func _process(dt: float) -> void:
	_age+=dt
	for collection in [_people,_builders]:
		for id in collection: _advance_person(collection[id],dt)

func _exit_point(floor_number: int) -> Vector2:
	return Vector2(LEFT+8.0,slot_center((floor_number-1)*COLUMNS).y)

func _advance_person(person: Dictionary, dt: float) -> void:
	if person.departed: return
	var slot := int(person.slot)
	var away: bool = str(person.activity) in ["away","expedition"]
	var target_slot := 0 if away else slot
	var rect := _room_rect(target_slot)
	var floor_pos := slot_center(target_slot)
	var source_floor := floori(int(person.position_slot)/float(COLUMNS))+1
	var target_floor := floori(target_slot/float(COLUMNS))+1
	var transit := float(person.transit)
	if transit>0.0:
		person.transit = maxf(0.0,transit-dt)
		person.node.modulate.a = clampf(1.0-float(person.transit)/0.2,0.0,1.0)
	if source_floor!=target_floor:
		# Floor transit is visual only: walk out of the old floor, then enter the new one.
		person.goal = _exit_point(source_floor)
		if (person.pos as Vector2).distance_to(person.goal)<1.0:
			person.pos = _exit_point(target_floor)
			person.position_slot = target_slot
			person.goal = _exit_point(1) if away else floor_pos
			person.transit = 0.2
			person.node.modulate.a = 0.0
	elif away:
		person.goal = _exit_point(1)
	elif int(person.position_slot)!=slot:
		person.goal = floor_pos
		if (person.pos as Vector2).distance_to(floor_pos)<1.0: person.position_slot = slot
	elif _age>=float(person.wander_at):
		var roam := 0.28 if str(person.activity) in ["idle","office","construction"] else 0.08
		person.goal = floor_pos+Vector2(sin(_age*0.72+float(person.phase))*rect.size.x*roam,0)
		person.wander_at = _age+2.1+absf(sin(float(person.phase)))
	var before: Vector2 = person.pos
	person.pos = (person.pos as Vector2).move_toward(person.goal,dt*38.0)
	if absf(float(person.pos.x)-before.x)>0.01: person.facing = signf(float(person.pos.x)-before.x)
	if away and source_floor==1 and (person.pos as Vector2).distance_to(person.goal)<1.0:
		person.departed = true
		person.position_slot = 0
		person.node.visible = false
	var moving := before.distance_squared_to(person.pos)>0.01
	var height := clampf(_room_width*0.23,39.0,61.0)
	person.node.update_state({"pos":person.pos,"facing":person.facing,"age":_age+float(person.phase),"action":"move" if moving else "idle"},dt,height)
