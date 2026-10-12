class_name HeroCombatUI
extends RefCounted

const PAUSE_ART := "res://assets/ui/pause-glass-01/"

static func hud(run: HeroRun, pause: Callable) -> Control:
	var root := HeroImageSkin.root()
	# Plate-free HUD: thick health bar, stone and wallet on its right, weapons below.
	var bar := ProgressBar.new(); bar.name = "HealthBar"; bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",HeroImageSkin.style("enamel/hp_track",Vector4.ZERO,4))
	bar.add_theme_stylebox_override("fill",HeroImageSkin.style("enamel/hp_fill",Vector4.ZERO,4))
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(bar); HeroUI.place(bar,Rect2(16,10,800,88))
	bar.scale = Vector2(0.25,0.25)
	var hp := _hud_text(root,"",Rect2(16,10,200,22),"number",16,HORIZONTAL_ALIGNMENT_CENTER)
	hp.name = "Health"
	var stone := HeroUI.fixed_art(root,Content.trimmed_texture("magicStone"),Rect2(226,13,16,16))
	stone.name = "StoneIcon"
	var money := _hud_text(root,"0",Rect2(246,8,52,26),"number",18)
	money.name = "Currency"
	var icon := HeroUI.fixed_art(root,Content.trimmed_texture("wallet"),Rect2(297,8,26,26))
	icon.name = "WalletIcon"; icon.modulate = Color(0.90,0.98,1.0)
	var wallet := _hud_text(root,"0",Rect2(328,8,52,26),"number",18)
	wallet.name = "Wallet"
	var weapons := Control.new(); weapons.name = "HudWeapons"; weapons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(weapons); HeroUI.place(weapons,Rect2(16,38,162,32))
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
	HeroEliteHud.build(root,run)
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
		hp.add_theme_color_override("font_color",Color.WHITE)
	var bar := root.find_child("HealthBar",true,false) as ProgressBar
	if bar:
		bar.max_value = run.stats.maxHp; bar.value = run.player.hp
		if bool(bar.get_meta("low_hp",false)) != low_hp:
			bar.set_meta("low_hp",low_hp)
			bar.add_theme_stylebox_override("fill",HeroImageSkin.style("enamel/hp_low" if low_hp else "enamel/hp_fill",Vector4.ZERO,4))
	var currency := root.find_child("Currency",true,false) as Label
	if currency:
		currency.text = HeroUI.amount(floori(run.currency))
		_stone_punch(root,currency,floori(run.currency))
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
	HeroEliteHud.update(root,run)

