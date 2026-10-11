class_name HeroSupportPresentation
extends Control

# Artwork animation consumes only accepted UI actions, never pays rewards.
# All times are advanced explicitly so hide/focus loss can freeze the opening.
signal claim_finished
signal opening_finished
const LIGHT_SHADER := preload("res://shaders/parcel_light.gdshader")
var kind := "recovery"
var capture_clock := false
var age := 0.0
var action_age := -1.0
var missing_art: Array[String] = []
var _completed := false
var _suspended := false
var _glint := false
var _drone: TextureRect
var _parcel: TextureRect
var _parcel_shadow: TextureRect
var _drone_shadow: TextureRect
var _body: TextureRect
var _lid: TextureRect
var _seal: TextureRect
var _light: TextureRect
const DRONE_ORIGIN := Vector2(141,154)
const PARCEL_ORIGIN := Vector2(242,255)
const BODY_ORIGIN := Vector2(126,124)
const LID_ORIGIN := Vector2(126,109)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "recovery":
		_drone_shadow = _art("res://assets/visuals/vfx/contact_shadow.png",Rect2(191,310,164,26))
		_drone_shadow.stretch_mode = TextureRect.STRETCH_SCALE
		_drone_shadow.modulate = Color(0.33,0.41,0.46,0.34)
		_parcel_shadow = _art("supportPackageShadow",Rect2(243,256,96,73))
		_parcel_shadow.modulate.a = 0.78
		_drone = _art("supportRecoveryDrone",Rect2(DRONE_ORIGIN,Vector2(252,176)))
		_drone.name = "RecoveryDrone"
		_parcel = _art("supportRecoveryPackage",Rect2(PARCEL_ORIGIN,Vector2(96,73)))
		_parcel.name = "RecoveryParcel"
	else:
		var contact := _art("supportPackageShadow",Rect2(BODY_ORIGIN,Vector2(347,212)))
		contact.modulate.a = 0.85
		_body = _art("supportSupplyBody",Rect2(BODY_ORIGIN,Vector2(347,212)))
		_body.name = "SupplyBody"
		_light = _art("res://assets/visuals/vfx/contact_shadow.png",Rect2(225,164,157,83))
		_light.stretch_mode = TextureRect.STRETCH_SCALE
		var light_material := ShaderMaterial.new()
		light_material.shader = LIGHT_SHADER
		_light.material = light_material
		_light.modulate.a = 0.0
		_lid = _art("supportSupplyLid",Rect2(LID_ORIGIN,Vector2(347,212)))
		_lid.name = "SupplyLid"
		_lid.pivot_offset = Vector2(137,60)
		_lid.scale = Vector2(1.0,0.868)
		_seal = TextureRect.new()
		_seal.texture = Content.trimmed_texture("vfxImpact")
		_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seal.modulate = Color(1.0,0.89,0.55,0.08)
		_lid.add_child(_seal)
		HeroUI.place(_seal,Rect2(121,112,30,30))

func _art(id: String, rect: Rect2) -> TextureRect:
	var result := TextureRect.new()
	# Untrimmed canvas coordinates own the body/lid/contact registration.
	result.texture = Content.texture(id)
	if result.texture == null: missing_art.append(id)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result)
	HeroUI.place(result,rect)
	return result

func start_claim() -> void:
	if kind != "recovery" or is_busy(): return
	action_age = 0.0
	_completed = false
	_glint = false

func start_open() -> void:
	if kind != "supply" or is_busy(): return
	action_age = 0.0
	_completed = false
	_glint = false
	Sound.cue("supplyLatch")

func is_busy() -> bool:
	return action_age >= 0.0 and not _completed

func suspend(value: bool) -> void:
	_suspended = value

func reset() -> void:
	action_age = -1.0
	_completed = false
	_glint = false
	if kind == "supply" and is_instance_valid(_lid):
		_lid.position = LID_ORIGIN
		_lid.rotation = 0.0
		_light.modulate.a = 0.0

func cancel() -> void:
	# No timer or completion callback survives screen removal.
	action_age = -1.0
	_completed = true
	_glint = true
	_suspended = true
	if is_instance_valid(_light): _light.modulate.a = 0.0

func _exit_tree() -> void:
	cancel()

func _process(dt: float) -> void:
	if not capture_clock: advance(dt)

func advance(dt: float) -> void:
	if _suspended or not is_visible_in_tree(): return
	age += dt
	if action_age >= 0.0: action_age += dt
	if kind == "recovery": _advance_recovery()
	else: _advance_supply()

func _advance_recovery() -> void:
	var bob := sin(age*1.8)*3.0
	_drone.position = DRONE_ORIGIN+Vector2(0,bob)
	_drone_shadow.modulate.a = 0.34-bob*0.01
	if action_age < 0.0:
		_parcel.position = PARCEL_ORIGIN
		return
	var landing := smoothstep(0.0,0.22,action_age)
	_parcel.position = PARCEL_ORIGIN+Vector2(0,2.0*landing)
	_parcel_shadow.position.y = 256.0+2.0*landing
	_parcel_shadow.modulate.a = lerpf(0.78,0.9,landing)
	_drone.position += Vector2(0,-7.0*smoothstep(0.1,0.4,action_age))
	if action_age >= 0.22 and not _glint:
		_glint = true
		_effect("offline",_parcel,61)
	if action_age >= 0.45 and not _completed:
		_completed = true
		claim_finished.emit()

func _advance_supply() -> void:
	if action_age < 0.0:
		_seal.modulate.a = 0.035+(sin(age*1.4)+1.0)*0.03
		return
	var opening := smoothstep(0.14,0.52,action_age)
	_lid.position = LID_ORIGIN+Vector2(-8.0*opening,-45.0*opening)
	_lid.rotation = -0.17*opening
	_seal.modulate.a = 0.28*(1.0-smoothstep(0.12,0.32,action_age))
	_light.modulate.a = smoothstep(0.18,0.4,action_age)*(1.0-smoothstep(0.64,0.84,action_age))*0.4
	if action_age >= 0.27 and not _glint:
		_glint = true
		_effect("supply",_body,81)
	if action_age >= 0.85 and not _completed:
		_completed = true
		Sound.cue("supplyFanfare")
		opening_finished.emit()

func _effect(effect: String, anchor: Control, seed_value: int) -> void:
	var effects := get_tree().get_first_node_in_group("ui_effects") as HeroUIEffects
	if effects != null: effects.show_effect(effect,{"control":anchor,"seed":seed_value})

func snapshot() -> Dictionary:
	return {"kind":kind,"age":age,"action_age":action_age,"busy":is_busy(),"suspended":_suspended,"completed":_completed}
