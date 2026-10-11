extends Node

# Art style test: art-library monster originals next to the current SD enemies in
# 광화문 combat. Library art is loaded at runtime and registered only in this
# process's memory; no game data, content.json or save file is changed.
# Requires --ui-preview so no profile or checkpoint is ever written.
const LIBRARY := [
	{"key":"lib001","asset":"monster-001","like":"crawler"},
	{"key":"lib065","asset":"monster-065","like":"runner"},
	{"key":"lib019","asset":"monster-019","like":"spitter"},
	{"key":"lib035","asset":"monster-035","like":"glassJelly"},
	{"key":"lib081","asset":"monster-081","like":"bulwark"},
	{"key":"lib145","asset":"monster-145","like":"bulwark","elite":true},
]
const TEXTURE_HEIGHT := 640
# Light boost tried on the library art for the tinted capture.
const TINT_BRIGHTNESS := 1.08
const TINT_CONTRAST := 1.04
const TINT_SATURATION := 1.32
# Outline style test: runtime material only, tuned here and reported with the captures.
const STYLE_SHADER := preload("res://shaders/library_monster_style.gdshader")
const LOCOMOTION_SHADER := preload("res://shaders/enemy_locomotion.gdshader")
const STYLED_SUFFIX := "s"
const STYLE := {"outline_px":2.5,"outline_color":Color("1a1420"),"outline_tint":0.5,"alpha_floor":0.15,"alpha_ramp":0.08,"saturation":1.35,"contrast":1.1,"quad_pad":0.2}
var _styled_textures: Dictionary = {}
var _pixel_scale := 1.0
var _output := ""
var _world: HeroWorld
var _canvas := CanvasLayer.new()
var _noop := func(_value = null,_other = null): pass
var _names: Dictionary = {}

func _ready() -> void:
	_main.call_deferred()

func _state(wave: int, elapsed: float) -> Dictionary:
	var setup := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	var run := HeroRun.new(Content.data.duplicate(true),setup,Profile.meta)
	run.wave = wave; run.elapsed = elapsed; run.combat_time = 100.0 + elapsed
	return {"run":run,"sim":HeroSimulation.new(run)}

func _visible_region(image: Image) -> Array:
	# Ignore almost-transparent generator specks, like the reviewed regions in actors.json.
	var step := 4
	var low := Vector2i(image.get_width(),image.get_height())
	var high := Vector2i(-1,-1)
	for y in range(0,image.get_height(),step):
		for x in range(0,image.get_width(),step):
			if image.get_pixel(x,y).a > 0.12:
				low = Vector2i(mini(low.x,x),mini(low.y,y)); high = Vector2i(maxi(high.x,x),maxi(high.y,y))
	if high.x < 0: return [0,0,image.get_width(),image.get_height()]
	low = (low - Vector2i(step,step)).max(Vector2i.ZERO)
	high = (high + Vector2i(step,step)).min(Vector2i(image.get_width(),image.get_height()))
	return [low.x,low.y,high.x - low.x,high.y - low.y]