# A collected stone briefly pops the HUD stone icon and warms its number to gold.
static func _stone_punch(root: Control, currency: Label, amount: int) -> void:
	var previous := int(root.get_meta("stone_amount",amount))
	root.set_meta("stone_amount",amount)
	if amount <= previous or not root.is_inside_tree(): return
	var icon := root.find_child("StoneIcon",true,false) as Control
	if root.has_meta("stone_tween"):
		var running: Tween = root.get_meta("stone_tween")
		if running and running.is_valid(): running.kill()
	var tween := root.create_tween().set_parallel(true)
	if icon:
		icon.pivot_offset = icon.size*0.5
		icon.scale = Vector2.ONE*1.32
		tween.tween_property(icon,"scale",Vector2.ONE,0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	currency.modulate = Color("ffe08a")
	tween.tween_property(currency,"modulate",Color.WHITE,0.28)
	root.set_meta("stone_tween",tween)

static func shop(run: HeroRun, tab: bool, set_tab: Callable, refresh: Callable, advance: Callable, pause: Callable) -> Control:
	return HeroShopScreen.build(run,tab,set_tab,refresh,advance,pause)

static func popup(root: Control, title: String, width: float = 440, height: float = 245) -> VBoxContainer:
	width = minf(width,883); height = minf(height,380)
	var blocker := ColorRect.new()
	blocker.color = Color(0.02,0.03,0.05,0.55)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.add_to_group("input_blocker"); root.add_child(blocker)
	var panel := HeroImageSkin.material(blocker,"ops/popup",Rect2((915-width)/2,(412-height)/2,width,height))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HeroUI.inset(panel,Vector2(20,12))
	box.set_meta("overlay",blocker)
	var heading := HeroUI.text_block(box,title,HeroUI.lines_height(box,18,2),18,HeroImageSkin.color("ink"),true,{"align":HORIZONTAL_ALIGNMENT_CENTER,"valign":VERTICAL_ALIGNMENT_CENTER,"lines":2,"font_role":"heading"})
	HeroImageSkin.apply_font(heading,"heading",18)
	return box

static func details_popup(root: Control, description: String, title: String) -> void:
	var box := popup(root,title,560,342)
	var scroll := HeroUI.scroll(box)
	var content := HeroUI.column(scroll); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HeroUI.paragraph(content,description,14)
	var close := HeroImageSkin.image_button(box,"닫기",Rect2(0,0,120,44),func(): box.get_meta("overlay").queue_free(),"ops/secondary",16)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

static func pause_menu(run: HeroRun, resume: Callable, quit: Callable) -> Control:
	var root := HeroImageSkin.root()
	root.name = "PauseMenu"
	var blocker := ColorRect.new(); blocker.color = Color(15.0/255,25.0/255,42.0/255,0.48)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP; blocker.add_to_group("input_blocker")
	root.add_child(blocker); blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Control.new(); panel.name = "PausePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.add_child(panel); HeroUI.place(panel,Rect2(252,52,410,308))
	HeroDesk.art(panel,PAUSE_ART+"pause-panel.png",Rect2(0,0,410,308))
	HeroDesk.text(panel,"일시정지",Rect2(30,24,230,34),"brand",26,"#243448")
	HeroDesk.text(panel,"PAUSED",Rect2(307,32,73,20),"tag",16,"#c64f5f",HORIZONTAL_ALIGNMENT_RIGHT)
	HeroDesk.nine(panel,HeroDesk.UNIFIED+"glass_row.png",Rect2(28,74,354,66),Vector4(24,24,24,24),0.25)
	HeroDesk.text(panel,str(run.map.name),Rect2(46,87,200,22),"heading",16,"#243448")
	HeroDesk.text(panel,"%d층" % run.setup.depth,Rect2(46,110,200,18),"body",14,"#657787")
	HeroDesk.text(panel,"%d / %d" % [run.wave,int(run.map.totalWaves)],Rect2(266,80,98,32),"number",26,"#243448",HORIZONTAL_ALIGNMENT_RIGHT)
	HeroDesk.text(panel,"웨이브",Rect2(266,113,98,17),"body",12,"#657787",HORIZONTAL_ALIGNMENT_RIGHT)
	_pause_button(panel,"계속하기",Rect2(28,160,354,48),resume,PAUSE_ART+"continue-button.png",Color.WHITE).name = "PauseResume"
	_pause_button(panel,"출동 종료",Rect2(28,217,354,44),quit,HeroDesk.UNIFIED+"glass_button.png",Color("c64f5f")).name = "PauseExit"
	return root

static func _pause_button(parent: Node, caption: String, rect: Rect2, action: Callable, path: String, ink: Color) -> Button:
	var key := HeroImageSkin.image_button(parent,caption,rect,action,"plain",16)
	key.add_theme_font_override("font",HeroDesk.font("control"))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		key.add_theme_color_override(state,ink)
	var surface := HeroDesk.nine(key,path,Rect2(Vector2.ZERO,rect.size),Vector4(72,20,72,20),0.25)
	surface.show_behind_parent = true
	key.draw.connect(func():
		surface.self_modulate = Color(0.92,0.92,0.92) if key.is_pressed() else Color(1.04,1.04,1.04) if key.is_hovered() or key.has_focus() else Color.WHITE
	)
	return key

static func revival(run: HeroRun, revive: Callable, die: Callable) -> Control:
	var root := HeroImageSkin.root()
	var box := popup(root,"생환석",630,300)
	var choices := HeroUI.row(box)
	for grade in Content.data.revivalStones:
		var stone: Dictionary = Content.data.revivalStones[grade]
		var count: int = Profile.meta.wallet.revivalStones[grade]
		var choice := HeroUI.choice(choices,"%s · %d\n%d%% 회복" % [stone.name,count,roundi(stone.healthFraction * 100)],Content.trimmed_texture(stone.image),false,func(): revive.call(grade),"ceramic",145)
		choice.disabled = count <= 0
	HeroUI.danger(HeroImageSkin.image_button(box,"생환 포기",Rect2(0,0,140,44),die,"ops/secondary",16)).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return root

static func result(run: HeroRun, back: Callable) -> Control:
	var root := HeroImageSkin.root()
	HeroUI.background(root,"titleGate",Color(0.45,0.5,0.6))
	HeroImageSkin.header(root,"작전 결과",back,[{"image_id":"associationCoin","name":"협회 코인","amount":HeroUI.amount(int(Profile.meta.wallet.associationCoins))}],{"back_caption":"로비로"})
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation",12)
	root.add_child(body); HeroUI.place(body,Rect2(16,76,883,324))
	var result_box := HeroUI.column(HeroUI.panel(body,"document"))
	HeroUI.label(result_box,"게이트 안정화" if run.phase == "stageClear" else "교전 종료",18,HeroImageSkin.color("ink"),"heading").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := HeroUI.column(HeroUI.scroll(result_box)); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HeroUI.paragraph(box,"%s · %d층 · 웨이브 %d" % [run.map.name,run.setup.depth,run.wave],14)
	HeroUI.paragraph(box,"처치 %d   전투 %02d:%02d" % [run.kills,int(run.combat_time)/60,int(run.combat_time)%60],16)
	var last: Dictionary = Profile.meta.statistics.get("lastRun",{})
	if last.get("runId","") == run.run_id:
		HeroUI.paragraph(box,"완료한 웨이브 %d / %d" % [int(last.get("completedWaves",0)),run.map.waveDefinitions.size()],14)
		var guild_rewards: Dictionary = last.get("guildRewards",{})
		for key in HeroGuildState.RESOURCES:
			if int(guild_rewards.get(key,0)) > 0: HeroUI.paragraph(box,"%s +%d" % [Content.data.resources[key].name,int(guild_rewards[key])],14)
	var contributions: Array = run.telemetry.weapons.keys()
	contributions.sort_custom(func(a,b): return run.telemetry.weapons[a].damage > run.telemetry.weapons[b].damage)
	for id in contributions.slice(0,3):
		var line := HeroUI.row(box)
		HeroUI.paragraph(line,run.data.weapons[id].name,14)
		HeroUI.label(line,"%d 피해" % roundi(run.telemetry.weapons[id].damage),18,HeroImageSkin.color("ink"),"number").horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	HeroImageSkin.image_button(result_box,"로비로",Rect2(0,0,150,44),back,"ops/primary",16).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var reward := HeroUI.column(HeroUI.panel(body,"reward"))
	HeroUI.image(reward,Content.trimmed_texture("associationCoin"),112,112).name = "ResultRewardArt"
	HeroUI.label(reward,"협회 코인 +%d" % run.reward,18,HeroImageSkin.color("reward"),"number").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stones: Array[String] = []
	for grade in ["high","mid","low"]:
		var count := int(run.loot.get("revivalStones",{}).get(grade,0))
		if count > 0: stones.append("%s +%d" % [Content.data.revivalStones[grade].name,count])
	if not stones.is_empty(): HeroUI.label(reward," · ".join(stones),16,HeroImageSkin.color("reward"),"number").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if run.reward_tickets > 0: HeroUI.label(reward,"보급권 +%d" % run.reward_tickets,16,HeroImageSkin.color("reward"),"number").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root
