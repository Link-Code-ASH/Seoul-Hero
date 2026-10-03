class_name HeroMetaScreens
extends RefCounted

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
	HeroImageSkin.frame(root,"info",Rect2(36,50,344,184))
	var seoul := HeroImageSkin.text(root,"서울",Rect2(60,66,296,55),"brand",46,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	var hero := HeroImageSkin.text(root,"히어로",Rect2(56,119,304,66),"brand",55,"accent",HORIZONTAL_ALIGNMENT_CENTER)
	for word in [seoul,hero]:
		word.add_theme_constant_override("outline_size",2)
		word.add_theme_color_override("font_outline_color",Color(0.95,0.97,0.98,0.9))
		word.add_theme_constant_override("shadow_offset_y",3)
		word.add_theme_color_override("font_shadow_color",Color(0.05,0.13,0.21,0.28))
	HeroImageSkin.text(root,"서울 게이트 생존 액션",Rect2(62,192,292,25),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	var primary := HeroImageSkin.button(root,"이어하기" if has_run else "시작하기",Rect2(44,248,328,52),resume if has_run else enter,"primary",19)
	primary.name = "TitleResume" if has_run else "TitleStart"
	if has_run:
		var restart := HeroImageSkin.button(root,"새로하기",Rect2(44,312,328,52),enter,"secondary",19)
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
	var root := HeroUI.root()
	var backgrounds := {"association":"metaAssociationOffice","offline":"metaOfflineTerminal","supply":"metaSupplyVault"}
	HeroUI.background(root,backgrounds[screen],Color(0.39,0.48,0.58))
	var layout := HeroUI.layout(root)
	var titles := {"association":"협회","offline":"오프라인 보상","supply":"보급 상자"}
	HeroUI.header(layout,titles[screen],func(): go.call("lobby"))
	match screen:
		"association": _association(layout,act)
		"offline": _offline(layout,act)
		"supply": _supply(layout,act)
	return root

static func _image_header(root: Control, title_text: String, subtitle: String, back: Callable) -> void:
	HeroImageSkin.button(root,"‹ 이전",Rect2(22,14,90,44),back,"plain",15)
	HeroImageSkin.text(root,title_text,Rect2(127,12,680,41),"brand",28)
	HeroImageSkin.text(root,subtitle,Rect2(128,54,739,28),"body",14,"muted")
	HeroImageSkin.material(root,"accents/rule_h",Rect2(22,84,871,2))

static func _image_backdrop(root: Control, image_id: String) -> void:
	HeroUI.background(root,image_id)
	var wash := ColorRect.new()
	wash.color = Color(0.91,0.94,0.95,0.94)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)

static func _growth_screen(view: Dictionary, go: Callable, act: Callable) -> Control:
	var root := HeroImageSkin.root()
	_image_backdrop(root,"metaGrowthLab")
	_image_header(root,"전략지원 · 영구 성장","보유 조각으로 성장 · 출동 축복 선택과 별도",func(): go.call("lobby"))
	var tab_index := 0
	for entry in [["character","각성자"],["weapon","공용 무기"],["blessing","단군의 축복"]]:
		HeroImageSkin.image_button(root,entry[1],Rect2(24+tab_index*170,93,162,44),func(): act.call("growthTab",entry[0]),"controls/selected" if view.kind == entry[0] else "controls/secondary",15)
		tab_index += 1
	var source: Dictionary = Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[view.kind]]
	if not source.has(view.id): view.id = source.keys()[0]
	var collection: Dictionary = Profile.meta[{"character":"characters","weapon":"sharedWeapons","blessing":"blessings"}[view.kind]]
	var list := HeroImageSkin.scroll(root,Rect2(24,149,254,249),view,"scroll_"+str(view.kind))
	list.name = "GrowthCollection"
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",8)
	list.add_child(rows)
	for id in source:
		var definition: Dictionary = source[id]
		var record: Dictionary = collection[id]
		var selected: bool = id == view.id
		var row := HeroImageSkin.image_button(rows,"",Rect2(0,0,238,56),func(): act.call("growthSelect",id),"growth/selected" if selected else "cards/normal",14)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art := HeroUI.image(row,_growth_texture(str(view.kind),str(id),definition),0,0)
		HeroUI.place(art,Rect2(9,7,40,41))
		HeroImageSkin.text(row,definition.name,Rect2(58,6,169,44),"control",14,"accent" if selected else "ink",HORIZONTAL_ALIGNMENT_LEFT,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
		if not record.unlocked: row.modulate = Color(0.9,0.93,0.94)
	var selected: Dictionary = source[view.id]
	var progress: Dictionary = collection[view.id]
	var level: int = int(progress.get("breakthrough",0)) if view.kind == "character" else int(progress.level)
	var max_level: int = int(Content.data.growth.maxLevel)
	var costs: Array = Content.data.growth[{"character":"characterCosts","weapon":"weaponCosts","blessing":"blessingCosts"}[view.kind]]
	var cost: int = int(costs[level]) if level < max_level else 0
	HeroImageSkin.material(root,"growth/panel",Rect2(301,143,590,262))
	HeroImageSkin.text(root,selected.name,Rect2(325,153,540,41),"heading",22,"ink",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var art := HeroUI.image(root,_growth_texture(str(view.kind),str(view.id),selected),0,0)
	HeroUI.place(art,Rect2(320,198,145,139))
	HeroImageSkin.text(root,"%s · %d / %d 단계" % ["해금" if progress.unlocked else "미해금",level,max_level],Rect2(315,345,154,30),"body",14,"accent" if progress.unlocked else "muted",HORIZONTAL_ALIGNMENT_CENTER,true,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var notes_scroll := HeroImageSkin.scroll(root,Rect2(494,199,372,99))
	var notes := VBoxContainer.new()
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.add_theme_constant_override("separation",8)
	notes_scroll.add_child(notes)
	_native_copy(notes,selected.description,14,"muted")
	if view.kind == "blessing":
		_native_copy(notes,"현재 효과" if level > 0 else "단계당 효과",14,"accent")
		for modifier in selected.modifiers:
			_native_copy(notes,_growth_modifier(modifier,maxi(1,level)),14,"ink")
		if selected.has("structureLimitAtLevel"):
			_native_copy(notes,"%d단계부터 설치물 한도 +1" % int(selected.structureLimitAtLevel),14,"ink")
	else:
		_native_copy(notes,"성장 효과 연결 예정",14,"muted")
	HeroImageSkin.text(root,"보유 조각",Rect2(494,299,151,25),"body",14,"muted")
	HeroImageSkin.text(root,str(int(progress.fragments)),Rect2(674,296,190,29),"number",22,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(max_level):
		var stage_rect := Rect2(494+i*75,330,65,22)
		HeroImageSkin.material(root,"growth/selected" if i < level else "growth/stage",stage_rect)
		HeroImageSkin.text(root,str(i+1),stage_rect,"number",15,"accent" if i < level else "muted",HORIZONTAL_ALIGNMENT_CENTER)
	var can_grow: bool = level < max_level and int(progress.fragments) >= cost and (view.kind == "blessing" or progress.unlocked)
	var caption := "최대 성장 완료" if level >= max_level else "성장 · %d 조각" % cost if progress.unlocked else "해금 · %d 조각" % cost
	var buy := HeroImageSkin.image_button(root,caption,Rect2(494,356,372,44),func(): act.call("grow",view.id),"controls/primary" if can_grow else "controls/disabled",16)
	buy.name = "GrowthAction"
	buy.disabled = not can_grow
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

static func _association(layout: VBoxContainer, act: Callable) -> void:
	var body := HeroUI.row(layout); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	HeroUI.image(body,Content.trimmed_texture("lobbyAssociation"),210,220)
	var scroll := HeroUI.scroll(body)
	var grid := GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	for id in Content.data.upgrades:
		var definition: Dictionary = Content.data.upgrades[id]
		var card := HeroUI.column(HeroUI.panel(grid,"document"))
		_heading(card,definition.name,17)
		HeroUI.paragraph(card,definition.description,14)
		var cost := HeroMeta.association_cost(Content.data,Profile.meta,id)
		var button := HeroUI.button(card,"완료" if cost < 0 else "%d 코인" % cost,func(): act.call("associationBuy",id),150)
		button.disabled = cost < 0 or Profile.meta.wallet.associationCoins < cost

static func _offline(layout: VBoxContainer, act: Callable) -> void:
	var body := HeroUI.row(layout); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art := HeroUI.image(body,Content.trimmed_texture("lobbyRecoveryUnit"),420,235)
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := HeroUI.panel(body,"reward"); panel.custom_minimum_size.x = 330; panel.size_flags_horizontal = Control.SIZE_FILL
	var info := HeroUI.column(panel)
	info.add_theme_constant_override("separation",6)
	_heading(info,"회수품 정산",22)
	var pending: Dictionary = Profile.meta.offlineReward.pendingRewards
	var row := HeroUI.row(info)
	HeroUI.image(row,Content.trimmed_texture("associationCoin"),48,48)
	var amount := HeroUI.label(row,HeroUI.amount(int(pending.associationCoins)),26,HeroUI.ink(info,"reward")); amount.name = "OfflineCoins"
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var counts: Array = []
	for grade in Content.data.revivalStones:
		var line := HeroUI.row(info)
		HeroUI.image(line,Content.trimmed_texture(Content.data.revivalStones[grade].image),30,30)
		var name_label := HeroUI.label(line,Content.data.revivalStones[grade].name,14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var count := HeroUI.label(line,str(int(pending.revivalStones[grade])),16)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.custom_minimum_size.x = 44
		counts.append(count)
	HeroUI.spacer(info)
	var claim := HeroUI.button(info,"모두 수령",func(): act.call("claimOffline",""),230,true)
	claim.pressed.connect(func():
		amount.text = "0"
		for count in counts: count.text = "0"
		claim.text = "정산 완료"; claim.disabled = true
	)
	claim.disabled = pending.associationCoins <= 0 and pending.revivalStones.values().all(func(value): return value <= 0)
	if Profile.meta.settings.developerMode:
		var tools := HeroUI.row(layout)
		HeroUI.button(tools,"오프라인 +1시간",func(): act.call("offlineAdvance",3600),150)
		HeroUI.button(tools,"+24시간",func(): act.call("offlineAdvance",86400),140)

static func _supply(layout: VBoxContainer, act: Callable) -> void:
	var body := HeroUI.row(layout); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chest := HeroUI.image(body,Content.trimmed_texture("lobbySupplyVault"),450,230)
	chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := HeroUI.panel(body,"reward")
	panel.custom_minimum_size.x = 330
	panel.size_flags_horizontal = Control.SIZE_FILL
	var info := HeroUI.column(panel)
	_heading(info,"협회 보급 상자",22)
	var row := HeroUI.row(info)
	HeroUI.image(row,Content.trimmed_texture("supplyTicket"),50,50)
	var amount := HeroUI.label(row,HeroUI.amount(int(Profile.meta.wallet.supplyTickets)),26,HeroUI.ink(info,"reward"))
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HeroUI.spacer(info)
	HeroUI.button(info,"1회 개봉",func(): act.call("supplyOpen",1),230).disabled = Profile.meta.wallet.supplyTickets < 1
	HeroUI.button(info,"10회 개봉",func(): act.call("supplyOpen",10),230).disabled = Profile.meta.wallet.supplyTickets < 10
	if Profile.meta.settings.developerMode: HeroUI.button(info,"보급권 +10",func(): act.call("devTickets",10),150)

static func _settings_screen(go: Callable, act: Callable) -> Control:
	var root := HeroImageSkin.root()
	_image_backdrop(root,"metaAssociationOffice")
	_image_header(root,"설정","음향 · 저장 데이터 · 화면 샘플",func(): go.call("lobby"))
	var audio_heading := HeroImageSkin.material(root,"console/title",Rect2(24,99,499,44))
	HeroImageSkin.text(audio_heading,"음향",HeroImageSkin.content_rect(audio_heading,"console/title"),"heading",20,"ink",HORIZONTAL_ALIGNMENT_CENTER,false,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var data_heading := HeroImageSkin.material(root,"console/title",Rect2(559,99,333,44))
	HeroImageSkin.text(data_heading,"데이터",HeroImageSkin.content_rect(data_heading,"console/title"),"heading",20,"ink",HORIZONTAL_ALIGNMENT_CENTER,false,{"valign":VERTICAL_ALIGNMENT_CENTER})
	var pairs := [["masterVolume","전체 음량"],["musicVolume","배경음악"],["combatVolume","전투 효과음"],["uiVolume","UI 효과음"]]
	for i in range(pairs.size()):
		var pair: Array = pairs[i]
		var y: float = 157+i*50
		HeroImageSkin.text(root,pair[1],Rect2(36,y,129,44),"control",14)
		var slider := HSlider.new()
		slider.name = "Volume_"+str(pair[0])
		slider.min_value = 0; slider.max_value = 100; slider.step = 1
		slider.value = float(Profile.meta.settings[pair[0]])*100.0
		slider.custom_minimum_size = Vector2(1100,176)
		slider.scale = Vector2.ONE/4.0
		slider.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		slider.mouse_filter = Control.MOUSE_FILTER_STOP
		slider.add_to_group("input_blocker")
		slider.add_theme_stylebox_override("slider",HeroImageSkin.style("bars/track",Vector4(0,4,0,4),4))
		slider.add_theme_stylebox_override("grabber_area",HeroImageSkin.style("bars/fill",Vector4(0,4,0,4),4))
		slider.add_theme_stylebox_override("grabber_area_highlight",HeroImageSkin.style("bars/fill",Vector4(0,4,0,4),4))
		slider.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
		slider.add_theme_icon_override("grabber",HeroImageSkin.texture("bars/thumb",4))
		slider.add_theme_icon_override("grabber_highlight",HeroImageSkin.texture("bars/thumb_active",4))
		slider.add_theme_icon_override("grabber_disabled",HeroImageSkin.texture("bars/thumb",4))
		slider.add_theme_constant_override("center_grabber",1)
		root.add_child(slider)
		HeroUI.place(slider,Rect2(175,y,1100,176))
		var number := HeroImageSkin.text(root,str(int(roundf(slider.value))),Rect2(462,y,48,44),"number",23,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
		slider.value_changed.connect(func(value): number.text = str(int(roundf(value))); act.call("volume",{"key":pair[0],"value":value/100.0}))
	HeroImageSkin.text(root,"음량 변경은 즉시 반영됩니다",Rect2(36,365,475,25),"body",14,"muted")
	# Native callbacks preserve immediate audio, backup, import and sample routes.
	HeroImageSkin.image_button(root,"저장 폴더",Rect2(575,158,300,44),func(): OS.shell_open(ProjectSettings.globalize_path("user://")),"controls/secondary",16)
	HeroImageSkin.image_button(root,"JSON 백업",Rect2(575,212,144,44),func(): act.call("backup",""),"controls/secondary",15)
	HeroImageSkin.image_button(root,"백업 가져오기",Rect2(729,212,146,44),func(): act.call("import",""),"controls/secondary",15)
	HeroImageSkin.image_button(root,"개발자 모드 · 켜짐" if Profile.meta.settings.developerMode else "개발자 모드 · 꺼짐",Rect2(575,266,300,44),func(): act.call("developer",not Profile.meta.settings.developerMode),"controls/selected" if Profile.meta.settings.developerMode else "controls/secondary",15)
	HeroImageSkin.image_button(root,"SD 캐릭터 샘플",Rect2(575,321,144,58),func(): act.call("sd-sample",""),"controls/secondary",14)
	HeroImageSkin.image_button(root,"전체 캐릭터·몬스터 모션",Rect2(729,321,146,58),func(): act.call("graphics",""),"controls/secondary",14)
	HeroImageSkin.text(root,"Seoul Hero · 915×412",Rect2(578,385,293,22),"body",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	return root

static func rewards_popup(root: Control, rewards: Array) -> void:
	var box := HeroCombatUI.popup(root,"보급 결과",740,335)
	var scroll := HeroUI.scroll(box)
	var grid := GridContainer.new(); grid.columns = 5; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(grid)
	var grouped := {}
	for reward in rewards:
		var key: String = reward.type + ":" + reward.contentId
		if not grouped.has(key): grouped[key] = reward.duplicate()
		else: grouped[key].amount += reward.amount
	for reward in grouped.values():
		var display := reward_display(reward)
		var card := HeroUI.column(grid)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		HeroUI.image(card,display.texture, 90,76)
		var reward_name := _heading(card,display.name,14)
		reward_name.custom_minimum_size.y = HeroUI.lines_height(card,14,3)
		reward_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_heading(card,"×%d" % int(reward.amount),18)
	HeroUI.button(box,"확인",func(): box.get_meta("overlay").queue_free(),160)

static func _heading(parent: Node, text: String, font_size: int) -> Label:
	var heading := HeroUI.paragraph(parent,text,font_size)
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
		"associationCoin": return {"name":"협회 코인","texture":Content.trimmed_texture("associationCoin")}
		"supplyTicket": return {"name":"보급권","texture":Content.trimmed_texture("supplyTicket")}
		"revivalStone": return {"name":Content.data.revivalStones[reward.contentId].name,"texture":Content.trimmed_texture(Content.data.revivalStones[reward.contentId].image)}
		"weaponFragment": return {"name":Content.data.weapons[reward.contentId].name + " 조각","texture":Content.weapon_icon(reward.contentId)}
		"characterFragment": return {"name":Content.data.characters[reward.contentId].name + " 조각","texture":Content.actor_preview("characters",reward.contentId,Content.data.characters[reward.contentId].portraitSprite)}
		_: return {"name":Content.data.blessings[reward.contentId].name + " 조각","texture":Content.trimmed_texture(Content.data.blessings[reward.contentId].image)}
