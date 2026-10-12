class_name HeroGuildIsoWorld
extends Node2D

# Quarter-view headquarters: 3 floors x 3 rooms in a staggered brick layout.
# Rooms sit side by side instead of on one shared lot, and the middle floor shifts half a
# room to the right, so no room's walls hide another (user switched from 3x3, 2026-10-09).
# Floor 1 is the back row. Same public API as HeroGuildOfficeWorld.
const ROOM_DIR := "res://assets/ui/guild-iso/rooms/"
const COLUMNS := 3
const ROWS := 3
const MAX_SCALE := 0.39
# Art units: rooms step 400 across, rows step 250 down, odd rows shift half a room.
const STEP := 400.0
const ROW_GAP := 250.0
const TOP := 4.0
# Template room: 512x448, floor diamond T(256,208) R(456,308) B(256,408) L(56,308).
const ART_SIZE := Vector2(512,448)
const FLOOR_CENTER := Vector2(256,308)
const HALF := Vector2(200,100)
const STAFF_ACTORS := ["hanSeoa","awakener","kangTaehoon","parkDojun"]
const FACILITY_NAMES := {
	"office":"운영실", "research":"연구실", "expedition":"탐험부", "production":"생산실",
	"recovery":"회복실", "workshop":"장비공방", "revival":"생환석 제조실", "analysis":"분석실"
}

var _assets: Dictionary = {}
var _model: Dictionary = {"unlockedFloors":1,"selectedSlot":-1,"facilities":[],"staff":[],"progress":{},"rewards":false}
var _width := 547.0
var _scale := MAX_SCALE
var _age := 0.0
var _textures: Dictionary = {}
var _rooms: Array[Sprite2D] = []
var _overlay: Node2D
var _people: Dictionary = {}
var _builders: Dictionary = {}
var _font: Font

class Overlay extends Node2D:
	var world: HeroGuildIsoWorld
	func _draw() -> void:
		if world: world._draw_overlay(self)

func configure(assets: Dictionary) -> void:
	_assets = assets
	_font = HeroImageSkin.font("heading")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	y_sort_enabled = true
	if _rooms.is_empty():
		for slot in range(COLUMNS*ROWS):
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			add_child(sprite)
			_rooms.append(sprite)
		_overlay = Overlay.new()
		_overlay.world = self
		_overlay.z_index = 10
		add_child(_overlay)
	_layout()
	_sync_people()

func sync_state(profile: Dictionary, selected_slot: int = -1) -> void:
	var guild: Dictionary = profile.get("guild",{})
	if guild.is_empty(): return
	var facilities: Array = []
	var progress: Dictionary = {}
	var jobs: Array = guild.get("jobs",[])
	var now := Time.get_unix_time_from_system()
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
	for job in jobs:
		var target := _job_facility(job)
		var slot := int(job.slot) if str(job.type)=="construction" else int(guild.facilities.get(target,{}).get("slot",-1))
		if slot<0 or progress.has(slot): continue
		var span := maxf(1.0,float(job.get("endsAt",now))-float(job.get("startedAt",now)))
		progress[slot] = clampf((now-float(job.get("startedAt",now)))/span,0.0,1.0)
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
				"expedition": activity = "away"
				"research", "recipe": activity = "research"; destination = "research"
				"training": activity = "training"; destination = "office"
				"manufacture": activity = "manufacture"; destination = "revival"
				"itemUpgrade": activity = "itemUpgrade"; destination = "workshop"
			break
		if activity.is_empty(): activity = "idle"
		var target: Dictionary = guild.facilities.get(destination,{})
		var target_slot := int(target.get("slot",0)) if int(target.get("level",0))>0 else 0
		staff.append({"id":id,"slot":target_slot,"actor":STAFF_ACTORS[index%STAFF_ACTORS.size()],"activity":activity})
	set_model({"unlockedFloors":HeroGuildState.floors(Content.data,guild),"selectedSlot":selected_slot,"facilities":facilities,"staff":staff,"progress":progress,"rewards":_has_rewards(guild.get("pendingRewards",{}))})