func _register_library() -> bool:
	var root := ProjectSettings.globalize_path("res://").path_join("../art-library").simplify_path()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("catalog.json")))
	if not catalog is Dictionary:
		push_error("art-library/catalog.json could not be read."); return false
	var assets := {}
	for asset in catalog.assets: assets[asset.id] = asset
	for entry in LIBRARY:
		var asset: Dictionary = assets.get(entry.asset,{})
		if asset.is_empty() or asset.get("category","") != "monster":
			push_error("Library monster %s is missing from the catalog." % entry.asset); return false
		var path: String = root.path_join(asset.record.files[0].path)
		var image := Image.load_from_file(path)
		if image == null:
			push_error("Library original could not be loaded: %s" % path); return false
		image.convert(Image.FORMAT_RGBA8)
		image.resize(roundi(image.get_width() * float(TEXTURE_HEIGHT) / image.get_height()),TEXTURE_HEIGHT,Image.INTERPOLATE_LANCZOS)
		var region := _visible_region(image)
		var boosted: Image = image.duplicate()
		boosted.adjust_bcs(TINT_BRIGHTNESS,TINT_CONTRAST,TINT_SATURATION)
		var inked: Image = image.duplicate()
		# Keeps colour under the raised alpha from darkening in the smaller mip levels.
		inked.fix_alpha_edges()
		for variant in [["lib:",image],["libTint:",boosted],["libStyle:",inked]]:
			variant[1].generate_mipmaps()
			Content._textures[variant[0] + entry.asset] = ImageTexture.create_from_image(variant[1])
		_styled_textures[Content._textures["libStyle:" + entry.asset]] = true
		# In-memory clone of the matching enemy: identical radius, behaviour, motion and shadow.
		var definition: Dictionary = Content.data.enemies[entry.like].duplicate(true)
		definition.id = entry.key; definition.name = asset.nameKo
		Content.data.enemies[entry.key] = definition
		Content.data.enemyPresentation[entry.key] = Content.data.enemyPresentation.get(entry.like,{}).duplicate(true)
		Content.visuals.enemies[entry.key] = {"rig":"legless","sprite":"lib:" + entry.asset,"region":region}
		# Same clone drawn through the outline material.
		var styled: String = entry.key + STYLED_SUFFIX
		Content.data.enemies[styled] = definition.duplicate(true)
		Content.data.enemies[styled].id = styled
		Content.data.enemyPresentation[styled] = Content.data.enemyPresentation[entry.key].duplicate(true)
		Content.visuals.enemies[styled] = {"rig":"legless","sprite":"libStyle:" + entry.asset,"region":region}
		_names[entry.key] = "%s\n%s" % [asset.nameKo,entry.asset]
		print("[library] %s %s (%s) like %s region %s" % [entry.asset,asset.nameKo,asset.family,entry.like,str(region)])
	return true

func _use_variant(prefix: String) -> void:
	for entry in LIBRARY: Content.visuals.enemies[entry.key].sprite = prefix + entry.asset

func _apply_style(node: Node = _world) -> void:
	# Visuals are pooled, so each one is set from the texture it currently shows.
	if node is HeroGroundedVisual and node._material != null:
		var styled: bool = node._texture is AtlasTexture and _styled_textures.has(node._texture.atlas)
		node._material.shader = STYLE_SHADER if styled else LOCOMOTION_SHADER
		if styled:
			for key in STYLE: node._material.set_shader_parameter(key,STYLE[key])
			node._material.set_shader_parameter("pixel_scale",_pixel_scale)
	for child in node.get_children(): _apply_style(child)

func _measure_current() -> void:
	# Ink line of the current SD enemies: dark run just inside the silhouette, per scan row.
	for id in ["crawler","runner","spitter","glassJelly","bulwark"]:
		var atlas: AtlasTexture = Content.actor_texture(Content.visuals.enemies[id])
		var image := atlas.atlas.get_image()
		if image.is_compressed(): image.decompress()
		var region := Rect2i(atlas.region)
		var runs: Array = []
		var ink := Vector3.ZERO
		var inked := 0
		var chroma := 0.0
		var body := 0
		for row in range(1,40):
			var y := region.position.y + region.size.y * row / 40
			var x := region.position.x
			while x < region.end.x and image.get_pixel(x,y).a < 0.6: x += 1
			var run_length := 0
			while x < region.end.x and image.get_pixel(x,y).a >= 0.6 and image.get_pixel(x,y).get_luminance() < 0.22:
				var pixel := image.get_pixel(x,y)
				ink += Vector3(pixel.r,pixel.g,pixel.b); inked += 1; run_length += 1; x += 1
			if run_length > 0: runs.append(run_length)
			for column in range(region.position.x,region.end.x,6):
				var pixel := image.get_pixel(column,y)
				if pixel.a > 0.9 and pixel.get_luminance() > 0.25: chroma += pixel.s; body += 1
		runs.sort()
		var median: float = runs[runs.size() / 2] if not runs.is_empty() else 0.0
		var colour := ink / maxf(1.0,inked)
		print("[current] %s ink %.1f src px of %d high (%.4f of height) colour #%s body saturation %.2f" % [id,median,region.size.y,median / region.size.y,Color(colour.x,colour.y,colour.z).to_html(false),chroma / maxf(1.0,body)])

