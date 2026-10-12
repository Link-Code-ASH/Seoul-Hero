class_name HeroGuildScreen
extends HeroMobileScreen

var meta: Dictionary
var view_state := {"panel":"facility","slot":0,"employee":"","expedition":"cityScout","selectedStaff":[]}
var act: Callable
var back: Callable
var deploy: Callable
var room_atlas: Texture2D
var state_atlas: Texture2D
var facility_order: Array = []
var tiers: Array = [1,4,7,10]
var read_only := true
var clock := 0.0
var refresh_clock := 0.0
var avatars: Array = []
var _contents: Control
var action_message := ""

static func build(profile: Dictionary, command: Callable, leave: Callable, enter_gate: Callable, art: Dictionary = {}, ui: Dictionary = {}) -> HeroGuildScreen:
	var screen := HeroGuildScreen.new()
	screen.meta = profile; screen.act = command; screen.back = leave; screen.deploy = enter_gate
	if not ui.is_empty(): screen.view_state = ui
	screen.room_atlas = art.get("rooms"); screen.state_atlas = art.get("states")
	screen.facility_order = art.get("facilityOrder",Content.data.guildManagement.facilities.keys())
	screen.tiers = art.get("tiers",[1,4,7,10])
	screen.theme = HeroImageSkin.theme()
	screen.set_meta("hero_ui_palette","image_skin")
	return screen

func _ready() -> void:
	HeroUI.background(self,"premiumLobbyRain")
	super._ready()
	_render()

func _process(dt: float) -> void:
	clock += dt; refresh_clock += dt
	for avatar in avatars:
		var pos: Vector2 = avatar.base
		var working: bool = avatar.working
		if not working: pos.x += sin(clock*0.42+avatar.phase)*25.0
		avatar.node.update_state({"pos":pos,"facing":1.0 if cos(clock*0.42+avatar.phase)>0 else -1.0,"age":clock+avatar.phase,"action":"idle" if working else "move"},dt,48.0)
	if not read_only and refresh_clock >= 1.0:
		refresh_clock = 0.0
		var jobs_before: int = meta.guild.jobs.size()
		HeroGuildClock.advance(Content.data,meta,Time.get_unix_time_from_system())
		if meta.guild.jobs.size() != jobs_before: Profile.save(); _render()
		else:
			for label in get_tree().get_nodes_in_group("guild_time"):
				if is_ancestor_of(label): label.text = remaining(float(label.get_meta("endsAt"))-Time.get_unix_time_from_system())

func _select(panel: String, slot: int = -1) -> void:
	action_message = ""
	view_state.panel = panel
	if slot >= 0: view_state.slot = slot
	_render()

func _command(action: String, args: Dictionary = {}) -> void:
	var accepted := act.is_valid() and bool(act.call(action,args))
	action_message = "" if accepted else "읽기 전용 상태에서는 변경할 수 없습니다." if read_only else _refusal()
	if accepted and action == "expedition": view_state.selectedStaff.clear()
	_render()

func _render() -> void:
	if _contents:
		remove_child(_contents); _contents.queue_free()
	avatars.clear()
	_contents = Control.new(); _contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contents); _contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var resources: Array = []
	for i in range(4):
		resources.append({"name":["길드 코인","마력자재","연구자료","가속권"][i],"amount":int(meta.guild.wallet[HeroGuildState.RESOURCES[i]])})
	HeroImageSkin.header(_contents,"길드 본부",back,resources,{"title_width":300})
	_building()
	HeroImageSkin.material(_contents,"ops/info",Rect2(674,82,229,318))
	HeroImageSkin.text(_contents,_panel_title(),Rect2(694,94,189,29),"heading",18)
	var scroll := HeroImageSkin.scroll(_contents,Rect2(691,132,195,250),view_state,"scroll"+str(view_state.panel)+(str(view_state.slot) if view_state.panel == "facility" else ""))
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",9); scroll.add_child(box)
	if not action_message.is_empty(): _copy(box,action_message,"muted")
	match view_state.panel:
		"staff": _staff(box)
		"hire": _hire(box)
		"jobs": _jobs(box)
		"expedition": _expedition(box)
		_: _facility(box)
	var actions := [["직원 · %d/%d" % [meta.guild.employees.size(),HeroGuildRules.staff_capacity(Content.data,meta.guild)],func(): _select("staff")],["진행 작업 · %d" % meta.guild.jobs.size(),func(): _select("jobs")],["보상 수령",func(): _command("claim")],["출동 준비",deploy]]
	for i in range(4): HeroImageSkin.image_button(_contents,actions[i][0],Rect2(24+i*160,352,150,48),actions[i][1],"ops/primary" if i == 3 else "ops/secondary",16)

