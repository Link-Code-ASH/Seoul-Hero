class_name HeroMetaScreens
extends RefCounted

const ECONOMY_UI_APPROVED := true

static func music_button(parent: Node) -> Button:
	var button := HeroUI.button(parent,"ON" if Sound.bgm_enabled() else "OFF",func():
		Profile.meta.settings.muted = not Profile.meta.settings.muted
		Sound.apply_settings(); Profile.save()
	,90)
	HeroUI.button_icon(button,"musicOn" if Sound.bgm_enabled() else "musicOff")
	button.pressed.connect(func():
		button.text = "ON" if Sound.bgm_enabled() else "OFF"
		HeroUI.set_icon(button,"musicOn" if Sound.bgm_enabled() else "musicOff")
	)
	return button

static func title(enter: Callable, resume: Callable, has_run: bool) -> Control:
	var root := HeroImageSkin.root()
	HeroUI.background(root,"titleGate")
	HeroImageSkin.material(root,"ops/info",Rect2(36,50,344,184))
	var seoul := HeroImageSkin.text(root,"서울",Rect2(60,66,296,55),"brand",46,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var hero := HeroImageSkin.text(root,"히어로",Rect2(56,119,304,66),"brand",55,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	for word in [seoul,hero]:
		word.add_theme_constant_override("outline_size",2)
		word.add_theme_color_override("font_outline_color",Color(0.02,0.06,0.10,0.9))
		word.add_theme_constant_override("shadow_offset_y",3)
		word.add_theme_color_override("font_shadow_color",Color(0.0,0.0,0.0,0.45))
	HeroImageSkin.text(root,"서울 게이트 생존 액션",Rect2(62,192,292,25),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var primary := HeroImageSkin.image_button(root,"이어하기" if has_run else "시작하기",Rect2(44,248,328,52),resume if has_run else enter,"compact/primary",19)
	primary.name = "TitleResume" if has_run else "TitleStart"
	if has_run:
		var restart := HeroImageSkin.image_button(root,"새로하기",Rect2(44,312,328,52),enter,"compact/secondary",19)
		restart.name = "TitleNewRun"
	var music := HeroImageSkin.button(root,"",Rect2(801,4,94,44),func():
		Profile.meta.settings.muted = not Profile.meta.settings.muted
		Sound.apply_settings(); Profile.save()
	,"plain",14)
	var music_label := HeroImageSkin.text(root,"음악 ON" if Sound.bgm_enabled() else "음악 OFF",Rect2(801,14,94,24),"body",14,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	music_label.add_theme_constant_override("outline_size",1)
	music_label.add_theme_color_override("font_outline_color",Color(0.05,0.12,0.2,0.9))
	music_label.add_theme_constant_override("shadow_offset_y",1)
	music_label.add_theme_color_override("font_shadow_color",Color(0.05,0.12,0.2,0.8))
	music.pressed.connect(func(): music_label.text = "음악 ON" if Sound.bgm_enabled() else "음악 OFF")
	return root

static func lobby(go: Callable) -> Control:
	return HeroLobbyScreen.build(go)

static func build(screen: String, view: Dictionary, go: Callable, act: Callable) -> Control:
	if screen == "growth": return _growth_screen(view,go,act)
	if screen == "settings": return _settings_screen(go,act)
	if screen == "offline": return HeroEconomyRecoveryScreen.build(go,act) if ECONOMY_UI_APPROVED else HeroRecoveryScreen.build(go,act)
	if screen == "supply": return HeroSupplyScreen.build(go,act)
	return HeroEconomyUI.association(go,act,str(view.get("associationId","vitality"))) if ECONOMY_UI_APPROVED else _association_screen(go,act)

static func _image_header(root: Control, title_text: String, subtitle: String, back: Callable) -> void:
	HeroImageSkin.header(root,title_text,back)
	if not subtitle.is_empty(): HeroImageSkin.text(root,subtitle,Rect2(28,72,790,24),"body",13,"muted")

static func _image_backdrop(root: Control, image_id: String) -> void:
	HeroImageSkin.night_backdrop(root,image_id)

static func _growth_screen(view: Dictionary, go: Callable, act: Callable) -> Control:
	var root := HeroImageSkin.root()
	_image_backdrop(root,"metaGrowthLab")
	_image_header(root,"전략지원","조각으로 각성자·무기 해금, 축복 성장 · 보유 코인 %d" % int(Profile.meta.wallet.associationCoins),func(): go.call("lobby"))
	var tab_index := 0
	for entry in [["character","각성자"],["weapon","공용 무기"],["blessing","단군의 축복"]]:
		HeroImageSkin.image_button(root,entry[1],Rect2(24+tab_index*170,102,162,44),func(): act.call("growthTab",entry[0]),"ops/tab",16,view.kind == entry[0])
		tab_index += 1
	var source: Dictionary = Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[view.kind]]
	if not source.has(view.id): view.id = source.keys()[0]
	var collection: Dictionary = Profile.meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[view.kind]]
	var list := HeroImageSkin.scroll(root,Rect2(24,158,254,240),view,"scroll_"+str(view.kind))
	list.name = "GrowthCollection"
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	list.add_child(rows)
	for id in source:
		var definition: Dictionary = source[id]
		var record: Dictionary = collection[id]
		var selected: bool = id == view.id
		var row := HeroImageSkin.image_button(rows,"",Rect2(0,0,238,56),func(): act.call("growthSelect",id),"ops/row",16,selected)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art := HeroUI.image(row,_growth_texture(str(view.kind),str(id),definition),0,0)
		HeroUI.place(art,Rect2(9,7,40,41))
		HeroImageSkin.text(row,definition.name,Rect2(58,6,169,44),"control",16,"accent" if selected else "ink",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
		if not record.unlocked: row.modulate = Color(0.72,0.76,0.80)
	var selected: Dictionary = source[view.id]
	var progress: Dictionary = collection[view.id]
	var growable: bool = view.kind == "blessing"
	var level: int = int(progress.level) if growable else 0
	var max_level: int = int(Content.data.growth.maxLevel)
	var cost: int = int(Content.data.growth.blessingCosts[level]) if growable and level < max_level else int(Content.data.growth.get(str(view.kind)+"UnlockCost",0))
	var coin_cost: int = int(Content.data.growth.coinCosts[level]) if growable and level < max_level else 0
	HeroImageSkin.material(root,"ops/info",Rect2(301,152,590,253))
	HeroImageSkin.text(root,selected.name,Rect2(325,164,540,32),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var art := HeroUI.image(root,_growth_texture(str(view.kind),str(view.id),selected),0,0)
	HeroUI.place(art,Rect2(321,201,145,139))
	art.name = "GrowthArt"
	var status := "%s · %d / %d 단계" % ["해금" if progress.unlocked else "미해금",level,max_level] if growable else ("해금 완료" if progress.unlocked else "미해금")
	HeroImageSkin.text(root,status,Rect2(315,345,154,30),"body",14,"accent" if progress.unlocked else "muted",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var notes_scroll := HeroImageSkin.scroll(root,Rect2(494,201,372,97))
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation",8)
	notes_scroll.add_child(notes)
	_native_copy(notes,selected.description,14,"muted")
	if growable:
		_native_copy(notes,"현재 효과" if level > 0 else "단계당 효과",14,"accent")
		for modifier in selected.modifiers:
			_native_copy(notes,_growth_modifier(modifier,maxi(1,level)),14,"ink")
		if selected.has("structureLimitAtLevel"):
			_native_copy(notes,"%d단계부터 설치물 한도 +1" % int(selected.structureLimitAtLevel),14,"ink")
	else:
		_native_copy(notes,"조각을 모아 해금하면 출동 준비와 상점에 나와요. 해금 뒤 따로 강화하지 않아요.",14,"accent")
	HeroImageSkin.text(root,"보유 조각",Rect2(494,299,151,25),"body",14,"muted")
	HeroImageSkin.text(root,str(int(progress.fragments)) if growable or progress.unlocked else "%d / %d" % [int(progress.fragments),cost],Rect2(674,296,190,29),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	if growable:
		for i in range(max_level):
			var stage_rect := Rect2(494+i*75,330,65,22)
			var stage := HeroImageSkin.material(root,"ops/row",stage_rect)
			if i < level: stage.modulate = Color(0.82,1.0,0.94)
			HeroImageSkin.text(root,str(i+1),stage_rect,"number",18,"accent" if i < level else "muted",HORIZONTAL_ALIGNMENT_CENTER)
	var can_act: bool
	var caption: String
	if growable:
		can_act = level < max_level and int(progress.fragments) >= cost and Profile.meta.wallet.associationCoins >= coin_cost
		caption = "최대 성장 완료" if level >= max_level else "%s · %d 조각 + %d 코인" % ["성장" if progress.unlocked else "해금",cost,coin_cost]
	else:
		can_act = not progress.unlocked and int(progress.fragments) >= cost
		caption = "해금 완료" if progress.unlocked else "해금 · %d 조각" % cost
	var buy := HeroImageSkin.image_button(root,caption,Rect2(494,356,372,44),func(): act.call("grow",view.id),"ops/primary",16)
	buy.name = "GrowthAction"
	buy.disabled = not can_act
	return root

static func _growth_texture(kind: String, id: String, definition: Dictionary) -> Texture2D:
	return Content.weapon_icon(id) if kind == "weapon" else Content.actor_preview("characters",id,definition.portraitSprite) if kind == "character" else Content.trimmed_texture(definition.image)

static func _growth_modifier(modifier: Dictionary, level: int) -> String:
	var value: float = (float(modifier.value)-1.0)*level if modifier.operation == "multiply" else float(modifier.value)*level
	var percent: bool = modifier.operation == "multiply" or modifier.stat in HeroArchive.PROBABILITIES
	if percent: value *= 100.0
	return "%s  %s%s%s" % [HeroArchive.STATS.get(modifier.stat,modifier.stat),"+" if value > 0 else "",HeroArchive.number(value),"%" if percent else ""]

static func _native_copy(parent: Node, caption: String, size: int = 14, color_role: String = "ink") -> Label:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HeroImageSkin.apply_font(label,"body",size)
	label.add_theme_color_override("font_color",HeroImageSkin.color(color_role))
	label.add_theme_constant_override("line_spacing",2)
	parent.add_child(label)
	return label

static func _association_screen(go: Callable, act: Callable) -> Control:
	var root := HeroImageSkin.root()
	_image_backdrop(root,"metaAssociationOffice")
	HeroImageSkin.header(root,"협회",func(): go.call("lobby"),[{"image_id":"associationCoin","amount":HeroUI.amount(int(Profile.meta.wallet.associationCoins)),"name":"협회 코인","label_name":"AssociationCoins"}])
	HeroImageSkin.material(root,"ops/info",Rect2(24,76,214,324))
	HeroImageSkin.text(root,"협회 지원",Rect2(44,88,174,28),"heading",18,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	HeroUI.fixed_art(root,Content.trimmed_texture("lobbyAssociation"),Rect2(44,122,174,194)).name = "AssociationRewardArt"
	HeroImageSkin.text(root,"협회 코인으로 영구 지원을 강화합니다.",Rect2(44,328,174,56),"body",14,"muted",HORIZONTAL_ALIGNMENT_LEFT,true)
	var scroll := HeroImageSkin.scroll(root,Rect2(254,76,638,324))
	scroll.name = "AssociationCollection"
	var grid := GridContainer.new()
	grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	scroll.add_child(grid)
	for id in Content.data.upgrades:
		var definition: Dictionary = Content.data.upgrades[id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(300,164)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",HeroImageSkin.style("ops/info",Vector4(20,12,20,12)))
		panel.set_meta("material_key","ops/info")
		grid.add_child(panel)
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation",8)
		panel.add_child(card)
		var heading := _native_copy(card,definition.name,18)
		HeroImageSkin.apply_font(heading,"heading",18)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var caption := str(definition.description)
		if definition.effect.type == "stat":
			var level := int(Profile.meta.association.upgrades.get(id,0))
			var bonus := HeroMeta.association_bonus(definition,level)
			var increase := HeroMeta.association_bonus(definition,level+1)-bonus
			caption = "강화 %d회 · 현재 +%s\n다음 구매 +%s" % [level,association_value(definition,bonus),association_value(definition,increase)]
			if float(definition.get("softCap",0.0)) > 0: caption += "\n협회 보너스 +%s에 점감 접근" % association_value(definition,float(definition.softCap))
		var description := _native_copy(card,caption,14,"muted")
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var cost := HeroMeta.association_cost(Content.data,Profile.meta,id)
		var button := HeroImageSkin.image_button(card,"완료" if cost < 0 else "성장 · %d 코인" % cost,Rect2(0,0,260,44),func(): act.call("associationBuy",id),"ops/primary",16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = cost < 0 or Profile.meta.wallet.associationCoins < cost
	return root

static func association_value(upgrade: Dictionary, value: float) -> String:
	var percent: bool = upgrade.effect.operation == "multiply" or upgrade.effect.stat in HeroArchive.MULTIPLIERS or upgrade.effect.stat in HeroArchive.PROBABILITIES
	if percent: value *= 100.0
	var unit := ("%" if upgrade.effect.operation == "multiply" else "%p") if percent else ""
	if value > 0.0 and value < 0.005: return "0.01"+unit+" 미만"
	var amount := (("%.2f" if absf(value) < 0.1 else "%.1f") % value).rstrip("0").rstrip(".")
	return amount+unit

# Same desk as 자료집: a paper "음향 설정" sheet with painted sliders on the left, a folder of
# data keys on the right.
static func _settings_screen(go: Callable, act: Callable) -> Control:
	if HeroDesk.presentation: return _settings_presentation(go,act)
	var root := HeroImageSkin.root()
	HeroDesk.backdrop(root)
	HeroDesk.header(root,"설정",func(): go.call("lobby"))
	var sound := HeroDesk.paper(root,Rect2(14,58,500,346),"SettingsSound")
	HeroDesk.art(sound,HeroDesk.ART+"tape_strip.png",Rect2(202,-10,96,28)).name = "SheetTape"
	HeroDesk.text(sound,"음향 설정",Rect2(26,18,300,32),"brand",22,HeroDesk.INK).name = "SettingsSoundTitle"
	var pairs := [["masterVolume","전체 음량"],["musicVolume","배경음악"],["combatVolume","전투 효과음"],["uiVolume","UI 효과음"]]
	for i in range(pairs.size()):
		var pair: Array = pairs[i]
		var y: float = 60+i*54
		HeroDesk.text(sound,pair[1],Rect2(28,y,120,40),"control",16,HeroDesk.INK)
		var slider := HSlider.new()
		slider.name = "Volume_"+str(pair[0])
		slider.min_value = 0; slider.max_value = 100; slider.step = 1
		slider.value = float(Profile.meta.settings[pair[0]])*100.0
		slider.mouse_filter = Control.MOUSE_FILTER_STOP
		slider.add_to_group("input_blocker")
		slider.add_theme_stylebox_override("slider",_desk_slider_box("slider_track.png"))
		slider.add_theme_stylebox_override("grabber_area",_desk_slider_box("slider_fill.png"))
		slider.add_theme_stylebox_override("grabber_area_highlight",_desk_slider_box("slider_fill.png"))
		slider.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		slider.add_theme_icon_override("grabber",load(HeroDesk.OFFICE+"slider_knob.png"))
		slider.add_theme_icon_override("grabber_highlight",load(HeroDesk.OFFICE+"slider_knob_active.png"))
		slider.add_theme_icon_override("grabber_disabled",load(HeroDesk.OFFICE+"slider_knob.png"))
		slider.add_theme_constant_override("center_grabber",1)
		sound.add_child(slider)
		HeroUI.place(slider,Rect2(152,y,276,40))
		var number := HeroDesk.text(sound,str(int(roundf(slider.value))),Rect2(436,y,40,40),"number",18,HeroDesk.ACCENT,HORIZONTAL_ALIGNMENT_RIGHT)
		slider.value_changed.connect(func(value): number.text = str(int(roundf(value))); act.call("volume",{"key":pair[0],"value":value/100.0}))
	HeroDesk.postit(root,Rect2(388,326,112,80),"음량은 바로 적용돼요!","mint",4.0)
	# Native callbacks preserve immediate audio, backup, import and sample routes.
	var data := HeroDesk.folder(root,Rect2(526,52,378,356),"SettingsData")
	HeroDesk.text(data,"데이터",Rect2(26,44,200,26),"brand",17,HeroDesk.INK).name = "SettingsDataTitle"
	HeroDesk.key(data,"저장 폴더 열기",Rect2(24,82,330,46),func(): OS.shell_open(ProjectSettings.globalize_path("user://")),"cream",16)
	HeroDesk.key(data,"JSON 백업",Rect2(24,138,160,46),func(): act.call("backup",""),"cream",16)
	HeroDesk.key(data,"백업 가져오기",Rect2(194,138,160,46),func(): act.call("import",""),"cream",16)
	HeroDesk.key(data,"개발자 모드 · 켜짐" if Profile.meta.settings.developerMode else "개발자 모드 · 꺼짐",Rect2(24,194,330,46),func(): act.call("developer",not Profile.meta.settings.developerMode),"navy" if Profile.meta.settings.developerMode else "cream",16)
	HeroDesk.key(data,"SD 캐릭터 샘플",Rect2(24,250,160,46),func(): act.call("sd-sample",""),"cream",14)
	HeroDesk.key(data,"캐릭터·몬스터 모션",Rect2(194,250,160,46),func(): act.call("graphics",""),"cream",14)
	HeroDesk.text(data,"Seoul Hero · 915×412",Rect2(24,312,330,22),"body",12,HeroDesk.BODY,HORIZONTAL_ALIGNMENT_CENTER)
	return root

static func _settings_presentation(go: Callable, act: Callable) -> Control:
	var root := HeroImageSkin.root()
	HeroDesk.backdrop(root,"settings")
	HeroDesk.header(root,"설정",func(): go.call("lobby"))
	var sound := HeroDesk.panel(root,Rect2(14,72,490,272),"SettingsSound")
	HeroDesk.text(sound,"음향 설정",Rect2(22,12,300,32),"heading",20,HeroDesk.INK).name = "SettingsSoundTitle"
	var pairs := [["masterVolume","전체 음량"],["musicVolume","배경음악"],["combatVolume","전투 효과음"],["uiVolume","UI 효과음"]]
	for i in range(pairs.size()):
		var pair: Array = pairs[i]
		var y: float = 54+i*48
		HeroDesk.nine(sound,HeroDesk.UNIFIED+"glass_row.png",Rect2(16,y,458,42),Vector4(24,24,24,24),42.0/112.0).name = "VolumeRow_"+str(pair[0])
		HeroDesk.text(sound,pair[1],Rect2(28,y,118,42),"control",15,HeroDesk.INK)
		var slider := HSlider.new()
		slider.name = "Volume_"+str(pair[0])
		slider.min_value = 0; slider.max_value = 100; slider.step = 1
		slider.value = float(Profile.meta.settings[pair[0]])*100.0
		slider.mouse_filter = Control.MOUSE_FILTER_STOP
		slider.add_to_group("input_blocker")
		slider.add_theme_stylebox_override("slider",_desk_slider_box("slider_track.png"))
		slider.add_theme_stylebox_override("grabber_area",_desk_slider_box("slider_fill.png"))
		slider.add_theme_stylebox_override("grabber_area_highlight",_desk_slider_box("slider_fill.png"))
		slider.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		slider.add_theme_icon_override("grabber",load(HeroDesk.OFFICE+"slider_knob.png"))
		slider.add_theme_icon_override("grabber_highlight",load(HeroDesk.OFFICE+"slider_knob_active.png"))
		slider.add_theme_icon_override("grabber_disabled",load(HeroDesk.OFFICE+"slider_knob.png"))
		slider.add_theme_constant_override("center_grabber",1)
		sound.add_child(slider); HeroUI.place(slider,Rect2(150,y-1,252,44))
		var number := HeroDesk.text(sound,str(int(roundf(slider.value))),Rect2(420,y,38,42),"number",20,HeroDesk.accent(root),HORIZONTAL_ALIGNMENT_RIGHT)
		slider.value_changed.connect(func(value): number.text = str(int(roundf(value))); act.call("volume",{"key":pair[0],"value":value/100.0}))
	var data := HeroDesk.panel(root,Rect2(516,72,385,272),"SettingsData")
	HeroDesk.text(data,"데이터",Rect2(22,12,200,32),"heading",20,HeroDesk.INK).name = "SettingsDataTitle"
	HeroDesk.key(data,"저장 폴더 열기",Rect2(22,52,341,44),func(): OS.shell_open(ProjectSettings.globalize_path("user://")),"cream",16)
	HeroDesk.key(data,"JSON 백업",Rect2(22,100,164,44),func(): act.call("backup",""),"cream",15)
	HeroDesk.key(data,"백업 가져오기",Rect2(194,100,169,44),func(): act.call("import",""),"cream",15)
	HeroDesk.key(data,"개발자 모드 · 켜짐" if Profile.meta.settings.developerMode else "개발자 모드 · 꺼짐",Rect2(22,148,341,44),func(): act.call("developer",not Profile.meta.settings.developerMode),"navy" if Profile.meta.settings.developerMode else "cream",16)
	HeroDesk.key(data,"SD 캐릭터 샘플",Rect2(22,196,164,44),func(): act.call("sd-sample",""),"cream",13)
	HeroDesk.key(data,"캐릭터·몬스터 모션",Rect2(194,196,169,44),func(): act.call("graphics",""),"cream",13)
	var footer := HeroDesk.nine(root,HeroDesk.UNIFIED+"glass_row.png",Rect2(14,354,490,46),Vector4(24,24,24,24),46.0/112.0)
	footer.self_modulate.a = 0.84
	HeroDesk.text(root,"협회 사무실 · 환경 설정",Rect2(30,354,458,46),"body",13,HeroDesk.INK).name = "SettingsFooter"
	var note := HeroDesk.postit(root,Rect2(814,340,78,60),"즉시 적용\n음향 설정","mint",2.0)
	(note.get_node("DeskNoteText") as Label).add_theme_font_size_override("font_size",11)
	return root

# Painted bar art for the volume sliders (downscaled bar_frame / bar_fill, 160x20).
static func _desk_slider_box(file: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(HeroDesk.OFFICE+file)
	box.texture_margin_left = 9.0; box.texture_margin_right = 9.0
	box.texture_margin_top = 6.0; box.texture_margin_bottom = 6.0
	box.content_margin_top = 1.0; box.content_margin_bottom = 1.0
	return box

static func rewards_popup(root: Control, rewards: Array, title: String = "보급 결과") -> void:
	var office_result: bool = HeroDesk.presentation and bool(root.get_meta("office_presentation",false)) and HeroDesk.profile(root) == "association"
	var box := _association_rewards_frame(root,title) if office_result else HeroCombatUI.popup(root,title,740,335)
	var scroll := HeroUI.scroll(box)
	var grid := GridContainer.new(); grid.columns = 5; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	var grouped := {}
	for reward in rewards:
		var key: String = reward.type + ":" + reward.contentId
		if not grouped.has(key): grouped[key] = reward.duplicate()
		else: grouped[key].amount += reward.amount
	var reveal_index := 0
	var shower_groups: Array = []
	for reward in grouped.values():
		var display := reward_display(reward)
		var card := HeroUI.column(grid)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Cards stay dim until their share of the loot rain lands on them.
		card.modulate.a = 0.12
		var reward_art := HeroUI.image(card,display.texture,90,76)
		reward_art.name = "SupplyReward_%d" % reveal_index
		shower_groups.append({"texture":display.texture,"amount":int(reward.amount),"target":reward_art,"card":card,"seed":reveal_index+17})
		reveal_index += 1
		var reward_name := _heading(card,display.name,14)
		if office_result:
			reward_name.add_theme_font_override("font",HeroDesk.font("body"))
			reward_name.add_theme_color_override("font_color",Color(HeroDesk.INK))
		reward_name.custom_minimum_size.y = HeroUI.lines_height(card,14,3)
		reward_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var amount := _heading(card,"×%d" % int(reward.amount),18)
		if office_result:
			amount.add_theme_font_override("font",HeroDesk.font("number"))
			amount.add_theme_color_override("font_color",Color(HeroDesk.accent(root)))
		else: HeroImageSkin.apply_font(amount,"number",18)
	var actions := HeroUI.row(box)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	if office_result:
		HeroDesk.key(actions,"확인",Rect2(0,0,160,44),func(): box.get_meta("overlay").queue_free(),"navy",16).name = "AssociationRewardConfirm"
	else:
		HeroImageSkin.image_button(actions,"확인",Rect2(0,0,160,44),func(): box.get_meta("overlay").queue_free(),"ops/primary",16)
	var effects = root.get_tree().get_first_node_in_group("ui_effects")
	Sound.cue("supplyFanfare")
	HeroLootShower.play(box.get_meta("overlay"),box,shower_groups,func(index: int):
		var entry: Dictionary = shower_groups[index]
		if is_instance_valid(entry.card): entry.card.modulate.a = 1.0
		if effects != null and is_instance_valid(entry.target): effects.show_effect("supply",{"anchor":entry.target.name,"seed":entry.seed})
	)

# The association owns its result frame; global combat/lobby popups stay intact.
static func _association_rewards_frame(root: Control, title: String) -> VBoxContainer:
	var blocker := ColorRect.new()
	blocker.name = "AssociationRewardOverlay"
	blocker.color = Color(0.05,0.09,0.14,0.48)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.add_to_group("input_blocker")
	root.add_child(blocker)
	var frame := HeroDesk.panel(blocker,Rect2(87.5,38.5,740,335),"AssociationRewardFrame")
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HeroUI.inset(frame,Vector2(20,12))
	box.name = "AssociationRewardContent"
	box.set_meta("overlay",blocker)
	var heading := HeroUI.text_block(box,title,44,22,Color(HeroDesk.accent(root)),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":1,"font_role":"heading"})
	heading.name = "AssociationRewardTitle"
	heading.add_theme_font_override("font",HeroDesk.font("brand"))
	return box

static func _heading(parent: Node, text: String, font_size: int) -> Label:
	var heading := _native_copy(parent,text,font_size)
	HeroImageSkin.apply_font(heading,"heading" if font_size >= 18 else "body",font_size)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return heading

static func _value_row(parent: Node, title_text: String, value_text: String, font_size: int) -> void:
	var row := HeroUI.row(parent)
	var title_label := HeroUI.label(row,title_text,14)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := HeroUI.label(row,value_text,font_size)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func reward_display(reward: Dictionary) -> Dictionary:
	match reward.type:
		"characterUnlock": return {"name":Content.data.characters[reward.contentId].name + " 해금","texture":Content.actor_preview("characters",reward.contentId,Content.data.characters[reward.contentId].portraitSprite)}
		"weaponUnlock": return {"name":Content.data.weapons[reward.contentId].name + " 해금","texture":Content.weapon_icon(reward.contentId)}
		"blessingUnlock": return {"name":Content.data.blessings[reward.contentId].name + " 해금","texture":Content.trimmed_texture(Content.data.blessings[reward.contentId].image)}
		"guildResource":
			var resource: Dictionary = Content.data.resources[reward.contentId]
			return {"name":resource.name,"texture":Content.trimmed_texture(resource.image) if ECONOMY_UI_APPROVED else null}
		"associationCoin": return {"name":"협회 코인","texture":Content.trimmed_texture("associationCoin")}
		"supplyTicket": return {"name":"보급권","texture":Content.trimmed_texture("supplyTicket")}
		"revivalStone": return {"name":Content.data.revivalStones[reward.contentId].name,"texture":Content.trimmed_texture(Content.data.revivalStones[reward.contentId].image)}
		"weaponFragment": return {"name":Content.data.weapons[reward.contentId].name + " 조각","texture":Content.weapon_icon(reward.contentId)}
		"characterFragment": return {"name":Content.data.characters[reward.contentId].name + " 조각","texture":Content.actor_preview("characters",reward.contentId,Content.data.characters[reward.contentId].portraitSprite)}
		_: return {"name":Content.data.blessings[reward.contentId].name + " 조각","texture":Content.trimmed_texture(Content.data.blessings[reward.contentId].image)}
