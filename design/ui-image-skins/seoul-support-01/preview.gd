extends HeroMobileScreen

# Approval-stage artwork preview only. No game routing, profile mutation,
# reward assignment, supply RNG, or production callbacks are used here.
const PANEL := Rect2(564,88,328,298)
var kind := "recovery"
var state := "ready"
var source_dir := ""
var capture_clock := false
var age := 0.0
var action_age := -1.0
var open_count := 1
var tickets := 12
var pending := {"associationCoins":1420,"revivalStones":{"low":2,"mid":1,"high":0},"supplyTickets":2}
var _textures: Dictionary = {}
var _missing: Array[String] = []
var _labels: Array[Label] = []
var _root: Control
var _info: Control
var _drone: TextureRect
var _parcel: TextureRect
var _parcel_shadow: TextureRect
var _drone_shadow: TextureRect
var _body: TextureRect
var _lid: TextureRect
var _seal: TextureRect
var _light: TextureRect
var _fx: HeroUIEffects
var _rows: Array[Dictionary] = []
var _claim: Button
var _open_one: Button
var _open_ten: Button
var _amount: Label
var _status: Label
var _results: Control
var _drone_origin := Vector2(141,154)
var _parcel_origin := Vector2(242,255)
var _body_origin := Vector2(126,124)
var _lid_origin := Vector2(126,109)
var _claim_glint := false
var _open_glint := false
var _result_revealed := false

func _ready() -> void:
	super._ready()
	if source_dir.is_empty():
		source_dir = get_script().resource_path.get_base_dir().path_join("source")
	_rebuild()

func configure(screen: String, fixture: String = "ready") -> void:
	kind = screen; state = fixture
	age = 0.0; action_age = -1.0
	_claim_glint = false; _open_glint = false; _result_revealed = false
	if kind == "recovery":
		pending = {"associationCoins":1420,"revivalStones":{"low":2,"mid":1,"high":0},"supplyTickets":2}
		if fixture in ["empty","claimed"]:
			pending = {"associationCoins":0,"revivalStones":{"low":0,"mid":0,"high":0},"supplyTickets":0}
	else:
		tickets = 0 if fixture == "insufficient" else 12
	if is_inside_tree(): _rebuild()

func _rebuild() -> void:
	if is_instance_valid(_root): _root.free()
	if is_instance_valid(_fx): _fx.free()
	_labels.clear(); _rows.clear(); _missing.clear()
	_results = null
	_root = Control.new(); _root.size = REFERENCE
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_root)
	_art(_root,kind+"_background.png",Rect2(Vector2.ZERO,REFERENCE),false,true)
	_surface(_root,Rect2(22,15,423,60))
	_text(_root,"회수 거점" if kind == "recovery" else "협회 보급 데스크",Rect2(42,22,358,30),"brand",24)
	_text(_root,"도착한 회수품을 가볍게 정산하세요" if kind == "recovery" else "오늘의 지원 물자가 도착했어요",Rect2(42,49,358,18),"body",13,"ink")
	var back := _button(_root,"뒤로",Rect2(801,22,91,44),"cstore/secondary",15)
	back.pressed.connect(func(): configure(kind,"ready"))
	_info = Control.new(); _info.size = REFERENCE
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE; _root.add_child(_info)
	_surface(_info,PANEL)
	if kind == "recovery": _build_recovery()
	else: _build_supply()
	_fx = HeroUIEffects.new(); add_child(_fx)
	_fx.bind_view(_root,"support-preview-"+kind,false)
	_fx.set_process(false)