func _spawn(run: HeroRun, id: String, position: Vector2, elite: bool = false) -> Dictionary:
	if not elite: return HeroSpawn.spawn(run,id,false,1.0,1.0,[],position)
	# Same size rule as the current Wave 7 featured elite.
	var rule: Dictionary = run.map.waveDefinitions[6].elites[0]
	var enemy := HeroSpawn.spawn(run,id,false,rule.hpMultiplier,rule.rewardMultiplier,rule.get("modifiers",[]),position)
	HeroFeaturedElites.spawned(run,enemy,{"title":run.data.enemies[id].name if id.begins_with("lib") else rule.title})
	return enemy

func _caption(screen: Control, text: String, world_point: Vector2, size: int = 9, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color(0.05,0.07,0.10))
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_constant_override("line_spacing",-2)
	screen.add_child(label)
	label.size = Vector2(170,30)
	label.position = _world.to_screen(world_point) - Vector2(85,0)

func _shot(screen: Control, id: String) -> void:
	_world.visible = true
	if screen.get_parent() == null: _canvas.add_child(screen)
	for frame in range(4): await get_tree().process_frame
	_apply_style()
	for frame in range(2): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(_output.path_join(id + ".png"))
	print("[capture] %s.png" % id)
	_canvas.remove_child(screen); screen.free()

func _lineup(id: String) -> void:
	var state := _state(1,0.0)
	var run: HeroRun = state.run
	_world.run = run; _world.visible = true
	await get_tree().process_frame
	run.player.pos = Vector2(-690,40)
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := -70.0
	var bottom := 255.0
	var columns := [-530.0,-360.0,-190.0,-10.0,200.0,500.0]
	_caption(screen,"현재 인게임 (밝은 SD)",Vector2(-690,top - 150),10,Color("ffe28a"))
	_caption(screen,"아트 라이브러리 (광택·차분)",Vector2(-690,bottom - 150),10,Color("9fe8ff"))
	_caption(screen,"플레이어",Vector2(-690,46))
	for index in range(LIBRARY.size()):
		var entry: Dictionary = LIBRARY[index]
		var elite: bool = entry.get("elite",false)
		_spawn(run,entry.like,Vector2(columns[index],top),elite)
		_spawn(run,entry.key,Vector2(columns[index],bottom),elite)
		var current: String = run.data.enemies[entry.like].name + "\n" + entry.like
		if elite: current = str(run.map.waveDefinitions[6].elites[0].title) + "\n정예 크기 · " + entry.like
		_caption(screen,current,Vector2(columns[index],top + 6))
		_caption(screen,str(_names[entry.key]) + ("\n정예 크기" if elite else ""),Vector2(columns[index],bottom + 6))
	await _shot(screen,id)

