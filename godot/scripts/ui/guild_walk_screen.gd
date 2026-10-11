class_name HeroGuildWalkScreen
extends HeroGuildScreen

# Approved 2026-10-04: persistent walking world with native management content.
var world := HeroGuild.new()
var guild_input := HeroGuildMovement.new()
var actor_id := "awakener"
var art: Dictionary = {}
var _surface: Control
var _hint := "방을 누르면 걸어가서 이용합니다."
var _hint_label: Label
var _visual_clock := 0.0

static func create(profile: Dictionary, command: Callable, leave: Callable, enter_gate: Callable, images: Dictionary, ui: Dictionary = {}, actor: String = "awakener") -> HeroGuildWalkScreen:
	var screen := HeroGuildWalkScreen.new()
	screen.meta = profile; screen.act = command; screen.back = leave; screen.deploy = enter_gate
	if not ui.is_empty(): screen.view_state = ui
	if not screen.view_state.has("panelOpen"): screen.view_state.panelOpen = false
	screen.actor_id = actor; screen.art = images
	screen.room_atlas = images.get("rooms"); screen.state_atlas = images.get("states")
	screen.facility_order = images.get("facilityOrder",Content.data.guildManagement.facilities.keys())
	screen.tiers = images.get("tiers",[1,4,7,10])
	screen.theme = HeroImageSkin.theme(); screen.set_meta("hero_ui_palette","image_skin")
	return screen

func _ready() -> void:
	HeroUI.background(self,"premiumLobbyRain")
	get_viewport().size_changed.connect(_fit); _fit()
	_surface = Control.new(); _surface.clip_contents = true
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface); HeroUI.place(_surface,Rect2(12,68,891,278))
	world.configure(meta,art,view_state,actor_id)
	world.arrived.connect(_arrived)
	world.enter_gate.connect(func(): deploy.call())
	world.hint_changed.connect(_set_hint)
	_surface.add_child(world)
	guild_input.z_index = 50
	add_child(guild_input); guild_input.configure(_surface)
	guild_input.tapped.connect(_tap)
	guild_input.interaction.connect(world.interact)
	_render(); world.snap_camera()

func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(_surface): return
	_visual_clock += dt
	if _visual_clock>=1.0:
		_visual_clock = 0.0; world.sync_state()
	guild_input.active = not bool(view_state.panelOpen)
	world.blocked = bool(view_state.panelOpen)
	world.set_manual_input(guild_input.vector())

func _tap(point: Vector2) -> void:
	var slot := world.slot_at(world.world_point(point))
	if slot >= 0: world.go_to(slot)

func _set_hint(caption: String) -> void:
	_hint = caption
	if is_instance_valid(_hint_label): _hint_label.text = caption

func _arrived(slot: int, panel: String) -> void:
	view_state.slot = slot; action_message = ""
	if panel == "claim":
		_command("claim")
		_set_hint("생산 보상을 수령했습니다." if action_message.is_empty() else action_message); return
	view_state.panel = panel; view_state.panelOpen = true
	world.blocked = true; guild_input.active = false; guild_input.reset()
	_render()

func _select(panel: String, slot: int = -1) -> void:
	action_message = ""; view_state.panel = panel; view_state.panelOpen = true
	if slot >= 0: view_state.slot = slot
	_render()

func close_management() -> bool:
	if not bool(view_state.panelOpen): return false
	view_state.panelOpen = false; action_message = ""
	world.blocked = false; guild_input.reset()
	_render()
	return true

func _command(action: String, args: Dictionary = {}) -> void:
	super._command(action,args)
	world.sync_state()
	# A free facility swap keeps the open panel attached to that facility.
	if action == "move" and action_message.is_empty():
		view_state.slot = int(meta.guild.facilities[str(args.id)].slot)
		_render()

func _render() -> void:
	if not is_instance_valid(_surface): return
	if is_instance_valid(_contents):
		remove_child(_contents); _contents.queue_free()
	_contents = Control.new(); _contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contents.z_index = 100
	add_child(_contents); _contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	HeroImageSkin.material(_contents,"glass/tools",Rect2(12,8,891,52))
	var previous := HeroImageSkin.button(_contents,"‹ 이전",Rect2(20,12,80,44),func():
		if not close_management(): back.call()
	,"plain",15)
	_scene_text(previous)
	HeroImageSkin.text(_contents,"길드 본부",Rect2(114,10,210,31),"brand",27,"scene")
	HeroImageSkin.text(_contents,"서울 사무소 · 운영실 Lv.%d" % int(meta.guild.facilities.office.level),Rect2(116,39,258,18),"body",13,"scene")
	for i in range(4):
		var x := 393.0+i*125.0
		HeroImageSkin.text(_contents,["길드 코인","마력자재","연구자료","가속권"][i],Rect2(x,10,110,19),"body",13,"scene",HORIZONTAL_ALIGNMENT_RIGHT)
		HeroImageSkin.text(_contents,HeroUI.amount(int(meta.guild.wallet[HeroGuildState.RESOURCES[i]])),Rect2(x,29,110,27),"number",22,"scene",HORIZONTAL_ALIGNMENT_RIGHT)
	HeroImageSkin.material(_contents,"glass/tools",Rect2(12,351,891,53))
	var actions := [
		["직원",func(): world.go_to(0,"staff")],
		["작업 %d" % meta.guild.jobs.size(),func(): world.go_to(0,"jobs")],
		["수령",func(): world.go_to(0,"claim")],
		["전체 보기" if not world.overview else "따라가기",func(): world.set_overview(not world.overview); _render()],
		["이용 · E",world.interact],
		["작전 투입",world.go_to_gate]
	]
	for i in range(actions.size()):
		var button := HeroImageSkin.button(_contents,actions[i][0],Rect2(22+i*145,356,135,44),actions[i][1],"primary" if i==5 else "secondary",14)
		button.disabled = bool(view_state.panelOpen)
	_hint_label = HeroImageSkin.text(_contents,_hint,Rect2(30,322,620,22),"body",13,"scene")
	_hint_label.add_theme_color_override("font_shadow_color",Color("#142136")); _hint_label.add_theme_constant_override("shadow_offset_x",1); _hint_label.add_theme_constant_override("shadow_offset_y",1)
	world.set_viewport_size(Vector2(650 if view_state.panelOpen else 891,278))
	world.sync_state()
	if not bool(view_state.panelOpen): return
	var panel := HeroImageSkin.frame(_contents,"info",Rect2(674,68,229,278))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP; panel.add_to_group("input_blocker")
	HeroImageSkin.text(_contents,_panel_title(),Rect2(691,77,145,29),"heading",19)
	HeroImageSkin.button(_contents,"닫기",Rect2(839,75,52,44),close_management,"plain",13)
	var key := "walkScroll"+str(view_state.panel)+(str(view_state.slot) if view_state.panel=="facility" else "")
	var scroll := HeroImageSkin.scroll(_contents,Rect2(691,119,195,209),view_state,key)
	scroll.add_to_group("input_blocker")
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",9); scroll.add_child(box)
	if not action_message.is_empty(): _copy(box,action_message,"muted")
	match view_state.panel:
		"staff": _staff(box)
		"hire": _hire(box)
		"jobs": _jobs(box)
		"expedition": _expedition(box)
		_: _facility(box)

func _scene_text(button: Button) -> void:
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,HeroImageSkin.color("scene"))