func set_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	_model["unlockedFloors"] = clampi(int(_model.get("unlockedFloors",1)),1,ROWS)
	_layout()
	_sync_people()

func set_viewport_width(width: float) -> void:
	_width = maxf(width,350.0)
	# Three and a half rooms plus the outer walls must fit the view.
	_scale = minf(MAX_SCALE,_width/((COLUMNS+0.5)*STEP+2.0*(FLOOR_CENTER.x-HALF.x)))
	_layout()

func get_content_height() -> float:
	return _origin().y+((ROWS-1)*ROW_GAP+ART_SIZE.y-FLOOR_CENTER.y)*_scale+4.0

# True when the point is on the office's "보상" bubble (only while rewards wait).
func reward_hit(point: Vector2) -> bool:
	if not bool(_model.get("rewards",false)): return false
	for item in _model.get("facilities",[]):
		if str(item.get("id",""))=="office" and int(item.get("level",0))>0:
			return _bubble_rect(slot_center(int(item.slot))).grow(6).has_point(point)
	return false

func _bubble_rect(center: Vector2) -> Rect2:
	return Rect2(center+Vector2(14,-34),Vector2(40,20))

func floor_at(point: Vector2) -> int:
	var slot := _slot_hit(point)
	return 0 if slot<0 else floori(slot/float(COLUMNS))+1

func floor_center(floor_number: int) -> Vector2:
	return slot_center((clampi(floor_number,1,ROWS)-1)*COLUMNS+1)

func slot_at(point: Vector2) -> int:
	var slot := _slot_hit(point)
	if slot<0 or floori(slot/float(COLUMNS))+1>int(_model.unlockedFloors): return -1
	return slot

func slot_center(slot: int) -> Vector2:
	var row := floori(slot/float(COLUMNS))
	var column := slot%COLUMNS
	return _origin()+Vector2(column*STEP+(row%2)*STEP*0.5,row*ROW_GAP)*_scale

func _origin() -> Vector2:
	# Floor centre of floor 1, room 1, with the whole block centred in the view.
	var span := ((COLUMNS-1)+0.5)*STEP*_scale
	return Vector2((_width-span)*0.5,TOP+FLOOR_CENTER.y*_scale)

func _slot_hit(point: Vector2) -> int:
	# Floors first, then the walls above them; front rows win because they draw on top.
	for slot in range(COLUMNS*ROWS-1,-1,-1):
		var local := (point-slot_center(slot))/(HALF*_scale)
		if absf(local.x)+absf(local.y)<=1.0: return slot
	for slot in range(COLUMNS*ROWS-1,-1,-1):
		var local := (point-slot_center(slot))/(HALF*_scale)
		if absf(local.x)<=1.0 and local.y<0.0 and local.y>=-2.6: return slot
	return -1

func _facility_at(slot: int) -> Dictionary:
	for item in _model.get("facilities",[]):
		if int(item.get("slot",-1))==slot: return item
	return {}

func _texture(name: String) -> Texture2D:
	if _textures.has(name): return _textures[name]
	var path := ROOM_DIR+name+".png"
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if texture==null:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image!=null and not image.is_empty():
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	_textures[name] = texture
	return texture

func _room_art(slot: int) -> String:
	if floori(slot/float(COLUMNS))+1>int(_model.unlockedFloors): return "locked"
	var facility := _facility_at(slot)
	if facility.is_empty(): return "empty"
	var level := int(facility.get("level",0))
	if level==0: return "construction"
	var tier := 1
	for step in [1,4,7,10]:
		if level>=step: tier = step
	return "%s_lv%d" % [str(facility.id),tier]

