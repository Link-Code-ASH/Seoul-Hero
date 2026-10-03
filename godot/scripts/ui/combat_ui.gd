class_name HeroCombatUI
extends RefCounted

static func hud(run: HeroRun, pause: Callable) -> Control:
	var root := HeroImageSkin.root()
	var hp := _hud_text(root,"",Rect2(20,6,82,28),"number",24)
	hp.name = "Health"
	var stone := HeroUI.fixed_art(root,Content.trimmed_texture("magicStone"),Rect2(104,14,12,12))
	stone.name = "StoneIcon"
	var money := _hud_text(root,"0",Rect2(120,8,32,24),"number",13)
	money.name = "Currency"; money.add_theme_constant_override("outline_size",1)
	var icon := HeroUI.fixed_art(root,Content.trimmed_texture("wallet"),Rect2(157,14,12,12))
	icon.name = "WalletIcon"; icon.modulate = Color(0.90,0.98,1.0)
	var wallet := _hud_text(root,"0",Rect2(173,8,27,24),"number",13)
	wallet.name = "Wallet"; wallet.add_theme_constant_override("outline_size",1)
	var bar := ProgressBar.new(); bar.name = "HealthBar"; bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",HeroImageSkin.style("enamel/hp_track",Vector4.ZERO,4))
	bar.add_theme_stylebox_override("fill",HeroImageSkin.style("enamel/hp_fill",Vector4.ZERO,4))
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(bar); HeroUI.place(bar,Rect2(20,37,720,40))
	bar.scale = Vector2(0.25,0.25)
	var weapons := Control.new(); weapons.name = "HudWeapons"; weapons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapons); HeroUI.place(weapons,Rect2(20,60,162,32))
	_sync_weapons(weapons,run)
	var wave := _hud_text(root,"",Rect2(365,8,185,26),"control",15,HORIZONTAL_ALIGNMENT_CENTER)
	wave.name = "Wave"
	var timer := _hud_text(root,"",Rect2(400,33,115,34),"number",27,HORIZONTAL_ALIGNMENT_CENTER)
	timer.name = "Timer"
	var pause_button := HeroImageSkin.button(root,"",Rect2(850,7,44,44),pause,"plain")
	pause_button.name = "PauseButton"
	HeroImageSkin.material(pause_button,"enamel/pause_icon",Rect2(12,10,20,24))
	if run.phase == "postWave":
		var notice := _hud_text(root,"웨이브 종료",Rect2(347,86,220,40),"heading",24,HORIZONTAL_ALIGNMENT_CENTER)
		notice.name = "WaveNotice"
	update_hud(root,run)
	return root

static func _hud_text(parent: Node, caption: String, rect: Rect2, role: String, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := HeroImageSkin.text(parent,caption,rect,role,font_size,"scene",align)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_outline_color",Color(0.05,0.10,0.16,0.85))
	label.add_theme_constant_override("outline_size",2)
	label.add_theme_color_override("font_shadow_color",Color(0.03,0.06,0.10,0.60))
	label.add_theme_constant_override("shadow_offset_x",0)
	label.add_theme_constant_override("shadow_offset_y",1)
	return label

static func _sync_weapons(weapons: Control, run: HeroRun) -> void:
	var signature: String = ":".join(run.owned.slice(0,6).map(func(slot): return str(slot.id)))
	if str(weapons.get_meta("weapon_ids","")) != signature:
		for child in weapons.get_children(): child.free()
		weapons.set_meta("weapon_ids",signature)
		for i in range(mini(6,run.owned.size())):
			var slot: Dictionary = run.owned[i]
			HeroUI.fixed_art(weapons,Content.weapon_icon(slot.id),Rect2(i*27,2,25,25))
			var level := _hud_text(weapons,"",Rect2(i*27+12,10,13,20),"number",14,HORIZONTAL_ALIGNMENT_RIGHT)
			level.name = "WeaponLevel%d" % i
			level.add_theme_constant_override("outline_size",1)
	for i in range(mini(6,run.owned.size())):
		var level := weapons.get_node_or_null("WeaponLevel%d" % i) as Label
		if level: level.text = str(int(run.owned[i].level))

static func update_hud(root: Control, run: HeroRun) -> void:
	var low_hp: bool = run.player.hp < run.stats.maxHp*0.25
	var hp := root.find_child("Health",true,false) as Label
	if hp:
		hp.text = "%d / %d" % [ceili(run.player.hp),roundi(run.stats.maxHp)]
		hp.add_theme_color_override("font_color",Color("ff8994") if low_hp else Color.WHITE)
	var bar := root.find_child("HealthBar",true,false) as ProgressBar
	if bar:
		bar.max_value = run.stats.maxHp; bar.value = run.player.hp
		bar.self_modulate = Color("f19b90") if low_hp else Color.WHITE
	var currency := root.find_child("Currency",true,false) as Label
	if currency: currency.text = HeroUI.amount(floori(run.currency))
	var wallet := root.find_child("Wallet",true,false) as Label
	if wallet: wallet.text = HeroUI.amount(ceili(run.wallet))
	var wave := root.find_child("Wave",true,false) as Label
	if wave: wave.text = "웨이브 %d / %d" % [run.wave,int(run.map.totalWaves)]
	var timer := root.find_child("Timer",true,false) as Label
	if timer:
		var remaining := ceili(maxf(0.0,run.wave_data().duration - run.elapsed))
		timer.text = "%02d:%02d" % [remaining / 60,remaining % 60]
		var urgent := remaining <= 5 and run.wave != int(run.map.bossWave)
		timer.add_theme_color_override("font_color",Color("ff8994") if urgent else Color.WHITE)
	var weapons := root.find_child("HudWeapons",true,false) as Control
	if weapons: _sync_weapons(weapons,run)
	var notice := root.find_child("WaveNotice",true,false) as Label
	if notice: notice.modulate.a = 0.7 + sin(run.post_elapsed * 18.0) * 0.3

static func shop(run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, advance: Callable, pause: Callable) -> Control:
	return HeroShopScreen.build(run,tab,set_tab,refresh,advance,pause)

static func popup(root: Control, title: String, width: float = 440, height: float = 245) -> VBoxContainer:
	width = minf(width,883); height = minf(height,380)
	var blocker := ColorRect.new()
	blocker.color = Color(0.02,0.03,0.05,0.55)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.add_to_group("input_blocker"); root.add_child(blocker)
	var panel := HeroUI.sheet(blocker,"glass",Rect2((915-width)/2,(412-height)/2,width,height))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HeroUI.inset(panel)
	box.set_meta("overlay",blocker)
	HeroUI.text_block(box,title,HeroUI.lines_height(box,21,2),21,HeroUI.ink(box),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2})
	return box

