extends RefCounted
# Approval-pending design only. Frozen assets/data; no production UI, profile or audio.

static func build(ui, parent: Control) -> void:
	ui.image(parent,"premiumLobbyRain",Rect2(0,0,915,412),false,true)
	ui.wash(parent,Color(0.95,0.98,1.0,0.09))
	ui.material(parent,"glass/tools",Rect2(18,12,511,58))
	var title: Label = ui.text(parent,"서울 히어로",Rect2(34,22,213,36),"brand",27,"scene")
	_readable(title)
	_resource(ui,parent,"associationCoin","12,480",Vector2(342,41))
	_resource(ui,parent,"supplyTicket","12",Vector2(462,41))
	ui.material(parent,"glass/tools",Rect2(714,17,182,48))
	_icon_target(ui,parent,"자료집","lobby_icons/codex",Rect2(725,19,44,44))
	_icon_target(ui,parent,"설정","lobby_icons/settings",Rect2(783,19,44,44))
	_icon_target(ui,parent,"음악 ON","lobby_icons/music_on",Rect2(841,19,44,44))
	var destinations := [
		["길드","lobbyGuildSD"],["전략지원","lobbyGrowthSD"],["협회","lobbyAssociationSD"],
		["회수","lobbyRecoverySD"],["보급","lobbySupplySD"]]
	for index in range(destinations.size()):
		var position := Vector2(27+index*99,278)
		ui.material(parent,"glass/guild",Rect2(position+Vector2(0,7),Vector2(92,106)))
		ui.image(parent,str(destinations[index][1]),Rect2(position+Vector2(6,0),Vector2(80,79)))
		var caption: Label = ui.text(parent,str(destinations[index][0]),Rect2(position+Vector2(0,79),Vector2(92,22)),"heading",16,"scene",HORIZONTAL_ALIGNMENT_CENTER)
		caption.add_theme_color_override("font_shadow_color",Color(0.05,0.13,0.21,0.85))
		caption.add_theme_constant_override("shadow_offset_y",1)
		_target(ui,parent,str(destinations[index][0]),Rect2(position,Vector2(92,113)))
	var terminal_rect := Rect2(695,145,190,175)
	ui.material(parent,"spy/terminal",terminal_rect)
	var pulse: NinePatchRect = ui.material(parent,"spy/pulse",terminal_rect)
	pulse.name = "OperationScan"
	pulse.modulate.a = 0.25
	pulse.set_meta("animation_intent",{"property":"modulate:a","minimum":0.25,"maximum":0.60,"periodSeconds":2.0,"fixedPosition":true,"fixedSize":true,"capturePhase":0.25})
	ui.frames[ui.frames.size()-1]["animationIntent"] = pulse.get_meta("animation_intent")
	if not "--capture" in OS.get_cmdline_user_args():
		var scan := pulse.create_tween().set_loops()
		scan.tween_property(pulse,"modulate:a",0.60,1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		scan.tween_property(pulse,"modulate:a",0.25,1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ui.material(parent,"spy/deploy",Rect2(659,340,240,56))
	var deploy: Label = ui.text(parent,"작전 투입",Rect2(673,346,212,43),"heading",20,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	_readable(deploy)
	_target(ui,parent,"작전 투입",Rect2(659,340,240,56))

static func _resource(ui, parent: Control, icon: String, caption: String, center: Vector2) -> void:
	var measured: Vector2 = ui.font("number").get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,21)
	var number_width := ceilf(measured.x)
	var left := center.x-(22.0+6.0+number_width)*0.5
	ui.image(parent,icon,Rect2(left,center.y-11,22,22))
	var amount: Label = ui.text(parent,caption,Rect2(left+28,center.y-18,number_width,36),"number",21,"scene")
	_readable(amount)

static func _icon_target(ui, parent: Control, caption: String, material_key: String, rect: Rect2) -> void:
	var role := material_key.get_slice("/",1)
	var bounds: Array = ui.materials.get("packs",{}).get("lobby_icons",{}).get("roles",{}).get(role,{}).get("rect",[0,0,36,36])
	var source_size := Vector2(float(bounds[2]),float(bounds[3]))
	var icon_size := source_size*(36.0/maxf(source_size.x,source_size.y))
	var artwork: NinePatchRect = ui.material(parent,material_key,Rect2(rect.position+(rect.size-icon_size)*0.5,icon_size))
	artwork.set_meta("preview_action",caption)
	if material_key == "lobby_icons/music_on": artwork.set_meta("alternate_material","lobby_icons/music_off")
	_target(ui,parent,caption,rect)

static func _readable(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color",Color(0.03,0.07,0.12,0.85))
	label.add_theme_constant_override("shadow_offset_y",1)

static func _target(ui, parent: Control, caption: String, rect: Rect2) -> void:
	var hit := Button.new()
	hit.position = rect.position; hit.size = rect.size
	for state in ["normal","hover","pressed","focus","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(hit)
	ui.controls.append({"caption":caption,"role":"preview-only unframed","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum44":rect.size.x >= 44 and rect.size.y >= 44})