func _layout() -> void:
	for slot in range(_rooms.size()):
		var sprite := _rooms[slot]
		sprite.texture = _texture(_room_art(slot))
		var center := slot_center(slot)
		# y-sort key is the floor's back corner, so staff in the room draw after it.
		sprite.scale = Vector2(_scale,_scale)
		sprite.position = center-Vector2(0,HALF.y*_scale)
		sprite.offset = Vector2(-FLOOR_CENTER.x,-(FLOOR_CENTER.y-HALF.y))
		sprite.modulate = Color(1,1,1,1) if _room_art(slot)!="locked" else Color(0.8,0.88,0.95,0.85)
	if _overlay: _overlay.queue_redraw()

func _draw_overlay(canvas: Node2D) -> void:
	var selected := int(_model.get("selectedSlot",-1))
	if selected>=0:
		var c := slot_center(selected)
		var h := HALF*_scale
		var outline := PackedVector2Array([c+Vector2(0,-h.y),c+Vector2(h.x,0),c+Vector2(0,h.y),c+Vector2(-h.x,0),c+Vector2(0,-h.y)])
		canvas.draw_polyline(outline,Color("#3dd6b5"),2.5,true)
	var next_locked := int(_model.unlockedFloors)+1
	for slot in range(COLUMNS*ROWS):
		var floor_number := floori(slot/float(COLUMNS))+1
		var center := slot_center(slot)
		var plate_at := center+Vector2(0,HALF.y*_scale*0.42)
		if floor_number>int(_model.unlockedFloors):
			if floor_number==next_locked and slot%COLUMNS==1:
				_plate(canvas,"%d층 · 운영실 Lv.%d" % [floor_number,_unlock_level(floor_number)],center,Color("#f4dcc0"),Color("#93a7b5"))
			continue
		var facility := _facility_at(slot)
		var id := str(facility.get("id",""))
		var level := int(facility.get("level",0))
		var caption := "빈 사무실" if id.is_empty() else _facility_name(id)
		var tag := "" if id.is_empty() else "Lv.%d" % level
		if bool(facility.get("construction",false)): tag = "공사" if level==0 else "강화 중"
		var ink := Color("#3dd6b5") if slot==selected else Color("#e6f0f4")
		_plate(canvas,caption,plate_at,ink,Color("#3dd6b5"),tag)
		var progress: Dictionary = _model.get("progress",{})
		if progress.has(slot):
			var bar := Rect2(plate_at+Vector2(-30,10),Vector2(60,5))
			canvas.draw_rect(bar,Color(0.04,0.08,0.12,0.9))
			canvas.draw_rect(Rect2(bar.position,Vector2(bar.size.x*float(progress[slot]),bar.size.y)),Color("#3dd6b5"))
		if id=="office" and bool(_model.get("rewards",false)):
			var bubble := _bubble_rect(center)
			bubble.position.y += sin(_age*3.2)*2.5
			canvas.draw_rect(bubble,Color("#e8b75a"))
			canvas.draw_rect(bubble,Color("#14283b"),false,1.5)
			_label(canvas,"보상",bubble.position+Vector2(0,15),bubble.size.x,12,Color("#2a1c05"),false)

func _plate(canvas: Node2D, caption: String, at: Vector2, ink: Color, accent: Color, tag: String = "") -> void:
	if _font==null: return
	var size := 12
	var text_width := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var tag_width := 0.0 if tag.is_empty() else _font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x+6.0
	var width := text_width+tag_width+14.0
	var rect := Rect2(at-Vector2(width*0.5,size*0.5+4),Vector2(width,size+8))
	canvas.draw_rect(rect,Color(0.035,0.07,0.11,0.86))
	_label(canvas,caption,rect.position+Vector2(7,size+3),text_width,size,ink)
	if not tag.is_empty(): _label(canvas,tag,rect.position+Vector2(7+text_width+6,size+2),tag_width,10,accent)