func _outline_lineup(id: String) -> void:
	var state := _state(1,0.0)
	var run: HeroRun = state.run
	_world.run = run; _world.visible = true
	await get_tree().process_frame
	run.player.pos = Vector2(-690,40)
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := [-139.0,96.0,331.0]
	var columns := [-530.0,-360.0,-190.0,-10.0,200.0,500.0]
	_caption(screen,"현재 인게임",Vector2(-690,rows[0] - 60),10,Color("ffe28a"))
	_caption(screen,"라이브러리 원본",Vector2(-690,rows[1] + 16),10,Color("9fe8ff"))
	_caption(screen,"라이브러리 + 외곽선 셰이더",Vector2(-690,rows[2] - 60),10,Color("b6ffb0"))
	for index in range(LIBRARY.size()):
		var entry: Dictionary = LIBRARY[index]
		var elite: bool = entry.get("elite",false)
		_spawn(run,entry.like,Vector2(columns[index],rows[0]),elite)
		_spawn(run,entry.key,Vector2(columns[index],rows[1]),elite)
		_spawn(run,entry.key + STYLED_SUFFIX,Vector2(columns[index],rows[2]),elite)
		_caption(screen,str(run.data.enemies[entry.like].name),Vector2(columns[index],rows[0] + 5))
		_caption(screen,str(entry.asset),Vector2(columns[index],rows[1] + 5))
		_caption(screen,str(run.data.enemies[entry.key].name),Vector2(columns[index],rows[2] + 5))
	await _shot(screen,id)

func _combat(id: String, suffix: String = "") -> void:
	seed(20261009)
	var state := _state(3,8.0)
	var run: HeroRun = state.run
	_world.run = run; _world.visible = true
	for step in range(6): state.sim.tick(1.0 / 60.0,Vector2.ZERO)
	await get_tree().process_frame
	run.enemies.clear()
	# A natural spread: both styles of every type mixed around the player, near and far.
	var kinds: Array = []
	for entry in LIBRARY:
		if entry.get("elite",false): continue
		var count := 2 if entry.like == "bulwark" else 4
		for copy in range(count): kinds.append(entry.like); kinds.append(entry.key + suffix)
	kinds.shuffle()
	for index in range(kinds.size()):
		var angle := TAU * index / kinds.size() + randf_range(-0.12,0.12)
		var reach := randf_range(175.0,330.0)
		_spawn(run,kinds[index],run.player.pos + Vector2(cos(angle) * reach * 1.9,sin(angle) * reach * 0.9))
	_spawn(run,"lib145" + suffix,run.player.pos + Vector2(330,-70),true)
	var hud := HeroCombatUI.hud(run,_noop)
	_canvas.add_child(hud)
	for step in range(54):
		if run.phase == "waveActive": run.player.hp = run.stats.maxHp
		state.sim.tick(1.0 / 60.0,Vector2.ZERO)
		HeroCombatUI.update_hud(hud,run)
		_apply_style()
		await get_tree().process_frame
	await _shot(hud,id)

func _main() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("Library style test requires --ui-preview to block save writes.")
		get_tree().quit(1); return
	_output = ProjectSettings.globalize_path("res://").path_join("../design/run-structure-captures").simplify_path()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(_output)
	Profile.meta = Content.data.defaultMeta.duplicate(true)
	Profile.meta.guild = HeroGuildState.create(Content.data,1000.0)
	HeroMeta.initialize(Content.data,Profile.meta)
	HeroMeta.weekly(Content.data,Profile.meta,Time.get_unix_time_from_system())
	if not _register_library():
		get_tree().quit(1); return
	_world = HeroWorld.new(); add_child(_world); _world.visible = false
	add_child(_canvas)
	_measure_current()
	var outline_only := OS.get_cmdline_user_args().has("--outline-only")
	# 1x is the 915x412 design frame; 2x shows the same frame closer to phone pixel density.
	for scale in [1,2]:
		var suffix := "" if scale == 1 else "@2x"
		DisplayServer.window_set_size(Vector2i(915,412) * scale)
		_pixel_scale = float(scale)
		for frame in range(6): await get_tree().process_frame
		_use_variant("lib:")
		await _outline_lineup("16-outline-lineup" + suffix)
		await _combat("17-outline-combat" + suffix,STYLED_SUFFIX)
		if outline_only: continue
		_use_variant("lib:")
		await _lineup("12-style-test-lineup" + suffix)
		await _combat("13-style-test-combat" + suffix)
		_use_variant("libTint:")
		await _combat("14-style-test-combat-tinted" + suffix)
		await _lineup("15-style-test-lineup-tinted" + suffix)
	get_tree().quit()
