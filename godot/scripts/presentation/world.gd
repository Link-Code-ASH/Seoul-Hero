class_name HeroWorld
extends Node2D

var run: HeroRun:
	set(value):
		run = value
		_fitted_arena = Vector2.ZERO
		_last_combat_time = value.combat_time if value != null else 0.0
		if is_instance_valid(_combat): _combat.bind(value)
var wallet_target := Vector2(215,59)
var _scale := 1.0
var _shadow: Texture2D
var _drawing_transform := Transform2D.IDENTITY
var _combat: HeroCombatPresentation
var _last_combat_time := 0.0
var _fitted_screen := Rect2()
var _fitted_arena := Vector2.ZERO
const STONE_VISUAL_SCALE := 1.3

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shadow = load("res://assets/visuals/vfx/contact_shadow.png")
	_combat = HeroCombatPresentation.new(); add_child(_combat)
	if run != null: _combat.bind(run)

func _process(_dt: float) -> void:
	if run == null or not visible: return
	_update_camera()
	var animation_dt := maxf(0,run.combat_time-_last_combat_time) if run.phase == "waveActive" else 0.0
	_last_combat_time = run.combat_time
	_combat.transform = _drawing_transform
	_combat.visible_world = _drawing_transform.affine_inverse()*get_viewport_rect()
	_combat.sync(animation_dt)
	# Complete only the brief visual collapse after combat stops for revival/results.
	# The simulation clock, projectiles and ordinary pause stay frozen.
	if run.phase in ["revivalChoice","gameOver"]: _combat.finish_player_death(_dt)
	queue_redraw()

func _update_camera() -> void:
	var screen := get_viewport_rect()
	var arena := Vector2(run.map.arenaWidth,run.map.arenaHeight)
	if screen == _fitted_screen and arena == _fitted_arena: return
	# Keep uniform scale and authored height; adapt width so every screen pixel is arena.
	_scale = screen.size.y/arena.y
	run.map.arenaWidth = screen.size.x/_scale
	arena.x = run.map.arenaWidth
	_fitted_screen = screen; _fitted_arena = arena
	_drawing_transform = Transform2D(0.0,Vector2.ONE*_scale,0.0,screen.get_center())

func to_screen(point: Vector2) -> Vector2:
	return _drawing_transform * point

func player_limits() -> Rect2:
	var arena := Vector2(run.map.arenaWidth,run.map.arenaHeight)
	var actor: Node2D = _combat._active.get("player")
	if actor == null: return Rect2()
	var bounds: Rect2 = actor.visual_bounds()
	# The avatar reaches the display edge with its visible body, without letterboxing ground.
	return Rect2(-arena*0.5-bounds.position,arena-bounds.size)

func _draw() -> void:
	if run == null: return
	var arena := Vector2(run.map.arenaWidth,run.map.arenaHeight)
	var visual: Dictionary = Content.visuals.get("maps",{}).get(run.setup.map,{})
	var path: String = visual.get("texture",run.map.thumbnail)
	var background := Content.texture(path)
	draw_set_transform_matrix(_drawing_transform)
	if background:
		# Landmarks and ground decoration belong to the authored scene. Keep its
		# proportions and crop the outer ground to fill the fixed arena.
		var texture_size := background.get_size()
		var fit_scale := maxf(arena.x/texture_size.x,arena.y/texture_size.y)
		var crop_size := arena/fit_scale
		var source := Rect2((texture_size-crop_size)*0.5,crop_size)
		draw_texture_rect_region(background,Rect2(-arena*0.5,arena),source)
	for pickup in run.pickups: _stone(pickup.pos,pickup.value)
	for hazard in run.hazards:
		draw_circle(hazard.pos,hazard.radius,Color(0.8,0.24,0.32,0.18+sin(run.combat_time*7.0)*0.04))
	# Wallet screen destination remains the live HUD icon position.
	if run.phase == "postWave":
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var t: float = clampf(run.post_elapsed/0.8,0,1)
		for pickup in run.wallet_flights:
			var point := to_screen(pickup.pos).lerp(wallet_target,1.0-pow(1.0-t,3))
			var texture := Content.trimmed_texture("magicStone")
			var size := Vector2(15,19)*STONE_VISUAL_SCALE
			if texture: draw_texture_rect(texture,Rect2(point-size*0.5,size),false,Color(1,1,1,1-t*0.4))
	draw_set_transform(Vector2.ZERO)

func _stone(point: Vector2, amount: float) -> void:
	var tier: Dictionary = run.data.magicStone["1"]
	for key in run.data.magicStone:
		if amount >= run.data.magicStone[key].minValue: tier = run.data.magicStone[key]
	draw_texture_rect(_shadow,Rect2(point-Vector2(8,3)*STONE_VISUAL_SCALE,Vector2(16,6)*STONE_VISUAL_SCALE),false,Color(1,1,1,0.7))
	var rgb := int(tier.tint)
	var tint := Color(float((rgb>>16)&255)/255,float((rgb>>8)&255)/255,float(rgb&255)/255)
	var texture := Content.trimmed_texture("magicStone")
	if texture:
		var size := texture.get_size()*minf(17.0/texture.get_width(),23.0/texture.get_height())*float(tier.scale)*STONE_VISUAL_SCALE
		draw_texture_rect(texture,Rect2(point-Vector2(0,6)*STONE_VISUAL_SCALE-size*0.5,size),false,tint)
