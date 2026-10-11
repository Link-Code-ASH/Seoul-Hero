extends RefCounted
# Preview-only raster materials and native fonts. No production autoloads.
const CANVAS := Vector2(915,412)
const ICON_KEYS := ["maxHp","hpRegen","lifeSteal","damage","meleeDamage","rangedDamage","area","attackSpeed","critChance","critDamage","armor","dodge","speed","luck","duration","range","pickupRange","curse","projectileSpeed","currencyGain","back","next","settings","details","musicOn","musicOff","pause","reroll","lock","unlock","wave","depth"]
var project_dir: String
var repo_dir: String
var content: Dictionary
var materials: Dictionary
var actor_visuals: Dictionary
var labels: Array[Label] = []
var frames: Array[Dictionary] = []
var controls: Array[Dictionary] = []
var textures: Dictionary = {}
var fonts: Dictionary = {}

func _init(project_path: String) -> void:
	project_dir = project_path.simplify_path().trim_suffix("/")
	repo_dir = project_dir.get_base_dir().get_base_dir().get_base_dir()
	content = json_file(repo_dir.path_join("godot/data/content.json"))
	actor_visuals = json_file(repo_dir.path_join("godot/data/visuals/actors.json"))
	materials = json_file(project_dir.path_join("materials.json"))

func json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): push_error("Preview data unavailable: "+path); return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: push_error("Invalid preview JSON: "+path); return {}
	return parsed

func font(role: String = "body") -> Font:
	if fonts.has(role): return fonts[role]
	var names := {"body":"Paperlogy-4Regular.ttf","control":"Paperlogy-5Medium.ttf","number":"BarlowCondensed-SemiBold.ttf","brand":"BMJUA.ttf","heading":"KMU80HaeongSans.ttf"}
	var native := FontFile.new()
	var path := repo_dir.path_join("design/ui-image-skins/fonts/"+str(names.get(role,names.body)))
	if native.load_dynamic_font(path) != OK: push_error("Font not loaded: "+path)
	if role != "body": native.fallbacks = [font("body")]
	fonts[role] = native
	return native

func color(role: String = "ink") -> Color:
	var colors := {"ink":"#243448","muted":"#657787","accent":"#267f75","mint":"#267f75","reward":"#9a7128","danger":"#b64e49","coral":"#b64e49","white":"#f5f8fa","scene":"#f5f8fa","rule":"#b4c6cf","navy":"#243c53","shadow":"#1a2634"}
	if role.begins_with("#"): return Color(role)
	return Color(str(colors.get(role,role if Color.html_is_valid(role) else colors.ink)))

func texture(source: String, trim: bool = true) -> Texture2D:
	var path := source
	var region: Array = []
	if content.get("images",{}).has(source):
		var entry: Dictionary = content.images[source]
		path = repo_dir.path_join("godot/"+str(entry.url).trim_prefix("res://"))
		if not FileAccess.file_exists(path): path = repo_dir.path_join(str(entry.url).trim_prefix("res://"))
		region = entry.get("region",[])
	elif source.begins_with("res://"):
		path = repo_dir.path_join("godot/"+source.trim_prefix("res://"))
	elif not source.is_absolute_path():
		path = project_dir.path_join(source)
		if not FileAccess.file_exists(path):
			path = repo_dir.path_join("design/ui-image-skins/operations-standard-01").path_join(source)
	var key := path+":"+JSON.stringify(region)+":"+str(trim)
	if textures.has(key): return textures[key]
	var bitmap := Image.load_from_file(path)
	if bitmap == null or bitmap.is_empty(): push_error("Preview image not loaded: "+path); return null
	if not region.is_empty(): bitmap = bitmap.get_region(Rect2i(int(region[0]),int(region[1]),int(region[2]),int(region[3])))
	if trim and bitmap.get_format() == Image.FORMAT_RGBA8:
		var used := bitmap.get_used_rect()
		if used.has_area(): bitmap = bitmap.get_region(used)
	var result := ImageTexture.create_from_image(bitmap)
	textures[key] = result
	return result

func image(parent: Control, source: String, rect: Rect2, trim: bool = true, cover: bool = false) -> TextureRect:
	return art(parent,source,rect,trim,cover)