func _build_recovery() -> void:
	_drone_shadow = _shadow(Rect2(191,310,164,26),0.34)
	_parcel_shadow = _art(_root,"package_ground_shadow.png",Rect2(243,256,96,73),false)
	# The parcel's visible foot is at y319. Keep its AO registered to that
	# point instead of leaving a separate horizontal shadow several pixels away.
	_parcel_shadow.modulate.a = 0.78
	_drone = _art(_root,"recovery_drone.png",Rect2(_drone_origin,Vector2(252,176)),false)
	_drone.name = "RecoveryDrone"
	# The parcel has reached the pavement. Only the drone hovers; ground objects
	# never inherit its idle bob, so their contact edge stays fixed.
	_parcel = _art(_root,"recovery_package.png",Rect2(_parcel_origin,Vector2(96,73)),false)
	_parcel.name = "RecoveryParcel"
	_text(_info,"회수품 정산",Rect2(580,108,204,28),"heading",21)
	_status = _text(_info,"정산 완료" if state == "claimed" else "도착 완료" if state == "ready" else "회수품 대기 중",Rect2(778,110,91,24),"control",13,"#31796b",HORIZONTAL_ALIGNMENT_RIGHT)
	var entries: Array = [{"name":"협회 코인","texture":Content.trimmed_texture("associationCoin"),"amount":int(pending.associationCoins)}]
	for grade in ["low","mid","high"]:
		var stone: Dictionary = Content.data.revivalStones[grade]
		entries.append({"name":stone.name,"texture":Content.trimmed_texture(stone.image),"amount":int(pending.revivalStones[grade])})
	if int(pending.supplyTickets) > 0:
		entries.append({"name":"보급권","texture":Content.trimmed_texture("supplyTicket"),"amount":int(pending.supplyTickets)})
	for index in range(entries.size()):
		var y := 145.0+index*36.0
		var row: Dictionary = entries[index]
		_native_art(_info,row.texture,Rect2(583,y,30,30))
		_text(_info,str(row.name),Rect2(625,y,166,30),"body",14)
		var amount := _text(_info,HeroUI.amount(int(row.amount)),Rect2(792,y,70,30),"number",21,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
		_rows.append({"amount":amount})
	if entries.size() < 5:
		_text(_info,"다음 회수품은 자동으로 모입니다",Rect2(582,301,286,22),"body",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_claim = _button(_info,"모두 수령" if state == "ready" else "정산 완료" if state == "claimed" else "회수품 대기 중",Rect2(580,330,290,44),"cstore/secondary",16)
	_claim.disabled = state != "ready"
	_claim.pressed.connect(start_claim)

func _build_supply() -> void:
	# Shadow uses the package's oblique footprint, with a dense contact rim
	# under both lower edges and a short cast toward the window's opposite side.
	var contact := _art(_root,"package_ground_shadow.png",Rect2(_body_origin,Vector2(347,212)),false)
	contact.modulate.a = 0.85
	_body = _art(_root,"supply_package_body.png",Rect2(_body_origin,Vector2(347,212)),false)
	_body.name = "SupplyBody"
	_light = _native_art(_root,load("res://assets/visuals/vfx/contact_shadow.png"),Rect2(225,164,157,83))
	_light.stretch_mode = TextureRect.STRETCH_SCALE
	var light_material := ShaderMaterial.new()
	light_material.shader = load(get_script().resource_path.get_base_dir().path_join("parcel_light.gdshader"))
	_light.material = light_material
	_light.modulate.a = 0.0
	_lid = _art(_root,"supply_package_lid.png",Rect2(_lid_origin,Vector2(347,212)),false)
	_lid.name = "SupplyLid"
	# Same source canvas and origin preserve the authored body/lid registration.
	_lid.pivot_offset = Vector2(137,60)
	_lid.scale = Vector2(1.0,0.868)
	_seal = _native_art(_lid,Content.trimmed_texture("vfxImpact"),Rect2(121,112,30,30))
	_seal.modulate = Color(1.0,0.89,0.55,0.08)
	_text(_info,"오늘의 보급",Rect2(580,109,286,30),"heading",22)
	_native_art(_info,Content.trimmed_texture("supplyTicket"),Rect2(584,155,34,34))
	_text(_info,"보급권",Rect2(630,155,67,34),"body",14)
	_amount = _text(_info,str(tickets),Rect2(704,154,65,35),"number",27)
	_text(_info,"지원 물자를 개봉해 성장 재료를 받아요",Rect2(580,207,289,52),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	_open_one = _button(_info,"1회 개봉",Rect2(580,282,290,44),"cstore/secondary",16)
	_open_ten = _button(_info,"10회 개봉",Rect2(580,330,290,44),"cstore/secondary",16)
	_open_one.disabled = tickets < 1; _open_ten.disabled = tickets < 10
	_open_one.pressed.connect(func(): start_open(1))
	_open_ten.pressed.connect(func(): start_open(10))
	if tickets == 0:
		_text(_info,"보급권이 필요해요",Rect2(580,251,290,22),"body",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)

func start_claim() -> void:
	if kind != "recovery" or state != "ready" or action_age >= 0: return
	action_age = 0.0; _claim.disabled = true
	_status.text = "회수품 수령 중"

func start_open(count: int = 1) -> void:
	if kind != "supply" or action_age >= 0 or tickets < count: return
	open_count = count; action_age = 0.0
	# Fixture consumption is presentation-only; no Profile or rewards are changed.
	tickets -= count; _amount.text = str(tickets)
	_open_one.disabled = true; _open_ten.disabled = true

func _process(dt: float) -> void:
	if not capture_clock: advance(dt)

func advance(dt: float) -> void:
	if not is_visible_in_tree(): return
	age += dt
	if action_age >= 0: action_age += dt
	if kind == "recovery": _advance_recovery()
	else: _advance_supply()
	if is_instance_valid(_fx): _fx.advance_for_capture(dt)

func _advance_recovery() -> void:
	var bob := sin(age*1.8)*3.0
	_drone.position = _drone_origin+Vector2(0,bob)
	_drone_shadow.modulate.a = 0.34-bob*0.01
	if action_age < 0:
		_parcel.position = _parcel_origin
		_drone.modulate = Color(0.99,1.0,0.995,1.0)
		return
	var fall := smoothstep(0.0,0.22,action_age)
	_parcel.position = _parcel_origin+Vector2(0,2.0*fall)
	_parcel_shadow.position.y = 256.0+2.0*fall
	_parcel_shadow.modulate.a = lerpf(0.78,0.9,fall)
	_drone.position += Vector2(0,-7.0*smoothstep(0.1,0.4,action_age))
	if action_age >= 0.22 and not _claim_glint:
		_claim_glint = true
		_fx.show_effect("offline",{"anchor":"RecoveryParcel","duration":0.45,"seed":61})
	if action_age >= 0.45 and state != "claimed":
		state = "claimed"; _status.text = "정산 완료"
		for row in _rows: row.amount.text = "0"
		_claim.text = "정산 완료"

func _advance_supply() -> void:
	if action_age < 0:
		# The restrained pulse belongs to the seal/art only, never the copy or panel.
		_seal.modulate.a = 0.035+(sin(age*1.4)+1.0)*0.03
		return
	var opening := smoothstep(0.14,0.52,action_age)
	_lid.position = _lid_origin+Vector2(-8*opening,-45*opening)
	_lid.rotation = -0.17*opening
	_lid.modulate = Color(1,1,1,1)
	_seal.modulate.a = 0.28*(1.0-smoothstep(0.12,0.32,action_age))
	_light.modulate.a = smoothstep(0.18,0.4,action_age)*(1.0-smoothstep(0.64,0.84,action_age))*0.4
	if action_age >= 0.27 and not _open_glint:
		_open_glint = true
		_fx.show_effect("supply",{"anchor":"SupplyBody","seed":81})
	_body.modulate = Color(1.0,1.0,1.0,1.0)
	if action_age >= 0.85 and not _result_revealed:
		_result_revealed = true; _show_results()
	if is_instance_valid(_results): _results.modulate.a = smoothstep(0.85,1.0,action_age)

func _show_results() -> void:
	# Reuse the actual reward-display mapping; quantities below are fixed fixtures.
	_info.hide()
	_results = Control.new(); _results.size = REFERENCE
	_results.mouse_filter = Control.MOUSE_FILTER_IGNORE; _root.add_child(_results)
	_surface(_results,PANEL)
	_text(_results,"보급 도착",Rect2(580,109,286,30),"heading",22)
	_text(_results,"1회 개봉 결과" if open_count == 1 else "10회 개봉 · 같은 보상은 합산",Rect2(580,143,286,22),"body",13,"muted")
	var rewards: Array = [{"type":"associationCoin","contentId":"","amount":12},{"type":"revivalStone","contentId":"low","amount":1}]
	if open_count == 10:
		rewards = [{"type":"associationCoin","contentId":"","amount":240},{"type":"revivalStone","contentId":"low","amount":3},{"type":"revivalStone","contentId":"mid","amount":1},{"type":"characterFragment","contentId":"awakener","amount":2},{"type":"weaponFragment","contentId":"manaSword","amount":3}]
	var y := 174.0
	for reward: Dictionary in rewards:
		var display := HeroMetaScreens.reward_display(reward)
		_native_art(_results,display.texture,Rect2(584,y,28,28))
		_text(_results,display.name,Rect2(630,y,177,28),"body",14)
		_text(_results,"×"+str(reward.amount),Rect2(812,y,50,28),"number",22,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
		y += 30
	var confirm := _button(_results,"확인",Rect2(580,330,290,44),"cstore/secondary",16)
	confirm.pressed.connect(func(): configure("supply","ready"))

func _load_art(file: String, trim: bool) -> Texture2D:
	var key := file+str(trim)
	if _textures.has(key): return _textures[key]
	var path := source_dir.path_join(file)
	if not FileAccess.file_exists(path):
		if not _missing.has(file): _missing.append(file)
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_missing.append(file); return null
	if trim:
		var bounds := image.get_used_rect()
		if bounds.has_area(): image = image.get_region(bounds)
	var texture := ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture

func _art(parent: Node, file: String, rect: Rect2, trim: bool = false, cover: bool = false) -> TextureRect:
	return _native_art(parent,_load_art(file,trim),rect,cover)

func _surface(parent: Node, rect: Rect2) -> NinePatchRect:
	var surface := NinePatchRect.new()
	surface.texture = _load_art("support_glass_panel.png",false)
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: surface.set_patch_margin(side,48)
	parent.add_child(surface)
	surface.position = rect.position
	surface.size = rect.size*4.0
	surface.scale = Vector2.ONE/4.0
	return surface

func _shadow(rect: Rect2, opacity: float) -> TextureRect:
	var shadow := _native_art(_root,load("res://assets/visuals/vfx/contact_shadow.png"),rect)
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.modulate = Color(0.33,0.41,0.46,opacity)
	return shadow

func _native_art(parent: Node, texture: Texture2D, rect: Rect2, cover: bool = false) -> TextureRect:
	var result := TextureRect.new(); result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result); HeroUI.place(result,rect)
	return result

func _text(parent: Node, caption: String, rect: Rect2, role: String = "body", font_size: int = 14, color_role: String = "ink", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var label := HeroImageSkin.text(parent,caption,rect,role,font_size,color_role,align,wrap,{"valign":VERTICAL_ALIGNMENT_CENTER})
	_labels.append(label)
	return label

func _button(parent: Node, caption: String, rect: Rect2, role: String, font_size: int) -> Button:
	# Bypass the default button audio callback so this draft is silent.
	return HeroImageSkin.image_button(parent,caption,rect,Callable(),role,font_size)

func diagnostics() -> Dictionary:
	var issues: Array = []
	for label in _labels:
		if not is_instance_valid(label): continue
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var height := label.get_line_count()*font.get_height(font_size)+maxi(0,label.get_line_count()-1)*2
		var width := font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		if height > label.size.y+1 or (label.autowrap_mode == TextServer.AUTOWRAP_OFF and width > label.size.x+1):
			issues.append({"text":label.text,"size":[label.size.x,label.size.y],"required":[width,height]})
	return {"kind":kind,"state":state,"size":[915,412],"missingArt":_missing.duplicate(),"fitIssues":issues,"fontRoles":{"title":"BMJUA","section":"HaeongSans","body":"Paperlogy","number":"BarlowCondensed"},"uiEffects":_fx.snapshot() if is_instance_valid(_fx) else {},"previewOnly":true,"runtimeConnected":false,"saveWrites":false,"rewardAssignment":false}
