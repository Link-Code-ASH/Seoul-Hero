class_name HeroGuild
extends Node2D

signal enter_gate
signal facility_changed
signal open_roster
var position_on_floor := Vector2.ZERO
var direction := Vector2.ZERO
var clock := 0.0
var moving := false
var nearest := ""
var movement: HeroMovement
var _avatar := HeroSDVisual.new()
var _avatar_layer := Node2D.new()
var _horizontal_facing := 1.0
var _canvas := Transform2D.IDENTITY

func _ready() -> void:
	var room: Dictionary = Content.data.guildRoom
	position_on_floor = Vector2(room.spawnX,room.spawnY)
	add_child(_avatar_layer); _avatar_layer.add_child(_avatar)
	_avatar.configure("hanSeoa",Content.visuals.npcs.hanSeoa)
	_update_avatar(0.0)

func _physics_process(dt: float) -> void:
	if not visible or movement == null: return
	direction = movement.vector(); moving = direction.length_squared() > 0.01; clock += dt
	if moving:
		if absf(direction.x) > 0.1: _horizontal_facing = signf(direction.x)
		var step: Vector2 = direction * Content.data.guildRoom.speed * dt
		var next := position_on_floor + Vector2(step.x,0)
		if _walkable(next): position_on_floor.x = next.x
		next = position_on_floor + Vector2(0,step.y)
		if _walkable(next): position_on_floor.y = next.y
	var target := ""
	var distance := float(Content.data.guildRoom.interactionRadius) + 70.0
	for id in Content.data.guildFacilities:
		var point: Dictionary = Content.data.guildFacilities[id]
		var gap := position_on_floor.distance_to(Vector2(point.x,point.y))
		if gap < distance: target = id; distance = gap
	for point in Content.data.guildPoints:
		var gap := position_on_floor.distance_to(Vector2(point.x,point.y))
		if gap < distance: target = point.id; distance = gap
	if nearest != target: nearest = target; facility_changed.emit()
	_update_avatar(dt)
	queue_redraw()

func _update_avatar(dt: float) -> void:
	var screen := get_viewport_rect().size
	var room: Dictionary = Content.data.guildRoom
	var scale_value := minf(screen.x / room.width,screen.y / room.height)
	var offset := (screen - Vector2(room.width,room.height) * scale_value) * 0.5
	_canvas = Transform2D(0,Vector2.ONE * scale_value,0,offset)
	_avatar_layer.transform = _canvas
	_avatar.update_state({"pos":position_on_floor,"facing":_horizontal_facing,"age":clock,"action":"move" if moving else "idle"},dt,108.0)

func _walkable(point: Vector2) -> bool:
	var room: Dictionary = Content.data.guildRoom
	if point.x < room.minX or point.x > room.maxX or point.y < room.minY or point.y > room.maxY: return false
	for obstacle in Content.data.guildFootprints:
		if point.x > obstacle.minX - 12 and point.x < obstacle.maxX + 12 and point.y > obstacle.minY - 8 and point.y < obstacle.maxY + 8: return false
	return true

func interact() -> void:
	if nearest == "gate": enter_gate.emit(); return
	if nearest == "roster": open_roster.emit(); return
	if not Content.data.guildFacilities.has(nearest): return
	var facility: Dictionary = Content.data.guildFacilities[nearest]
	var level: int = Profile.meta.guild.facilityLevels[nearest]
	if level >= int(facility.maxLevel): return
	var cost: int = facility.costs[level]
	if Profile.meta.wallet.associationCoins < cost: return
	Profile.meta.wallet.associationCoins -= cost
	Profile.meta.guild.facilityLevels[nearest] = level + 1
	Profile.save(); Sound.cue("purchase"); facility_changed.emit()

func _draw() -> void:
	var screen := get_viewport_rect().size
	var room: Dictionary = Content.data.guildRoom
	var scale_value := minf(screen.x / room.width,screen.y / room.height)
	var offset := (screen - Vector2(room.width,room.height) * scale_value) * 0.5
	_canvas = Transform2D(0,Vector2.ONE * scale_value,0,offset)
	draw_set_transform_matrix(_canvas)
	var background := Content.texture("guildHall")
	if background: draw_texture_rect(background,Rect2(Vector2.ZERO,Vector2(room.width,room.height)),false)
	draw_set_transform(Vector2.ZERO)

func controls(back: Callable) -> Control:
	var root := HeroUI.root()
	HeroUI.place(HeroUI.button(root,"이전",back,88),Rect2(12,10,88,44))
	var group := Control.new()
	group.name = "Interaction"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(group)
	HeroUI.place(group,Rect2(603,232,300,168))
	if nearest.is_empty(): return root
	if nearest == "gate":
		HeroUI.framed_button(group,"출동 준비",Rect2(0,112,300,56),interact)
		return root
	if nearest == "roster":
		HeroUI.framed_button(group,"길드 명부",Rect2(0,112,300,56),interact)
		return root
	if not Content.data.guildFacilities.has(nearest): return root
	var facility: Dictionary = Content.data.guildFacilities[nearest]
	var panel := HeroUI.panel(group,"glass")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := HeroUI.column(panel)
	var level: int = Profile.meta.guild.facilityLevels[nearest]
	var title := HeroUI.paragraph(box,"%s · %d / 3" % [facility.name,level],17)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HeroUI.text_block(box,facility.effect,HeroUI.lines_height(box,14,2),14,HeroUI.ink(box),true,{"align":HORIZONTAL_ALIGNMENT_LEFT,"valign":VERTICAL_ALIGNMENT_TOP,"lines":2,"overflow":"wrap"})
	HeroUI.spacer(box)
	var cost: int = facility.costs[level] if level < 3 else 0
	HeroUI.button(box,"완료" if level >= 3 else "강화 · %d 코인" % cost,interact,220).disabled = level >= 3 or Profile.meta.wallet.associationCoins < cost
	return root
