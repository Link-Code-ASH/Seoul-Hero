extends RefCounted

# Independent static lobby proposal. Targets are documented; no game navigation or audio.
static func build(ui, parent: Control) -> void:
	ui.image(parent,"premiumLobbyRain",Rect2(0,0,915,412),false,true)
	ui.material(parent,"glass/tools",Rect2(18,12,511,58))
	ui.hud_text(parent,"서울 히어로",Rect2(34,22,213,36),"brand",24,HORIZONTAL_ALIGNMENT_LEFT,"scene")
	_resource(ui,parent,"associationCoin","12,480",Vector2(342,41))
	_resource(ui,parent,"supplyTicket","12",Vector2(462,41))
	ui.material(parent,"glass/tools",Rect2(714,17,182,48))
	_icon_target(ui,parent,"자료집","lobby_icons/codex",Rect2(725,19,44,44))
	_icon_target(ui,parent,"설정","lobby_icons/settings",Rect2(783,19,44,44))
	_icon_target(ui,parent,"음악 ON","lobby_icons/music_on",Rect2(841,19,44,44))
	var destinations := [["길드 본부","lobbyGuildSD"],["전략지원","lobbyGrowthSD"],["협회","lobbyAssociationSD"],["회수","lobbyRecoverySD"],["보급","lobbySupplySD"]]
	for index in range(destinations.size()):
		var position := Vector2(27+index*99,278)
		ui.material(parent,"glass/guild",Rect2(position+Vector2(0,7),Vector2(92,106)))
		ui.image(parent,str(destinations[index][1]),Rect2(position+Vector2(6,0),Vector2(80,79)))
		ui.hud_text(parent,str(destinations[index][0]),Rect2(position+Vector2(0,79),Vector2(92,26)),"control",16,HORIZONTAL_ALIGNMENT_CENTER,"scene")
		_target(ui,parent,str(destinations[index][0]),Rect2(position,Vector2(92,113)),"facility")
	var terminal_rect := Rect2(695,145,190,175)
	ui.material(parent,"spy/terminal",terminal_rect)
	var pulse: NinePatchRect = ui.material(parent,"spy/pulse",terminal_rect)
	pulse.modulate.a = 0.25
	pulse.set_meta("animation_intent",{"property":"modulate:a","minimum":0.25,"maximum":0.60,"periodSeconds":2.0,"capturePhase":0.25})
	ui.material(parent,"spy/deploy",Rect2(659,340,240,56))
	ui.hud_text(parent,"출동 준비",Rect2(673,346,212,43),"control",16,HORIZONTAL_ALIGNMENT_CENTER,"scene")
	_target(ui,parent,"출동 준비",Rect2(659,340,240,56),"prepare")

static func _resource(ui, parent: Control, icon: String, caption: String, center: Vector2) -> void:
	ui.icon_number(parent,ui.texture(icon),caption,center,18,22,"scene")

static func _icon_target(ui, parent: Control, caption: String, material_key: String, rect: Rect2) -> void:
	var role := material_key.get_slice("/",1)
	var bounds: Array = ui.materials.get("packs",{}).get("lobby_icons",{}).get("roles",{}).get(role,{}).get("rect",[0,0,36,36])
	var source_size := Vector2(float(bounds[2]),float(bounds[3]))
	var icon_size := source_size*(36.0/maxf(source_size.x,source_size.y))
	var artwork: NinePatchRect = ui.material(parent,material_key,Rect2(rect.position+(rect.size-icon_size)*0.5,icon_size))
	artwork.set_meta("preview_action",caption)
	if material_key == "lobby_icons/music_on": artwork.set_meta("alternate_material","lobby_icons/music_off")
	_target(ui,parent,caption,rect,"toolbar")

static func _target(ui, parent: Control, caption: String, rect: Rect2, role: String) -> void:
	var hit := Button.new()
	hit.position = rect.position; hit.size = rect.size
	for state in ["normal","hover","pressed","focus","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hit.mouse_filter = Control.MOUSE_FILTER_STOP; parent.add_child(hit)
	ui.controls.append({"caption":caption,"role":"preview-only "+role,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum44":rect.size.x>=44 and rect.size.y>=44})