func _label(canvas: Node2D, caption: String, baseline: Vector2, width: float, size: int, color: Color, outline: bool = true) -> void:
	var text_width := _font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var at := baseline+Vector2(maxf(0,(width-text_width)*0.5),0)
	if outline: canvas.draw_string_outline(_font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Color("#14283b"))
	canvas.draw_string(_font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _unlock_level(floor_number: int) -> int:
	var levels: Array = Content.data.guildManagement.balance.floorUnlockOfficeLevels
	return int(levels[clampi(floor_number-1,0,levels.size()-1)])

func _facility_name(id: String) -> String:
	return str(Content.data.guildManagement.facilities.get(id,{}).get("name",FACILITY_NAMES.get(id,id)))

func _job_facility(job: Dictionary) -> String:
	match str(job.type):
		"construction": return str(job.targetId)
		"research", "recipe": return "research"
		"itemUpgrade": return "workshop"
		"expedition": return "expedition"
		"manufacture": return "revival"
	return "office"

func _has_rewards(reward: Dictionary) -> bool:
	for key in reward:
		var value = reward[key]
		if value is int or value is float:
			if float(value)>0.0: return true
		elif value is Array:
			if not value.is_empty(): return true
		elif value is Dictionary:
			if _has_rewards(value): return true
	return false

# Staff wander inside the back half of their room so y-sorting keeps them behind front rooms.
func _new_person(slot: int, index: int, actor: String) -> Dictionary:
	var visual: Dictionary = Content.visuals.npcs.get(actor,Content.visuals.characters.get(actor,Content.visuals.characters.awakener))
	var node := HeroSDVisual.new()
	add_child(node)
	node.configure(actor,visual)
	var pos := _spot(slot,float(index)*1.61)
	return {"node":node,"slot":slot,"pos":pos,"goal":pos,"facing":1.0,"activity":"","phase":float(index)*1.61,"wander_at":0.0}

func _spot(slot: int, phase: float) -> Vector2:
	var h := HALF*_scale
	return slot_center(slot)+Vector2(sin(phase)*h.x*0.32,-h.y*0.18+cos(phase*1.3)*h.y*0.12)

func _sync_people() -> void:
	if _assets.is_empty() and _rooms.is_empty(): return
	var present: Array[String] = []
	var index := 0
	for employee in _model.get("staff",[]):
		var id := str(employee.get("id","staff%d"%index))
		var activity := str(employee.get("activity","idle"))
		var slot := clampi(int(employee.get("slot",0)),0,int(_model.unlockedFloors)*COLUMNS-1)
		index += 1
		if activity=="away": continue
		present.append(id)
		if not _people.has(id): _people[id] = _new_person(slot,index,str(employee.get("actor","hanSeoa")))
		var person: Dictionary = _people[id]
		if int(person.slot)!=slot:
			person.slot = slot
			person.pos = _spot(slot,float(person.phase))
			person.goal = person.pos
		person.activity = activity
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
			var person := _new_person(slot,index+slot,"hanSeoa")
			person.node.modulate = Color(1,0.91,0.69)
			_builders[slot] = person
	for slot in _builders.keys():
		if slot not in construction_slots:
			_builders[slot].node.queue_free()
			_builders.erase(slot)

func _process(dt: float) -> void:
	_age += dt
	for collection in [_people,_builders]:
		for id in collection: _advance(collection[id],dt)
	if _overlay and bool(_model.get("rewards",false)): _overlay.queue_redraw()

func _advance(person: Dictionary, dt: float) -> void:
	if _age>=float(person.wander_at):
		person.goal = _spot(int(person.slot),float(person.phase)+_age*0.37)
		person.wander_at = _age+2.4+absf(sin(float(person.phase)))
	var before: Vector2 = person.pos
	person.pos = (person.pos as Vector2).move_toward(person.goal,dt*16.0)
	if absf(float(person.pos.x)-before.x)>0.01: person.facing = signf(float(person.pos.x)-before.x)
	var moving := before.distance_squared_to(person.pos)>0.01
	person.node.update_state({"pos":person.pos,"facing":person.facing,"age":_age+float(person.phase),"action":"move" if moving else "idle"},dt,30.0)
