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
const HAZARD_SMOKE = preload("res://assets/visuals/vfx/smoke.png")
const HAZARD_RIM = preload("res://assets/visuals/vfx/shockwave.png")
const HAZARD_GLINT = preload("res://assets/visuals/vfx/spark.png")
# Presentation-only stone shimmer; never stored in Run or checkpoints.
const STONE_BOB := 0.7
const STONE_GLINT_PERIOD := 2.4
const STONE_GLINT_LENGTH := 0.32
var _glow: GradientTexture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_shadow = load("res://assets/visuals/vfx/contact_shadow.png")
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,0.85),Color(1,1,1,0.0)])
	_glow = GradientTexture2D.new(); _glow.gradient = gradient
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5,0.5); _glow.fill_to = Vector2(0.5,1.0)
	_glow.width = 32; _glow.height = 32
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
	for drop in run.loot_pickups: _loot(drop)
	for hazard in run.hazards:
		_hazard(hazard.pos,hazard.radius)
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

# 협회 코인 / 생환석 on the ground: same contact shadow as stones, a little larger.
func _loot(drop: Dictionary) -> void:
	var image_id: String = "associationCoin" if drop.type == "coin" else str(run.data.revivalStones[drop.grade].image)
	var texture := Content.trimmed_texture(image_id)
	if texture == null: return
	var point: Vector2 = drop.pos
	var size := texture.get_size()*minf(30.0/texture.get_width(),30.0/texture.get_height())*STONE_VISUAL_SCALE
	var shadow_size := Vector2(size.x*1.5,size.x*0.9)
	if _shadow: draw_texture_rect(_shadow,Rect2(point+Vector2(-size.x*0.12,size.y*0.3)-shadow_size*0.5,shadow_size),false,Color(1,1,1,0.8))
	var lift := (0.5+0.5*sin(run.combat_time*3.0+fmod(absf(point.x*0.05),TAU)))*STONE_BOB*STONE_VISUAL_SCALE
	draw_texture_rect(texture,Rect2(point-Vector2(size.x*0.5,size.y*0.85+lift),size),false)

func _stone(point: Vector2, amount: float) -> void:
	var tier: Dictionary = run.data.magicStone["1"]
	for key in run.data.magicStone:
		if amount >= run.data.magicStone[key].minValue: tier = run.data.magicStone[key]
	# Phase comes from the ground position so neighbouring stones do not bob in unison.
	var phase := fmod(absf(point.x*0.043+point.y*0.067),TAU)
	# Stones being pulled in move fast; keep them still so the position phase cannot jitter.
	var settled := point.distance_to(run.player.pos) >= float(run.stats.get("pickupRange",0.0))
	var lift := (0.5+0.5*sin(run.combat_time*3.2+phase))*STONE_BOB*STONE_VISUAL_SCALE if settled else 0.0
	var rgb := int(tier.tint)
	var tint := Color(float((rgb>>16)&255)/255,float((rgb>>8)&255)/255,float(rgb&255)/255)
	var texture := Content.trimmed_texture("magicStone")
	if texture:
		var size := texture.get_size()*minf(17.0/texture.get_width(),23.0/texture.get_height())*float(tier.scale)*STONE_VISUAL_SCALE
		# Stones rest on the ground: a dark contact shadow as wide as the stone, the base
		# tucked into it, and only a slight bob that tightens the shadow when it lifts.
		# The shadow falls down-left like the plaza's statues and trees, so it shows past the stone.
		var foot := point+Vector2(-size.x*0.12,size.y*0.08)
		var shadow_size := Vector2(size.x*1.5,size.x*0.95)*(1.0-lift*0.04)
		# One light pass of the soft contact shadow (user: the old double pass + smoke core was too dark).
		draw_texture_rect(_shadow,Rect2(foot-shadow_size*0.5,shadow_size),false,Color(1,1,1,0.5))
		var center := point-Vector2(0,size.y*0.38+lift)
		draw_texture_rect(texture,Rect2(center-size*0.5,size),false,tint)
		if settled: _stone_glint(center+Vector2(size.x*0.18,-size.y*0.22),size.y,phase)

func _stone_glint(center: Vector2, height: float, phase: float) -> void:
	var cycle := fmod(run.combat_time+phase/TAU*STONE_GLINT_PERIOD,STONE_GLINT_PERIOD)
	if cycle > STONE_GLINT_LENGTH: return
	var strength := sin(cycle/STONE_GLINT_LENGTH*PI)
	var arm := height*0.42*strength
	if arm < 1.0: return
	var glint := Vector2.ONE*arm*2.4
	draw_texture_rect(HAZARD_GLINT,Rect2(center-glint*0.5,glint),false,Color(1.0,0.96,0.82,0.95*strength))

# Painted danger pool: a soft coral smoke patch with a smudged rim that breathes.
func _hazard(point: Vector2, radius: float) -> void:
	var pulse := sin(run.combat_time*7.0)
	var pool := Vector2.ONE*radius*2.1
	draw_texture_rect(HAZARD_SMOKE,Rect2(point-pool*0.5,pool),false,Color(0.94,0.36,0.3,0.42+pulse*0.06))
	var rim := Vector2.ONE*radius*2.0*(1.0+pulse*0.02)
	draw_texture_rect(HAZARD_RIM,Rect2(point-rim*0.5,rim),false,Color(0.94,0.42,0.36,0.55+pulse*0.08))
