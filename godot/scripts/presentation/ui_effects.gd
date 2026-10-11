class_name HeroUIEffects
extends HeroMobileScreen

const PRESETS := "res://data/visuals/ui_effects.json"
const SHADER := preload("res://shaders/ui_vfx.gdshader")
var _data: Dictionary = {}
var _view: Control
var _view_key := ""
var _pending: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _suspended := false
var _particles := 0
var _serial := 0
var _used_rects: Dictionary = {}

func _ready() -> void:
	super._ready()
	_data = JSON.parse_string(FileAccess.get_file_as_string(PRESETS))
	add_to_group("ui_effects")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visibility_changed.connect(func():
		if not is_visible_in_tree(): clear()
	)

static func texture_bounds(material: ShaderMaterial, texture: Texture2D, region: Rect2 = Rect2()) -> void:
	if texture == null: return
	var source := texture
	var bounds := region if region.has_area() else Rect2(Vector2.ZERO,texture.get_size())
	while source is AtlasTexture:
		var atlas := source as AtlasTexture
		bounds.position += atlas.region.position
		source = atlas.atlas
		if source == null: return
	var dimensions := source.get_size()
	material.set_shader_parameter("texture_bounds",Vector4(bounds.position.x/dimensions.x,bounds.position.y/dimensions.y,bounds.size.x/dimensions.x,bounds.size.y/dimensions.y))

static func enqueue(owner: Node, kind: String, payload: Dictionary = {}) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree(): return
	var layer := owner.get_tree().get_first_node_in_group("ui_effects") as HeroUIEffects
	if layer != null: layer.queue_effect(kind,payload)

func queue_effect(kind: String, payload: Dictionary = {}) -> void:
	if _suspended: return
	if _pending.size() >= int(_data.get("maxQueued",16)): _pending.pop_front()
	_pending.append({"kind":kind,"payload":payload.duplicate(),"view_key":str(payload.get("view_key",_view_key))})

func bind_view(control: Control, screen_key: String, enter: bool = false) -> void:
	if screen_key != _view_key:
		clear(false)
	_view = control
	_view_key = screen_key
	var serial := _serial + 1
	_serial = serial
	_finish_mount.call_deferred(serial,enter)

func _finish_mount(serial: int, enter: bool) -> void:
	if serial != _serial or not is_instance_valid(_view) or _suspended: return
	if enter: show_effect("entry")
	var queued := _pending.duplicate()
	_pending.clear()
	for intent: Dictionary in queued:
		if str(intent.view_key) == _view_key: show_effect(str(intent.kind),intent.payload)

func show_effect(kind: String, payload: Dictionary = {}) -> void:
	if _suspended or not is_visible_in_tree(): return
	var recipes: Dictionary = _data.get("recipes",{})
	if not recipes.has(kind): return
	var recipe: Dictionary = recipes[kind]
	var duration := maxf(0.05,float(recipe.duration))
	if str(recipe.get("mode","")) == "fade":
		_fade(kind,recipe,payload,duration)
		return
	var target := _anchor(payload,recipe)
	var rect := _effect_rect(target,payload,recipe)
	if not rect.has_area(): return
	var clip := Rect2(Vector2.ZERO,REFERENCE)
	var ancestor: Node = target
	while is_instance_valid(ancestor):
		if ancestor is ScrollContainer: clip = clip.intersection(local_rect(ancestor))
		ancestor = ancestor.get_parent()
	if payload.get("clip") is Rect2: clip = clip.intersection(payload.clip)
	if not rect.intersects(clip): return
	_limit_effects()
	# Coalesce repeated glints on the same visible region rather than piling up.
	for effect: Dictionary in _effects:
		if effect.get("kind","") == kind and effect.get("rect",Rect2()) == rect:
			effect.age = 0.0
			return
	var holder := Control.new()
	holder.name = "UIFX_"+kind
	holder.position = clip.position; holder.size = clip.size
	holder.clip_contents = true; holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var material := ShaderMaterial.new(); material.shader = SHADER
	material.set_shader_parameter("strength",float(recipe.get("strength",0.2)))
	material.set_shader_parameter("edge_only",bool(recipe.get("edgeOnly",false)))
	material.set_shader_parameter("accent",Color(str(recipe.get("color","#d4fff2"))))
	var face: Control
	if str(recipe.get("mode","")) == "edge":
		# Match the existing nine-slice outline exactly, including partial scroll clipping.
		face = HeroImageSkin.material(holder,"accents/selection",Rect2(rect.position-clip.position,rect.size))
		for surface in face.get_children(true):
			if surface is HeroImageSkin.ImageSurface:
				surface.material = material
				texture_bounds(material,surface.texture,surface.region_rect)
	else:
		var image := TextureRect.new()
		var supplied = payload.get("texture")
		image.texture = supplied as Texture2D if supplied is Texture2D else HeroImageSkin.source_texture("glass/cell")
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_SCALE
		image.position = rect.position-clip.position; image.size = rect.size
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE; image.material = material
		holder.add_child(image); face = image
		texture_bounds(material,image.texture)
	var effect := {"kind":kind,"age":float(payload.get("elapsed",0.0))-maxf(0,float(payload.get("delay",0.0))),"duration":duration,"holder":holder,"face":face,"material":material,"rect":rect,"particles":[],"count":0,"recipe":recipe,"target":weakref(target) if is_instance_valid(target) and not payload.has("rect") else null,"clip":clip}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(payload.get("seed",Time.get_ticks_usec()))
	var count := mini(int(recipe.get("particles",0)),int(_data.get("maxParticles",48))-_particles)
	var texture := Content.trimmed_texture(str(_data.get("particleImage","supplyOpeningBurst")))
	var center := rect.get_center()
	for index in range(maxi(0,count)):
		var spark := TextureRect.new()
		spark.texture = texture; spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.modulate = Color(str(recipe.get("color","#fff0ba")))
		var diameter := float(recipe.get("particleSize",8))*rng.randf_range(0.65,1.1)
		spark.size = Vector2.ONE*diameter
		holder.add_child(spark)
		var angle := TAU*float(index)/maxf(1,count)+rng.randf_range(-0.2,0.2)
		var travel := Vector2(cos(angle),sin(angle))*float(recipe.get("spread",24))*rng.randf_range(0.7,1.1)
		var origin := center+Vector2(rng.randf_range(-5,5),rng.randf_range(-4,4))-clip.position
		effect.particles.append({"node":spark,"origin":origin,"travel":travel,"rotation":rng.randf_range(-0.5,0.5)})
	effect.count = count; _particles += count
	_effects.append(effect)
	_update_effect(effect)