func _building() -> void:
	var count := HeroGuildRules.rooms(Content.data,meta.guild)
	if count == 4:
		for column in range(4): HeroUI.fixed_art(_contents,_state_texture(2),Rect2(42+column*153,91,151,131))
		HeroImageSkin.material(_contents,"glass/tools",Rect2(126,128,447,51))
		HeroImageSkin.text(_contents,"운영실 Lv.3 · 2층 증축",Rect2(148,133,403,38),"heading",22,"scene",HORIZONTAL_ALIGNMENT_CENTER)
	for slot in range(count):
		var rect := Rect2(42+(slot%4)*153,225 if slot < 4 else 91,151,118)
		var id := _facility_at(slot)
		var job: Dictionary = {}
		for candidate in meta.guild.jobs:
			if candidate.type == "construction" and candidate.slot == slot: job = candidate; break
		var caption := "빈 방 · 건설" if id == "" else str(Content.data.guildManagement.facilities[id].name)
		var picture := _state_texture(0) if id == "" else _room_texture(id,int(meta.guild.facilities[id].level))
		if not job.is_empty() and id == "": picture = _state_texture(1); caption = str(Content.data.guildManagement.facilities[job.targetId].name)
		HeroUI.fixed_art(_contents,picture,Rect2(rect.position,Vector2(151,79)))
		if not job.is_empty() and id != "":
			var scaffolding := HeroUI.fixed_art(_contents,_state_texture(1),Rect2(rect.position,Vector2(151,79)))
			scaffolding.modulate.a = 0.32
		HeroImageSkin.material(_contents,"glass/tools",Rect2(rect.position+Vector2(0,80),Vector2(151,38)))
		HeroImageSkin.text(_contents,caption,Rect2(rect.position+Vector2(6,79),Vector2(139,20)),"heading",14,"scene",HORIZONTAL_ALIGNMENT_CENTER)
		var status := "시설 선택" if id == "" else "Lv.%d · 운영 중" % int(meta.guild.facilities[id].level)
		if not job.is_empty(): status = "공사 중 · "+remaining(job.endsAt-Time.get_unix_time_from_system())
		HeroImageSkin.text(_contents,status,Rect2(rect.position+Vector2(5,98),Vector2(141,18)),"body",13,"scene",HORIZONTAL_ALIGNMENT_CENTER)
		if int(view_state.slot) == slot and view_state.panel == "facility": HeroImageSkin.material(_contents,"accents/selection",rect)
		HeroImageSkin.button(_contents,"",rect,func(): _select("facility",slot),"plain")
		if not job.is_empty():
			HeroImageSkin.text(_contents,"공사",Rect2(rect.position+Vector2(119,8),Vector2(23,24)),"heading",20,"scene")
			_add_avatar("hanSeoa",rect.position+Vector2(101,76),true,float(slot))
		for i in range(meta.guild.employees.size()):
			var employee: Dictionary = meta.guild.employees[i]
			var facility: String = employee.assignment if employee.assignment != "" else "office"
			for task in meta.guild.jobs:
				if employee.id in task.employeeIds: facility = "expeditionAway" if task.type == "expedition" else "research" if task.type in ["recipe","research"] else "office"
			if facility == id and id != "": _add_avatar(_staff_actor(i),rect.position+Vector2(36+i%3*35,76),employee.assignment != "",float(i)*1.73)

func _add_avatar(actor: String, pos: Vector2, working: bool, phase: float) -> void:
	var node := HeroSDVisual.new(); _contents.add_child(node)
	node.configure(actor,Content.visuals.npcs.hanSeoa if actor == "hanSeoa" else Content.visuals.characters[actor])
	avatars.append({"node":node,"base":pos,"working":working,"phase":phase})

func _staff_actor(index: int) -> String:
	return ["hanSeoa","awakener","kangTaehoon","parkDojun"][index%4]

func _facility_at(slot: int) -> String:
	for id in meta.guild.facilities:
		if meta.guild.facilities[id].level > 0 and meta.guild.facilities[id].slot == slot: return id
	return ""

