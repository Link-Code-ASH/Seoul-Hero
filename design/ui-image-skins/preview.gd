extends Control

# This project only reads shipped artwork/data. Captures are design proposals;
# the production project, save state and gameplay callbacks are never loaded.
const CANVAS := Vector2(915,412)
const ITEMS := ["phoenixMatch","vaultLedger","revengeFuse","ankleGuard"]
const ICON_KEYS := ["maxHp","hpRegen","lifeSteal","damage","meleeDamage","rangedDamage","area","attackSpeed","critChance","critDamage","armor","dodge","speed","luck","duration","range","pickupRange","curse","projectileSpeed","currencyGain","back","next","settings","details","musicOn","musicOff","pause","reroll","lock","unlock","wave","depth"]
var _project_dir: String
var _repo_dir: String
var _content: Dictionary
var _skins: Dictionary
var _theme: Dictionary
var _theme_id := "a"
var _textures: Dictionary = {}
var _fonts: Dictionary = {}
var _labels: Array[Label] = []
var _frames: Array[Dictionary] = []
var _report: Array[Dictionary] = []
var _output: String
var _variants: Array[String] = ["a","b"]
var _glass_shader: Shader

func _ready() -> void:
	_project_dir = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	_repo_dir = _project_dir.get_base_dir().get_base_dir()
	_output = _project_dir.path_join("screenshots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _output = arg.trim_prefix("--output=")
		if arg.begins_with("--themes="):
			_variants.clear()
			for variant in arg.trim_prefix("--themes=").split(",",false): _variants.append(variant.strip_edges().to_lower())
	_content = _json(_repo_dir.path_join("godot/data/content.json"))
	_skins = _json(_project_dir.path_join("skins.json"))
	if _content.is_empty() or _skins.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(_output)
	await _capture_all()

func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Preview JSON unavailable: "+path); return {}
	return parsed

func _capture_all() -> void:
	for variant in _variants:
		_theme_id = variant
		var themes: Dictionary = _skins.get("themes",_skins)
		_theme = themes.get(variant,themes.get(variant.to_upper(),{}))
		if _theme.is_empty(): push_error("Missing image skin: "+variant); get_tree().quit(2); return
		for screen in ["title","lobby","shop"]:
			_labels.clear(); _frames.clear()
			var surface := Control.new(); surface.size = CANVAS; add_child(surface)
			match screen:
				"title": _title(surface)
				"lobby": _lobby(surface)
				"shop": _shop(surface)
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var file := _output.path_join(variant+"-"+screen+".png")
			get_viewport().get_texture().get_image().save_png(file)
			_report.append(_layout_report(variant,screen))
			surface.queue_free(); await get_tree().process_frame
	var report_name := "layout.json" if _variants == ["a","b"] else "layout-"+"-".join(_variants)+".json"
	var report_file := FileAccess.open(_output.path_join(report_name),FileAccess.WRITE)
	report_file.store_string(JSON.stringify({"size":[915,412],"productionLoaded":false,"savesLoaded":false,"screens":_report},"\t"))
	print("Image UI proposals captured: ",_output)
	get_tree().quit()

func _font(role: String) -> Font:
	var key := _theme_id+":"+role
	if _fonts.has(key): return _fonts[key]
	var relative := "design/ui-image-skins/fonts/Paperlogy-4Regular.ttf"
	match role:
		"control": relative = "design/ui-image-skins/fonts/Paperlogy-5Medium.ttf"
		"number": relative = "design/ui-image-skins/fonts/BarlowCondensed-SemiBold.ttf"
		"brand": relative = "design/ui-image-skins/fonts/SFSsaraknun.ttf" if _theme_id == "a" else "design/ui-image-skins/fonts/BMJUA.ttf"
		"heading": relative = "design/ui-image-skins/fonts/KMU80SungkokSerif.ttf" if _theme_id == "a" else "design/ui-image-skins/fonts/KMU80HaeongSans.ttf"
	var native := FontFile.new()
	var error := native.load_dynamic_font(_repo_dir.path_join(relative))
	if error != OK: push_error("Preview font unavailable: "+relative); get_tree().quit(2)
	if role != "body": native.fallbacks = [_font("body")]
	_fonts[key] = native
	return native

func _color(role: String) -> Color:
	var defaults := {"ink":"#20354b","muted":"#5d6b7a","accent":"#287b79","reward":"#99631e","danger":"#a23e4c","scene":"#f4f7fa"}
	return Color(str(_theme.get("colors",{}).get(role,defaults.get(role,defaults.ink))))

func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	var image := Image.load_from_file(path)
	if image == null or image.is_empty(): push_error("Preview image unavailable: "+path); get_tree().quit(2); return null
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture

func _content_texture(id: String, trim: bool = true) -> Texture2D:
	var entry: Dictionary = _content.images[id]
	var path := _repo_dir.path_join("godot/"+str(entry.url).trim_prefix("res://"))
	var cache_key := path+":"+JSON.stringify(entry.get("region",[]))+":"+str(trim)
	if _textures.has(cache_key): return _textures[cache_key]
	var image := Image.load_from_file(path)
	if entry.has("region"):
		var region: Array = entry.region
		image = image.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	if trim and image.get_format() == Image.FORMAT_RGBA8:
		var used := image.get_used_rect()
		if used.has_area(): image = image.get_region(used)
	var texture := ImageTexture.create_from_image(image)
	_textures[cache_key] = texture
	return texture

func _art(parent: Control, texture: Texture2D, rect: Rect2, cover: bool = false) -> TextureRect:
	var image := TextureRect.new(); image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position; image.size = rect.size
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(image)
	return image

func _skin(parent: Control, pack_name: String, role: String, rect: Rect2) -> NinePatchRect:
	var pack: Dictionary = _theme[pack_name]
	var definition: Dictionary = pack.roles[role]
	var texture := _texture(_project_dir.path_join(str(pack.file)))
	var region := Rect2(Vector2.ZERO,texture.get_size())
	if definition.has("rect"):
		var bounds: Array = definition.rect
		region = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
	elif definition.has("cell"):
		var cell: Array = definition.cell
		var cell_size := texture.get_size()/Vector2(int(pack.columns),int(pack.rows))
		region = Rect2(Vector2(float(cell[0]),float(cell[1]))*cell_size,cell_size)
	var scale_factor := float(definition.get("asset_scale",pack.get("asset_scale",2.0)))
	var slices: Array = definition.get("slice",pack.get("slice",[24,24,24,24]))
	var frame := NinePatchRect.new()
	frame.texture = texture; frame.region_rect = region
	frame.patch_margin_left = int(slices[0]); frame.patch_margin_top = int(slices[1])
	frame.patch_margin_right = int(slices[2]); frame.patch_margin_bottom = int(slices[3])
	frame.position = rect.position; frame.size = rect.size*scale_factor
	frame.scale = Vector2.ONE/scale_factor
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_frames.append({"pack":pack_name,"role":role,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"source":[region.position.x,region.position.y,region.size.x,region.size.y],"slices":slices,"assetScale":scale_factor})
	return frame

func _glass_tile(parent: Control, role: String, rect: Rect2) -> void:
	# The authored PNG defines this frameless surface and its alpha silhouette.
	# A small scene-texture blur supports the raster frosting without adding a plate.
	var tile := _skin(parent,"glass",role,rect)
	if _glass_shader == null:
		_glass_shader = Shader.new()
		_glass_shader.code = """shader_type canvas_item;
uniform sampler2D scene_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float surface_opacity = 0.28;
void fragment() {
	vec4 authored = texture(TEXTURE, UV);
	vec3 behind = textureLod(scene_texture, SCREEN_UV, 2.0).rgb;
	COLOR = vec4(mix(authored.rgb, behind, 0.28), authored.a * surface_opacity);
}"""
	var material := ShaderMaterial.new(); material.shader = _glass_shader
	material.set_shader_parameter("surface_opacity",float(_theme.glass.get("opacity",0.28)))
	tile.material = material

func _text(parent: Control, text: String, rect: Rect2, role: String = "body", size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var label := Label.new(); label.text = text
	label.position = rect.position; label.size = rect.size
	label.add_theme_font_override("font",_font(role)); label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",_color(color_role))
	label.add_theme_constant_override("line_spacing",2)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false; label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("allocated_rect",rect); label.set_meta("font_role",role)
	parent.add_child(label)
	# Assign the box after font/wrap properties; Label otherwise retains an early
	# minimum computed with the default font before the selected face is applied.
	label.position = rect.position; label.size = rect.size
	_labels.append(label)
	return label

func _button(parent: Control, text: String, rect: Rect2, role: String = "secondary", size: int = 16) -> void:
	_skin(parent,"buttons",role,rect)
	_text(parent,text,Rect2(rect.position+Vector2(12,4),rect.size-Vector2(24,8)),"control",size,"scene" if role == "primary" else "muted" if role == "disabled" else "ink",HORIZONTAL_ALIGNMENT_CENTER)

func _icon(parent: Control, key: String, rect: Rect2) -> void:
	var index := ICON_KEYS.find(key)
	var texture := _content_texture("urbanIconsAtlas",false)
	var cell := texture.get_size()/Vector2(8,4)
	var atlas := AtlasTexture.new(); atlas.atlas = texture
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell); atlas.filter_clip = true
	_art(parent,atlas,rect)

func _title(root: Control) -> void:
	_art(root,_content_texture("titleGate",false),Rect2(Vector2.ZERO,CANVAS),true)
	_skin(root,"panels","info",Rect2(36,50,344,184))
	var seoul := _text(root,"서울",Rect2(60,66,296,55),"brand",46,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var hero := _text(root,"히어로",Rect2(56,119,304,66),"brand",55,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	for word in [seoul,hero]:
		word.add_theme_constant_override("outline_size",2)
		word.add_theme_color_override("font_outline_color",Color(0.95,0.97,0.98,0.9))
		word.add_theme_constant_override("shadow_offset_y",3)
		word.add_theme_color_override("font_shadow_color",Color(0.05,0.13,0.21,0.28))
	_text(root,"서울 게이트 생존 액션",Rect2(62,192,292,25),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_button(root,"이어하기",Rect2(44,248,328,52),"primary",19)
	_button(root,"입장",Rect2(44,312,328,52),"secondary",19)
	var music := _text(root,"음악 ON",Rect2(801,14,94,24),"body",14,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	music.add_theme_color_override("font_outline_color",Color(0.05,0.12,0.2,0.95))
	music.add_theme_constant_override("outline_size",1)
	music.add_theme_color_override("font_shadow_color",Color(0.02,0.08,0.16,0.8))
	music.add_theme_constant_override("shadow_offset_y",1)

func _lobby(root: Control) -> void:
	var background := _art(root,_content_texture("premiumLobbyRain",false),Rect2(Vector2.ZERO,CANVAS),true)
	var daylight := Shader.new()
	daylight.code = FileAccess.get_file_as_string(_repo_dir.path_join("godot/shaders/lobby_daylight.gdshader"))
	var material := ShaderMaterial.new(); material.shader = daylight; background.material = material
	var mist := _art(root,_texture(_repo_dir.path_join("design/ui-premium-v5/assets/dock-haze.png")),Rect2(18,281,879,117),true)
	mist.modulate.a = 0.08
	_skin(root,"panels","header",Rect2(18,12,879,54))
	_text(root,"서울 히어로",Rect2(33,19,256,39),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_art(root,_content_texture("associationCoin"),Rect2(377,28,22,22))
	_text(root,"12,480",Rect2(404,21,78,34),"number",19,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_art(root,_content_texture("supplyTicket"),Rect2(500,28,22,22))
	_text(root,"12",Rect2(529,21,46,34),"number",19,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_button(root,"자료집",Rect2(597,18,94,44))
	_button(root,"설정",Rect2(700,18,78,44))
	_button(root,"음악 ON",Rect2(787,18,98,44),"secondary",14)
	if _theme_id != "c": _skin(root,"panels","footer",Rect2(18,313,508,83))
	var entries := [["lobbyGuildSD","길드"],["lobbyGrowthSD","전략지원"],["lobbyAssociationSD","협회"],["lobbyRecoverySD","회수"],["lobbySupplySD","보급"]]
	var glass_roles := ["guild","growth","association","recovery","supply"]
	for i in range(entries.size()):
		var x := 27+i*99
		if _theme_id == "c": _glass_tile(root,glass_roles[i],Rect2(x,285,92,106))
		_art(root,_content_texture(entries[i][0]),Rect2(x+6,278,80,79))
		var caption := _text(root,entries[i][1],Rect2(x,357,92,22),"control" if _theme_id == "c" else "body",14,"scene",HORIZONTAL_ALIGNMENT_CENTER)
		if _theme_id == "c":
			caption.add_theme_color_override("font_shadow_color",Color(0.05,0.12,0.2,0.85))
			caption.add_theme_constant_override("shadow_offset_y",1)
	_art(root,_content_texture("lobbyDeploymentSD"),Rect2(746,229,126,103))
	_button(root,"작전 투입",Rect2(659,340,240,56),"primary",21)

func _shop(root: Control) -> void:
	_art(root,_content_texture("premiumLobbyRain",false),Rect2(Vector2.ZERO,CANVAS),true)
	_skin(root,"panels","cabinet",Rect2(14,10,887,392))
	_skin(root,"panels","header",Rect2(24,20,867,47))
	_text(root,"게이트24",Rect2(42,25,174,35),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_icon(root,"wave",Rect2(390,32,22,22))
	_text(root,"12 / 20",Rect2(419,25,83,34),"number",19,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	_art(root,_content_texture("magicStone"),Rect2(542,29,26,26))
	_text(root,"60",Rect2(580,25,74,34),"number",22,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_button(root,"일시정지",Rect2(770,22,111,44),"secondary",14)
	_skin(root,"panels","info",Rect2(24,78,169,287))
	_art(root,_texture(_repo_dir.path_join("assets/characters-sd/song_sd_01.png")),Rect2(64,87,90,113))
	_text(root,"송진우",Rect2(39,200,138,29),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var stats := [["maxHp","120 / 120"],["damage","+24%"],["attackSpeed","+15%"],["armor","12"]]
	for i in range(stats.size()):
		_icon(root,stats[i][0],Rect2(39,232+i*21,18,18))
		_text(root,stats[i][1],Rect2(68,228+i*21,105,23),"number",17,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	_button(root,"전체 스탯",Rect2(37,321,145,44),"secondary",14)
	_button(root,"무기",Rect2(205,78,102,44),"tab",15)
	_button(root,"아이템",Rect2(315,78,102,44),"selected",15)
	_button(root,"재진열 20",Rect2(748,78,130,44),"secondary",14)
	for i in range(ITEMS.size()):
		_shop_card(root,ITEMS[i],Rect2(205+i*171,131,162,219),i)
	_text(root,"보유 아이템  ·  불사 성냥  ×1",Rect2(205,359,450,28),"body",14,"ink")
	_button(root,"다음 웨이브",Rect2(674,350,205,44),"primary",18)

func _shop_card(root: Control, id: String, rect: Rect2, index: int) -> void:
	var item: Dictionary = _content.items[id]
	_skin(root,"panels","card",rect)
	var x := rect.position.x; var y := rect.position.y
	_art(root,_content_texture(item.icon),Rect2(x+37,y+8,88,43))
	var name := _text(root,item.name,Rect2(x+10,y+51,142,44),"heading",17,"ink",HORIZONTAL_ALIGNMENT_CENTER,true)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text(root,"\n".join(item.shopText.effects),Rect2(x+10,y+97,142,36),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_text(root,"\n".join(item.shopText.penalties),Rect2(x+10,y+136,142,19),"body",14,"danger")
	_text(root,"재화 부족 · 상한1/1" if index == 0 else "진열 유지" if index == 1 else "보유 0/%d" % int(item.maxStacks),Rect2(x+10,y+155,142,17),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var footer_y := y+172
	var unavailable := index == 0
	_button(root,str(int(item.basePrice))+"  구매",Rect2(x+8,footer_y,94,44),"disabled" if unavailable else "primary",15)
	_skin(root,"buttons","locked" if index == 1 else "secondary",Rect2(x+110,footer_y,44,44))
	_icon(root,"lock" if index == 1 else "unlock",Rect2(x+123,footer_y+12,18,19))

func _layout_report(variant: String, screen: String) -> Dictionary:
	var labels: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	for label in _labels:
		var rect: Rect2 = label.get_meta("allocated_rect")
		var font := label.get_theme_font("font")
		var size := label.get_theme_font_size("font_size")
		var lines := label.get_line_count()
		var needed_height := font.get_height(size)*lines+2*maxi(0,lines-1)
		var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x if label.autowrap_mode == TextServer.AUTOWRAP_OFF else label.size.x
		var logical_line_width := 0.0
		for line in label.text.split("\n"):
			logical_line_width = maxf(logical_line_width,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
		var entry := {"text":label.text,"font":str(label.get_meta("font_role")),"size":size,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"actualBox":[label.position.x,label.position.y,label.size.x,label.size.y],"lines":lines,"fontHeight":font.get_height(size),"requiredHeight":needed_height,"requiredWidth":width,"unwrappedLineWidth":logical_line_width,"align":label.horizontal_alignment}
		labels.append(entry)
		if needed_height > rect.size.y+1 or width > rect.size.x+1: issues.append(entry)
	return {"variant":variant,"screen":screen,"labels":labels,"frames":_frames.duplicate(true),"fitIssues":issues}