func _anchor(payload: Dictionary, recipe: Dictionary) -> Control:
	var control = payload.get("control")
	if is_instance_valid(control) and control is Control: return control
	var key := str(payload.get("anchor",recipe.get("anchor","")))
	return _view.find_child(key,true,false) as Control if is_instance_valid(_view) and not key.is_empty() else null

func local_rect(control: Control) -> Rect2:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var bounds := control.get_global_rect()
	return Rect2(inverse*bounds.position, inverse.basis_xform(bounds.size))

func _effect_rect(target: Control, payload: Dictionary, recipe: Dictionary) -> Rect2:
	if payload.get("rect") is Rect2: return payload.rect
	if payload.get("rect") is Array:
		var values: Array = payload.rect
		if values.size() == 4: return Rect2(values[0],values[1],values[2],values[3])
	if is_instance_valid(target):
		var bounds := local_rect(target)
		if str(recipe.get("mode","")) == "burst" and target.has_meta("ui_fx_art_rect"):
			var art: Rect2 = target.get_meta("ui_fx_art_rect")
			return Rect2(bounds.position+art.position,art.size)
		if target is TextureRect and str(recipe.get("mode","")) == "burst": return _image_rect(target as TextureRect,bounds)
		return bounds
	var fallback: Array = recipe.get("rect",[])
	return Rect2(fallback[0],fallback[1],fallback[2],fallback[3]) if fallback.size() == 4 else Rect2()

func _image_rect(control: TextureRect, bounds: Rect2) -> Rect2:
	var texture := control.texture
	if texture == null: return bounds
	var dimensions := texture.get_size()
	if dimensions.x <= 0 or dimensions.y <= 0: return bounds
	var drawn := bounds
	if control.stretch_mode in [TextureRect.STRETCH_KEEP_ASPECT,TextureRect.STRETCH_KEEP_ASPECT_CENTERED]:
		var factor := minf(bounds.size.x/dimensions.x,bounds.size.y/dimensions.y)
		drawn.size = dimensions*factor
		if control.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED: drawn.position += (bounds.size-drawn.size)*0.5
	elif control.stretch_mode == TextureRect.STRETCH_KEEP:
		drawn.size = dimensions
	elif control.stretch_mode != TextureRect.STRETCH_SCALE: return bounds
	var key := texture.get_instance_id()
	if not _used_rects.has(key):
		var bitmap := texture.get_image()
		_used_rects[key] = Rect2(bitmap.get_used_rect()) if bitmap != null else Rect2(Vector2.ZERO,dimensions)
	var used: Rect2 = _used_rects[key]
	if not used.has_area(): return drawn
	return Rect2(drawn.position+used.position/dimensions*drawn.size,used.size/dimensions*drawn.size)

