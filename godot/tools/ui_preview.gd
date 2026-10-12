extends Node

# Static native UI fixtures only. Never instantiate combat/main or write saves.
var _issues: Array = []
var _captures: Array = []
var _text_boxes: Array = []

func _ready() -> void:
	_preview.call_deferred()

func _run() -> HeroRun:
	var draft := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	var run := HeroRun.new(Content.data.duplicate(true),draft,Profile.meta)
	run.phase = "shop"; run.currency = 300; run.wave = 12
	HeroShop.refresh(run,true); HeroShop.refresh(run,false)
	return run

func _archive(group: String, id: String, page: int, noop: Callable) -> Control:
	return HeroArchive.build({"group":group,"id":id,"page":page,"growthPage":0,"map":"seoul","scroll":0},noop,noop)

func _guild(nearest: String, noop: Callable) -> Control:
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/guild.json"))
	var images := {"rooms":Content.texture(visuals.rooms.file),"states":Content.texture(visuals.states.file),"facilityOrder":visuals.rooms.facility_order,"tiers":visuals.rooms.tiers,"structure":Content.texture(visuals.walk.file),"structureRegions":visuals.walk.regions}
	var slot := int(Profile.meta.guild.facilities.get(nearest,{}).get("slot",0))
	var ui := {"panel":"staff" if nearest=="roster" else "facility","slot":slot,"employee":"","expedition":"cityScout","selectedStaff":[],"panelOpen":not nearest.is_empty() and nearest!="gate","walk":{"x":240.0,"floor":0}}
	return HeroGuildWalkScreen.create(Profile.meta,noop,noop,noop,images,ui)