func art(parent: Control, source: Variant, rect: Rect2, trim: bool = true, cover: bool = false) -> TextureRect:
	var image_node := TextureRect.new()
	image_node.texture = source if source is Texture2D else texture(str(source),trim)
	image_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_node.position = rect.position; image_node.size = rect.size
	image_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image_node)
	return image_node

func material(parent: Control, key: String, rect: Rect2) -> NinePatchRect:
	var packs: Dictionary = materials.get("packs",{})
	var pack_name := ""; var role_name := key
	if key.contains("/"):
		pack_name = key.get_slice("/",0); role_name = key.get_slice("/",1)
	else:
		for candidate in packs:
			if packs[candidate].get("roles",{}).has(key): pack_name = candidate; break
	if pack_name.is_empty() or not packs.has(pack_name) or not packs[pack_name].get("roles",{}).has(role_name):
		push_error("Preview material unavailable: "+key); return null
	var pack: Dictionary = packs[pack_name]
	var definition: Dictionary = pack.roles[role_name]
	if bool(definition.get("unframed",false)):
		var hit_surface := NinePatchRect.new()
		hit_surface.position = rect.position; hit_surface.size = rect.size
		hit_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hit_surface)
		return hit_surface
	var source := texture(str(definition.get("file",pack.file)),false)
	var bounds: Array = definition.get("rect",[0,0,source.get_width(),source.get_height()])
	var source_rect := Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3]))
	var slices: Array = definition.get("slice",[0,0,0,0])
	var scale_factor := float(definition.get("asset_scale",pack.get("asset_scale",2.0)))
	var result := NinePatchRect.new()
	result.texture = source; result.region_rect = source_rect
	result.patch_margin_left = int(slices[0]); result.patch_margin_top = int(slices[1])
	result.patch_margin_right = int(slices[2]); result.patch_margin_bottom = int(slices[3])
	result.position = rect.position; result.size = rect.size*scale_factor
	result.scale = Vector2.ONE/scale_factor
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	if definition.has("opacity"): result.modulate.a = float(definition.opacity)
	if definition.has("tint"):
		var tint: Array = definition.tint
		result.modulate = Color(float(tint[0]),float(tint[1]),float(tint[2]),float(tint[3]))
	if bool(definition.get("grayscale",false)):
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV)*COLOR; float g=dot(c.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(vec3(g),c.a); }"
		var skin := ShaderMaterial.new(); skin.shader = shader; result.material = skin
	frames.append({"material":key,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"source":[source_rect.position.x,source_rect.position.y,source_rect.size.x,source_rect.size.y],"slice":slices,"assetScale":scale_factor})
	return result

func frame(parent: Control, pack: String, role: String, rect: Rect2) -> NinePatchRect:
	return material(parent,pack+"/"+role,rect)

func text(parent: Control, caption: String, rect: Rect2, font_role: String = "body", size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var result := Label.new()
	result.add_theme_font_override("font",font(font_role))
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color(color_role))
	result.add_theme_constant_override("line_spacing",2)
	result.horizontal_alignment = align
	result.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	result.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	result.clip_text = false
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.set_meta("allocated_rect",rect); result.set_meta("font_role",font_role)
	parent.add_child(result)
	result.position = rect.position; result.size = rect.size
	result.text = caption
	labels.append(result)
	return result

func hud_text(parent: Control, caption: String, rect: Rect2, role: String = "number", size: int = 21, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, color_role: String = "white") -> Label:
	var result := text(parent,caption,rect,role,size,color_role,align)
	result.add_theme_color_override("font_outline_color",Color("#1a2634"))
	result.add_theme_constant_override("outline_size",3)
	result.add_theme_color_override("font_shadow_color",Color(0.03,0.05,0.08,0.45))
	result.add_theme_constant_override("shadow_offset_y",1)
	return result