func _fade(kind: String, recipe: Dictionary, payload: Dictionary, duration: float) -> void:
	var targets: Array[CanvasItem] = []
	var anchor := _anchor(payload,recipe)
	if is_instance_valid(anchor): targets.append(anchor)
	elif is_instance_valid(_view):
		if str(recipe.get("targets","")) == "surfaces":
			_collect_surfaces(_view,targets)
		else:
			for key in recipe.get("anchors",[]):
				var node := _view.find_child(str(key),true,false) as CanvasItem
				if is_instance_valid(node): targets.append(node)
	if targets.is_empty(): return
	# Restore and remove overlapping fades before reading their original alpha.
	for index in range(_effects.size()-1,-1,-1):
		var previous: Dictionary = _effects[index]
		if not previous.has("fade"): continue
		var overlaps := false
		for state: Dictionary in previous.fade:
			if state.node in targets: overlaps = true; break
		if overlaps:
			_dispose(previous); _effects.remove_at(index)
	_limit_effects()
	var states: Array[Dictionary] = []
	for node in targets: states.append({"node":node,"color":node.self_modulate})
	var effect := {"kind":kind,"age":float(payload.get("elapsed",0.0))-maxf(0,float(payload.get("delay",0.0))),"duration":duration,"fade":states,"from":float(recipe.get("from",0.5)),"count":0}
	_effects.append(effect)
	_update_effect(effect)

func _collect_surfaces(node: Node, result: Array[CanvasItem]) -> void:
	for child in node.get_children(true):
		if child is HeroImageSkin.ImageSurface: result.append(child)
		else: _collect_surfaces(child,result)

func _limit_effects() -> void:
	if _effects.size() >= int(_data.get("maxEffects",20)):
		_dispose(_effects.pop_front())

func _process(delta: float) -> void:
	if _suspended or not is_visible_in_tree(): return
	advance_for_capture(minf(delta,0.04))

func advance_for_capture(seconds: float) -> void:
	for index in range(_effects.size()-1,-1,-1):
		var effect: Dictionary = _effects[index]
		effect.age = float(effect.age)+maxf(0,seconds)
		if float(effect.age) >= float(effect.duration):
			_dispose(effect); _effects.remove_at(index)
		else: _update_effect(effect)

func _update_effect(effect: Dictionary) -> void:
	var progress := clampf(float(effect.age)/float(effect.duration),0,1)
	if effect.has("fade"):
		for state: Dictionary in effect.fade:
			if is_instance_valid(state.node):
				var original: Color = state.color
				state.node.self_modulate = Color(original,original.a*lerpf(float(effect.from),1.0,1.0-pow(1.0-progress,2)))
		return
	_follow_anchor(effect)
	var material: ShaderMaterial = effect.material
	material.set_shader_parameter("progress",progress)
	for particle: Dictionary in effect.particles:
		var spark: TextureRect = particle.node
		var at: Vector2 = particle.origin+particle.travel*(1-pow(1-progress,2))
		spark.position = at-spark.size*0.5
		spark.rotation = float(particle.rotation)*progress
		spark.modulate.a = sin(progress*PI)*0.72

func _follow_anchor(effect: Dictionary) -> void:
	var reference = effect.get("target")
	if not reference is WeakRef: return
	var target := reference.get_ref() as Control
	if not is_instance_valid(target):
		effect.holder.visible = false
		return
	var actual := _effect_rect(target,{},effect.recipe)
	var previous: Rect2 = effect.rect
	if actual == previous: return
	var movement := actual.get_center()-previous.get_center()
	var clip: Rect2 = effect.clip
	effect.face.position = actual.position-clip.position
	effect.face.size = actual.size
	for particle: Dictionary in effect.particles: particle.origin += movement
	effect.rect = actual

func _dispose(effect: Dictionary) -> void:
	_particles = maxi(0,_particles-int(effect.get("count",0)))
	if effect.has("fade"):
		for state: Dictionary in effect.fade:
			if is_instance_valid(state.node): state.node.self_modulate = state.color
	if is_instance_valid(effect.get("holder")): effect.holder.queue_free()

func clear(clear_pending: bool = true) -> void:
	for effect: Dictionary in _effects: _dispose(effect)
	_effects.clear(); _particles = 0
	if clear_pending: _pending.clear()

func suspend(value: bool) -> void:
	_suspended = value
	if value: clear()
	set_process(not value)

func snapshot() -> Dictionary:
	var anchors := {}
	if is_instance_valid(_view):
		for key in ["ResultRewardArt","GrowthArt","SupplyPreviewArt","GateDetailArt","OfflineRewardArt"]:
			var target := _view.find_child(key,true,false) as Control
			if not is_instance_valid(target): continue
			var bounds := _effect_rect(target,{},{"mode":"burst"})
			anchors[key] = [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
	var active: Array[Dictionary] = []
	for effect: Dictionary in _effects:
		if not effect.has("rect"): continue
		var bounds: Rect2 = effect.rect
		active.append({"kind":effect.kind,"rect":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
	return {"effects":_effects.size(),"particles":_particles,"pending":_pending.size(),"screen":_view_key,"suspended":_suspended,"anchors":anchors,"active":active}