func _room_texture(id: String, level: int) -> Texture2D:
	if room_atlas == null: return null
	var ids: Array = facility_order
	var column := 0
	for i in range(tiers.size()):
		if level >= tiers[i]: column = i
	var cell := room_atlas.get_size()/Vector2(4,8)
	var atlas := AtlasTexture.new(); atlas.atlas = room_atlas; atlas.region = Rect2(Vector2(column,ids.find(id))*cell,cell); atlas.filter_clip = true
	return atlas

func _state_texture(row: int) -> Texture2D:
	if state_atlas == null: return null
	var cell := state_atlas.get_size()/Vector2(1,3)
	var atlas := AtlasTexture.new(); atlas.atlas = state_atlas; atlas.region = Rect2(Vector2(0,row)*cell,cell); atlas.filter_clip = true
	return atlas

func _panel_title() -> String:
	return {"staff":"직원 배치","hire":"지원자 채용","jobs":"진행 작업","expedition":"탐험 파견"}.get(view_state.panel,"빈 방 · 건설" if _facility_at(int(view_state.slot)) == "" else Content.data.guildManagement.facilities[_facility_at(int(view_state.slot))].name)

func _copy(box: Node, caption: String, color: String = "ink") -> void:
	HeroMetaScreens._native_copy(box,caption,14,color)

static func _refusal() -> String:
	var reason := HeroGuildRules.last_error
	return reason if not reason.is_empty() else "진행할 수 없습니다. 자원·시설 레벨·직원 예약 상태를 확인하세요."

# Shows, right above a button, why that command would be refused right now.
func _why(box: Node, action: String, args: Dictionary = {}) -> void:
	if read_only: return
	var reason := HeroGuildRules.check(Content.data,meta,action,args)
	if not reason.is_empty(): _copy(box,"⚠ "+reason,"danger")

func _button(box: Node, caption: String, command: Callable, disabled: bool = false, primary: bool = false) -> void:
	var button := HeroImageSkin.image_button(box,caption,Rect2(0,0,190,44),command,"ops/primary" if primary else "ops/secondary",16)
	button.custom_minimum_size.x = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled

func _entry(box: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",HeroImageSkin.style("ops/row",Vector4(12,12,12,12)))
	box.add_child(panel)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	return column

func _facility(box: Node) -> void:
	var g: Dictionary = meta.guild
	var id := _facility_at(int(view_state.slot))
	if id == "":
		for job in g.jobs:
			if job.type == "construction" and job.slot == view_state.slot: _copy(box,"공사 중 · "+remaining(job.endsAt-Time.get_unix_time_from_system())); return
		var available := 0
		for key in Content.data.guildManagement.facilities:
			var f: Dictionary = Content.data.guildManagement.facilities[key]
			if key == "office" or g.facilities[key].level > 0 or HeroGuildRules._has(g,["construction"],key): continue
			available += 1
			_copy(box,f.name+" · 운영실 Lv."+str(int(f.unlockOfficeLevel)))
			_copy(box,f.effect,"muted")
			_copy(box,"공사 · "+remaining(f.levels[0].durationMs/1000.0),"muted")
			_why(box,"construct",{"id":key,"slot":view_state.slot})
			_button(box,"건설 · "+cost(f.levels[0].cost),func(): _command("construct",{"id":key,"slot":view_state.slot}),HeroGuildRules.level(g,"office")<f.unlockOfficeLevel or not HeroGuildRules.afford(g,f.levels[0].cost) or not HeroGuildRules._construction_available(Content.data,g,key),true)
		if available == 0: _copy(box,"현재 건설할 수 있는 시설이 없습니다. 새 시설을 위한 빈 사무실입니다.","muted")
		return
	var definition: Dictionary = Content.data.guildManagement.facilities[id]
	var level := int(g.facilities[id].level)
	_copy(box,"Lv.%d / %d" % [level,int(definition.maxLevel)],"accent")
	_copy(box,definition.effect)
	if level < definition.maxLevel:
		_copy(box,"강화 · "+cost(definition.levels[level].cost)+" · "+remaining(definition.levels[level].durationMs/1000.0),"muted")
		var depth_needed := HeroGuildRules.office_depth(Content.data,level+1) if id == "office" else 0
		var depth_locked := HeroMeta.cleared_depth(meta) < depth_needed
		_why(box,"upgrade",{"id":id})
		_button(box,"시설 강화",func(): _command("upgrade",{"id":id}),depth_locked or (id != "office" and level >= HeroGuildRules.level(g,"office")) or not HeroGuildRules.afford(g,definition.levels[level].cost) or not HeroGuildRules._construction_available(Content.data,g,id),true)
	_button(box,"직원 배치",func(): _select("staff"))
	_facility_extras(box,id,level)

# Room-specific controls shared by every guild layout (move, production targets, research, ...).
func _facility_extras(box: Node, id: String, level: int) -> void:
	var g: Dictionary = meta.guild
	if id != "office":
		var options := ["이동할 방 선택"]
		for slot in range(1,HeroGuildRules.rooms(Content.data,g)): options.append(_room_label(slot))
		_pick(box,options,0,func(index):
			if index>0: _command("move",{"id":id,"slot":index})
		)
	match id:
		"production":
			_copy(box,"코인과 세 조각 채널 동시 생산","accent")
			for kind in ["character","weapon","blessing"]:
				var known: Dictionary = Content.data[{"character":"characters","weapon":"weapons","blessing":"blessings"}[kind]]
				var keys: Array = known.keys().filter(func(key): return kind == "blessing" or not meta["sharedWeapons" if kind == "weapon" else "characters"][key].unlocked)
				var enabled: bool = level >= Content.data.guildManagement.balance.productionFragmentUnlockLevels[kind]
				_copy(box,{"character":"캐릭터 Lv.1","weapon":"무기 Lv.3","blessing":"축복 Lv.5"}[kind]+("" if enabled else " · 미해금"),"accent" if enabled else "muted")
				_pick(box,keys.map(func(key): return known[key].name),keys.find(g.productionTargets[kind+"Id"]),func(index): _command("production",{"kind":kind,"id":keys[index]}),not enabled)
			_copy(box,"보관 %.1f / %d시간" % [g.productionAccumulated/3600.0,int(HeroGuildSupport.effects(Content.data,g).offlineCapHours)],"muted")
		"expedition": _button(box,"행선지·직원 선택",func(): _select("expedition"))
		"research":
			for key in Content.data.guildManagement.research:
				var research: Dictionary = Content.data.guildManagement.research[key]
				_copy(box,research.name+" · "+str(int(g.researchLevels.get(key,0)))+"/5","accent")
				_copy(box,research.description)
				_research_button(box,key,"research")
		"workshop": _workshop(box)
		"revival":
			_why(box,"manufacture")
			_button(box,"생환석 제조 · "+cost(Content.data.guildManagement.balance.manufactureCost),func(): _command("manufacture"),false,true)
			_copy(box,"제조 1개 보장 · 효율 연구는 자재 할인 · 순도 연구는 등급 확률 증가","muted")
			_why(box,"synthesize",{"id":"low"})
			for grade in ["low","mid"]: _button(box,"%s 3개 → 다음 등급 1개" % Content.data.revivalStones[grade].grade,func(): _command("synthesize",{"id":grade}),not HeroGuildSupport.effects(Content.data,g).canSynthesizeStones)
		"analysis":
			for key in Content.data.characters:
				if not meta.characters[key].unlocked: continue
				_copy(box,Content.data.characters[key].name,"accent")
				_copy(box,_affix_copy(g.characterAffixes.get(key,{})),"muted")
				_button(box,"옵션 재추첨 · "+cost(Content.data.guildManagement.balance.affixCost),func(): _command("affix",{"id":key}),not g.pendingAffix.is_empty() or not HeroGuildRules.afford(g,Content.data.guildManagement.balance.affixCost,meta.wallet))
			if not g.pendingAffix.is_empty():
				_copy(box,"신규 옵션 · "+_affix_copy(g.pendingAffix.option),"accent")
				for accept in [false,true]: _button(box,"신규 선택" if accept else "기존 유지",func(): _command("resolveAffix",{"id":g.pendingAffix.characterId,"accept":accept}))

func _research_button(box: Node, id: String, action: String) -> void:
	var g: Dictionary = meta.guild
	var definition: Dictionary = Content.data.guildManagement["research" if action == "research" else "recipes"][id]
	var spec: Dictionary = definition
	var locked := HeroGuildRules.level(g,"research") <= 0
	if action == "research":
		var current := int(g.researchLevels.get(id,0))
		if current >= int(definition.maxLevel): _copy(box,"연구 완료","muted"); return
		spec = definition.levels[current]
		locked = locked or HeroGuildRules.level(g,definition.facility)<int(definition.unlockFacilityLevel)
	_copy(box,cost(spec.cost)+" · "+remaining(spec.durationMs/1000.0),"muted")
	var free: Array = meta.guild.employees.filter(func(e): return not HeroGuildClock.busy(meta.guild,e.id))
	var ids: Array = free.map(func(e): return e.id)
	var chosen := [ids[0]] if not ids.is_empty() else []
	if not ids.is_empty(): _pick(box,ids.map(func(key): return Content.data.guildManagement.employees[key].name),0,func(index): chosen[0] = ids[index])
	_why(box,action,{"id":id,"employees":chosen})
	_button(box,"연구 시작",func(): _command(action,{"id":id,"employees":chosen}),ids.is_empty() or locked or HeroGuildRules._has(g,["research","recipe"]) or not HeroGuildRules.afford(g,spec.cost),true)

func _workshop(box: Node) -> void:
	var g: Dictionary = meta.guild
	_copy(box,"상품별 긍정 수치 +5%/단계 · 최대 5단계","accent")
	_copy(box,"가격·중첩 한도·페널티·특수효과 수량 유지","muted")
	var items: Array = Content.data.items.keys()
	var chosen := [items[0]]
	var purchase := {}
	var cannot_upgrade := func() -> bool:
		var current := int(g.itemLevels.get(chosen[0],0))
		if current >= int(Content.data.guildManagement.balance.maxItemLevel) or HeroGuildRules._has(g,["itemUpgrade"]): return true
		return not HeroGuildRules.afford(g,Content.data.guildManagement.balance.itemUpgradeLevels[current].cost,meta.wallet)
	_pick(box,items.map(func(key): return Content.data.items[key].name+" · 강화 "+str(int(g.itemLevels.get(key,0)))),0,func(index):
		chosen[0]=items[index]
		if purchase.has("button"): purchase.button.disabled = cannot_upgrade.call()
	)
	_copy(box,"보유 협회 코인 %d" % int(meta.wallet.associationCoins),"accent")
	for index in range(Content.data.guildManagement.balance.itemUpgradeLevels.size()):
		var spec: Dictionary = Content.data.guildManagement.balance.itemUpgradeLevels[index]
		_copy(box,"%d단계 · %s · %s" % [index+1,cost(spec.cost),remaining(spec.durationMs/1000.0)],"muted")
	_button(box,"선택 상품 영구 강화",func(): _command("itemUpgrade",{"id":chosen[0]}),cannot_upgrade.call(),true)
	purchase.button = box.get_child(box.get_child_count()-1) as Button
	for kind in ["weapon","item"]:
		var known: Dictionary = Content.data["weapons" if kind == "weapon" else "items"]
		var excluded: Array = g["excludedWeaponIds" if kind == "weapon" else "excludedItemIds"]
		var slots := int(HeroGuildSupport.effects(Content.data,g)["weaponExclusionSlots" if kind == "weapon" else "itemExclusionSlots"])
		_copy(box,"등장 제외 · "+("무기" if kind == "weapon" else "아이템")+" · %d / %d칸" % [excluded.size(),slots],"accent")
		if slots <= 0: _copy(box,"⚠ 연구실의 '선별 납품' 연구 후 쓸 수 있어요","danger")
		var keys: Array = known.keys(); var selected := [keys[0]]
		_pick(box,keys.map(func(key): return ("제외 · " if key in excluded else "")+known[key].name),0,func(index): selected[0]=keys[index])
		_button(box,"선택 상품 제외 전환",func(): _command("exclude",{"kind":kind,"id":selected[0]}))
	for id in Content.data.guildManagement.recipes:
		var recipe: Dictionary = Content.data.guildManagement.recipes[id]
		_copy(box,recipe.name,"accent")
		_copy(box,"해금 완료" if id in g.unlockedRecipeIds else "설계도 확보" if id in g.blueprints else "탐험에서 설계도 발견 필요","muted")
		if id not in g.unlockedRecipeIds and id in g.blueprints: _research_button(box,id,"recipe")

func _staff(box: Node) -> void:
	if _staff_can_hire(): _button(box,"지원자 채용",func(): _select("hire"))
	for e in _staff_entries():
		var row := _entry(box)
		var definition: Dictionary = Content.data.guildManagement.employees[e.id]
		_copy(row,definition.name+" · Lv."+str(int(e.level)),"accent")
		_copy(row,definition.role+" · 특기 "+Content.data.guildManagement.facilities[definition.specialty].name)
		var busy := HeroGuildClock.busy(meta.guild,e.id)
		_copy(row,"작업 종료까지 예약됨" if busy else "근무 경험 %.1f" % e.experience,"muted")
		var ids: Array = [""]+meta.guild.facilities.keys().filter(func(id): return meta.guild.facilities[id].level>0)
		_pick(row,ids.map(func(id): return "대기" if id=="" else Content.data.guildManagement.facilities[id].name),ids.find(e.assignment),func(index): _command("assign",{"id":e.id,"facility":ids[index]}),busy)
		_button(row,"교육 · 2시간 · "+cost(Content.data.guildManagement.balance.educationCost),func(): _command("train",{"id":e.id}),busy or e.level>=Content.data.guildManagement.balance.maxStaffLevel)

# Screens can scope the shared management content without duplicating commands.
func _staff_entries() -> Array:
	return meta.guild.employees

func _staff_can_hire() -> bool:
	return true

func _room_label(slot: int) -> String:
	return "%d번 방" % (slot+1)

func _job_entries() -> Array:
	return meta.guild.jobs

func _hire(box: Node) -> void:
	for id in Content.data.guildManagement.employees:
		if meta.guild.employees.any(func(e): return e.id==id): continue
		var row := _entry(box)
		var e: Dictionary = Content.data.guildManagement.employees[id]
		_copy(row,e.name+" · "+e.role,"accent")
		_copy(row,e.description)
		_why(row,"hire",{"id":id})
		_button(row,"채용 · "+cost(e.hireCost),func(): _command("hire",{"id":id}),meta.guild.employees.size()>=HeroGuildRules.staff_capacity(Content.data,meta.guild) or not HeroGuildRules.afford(meta.guild,e.hireCost),true)

func _expedition(box: Node) -> void:
	var effects := HeroGuildSupport.effects(Content.data,meta.guild)
	_copy(box,"동시 %d팀 · 팀당 %d명" % [int(effects.expeditionTeams),int(effects.expeditionPartySize)],"accent")
	var keys: Array = Content.data.guildManagement.expeditions.keys()
	_pick(box,keys.map(func(id): return Content.data.guildManagement.expeditions[id].name),keys.find(view_state.expedition),func(index): view_state.expedition=keys[index]; _render())
	var definition: Dictionary = Content.data.guildManagement.expeditions[view_state.expedition]
	var depth_needed := int(definition.get("minDepth",0))
	var depth_locked := HeroMeta.cleared_depth(meta) < depth_needed
	_copy(box,remaining(definition.durationMs/1000.0)+" · "+cost(definition.cost))
	_copy(box,"기본 보상: "+cost(definition.baseRewards))
	var extras := "랜덤 조각 %d개 확정" % int(definition.get("fragmentAmount",0))
	var ticket := float(definition.get("supplyTicketChance",0.0))
	extras += " · 보급권 확정" if ticket >= 1.0 else " · 보급권 %d%%" % roundi(ticket*100.0)
	_copy(box,extras,"accent")
	var region := HeroMeta.region_multiplier(Content.data,meta)
	if region > 1.0: _copy(box,"층 보너스 +%d%%" % roundi((region-1.0)*100.0),"muted")
	for e in meta.guild.employees:
		var selected: bool = e.id in view_state.selectedStaff
		_button(box,("✓ " if selected else "")+Content.data.guildManagement.employees[e.id].name,func():
			if e.id in view_state.selectedStaff: view_state.selectedStaff.erase(e.id)
			elif view_state.selectedStaff.size()<effects.expeditionPartySize: view_state.selectedStaff.append(e.id)
			_render()
		,HeroGuildClock.busy(meta.guild,e.id))
	_why(box,"expedition",{"id":view_state.expedition,"employees":view_state.selectedStaff.duplicate()})
	_button(box,"탐험 파견",func(): _command("expedition",{"id":view_state.expedition,"employees":view_state.selectedStaff.duplicate()}),depth_locked or view_state.selectedStaff.is_empty(),true)

func _jobs(box: Node) -> void:
	var jobs := _job_entries()
	if jobs.is_empty(): _copy(box,"진행 중인 작업이 없습니다.")
	for job in jobs:
		var row := _entry(box)
		var config: Dictionary = Content.data.guildManagement
		var known: Dictionary = {"construction":config.facilities,"research":config.research,"expedition":config.expeditions,"training":config.employees,"manufacture":Content.data.revivalStones,"itemUpgrade":Content.data.items,"recipe":config.recipes}[job.type]
		_copy(row,known[job.targetId].name,"accent")
		var label := HeroMetaScreens._native_copy(row,remaining(job.endsAt-Time.get_unix_time_from_system()),18,"muted")
		HeroImageSkin.apply_font(label,"number",18)
		label.add_to_group("guild_time"); label.set_meta("endsAt",job.endsAt)
		_button(row,"작업 가속 · 가속권 1장",func(): _command("speedup",{"id":job.id,"method":"ticket"}),meta.guild.wallet.speedupTickets<=0)
		_copy(row,"가속권 1장으로 15분 단축","muted")
		var finish_cost := ceili(maxf(0.0,job.endsAt-Time.get_unix_time_from_system())/60.0)*int(Content.data.guildManagement.balance.speedupCoinsPerMinute)
		_button(row,"즉시 완료 · %d 코인" % finish_cost,func(): _command("speedup",{"id":job.id,"method":"coins"}),meta.guild.wallet.coins<finish_cost)
		var finish_button := row.get_child(row.get_child_count()-1) as Button
		finish_button.add_to_group("guild_speedup_cost"); finish_button.set_meta("endsAt",job.endsAt)

func _pick(box: Node, options: Array, selected: int, change: Callable, disabled: bool = false) -> void:
	var picker := OptionButton.new(); picker.custom_minimum_size = Vector2(44,44); HeroImageSkin.apply_font(picker,"control",16)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	for caption in options: picker.add_item(str(caption))
	for state in ["normal","hover","pressed","disabled","focus"]: picker.add_theme_stylebox_override(state,HeroImageSkin.style("ops/secondary",Vector4(12,4,24,4)))
	picker.get_popup().add_theme_stylebox_override("panel",HeroImageSkin.style("ops/popup",Vector4(20,20,20,20)))
	picker.selected = maxi(0,selected); picker.disabled = disabled or options.is_empty(); picker.item_selected.connect(change); box.add_child(picker)

static func cost(value: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in ["associationCoins"]+HeroGuildState.RESOURCES:
		if value.get(key,0)>0: parts.append("%d %s" % [int(value[key]),str(Content.data.resources[key].name)])
	return " / ".join(parts)

static func remaining(seconds: float) -> String:
	var minutes := ceili(maxf(0.0,seconds)/60.0)
	return "%d시간 %d분" % [minutes/60,minutes%60] if minutes>=60 else "%d분" % minutes

static func _affix_copy(affix: Dictionary) -> String:
	return "추가 옵션 없음" if affix.is_empty() else HeroArchive.STATS.get(affix.stat,affix.stat)+" +"+HeroArchive.stat_value(affix.stat,affix.value)

static func crafting_dialog(root: Control, run: HeroRun, refresh: Callable) -> void:
	var box := HeroShopScreen._popup(root,"장비공방 · 조합법",610,360)
	var content := HeroUI.column(HeroUI.scroll(box)); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in run.guild_support.unlockedRecipeIds:
		var recipe: Dictionary = run.data.guildManagement.recipes[id]
		HeroMetaScreens._native_copy(content,recipe.name,18,"accent")
		var lines := PackedStringArray()
		for ingredient in recipe.ingredients: lines.append("%s %d/%d" % [run.data.items[ingredient].name,int(run.items.get(ingredient,0)),int(recipe.ingredients[ingredient])])
		HeroMetaScreens._native_copy(content," + ".join(lines)+" → "+run.data.items[recipe.resultItemId].name,14)
		HeroMetaScreens._native_copy(content,run.data.items[recipe.resultItemId].description,14,"muted")
		var button := HeroImageSkin.image_button(content,"재료 소비 · 조합",Rect2(0,0,200,44),func():
			if HeroItemCrafting.craft(run,id): refresh.call()
		,"ops/primary",16)
		button.disabled = not HeroItemCrafting.can_craft(run,id)
	HeroShopScreen._close_button(box)