func _preview() -> void:
	await get_tree().process_frame
	if Profile.writable:
		push_error("UI preview requires --ui-preview (save writes blocked).")
		get_tree().quit(1); return
	Profile.meta = Profile.meta.duplicate(true)
	var root := get_tree().root
	var output := "res://exports/ui-preview"
	var filters := PackedStringArray()
	var stress := "--stress" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument.begins_with("--screen="): filters = argument.trim_prefix("--screen=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var draft := {"map":"seoul","depth":1,"character":"awakener","weapon":"manaBolt","blessing":"","weekly":Profile.meta.weeklyGate.ruleId}
	var noop := func(_value = null, _other = null): pass
	var run := _run()
	var screens := {
		"title":HeroMetaScreens.title(noop,noop,false),
		"title-resume":HeroMetaScreens.title(noop,noop,true),
		"lobby":HeroLobbyScreen.build(noop),
		"maps":HeroGateScreen.build(draft.duplicate(),0,noop,noop,noop),
		"depth":HeroGateScreen.build(draft.duplicate(),1,noop,noop,noop),
		"characters":HeroGateScreen.build(draft.duplicate(),2,noop,noop,noop),
		"weapons":HeroGateScreen.build(draft.duplicate(),3,noop,noop,noop),
		"confirm":HeroGateScreen.build(draft.duplicate(),5,noop,noop,noop),
		"growth":HeroMetaScreens.build("growth",{"kind":"character","id":"awakener"},noop,noop),
		"growth-weapon":HeroMetaScreens.build("growth",{"kind":"weapon","id":"manaSword"},noop,noop),
		"growth-blessing":HeroMetaScreens.build("growth",{"kind":"blessing","id":"harvestKnot"},noop,noop),
		"association":HeroMetaScreens.build("association",{},noop,noop),
		"offline":HeroMetaScreens.build("offline",{},noop,noop),
		"supply":HeroMetaScreens.build("supply",{},noop,noop),
		"settings":HeroMetaScreens.build("settings",{},noop,noop),
		"hud":HeroCombatUI.hud(run,noop),
		"shop":HeroCombatUI.shop(run,true,noop,noop,noop,noop),
		"shop-items":HeroCombatUI.shop(run,false,noop,noop,noop,noop),
		"pause":HeroCombatUI.pause_menu(run,noop,noop),
		"revival":HeroCombatUI.revival(run,noop,noop),
		"result":HeroCombatUI.result(run,noop),
	}
	var guild_views := {"guild":"","guild-gate":"gate","guild-roster":"roster"}
	for id in Content.data.guildFacilities: guild_views["guild-"+id] = id
	for id in guild_views:
		if filters.is_empty() or id in filters: screens[id] = _guild(guild_views[id],noop)
	var archive_ids := {"weapons":"manaSword","characters":"awakener","enemies":"gatekeeper","items":"phoenixMatch","weeklyRules":"attrition","blessings":"harvestKnot"}
	for group in archive_ids:
		var id: String = archive_ids[group]
		for page in range(HeroArchive.detail_tabs(group,Content.data[group][id]).size()):
			screens["archive-%s-%d" % [group,page]] = _archive(group,id,page,noop)
	for id in Profile.meta.blessings: Profile.meta.blessings[id].unlocked = true
	screens.blessings = HeroGateScreen.build(draft.duplicate(),4,noop,noop,noop)
	var rewards := []
	for id in Content.data.weapons: rewards.append({"type":"weaponFragment","contentId":id,"amount":12345678})
	var reward_root := HeroUI.root(); HeroMetaScreens.rewards_popup(reward_root,rewards); screens["supply-rewards"] = reward_root
	var opening := HeroUI.root(); var opening_box := HeroCombatUI.popup(opening,"봉인 해제",650,300)
	HeroUI.image(opening_box,Content.trimmed_texture("lobbySupplyVault"),300,124).size_flags_vertical = Control.SIZE_EXPAND_FILL
	HeroUI.image(opening_box,Content.trimmed_texture("supplyOpeningBurst"),200,52)
	screens["supply-opening"] = opening
	if stress:
		for id in ["parkDojun"]:
			var character_draft := draft.duplicate(); character_draft.character = id; character_draft.characterPage = 1
			screens["character-"+id] = HeroGateScreen.build(character_draft,2,noop,noop,noop)
		var item_ids: Array = Content.data.items.keys()
		for page in range(ceili(item_ids.size()/4.0)):
			var stock_run := _run()
			for i in range(4): stock_run.item_stock[i] = {"id":item_ids[mini(page*4+i,item_ids.size()-1)],"locked":i == 1}
			screens["shop-all-%02d" % page] = HeroCombatUI.shop(stock_run,false,noop,noop,noop,noop)
		var state_run := _run(); state_run.currency = 12345678; state_run.wallet = 1234567
		state_run.owned.clear()
		for id in ["manaSword","guardianDaggers","manaBolt","piercingShot","chainLightning","manaBombard"]:
			state_run.owned.append({"id":id,"level":3,"cooldown":0.0,"branch":"A"})
		for i in range(4):
			var id: String = state_run.owned[i].id
			state_run.weapon_stock[i] = {"id":id,"level":4,"locked":i == 1}
			state_run.data.weapons[id].name = "긴 상품 이름 확인 · "+state_run.data.weapons[id].name
		screens["shop-long"] = HeroCombatUI.shop(state_run,true,noop,noop,noop,noop)
		screens["hud-full"] = HeroCombatUI.hud(state_run,noop)
		state_run.pending_branch = "manaBolt"
		for branch in state_run.data.weapons.manaBolt.branches: branch.description += " 긴 분기 설명의 줄바꿈과 스크롤을 확인합니다.".repeat(8)
		screens.branch = HeroCombatUI.shop(state_run,true,noop,noop,noop,noop)
		state_run.pending_branch = ""
		var item_run := _run(); item_run.currency = 0; item_run.items.phoenixMatch = 1
		var special_ids := ["phoenixMatch","vaultLedger","revengeFuse","ionConductor"]
		for i in range(4): item_run.item_stock[i] = {"id":special_ids[i],"locked":i == 1}
		screens["shop-states"] = HeroCombatUI.shop(item_run,false,noop,noop,noop,noop)
		var price_run := _run(); price_run.currency = 12345678
		price_run.item_stock[0] = {"id":"phoenixMatch","locked":true}; price_run.data.items.phoenixMatch.basePrice = 12345678
		screens["shop-price"] = HeroCombatUI.shop(price_run,false,noop,noop,noop,noop)
		var details := HeroUI.root()
		HeroShopScreen._offer_popup(details,HeroShopScreen._offer_model(item_run,item_run.item_stock[0],false,false))
		screens["item-detail"] = details
		var detail_root := HeroUI.root()
		HeroCombatUI.details_popup(detail_root,"긴 상세 설명을 확인합니다. ".repeat(60),"긴 상품 제목 · 설명 영역과 하단 버튼 배치 확인")
		screens["details-long"] = detail_root
		var stat_root := HeroUI.root(); HeroShopScreen._stats_popup(stat_root,state_run); screens["stats-popup"] = stat_root
		state_run.reward = 12345678; state_run.kills = 123456; state_run.phase = "stageClear"
		for slot in state_run.owned: state_run.telemetry.weapons[slot.id] = {"damage":12345678.0}
		screens["result-large"] = HeroCombatUI.result(state_run,noop)
	for id in screens:
		var screen: Control = screens[id]
		if not filters.is_empty() and id not in filters:
			screen.free(); continue
		if id in ["hud","hud-full"]:
			# Static arena art only: show HUD contrast without running combat.
			HeroUI.background(screen,Content.visuals.maps.seoul.texture)
		root.add_child(screen)
		for frame in range(3): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(id+".png"))
		_text_boxes.clear(); _scan(screen,id); _overlaps(id)
		_captures.append(id)
		root.remove_child(screen); screen.queue_free()
	var report := {"saveWrites":false,"simulation":false,"captures":_captures,"issues":_issues}
	var file := FileAccess.open(output.path_join("layout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("UI previews: %s; captures=%d; layout issues=%d" % [ProjectSettings.globalize_path(output),_captures.size(),_issues.size()])
	get_tree().quit()

func _issue(screen: String, kind: String, node: Node, detail: String) -> void:
	_issues.append({"screen":screen,"kind":kind,"path":str(node.get_path()),"detail":detail})
	print("UI layout: %s / %s / %s" % [screen,kind,detail])

func _shape(text: String, font: Font, font_size: int, width: float, wrap: bool) -> TextParagraph:
	var shaped := TextParagraph.new()
	shaped.break_flags = TextServer.BREAK_MANDATORY
	if wrap: shaped.break_flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	shaped.add_string(text,font,font_size)
	shaped.width = maxf(1,width) if wrap else -1
	return shaped

func _scan(node: Node, screen: String, inside_scroll: bool = false) -> void:
	if node is Control and not inside_scroll and not node.has_meta("full_bleed"):
		var rect: Rect2 = node.get_global_rect()
		if rect.size.x > 0 and rect.size.y > 0 and not get_viewport().get_visible_rect().grow(1).encloses(rect):
			_issue(screen,"outside",node,str(rect))
	if node is Label or node is Button:
		var control := node as Control
		var text: String = node.text
		if not text.is_empty():
			var available := control.size
			var offset := Vector2.ZERO
			var alignment: int = node.horizontal_alignment if node is Label else node.alignment
			var vertical: int = node.vertical_alignment if node is Label else VERTICAL_ALIGNMENT_CENTER
			if node is Button:
				var style := control.get_theme_stylebox("normal")
				offset = Vector2(style.get_content_margin(SIDE_LEFT),style.get_content_margin(SIDE_TOP))
				available -= style.get_minimum_size()
			elif node.has_meta("text_frame"):
				available = (node.get_parent() as Control).size
			var font_size := control.get_theme_font_size("font_size")
			var shaped := _shape(text,control.get_theme_font("font"),font_size,available.x,node.autowrap_mode != TextServer.AUTOWRAP_OFF)
			var lines := shaped.get_line_count()
			var extent := shaped.get_size()
			var spacing := control.get_theme_constant("line_spacing")
			extent.y += maxi(0,lines-1)*spacing
			if extent.x > available.x+1 or extent.y > available.y+1:
				_issue(screen,"text-fit",node,"%s needs %s / available %s" % [text,extent,available])
			if node is Label and node.max_lines_visible > 0 and lines > node.max_lines_visible:
				_issue(screen,"line-budget",node,"%s: %d lines / %d allowed" % [text,lines,node.max_lines_visible])
			if alignment == HORIZONTAL_ALIGNMENT_CENTER: offset.x += (available.x-extent.x)*0.5
			elif alignment == HORIZONTAL_ALIGNMENT_RIGHT: offset.x += available.x-extent.x
			if vertical == VERTICAL_ALIGNMENT_CENTER: offset.y += (available.y-extent.y)*0.5
			elif vertical == VERTICAL_ALIGNMENT_BOTTOM: offset.y += available.y-extent.y
			var transform := control.get_global_transform()
			var bounds := Rect2(transform*offset,extent*transform.get_scale().abs())
			var ancestor := control.get_parent()
			var domain := 0
			while ancestor is Control:
				if ancestor.clip_contents: bounds = bounds.intersection(ancestor.get_global_rect())
				if ancestor is ScrollContainer:
					var bar: VScrollBar = ancestor.get_v_scroll_bar()
					if bar.visible and bounds.intersects(bar.get_global_rect()):
						_issue(screen,"scrollbar-overlap",node,text)
				if ancestor is ColorRect and ancestor.is_in_group("input_blocker"): domain = ancestor.get_instance_id()
				ancestor = ancestor.get_parent()
			if bounds.has_area(): _text_boxes.append({"rect":bounds,"node":node,"text":text,"domain":domain})
	for child in node.get_children(): _scan(child,screen,inside_scroll or node is ScrollContainer)

func _overlaps(screen: String) -> void:
	for i in range(_text_boxes.size()):
		for j in range(i+1,_text_boxes.size()):
			var a: Dictionary = _text_boxes[i]; var b: Dictionary = _text_boxes[j]
			if a.domain != b.domain: continue
			var intersection: Rect2 = a.rect.intersection(b.rect)
			if intersection.size.x > 1 and intersection.size.y > 1:
				_issue(screen,"text-overlap",a.node,"%s / %s %s" % [a.text,b.text,intersection])