static func details_popup(root: Control, description: String, title: String) -> void:
	var box := popup(root,title,560,342)
	var scroll := HeroUI.scroll(box)
	var content := HeroUI.column(scroll); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HeroUI.paragraph(content,description,14)
	var close := HeroUI.button(box,"닫기",func(): box.get_meta("overlay").queue_free(),120)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

static func pause_menu(run: HeroRun, resume: Callable, quit: Callable) -> Control:
	var root := HeroImageSkin.root()
	var blocker := ColorRect.new(); blocker.color = Color(0.04,0.08,0.13,0.42)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP; blocker.add_to_group("input_blocker")
	root.add_child(blocker); blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := HeroImageSkin.material(root,"command/panel",Rect2(294,81,327,250))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	HeroImageSkin.material(panel,"command/title",Rect2(23,20,281,43))
	HeroImageSkin.text(panel,"일시정지",Rect2(34,28,259,34),"heading",24,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	HeroImageSkin.text(panel,"%s · 심도 %d" % [run.map.name,run.setup.depth],Rect2(23,78,281,27),"body",14,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	HeroImageSkin.text(panel,"%d / %d 웨이브" % [run.wave,int(run.map.totalWaves)],Rect2(23,109,281,27),"control",16,"ink",HORIZONTAL_ALIGNMENT_CENTER)
	HeroImageSkin.image_button(panel,"계속하기",Rect2(31,145,265,44),resume,"controls/primary",17)
	var exit_button := HeroImageSkin.image_button(panel,"출동 종료",Rect2(31,193,265,44),quit,"controls/secondary",16)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		exit_button.add_theme_color_override(state,HeroImageSkin.color("danger"))
	return root

static func revival(run: HeroRun, revive: Callable, die: Callable) -> Control:
	var root := HeroUI.root()
	var box := popup(root,"생환석",630,300)
	var choices := HeroUI.row(box)
	for grade in Content.data.revivalStones:
		var stone: Dictionary = Content.data.revivalStones[grade]
		var count: int = Profile.meta.wallet.revivalStones[grade]
		var choice := HeroUI.choice(choices,"%s · %d\n%d%% 회복" % [stone.name,count,roundi(stone.healthFraction * 100)],Content.trimmed_texture(stone.image),false,func(): revive.call(grade),"ceramic",145)
		choice.disabled = count <= 0
	HeroUI.danger(HeroUI.button(box,"생환 포기",die,140)).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return root

static func result(run: HeroRun, back: Callable) -> Control:
	var root := HeroUI.root()
	HeroUI.background(root,"titleGate",Color(0.45,0.5,0.6))
	var layout := HeroUI.layout(root)
	HeroUI.header(layout,"작전 결과",back)
	var body := HeroUI.row(layout); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var result_box := HeroUI.column(HeroUI.panel(body,"document"))
	HeroUI.label(result_box,"게이트 안정화" if run.phase == "stageClear" else "교전 종료",22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := HeroUI.column(HeroUI.scroll(result_box)); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HeroUI.paragraph(box,"%s · 심도 %d · 웨이브 %d" % [run.map.name,run.setup.depth,run.wave],14)
	HeroUI.paragraph(box,"처치 %d   전투 %02d:%02d" % [run.kills,int(run.combat_time)/60,int(run.combat_time)%60],16)
	var contributions: Array = run.telemetry.weapons.keys()
	contributions.sort_custom(func(a,b): return run.telemetry.weapons[a].damage > run.telemetry.weapons[b].damage)
	for id in contributions.slice(0,3):
		var line := HeroUI.row(box)
		HeroUI.paragraph(line,run.data.weapons[id].name,14)
		HeroUI.label(line,"%d 피해" % roundi(run.telemetry.weapons[id].damage),14).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	HeroUI.button(result_box,"이전",back,150).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var reward := HeroUI.column(HeroUI.panel(body,"reward"))
	HeroUI.image(reward,Content.trimmed_texture("associationCoin"),112,112)
	HeroUI.paragraph(reward,"협회 코인 +%d" % run.reward,20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root
