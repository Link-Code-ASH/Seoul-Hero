class_name HeroLobbyScreen
extends RefCounted

class MusicStateIcon extends TextureRect:
	var _has_state := false
	var _enabled := false
	func _ready() -> void:
		visibility_changed.connect(_visibility_changed)
		_visibility_changed()
		_refresh()
	func _visibility_changed() -> void:
		set_process(is_visible_in_tree())
	func _process(_delta: float) -> void:
		_refresh()
	func _refresh() -> void:
		var enabled := Sound.bgm_enabled()
		if _has_state and enabled == _enabled: return
		_enabled = enabled; _has_state = true
		texture = HeroImageSkin.source_texture("lobby_icons/music_on" if enabled else "lobby_icons/music_off")

static func build(go: Callable, scene_id: String = "") -> Control:
	var root := HeroImageSkin.root()
	if scene_id.is_empty(): scene_id = str(Content.data.premiumUI.scenes.pick_random())
	root.set_meta("lobbyAmbience", _environment_cue(scene_id))
	var backdrop := HeroUI.background(root,scene_id)
	var daylight := ShaderMaterial.new()
	daylight.shader = preload("res://shaders/lobby_daylight.gdshader")
	backdrop.material = daylight
	var ambience := HeroLobbyAtmosphere.new()
	ambience.scene_id = scene_id
	ambience.set_meta("full_bleed",true)
	root.add_child(ambience)
	HeroImageSkin.material(root,"glass/tools",Rect2(18,12,511,58))
	var title := HeroImageSkin.text(root,"서울 히어로",Rect2(34,22,213,36),"brand",27,"scene")
	_readable(title)
	_wallet(root,"associationCoin",int(Profile.meta.wallet.associationCoins),Vector2(342,41),"AssociationCoins")
	_wallet(root,"supplyTicket",int(Profile.meta.wallet.supplyTickets),Vector2(462,41),"SupplyTickets")
	HeroImageSkin.material(root,"glass/tools",Rect2(714,17,182,48))
	var archive := _icon_button(root,"lobby_icons/codex",Rect2(725,19,44,44),func(): go.call("archive"))
	archive.name = "LobbyArchive"
	var settings := _icon_button(root,"lobby_icons/settings",Rect2(783,19,44,44),func(): go.call("settings"))
	settings.name = "LobbySettings"
	var music := HeroImageSkin.button(root,"",Rect2(841,19,44,44),func():
		Profile.meta.settings.muted = not Profile.meta.settings.muted
		Sound.apply_settings(); Profile.save()
	,"plain")
	music.name = "LobbyMusic"
	var music_art := MusicStateIcon.new()
	music_art.name = "MusicStateIcon"
	music_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	music_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	music_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	music_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music.add_child(music_art); HeroUI.place(music_art,Rect2(4,4,36,36))
	music.pressed.connect(music_art._refresh)
	var destinations := [["guild","길드","lobbyGuildSD"],["growth","전략지원","lobbyGrowthSD"],["association","협회","lobbyAssociationSD"],["offline","회수","lobbyRecoverySD"],["supply","보급","lobbySupplySD"]]
	for i in range(destinations.size()):
		var x := 27+i*99
		var target := str(destinations[i][0])
		var icon_id := str(destinations[i][2])
		var facility := HeroImageSkin.button(root,"",Rect2(x,278,92,113),func(): go.call(target),"plain")
		var glass := HeroImageSkin.glass(facility,Rect2(0,7,92,106))
		HeroUI.fixed_art(facility,Content.actor_texture({"sprite":icon_id,"region":Content.data.images[icon_id].region}),Rect2(6,0,80,79))
		var caption := HeroImageSkin.text(facility,str(destinations[i][1]),Rect2(0,79,92,22),"heading",16,"scene",HORIZONTAL_ALIGNMENT_CENTER)
		_readable(caption)
		facility.mouse_entered.connect(func(): glass.modulate = Color(1.08,1.08,1.08))
		facility.mouse_exited.connect(func(): glass.modulate = Color.WHITE)
		facility.focus_entered.connect(func(): glass.modulate = Color(1.08,1.08,1.08))
		facility.focus_exited.connect(func(): glass.modulate = Color.WHITE)
	var terminal_rect := Rect2(695,145,190,175)
	HeroImageSkin.material(root,"spy/terminal",terminal_rect)
	_scan(root,terminal_rect)
	var deploy := HeroImageSkin.button(root,"",Rect2(659,340,240,56),func(): go.call("gate"),"plain")
	deploy.name = "LobbyDeploy"
	HeroImageSkin.put_surface(deploy,"spy/deploy")
	var deploy_caption := HeroImageSkin.text(deploy,"작전 투입",Rect2(14,6,212,43),"heading",20,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	_readable(deploy_caption)
	return root

static func _environment_cue(scene_id: String) -> String:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HeroLobbyAtmosphere.CATALOG))
	var definition: Dictionary = catalog.get(scene_id, {})
	var environment := str(definition.get("environment", ""))
	var backgrounds: Dictionary = Content.data.get("audioConnections", {}).get("lobbyBackgrounds", {})
	return str(backgrounds.get(environment, ""))

static func _scan(parent: Node, rect: Rect2) -> void:
	var pulse := HeroImageSkin.material(parent,"spy/pulse",rect)
	pulse.name = "OperationScan"
	pulse.modulate.a = 0.25
	pulse.ready.connect(func():
		var scan := pulse.create_tween().set_loops()
		scan.tween_property(pulse,"modulate:a",0.60,1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		scan.tween_property(pulse,"modulate:a",0.25,1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.visibility_changed.connect(func():
			if pulse.is_visible_in_tree(): scan.play()
			else: scan.pause()
		)
		if not pulse.is_visible_in_tree(): scan.pause()
	)

static func _icon_button(parent: Node, key: String, rect: Rect2, action: Callable) -> Button:
	var button := HeroImageSkin.button(parent,"",rect,action,"plain")
	HeroUI.fixed_art(button,HeroImageSkin.source_texture(key),Rect2(4,4,36,36)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return button

static func _readable(label: Label) -> void:
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color(0.03,0.07,0.12,0.85))
	label.add_theme_constant_override("shadow_offset_y",1)

static func _wallet(parent: Node, image_id: String, value: int, center: Vector2, node_name: String) -> void:
	var caption := HeroUI.amount(value)
	var number_width := ceilf(HeroImageSkin.font("number").get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x)
	var left := center.x-(22.0+6.0+number_width)*0.5
	HeroUI.fixed_art(parent,Content.trimmed_texture(image_id),Rect2(left,center.y-11,22,22))
	var amount := HeroImageSkin.text(parent,caption,Rect2(left+28,center.y-18,number_width,36),"number",21,"scene")
	amount.name = node_name
	_readable(amount)