func button(parent: Control, caption: String, rect: Rect2, role: String = "light/secondary", size: int = 16, options: Dictionary = {}) -> Button:
	var surface := material(parent,role,rect)
	var hit := Button.new()
	hit.position = rect.position; hit.size = rect.size
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.disabled = bool(options.get("disabled",false))
	for state in ["normal","hover","pressed","focus","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	parent.add_child(hit)
	var ink := "muted" if hit.disabled or role.ends_with("disabled") else "scene" if role in ["ops/primary","light/primary","light/back"] else "accent" if role.ends_with("tab_selected") else "ink"
	var definition: Dictionary = materials.packs[role.get_slice("/",0)].roles[role.get_slice("/",1)]
	var padding: Array = options.get("padding",definition.get("safe_padding",[12,4,12,4]))
	text(parent,caption,Rect2(rect.position+Vector2(float(padding[0]),float(padding[1])),rect.size-Vector2(float(padding[0])+float(padding[2]),float(padding[1])+float(padding[3]))),"control",size,ink,HORIZONTAL_ALIGNMENT_CENTER)
	if hit.disabled and surface != null:
		var shader := Shader.new()
		shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR; float g=dot(c.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(vec3(g),c.a);}"
		var state := ShaderMaterial.new(); state.shader = shader; surface.material = state
		surface.modulate = Color(0.8,0.84,0.88)
	controls.append({"caption":caption,"role":role,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum44":rect.size.x >= 44 and rect.size.y >= 44,"staticPreview":true,"disabled":hit.disabled})
	return hit

func line(parent: Control, rect: Rect2, _color_role: String = "rule") -> Control:
	var result := material(parent,"accents/rule_v" if rect.size.y > rect.size.x else "accents/rule_h",rect)
	return result

func wash(parent: Control, shade: Color) -> ColorRect:
	var result := ColorRect.new()
	result.color = shade; result.size = CANVAS
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(result)
	return result

func icon(parent: Control, key: String, rect: Rect2) -> TextureRect:
	var index := ICON_KEYS.find(key)
	var atlas := AtlasTexture.new(); atlas.atlas = texture("urbanIconsAtlas",false)
	var cell := atlas.atlas.get_size()/Vector2(8,4)
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell)
	atlas.filter_clip = true
	return art(parent,atlas,rect)

func header(parent: Control, title: String, subtitle: String = "", step: String = "", options: Dictionary = {}) -> void:
	material(parent,"ops/header",Rect2(16,12,float(options.get("width",883)),52))
	var with_back := bool(options.get("back",true))
	if with_back:
		button(parent,"‹",Rect2(20,16,44,44),"light/back",24)
		controls[-1]["caption"] = str(options.get("back_caption","뒤로"))
	var title_x := 76.0 if with_back else 36.0
	var title_width := minf(float(options.get("title_width",580)),ceilf(font("brand").get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x)+12)
	text(parent,title,Rect2(title_x,16,title_width,44),"brand",24,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	if not subtitle.is_empty(): text(parent,subtitle,Rect2(28,72,790,26),"body",14,"muted")
	if not step.is_empty(): text(parent,step,Rect2(800,20,80,36),"number",18,"scene",HORIZONTAL_ALIGNMENT_RIGHT)

func icon_number(parent: Control, source: Texture2D, number: String, center: Vector2, font_size: int = 18, icon_size: float = 20, color_role: String = "ink") -> Label:
	var width := ceilf(font("number").get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)+2
	var left := center.x-(icon_size+6+width)*0.5
	art(parent,source,Rect2(left,center.y-icon_size/2,icon_size,icon_size))
	return text(parent,number,Rect2(left+icon_size+6,center.y-16,width,32),"number",font_size,color_role)

func reset() -> void:
	labels.clear(); frames.clear(); controls.clear()

func report(screen: String) -> Dictionary:
	var measured: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	for label in labels:
		var allocated: Rect2 = label.get_meta("allocated_rect")
		var face := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var lines := label.get_line_count()
		var needed_h := face.get_height(font_size)*lines+2*maxi(0,lines-1)
		var needed_w := 0.0
		for line_text in label.text.split("\n"): needed_w = maxf(needed_w,face.get_string_size(line_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF: needed_w = allocated.size.x
		var entry := {"text":label.text,"role":str(label.get_meta("font_role")),"fontSize":font_size,"rect":[allocated.position.x,allocated.position.y,allocated.size.x,allocated.size.y],"actualSize":[label.size.x,label.size.y],"fontHeight":face.get_height(font_size),"lines":lines,"requiredHeight":needed_h,"requiredWidth":needed_w,"align":label.horizontal_alignment}
		measured.append(entry)
		if needed_h > allocated.size.y+1 or needed_w > allocated.size.x+1: issues.append(entry)
		if not bool(label.get_meta("scroll_copy",false)) and label.size.y > allocated.size.y+1: issues.append({"expandedLabel":entry})
		var absolute := label.global_position
		if not bool(label.get_meta("scroll_copy",false)) and (absolute.x < -1 or absolute.y < -1 or absolute.x+allocated.size.x > CANVAS.x+1 or absolute.y+allocated.size.y > CANVAS.y+1): issues.append({"outsideCanvas":entry})
	for control in controls:
		if not control.minimum44: issues.append({"smallHit":control})
	return {"screen":screen,"labels":measured,"materials":frames.duplicate(true),"controls":controls.duplicate(true),"fitIssues":issues}

func card(parent: Control, caption: String, source: Variant, rect: Rect2, selected: bool = false, locked: bool = false, options: Dictionary = {}) -> Control:
	var cell := Control.new(); cell.position = rect.position; cell.size = rect.size; cell.clip_contents = true; cell.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(cell)
	var bg := material(cell,"cards/normal",Rect2(Vector2.ZERO,rect.size))
	if locked: bg.modulate = Color(0.82,0.86,0.88)
	elif selected: bg.modulate = Color(0.92,1.0,0.97)
	material(cell,"glass/cell",Rect2(Vector2.ZERO,rect.size))
	var name_h := maxf(25.0,font("control").get_height(int(options.get("caption_size",14)))*caption.split("\n").size()+2*maxi(0,caption.split("\n").size()-1)+2) if not caption.is_empty() else 0.0
	var art_h := minf(float(options.get("image_height",rect.size.y-name_h-18)),rect.size.y-name_h-18)
	var art_rect := Rect2(12,8,rect.size.x-24,art_h)
	if source != null and not (source is String and str(source).is_empty()):
		var shadow := material(cell,"glass/shadow",Rect2(rect.size.x*0.24,art_rect.end.y-10,rect.size.x*0.52,14)); shadow.modulate.a = 0.4
		art(cell,source,art_rect)
	if not caption.is_empty(): text(cell,caption,Rect2(8,rect.size.y-name_h-5,rect.size.x-16,name_h),"control",int(options.get("caption_size",14)),"muted" if locked else "ink",HORIZONTAL_ALIGNMENT_CENTER)
	if selected: material(cell,"accents/selection",Rect2(Vector2.ZERO,rect.size))
	if locked: icon(cell,"lock",Rect2(rect.size.x-23,7,16,16))
	return cell

func item_texture(id: String) -> Texture2D:
	var source := str(content.items.get(id,{}).get("icon",""))
	if content.images.has(source): return texture(source,true)
	var ids := ["energyDrink","riceBall","runningShoes","scope","luckyCharm","vest","bandage","wallet","notebook","magnet","gloves","sight","lens","spring","timer","battery","wideLens","criticalEye","sharpStone","umbrella","bloodPack","swordManual","toolbox","conductor","splitter","mineCase","cursedStone","hunterCoat","bloodCircuit","commandCore","stormCore"]
	var index := maxi(0,ids.find(id))
	var atlas := AtlasTexture.new(); atlas.atlas = texture("inventoryAtlasTransparent",false)
	var cell := atlas.atlas.get_size()/Vector2(8,6)
	atlas.region = Rect2(Vector2(index%8,floori(index/8.0))*cell,cell); atlas.filter_clip = true
	return atlas

func actor_texture(group: String, id: String, fallback: String = "") -> Texture2D:
	var entry: Dictionary = actor_visuals.get(group,{}).get(id,{})
	var source := str(entry.get("sprite",fallback))
	var original := texture(source,false)
	var bounds: Array = entry.get("region",[])
	if bounds.size() != 4: return texture(source,true)
	var atlas := AtlasTexture.new(); atlas.atlas = original
	atlas.region = Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3])); atlas.filter_clip = true
	return atlas
