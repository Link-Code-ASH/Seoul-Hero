class_name HeroGuildOfficeScreen
extends HeroGuildScreen

# Approved fixed composition: room selection never resizes the building.
const BUILDING_RECT := Rect2(12,72,547,328)
const PANE_RECT := Rect2(573,72,330,328)
const NO_POINTER := -999

var world := HeroGuildIsoWorld.new()
var art: Dictionary = {}
var _building_view: Control
var _pane: Control
var _resource_labels: Array[Label] = []
var _pointer := NO_POINTER
var _start := Vector2.ZERO
var _start_scroll := 0.0
var _dragging := false
var _revision := ""

static func create(profile: Dictionary, command: Callable, leave: Callable, enter_gate: Callable, images: Dictionary, ui: Dictionary = {}) -> HeroGuildOfficeScreen:
	var screen := HeroGuildOfficeScreen.new()
	screen.meta=profile; screen.act=command; screen.back=leave; screen.deploy=enter_gate; screen.art=images
	if not ui.is_empty(): screen.view_state=ui
	var defaults := {"panelOpen":false,"selectedFacility":"","officeTab":"management","officeTabs":{},"officeDetail":"","officeLockedFloor":1}
	for key in defaults:
		if not screen.view_state.has(key): screen.view_state[key]=defaults[key]
	screen.room_atlas=images.get("rooms"); screen.state_atlas=images.get("states")
	screen.facility_order=images.get("facilityOrder",Content.data.guildManagement.facilities.keys())
	screen.tiers=images.get("tiers",[1,4,7,10])
	screen.theme=HeroImageSkin.theme(); screen.set_meta("hero_ui_palette","image_skin")
	return screen

func _ready() -> void:
	HeroUI.background(self,"premiumLobbyRain")
	get_viewport().size_changed.connect(_fit); _fit()
	_building_view=Control.new(); _building_view.clip_contents=true; _building_view.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(_building_view); HeroUI.place(_building_view,BUILDING_RECT)
	world.configure(art); world.set_viewport_width(BUILDING_RECT.size.x); _building_view.add_child(world)
	if bool(view_state.panelOpen) and str(view_state.selectedFacility).is_empty() and str(view_state.panel)!="locked":
		view_state.selectedFacility=_facility_at(int(view_state.slot))
	world.sync_state(meta,_selected_slot())
	if not view_state.has("officeScroll"): view_state.officeScroll=_max_scroll()
	_render()

func _process(dt: float) -> void:
	refresh_clock+=dt
	if refresh_clock<1.0 or not is_instance_valid(_building_view): return
	refresh_clock=0.0
	if not read_only: HeroGuildClock.advance(Content.data,meta,Time.get_unix_time_from_system())
	var revision := _state_revision()
	if revision!=_revision:
		if not read_only: Profile.save()
		_render()
	else:
		_update_resources()
		for label in get_tree().get_nodes_in_group("guild_time"):
			if is_ancestor_of(label): label.text=remaining(float(label.get_meta("endsAt"))-Time.get_unix_time_from_system())
		var now := Time.get_unix_time_from_system()
		for button in get_tree().get_nodes_in_group("guild_speedup_cost"):
			if not is_ancestor_of(button): continue
			var finish_cost := ceili(maxf(0.0,float(button.get_meta("endsAt"))-now)/60.0)*int(Content.data.guildManagement.balance.speedupCoinsPerMinute)
			var caption = button.get_meta("caption_label",null)
			if caption is Label: caption.text=HeroUI.amount(finish_cost)
			else: button.text="즉시 완료 · %d 코인" % finish_cost
			button.disabled=meta.guild.wallet.coins<finish_cost
		for ring in get_tree().get_nodes_in_group("guild_ring"):
			if not is_ancestor_of(ring): continue
			var started := float(ring.get_meta("startedAt")); var ends := float(ring.get_meta("endsAt"))
			ring.set("progress",clampf((now-started)/maxf(1.0,ends-started),0.0,1.0)); ring.queue_redraw()
		_sync_world()

func _state_revision() -> String:
	var facilities := []
	for id in meta.guild.facilities: facilities.append([id,meta.guild.facilities[id].level,meta.guild.facilities[id].slot])
	return JSON.stringify([facilities,meta.guild.jobs.map(func(job): return [job.id,job.endsAt]),meta.guild.employees.map(func(employee): return [employee.id,employee.level,employee.assignment]),meta.guild.get("unlockedFloors",1)])

func _selected_slot() -> int:
	return int(view_state.slot) if bool(view_state.panelOpen) and str(view_state.panel)!="locked" else -1

func _resolve_selection() -> void:
	var id := str(view_state.selectedFacility)
	if id.is_empty(): return
	if meta.guild.facilities.has(id) and int(meta.guild.facilities[id].level)>0:
		view_state.slot=int(meta.guild.facilities[id].slot); return
	for job in meta.guild.jobs:
		if job.type=="construction" and job.targetId==id:
			view_state.slot=int(job.slot); return
	view_state.selectedFacility=""

func _sync_world() -> void:
	_resolve_selection()
	var previous_height := world.get_content_height()
	world.sync_state(meta,_selected_slot())
	var height_delta := world.get_content_height()-previous_height
	if previous_height>0 and height_delta>0: view_state.officeScroll=float(view_state.officeScroll)+height_delta
	_apply_scroll()

func _max_scroll() -> float:
	return maxf(0,world.get_content_height()-BUILDING_RECT.size.y)

func _apply_scroll() -> void:
	view_state.officeScroll=clampf(float(view_state.get("officeScroll",0)),0,_max_scroll())
	world.position=Vector2(0,-float(view_state.officeScroll))

func _select(panel: String, slot: int = -1) -> void:
	action_message=""; view_state.panelOpen=true
	if slot>=0:
		view_state.slot=slot; view_state.selectedFacility=_facility_at(slot)
		var construction := _construction_at(slot)
		if str(view_state.selectedFacility).is_empty() and not construction.is_empty(): view_state.selectedFacility=construction.targetId
		view_state.officeTab=str(view_state.officeTabs.get(str(view_state.selectedFacility),"management"))
		view_state.officeDetail=""
	view_state.panel="facility"
	match panel:
		"staff","jobs": _set_tab(panel)
		"hire","expedition": view_state.officeDetail=panel
	_render()

func _set_tab(tab: String) -> void:
	view_state.officeTab=tab; view_state.officeDetail=""
	if not str(view_state.selectedFacility).is_empty(): view_state.officeTabs[str(view_state.selectedFacility)]=tab

func _change_tab(tab: String) -> void:
	action_message=""; _set_tab(tab); _render()

func close_management() -> bool:
	if not bool(view_state.panelOpen): return false
	view_state.panelOpen=false; view_state.selectedFacility=""; view_state.officeDetail=""; action_message=""
	_render(); return true

func _command(action: String, args: Dictionary = {}) -> void:
	var pending: Array = []
	if action=="claim":
		if not read_only: HeroGuildClock.advance(Content.data,meta,Time.get_unix_time_from_system())
		pending=claim_list(meta.guild.pendingRewards)
	var accepted := act.is_valid() and bool(act.call(action,args))
	action_message="" if accepted else "읽기 전용 상태에서는 변경할 수 없습니다." if read_only else _refusal()
	if accepted and action=="claim":
		if pending.is_empty(): action_message="받을 보상이 아직 없어요"
		else:
			HeroMetaScreens.rewards_popup(self,pending,"길드 보상 수령")
			# The popup is the newest child; lift it above the management pane (z 20).
			var overlay := get_child(get_child_count()-1) as CanvasItem
			if overlay: overlay.z_index=50
	if accepted:
		if action=="construct": view_state.selectedFacility=str(args.id)
		if action=="expedition": view_state.selectedStaff.clear()
	_resolve_selection(); _render()

func _render() -> void:
	if not is_instance_valid(_building_view): return
	_sync_world(); _revision=_state_revision()
	if is_instance_valid(_contents): remove_child(_contents); _contents.queue_free()
	_contents=Control.new(); _contents.mouse_filter=Control.MOUSE_FILTER_IGNORE; _contents.z_index=20
	add_child(_contents); _contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_header()
	# Even the empty right side owns its input area.
	_pane=Control.new(); _pane.mouse_filter=Control.MOUSE_FILTER_STOP; _pane.add_to_group("input_blocker")
	_contents.add_child(_pane); HeroUI.place(_pane,PANE_RECT)
	if not bool(view_state.panelOpen): return
	_management()

func _header() -> void:
	if HeroMetaScreens.ECONOMY_UI_APPROVED:
		_economy_header()
		return
	var resources: Array = []
	for index in range(4):
		resources.append({"name":["길드 코인","마력자재","연구자료","가속권"][index],"amount":int(meta.guild.wallet[HeroGuildState.RESOURCES[index]]),"label_name":"GuildResource_%d" % index})
	var header := HeroImageSkin.header(_contents,"길드 본부",func():
		if not close_management(): back.call()
	,resources,{"title_width":300})
	_resource_labels.clear()
	for index in range(4): _resource_labels.append(header.find_child("GuildResource_%d" % index,true,false) as Label)
	_update_resources()

func _update_resources() -> void:
	for i in range(_resource_labels.size()):
		if is_instance_valid(_resource_labels[i]): _resource_labels[i].text=HeroUI.amount(int(meta.guild.wallet[HeroGuildState.RESOURCES[i]]))
	var association := _contents.find_child("GuildAssociationCoins",true,false) as Label
	if association: association.text = HeroUI.amount(int(meta.wallet.associationCoins))

func _economy_header() -> void:
	var resources: Array = []
	for index in range(3):
		var key: String = HeroGuildState.RESOURCES[index]
		var definition: Dictionary = Content.data.resources[key]
		resources.append({"image_id":definition.image,"name":definition.name,"amount":HeroUI.amount(int(meta.guild.wallet[key])),"label_name":"GuildResource_%d" % index,"texture_filter":CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS})
	resources.append({"image_id":"associationCoin","name":"협회","amount":HeroUI.amount(int(meta.wallet.associationCoins)),"label_name":"GuildAssociationCoins"})
	var header := HeroImageSkin.header(_contents,"길드 본부",func():
		if not close_management(): back.call()
	,resources,{"title_width":180,"resources_right":96,"resource_separation":12})
	HeroImageSkin.image_button(header,"재화",Rect2(803,4,64,44),func(): HeroEconomyUI.wallet(_contents,meta),"ops/secondary",16)
	_resource_labels.clear()
	for index in range(3): _resource_labels.append(header.find_child("GuildResource_%d" % index,true,false) as Label)
	_update_resources()

func _management() -> void:
	var locked := str(view_state.panel)=="locked"
	var id := str(view_state.selectedFacility)
	var level := 0 if id.is_empty() else HeroGuildRules.level(meta.guild,id)
	var built := not id.is_empty() and level>0
	var construction := {} if locked else _construction_at(int(view_state.slot))
	var floor_number := int(view_state.officeLockedFloor) if locked else floori(int(view_state.slot)/3.0)+1
	HeroGuildPanelKit.frame(_pane,Rect2(0,0,326,322))
	var title := "%d층 증축" % floor_number if locked else "빈 사무실" if id.is_empty() else str(Content.data.guildManagement.facilities[id].name)
	var art_name := "locked" if locked else "construction" if not built and not construction.is_empty() else "empty" if not built else _room_art_name(id,level)
	HeroGuildPanelKit.thumbnail(_pane,world._texture(art_name),Rect2(12,12,86,70),"Lv.%d" % level if built else "")
	HeroGuildPanelKit.placed_label(_pane,title,Rect2(108,12,170,30),21)
	var subtitle := "운영실 성장으로 사무실 3칸 개방" if locked else _room_label(int(view_state.slot))
	if built and id!="office": subtitle+=" · 직원 %d명" % _staff_entries().size()
	elif not built and not construction.is_empty(): subtitle+=" · 공사 중"
	HeroGuildPanelKit.placed_label(_pane,subtitle,Rect2(108,42,172,18),12,HeroGuildPanelKit.MUTED,"body")
	if built: HeroGuildPanelKit.pips(_pane,Rect2(108,66,172,9),level,int(Content.data.guildManagement.facilities[id].maxLevel))
	var close := HeroGuildPanelKit.button(_pane,"×",close_management,"secondary",20,Vector2(34,34))
	HeroUI.place(close,Rect2(282,10,34,34))
	var content_top := 92.0
	if built:
		var busy := not _job_entries().is_empty()
		for i in range(3):
			var tab: String=["management","staff","jobs"][i]
			HeroGuildPanelKit.tab(_pane,["관리","직원","작업"][i],Rect2(12+i*102,90,96,34),str(view_state.officeTab)==tab,_change_tab.bind(tab),tab=="jobs" and busy and str(view_state.officeTab)!="jobs")
		content_top=132.0
	var identity := "locked:%d" % floor_number if locked else "empty:%d" % int(view_state.slot) if id.is_empty() else id
	var scroll_key := "officePanel:"+identity+":"+str(view_state.officeTab)+":"+str(view_state.officeDetail)
	var scroll := HeroImageSkin.scroll(_pane,Rect2(12,content_top,306,314-content_top),view_state,scroll_key)
	var box := VBoxContainer.new(); box.custom_minimum_size.x=294; box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",7); scroll.add_child(box)
	if not action_message.is_empty(): _copy(box,action_message,"danger")
	if locked:
		var unlocks: Array=Content.data.guildManagement.balance.floorUnlockOfficeLevels
		HeroGuildPanelKit.tiles(box,["운영실 Lv.%d에서 개방" % int(unlocks[floor_number-1]),"사무실 3칸 추가"])
		HeroGuildPanelKit.button(box,"운영실 보러 가기",func(): _select("facility",0),"secondary",16,Vector2(0,42))
	elif not built and not construction.is_empty(): _job_cards(box)
	elif not built: _build_cards(box)
	elif str(view_state.officeDetail)=="hire":
		HeroGuildPanelKit.button(box,"‹ 직원 목록",func(): _select("staff"),"secondary",15,Vector2(0,36)); _hire(box)
	elif str(view_state.officeDetail)=="assign": _assign_cards(box)
	elif str(view_state.officeDetail)=="expedition":
		HeroGuildPanelKit.button(box,"‹ 탐험본부",func(): view_state.officeDetail=""; _render(),"secondary",15,Vector2(0,36)); _expedition(box)
	elif str(view_state.officeTab)=="staff": _staff_cards(box)
	elif str(view_state.officeTab)=="jobs": _job_cards(box)
	else:
		_facility_card(box,id,level)
		if id=="office": _office_actions(box)
		_facility_extras(box,id,level)

func _room_art_name(id: String, level: int) -> String:
	var tier := 1
	for step in [1,4,7,10]:
		if level>=step: tier=step
	return "%s_lv%d" % [id,tier]

func _facility_card(box: Node, id: String, level: int) -> void:
	var definition: Dictionary = Content.data.guildManagement.facilities[id]
	var phrases: Array = Array(str(definition.effect).split(" · ")).slice(0,3)
	HeroGuildPanelKit.tiles(box,phrases)
	if level>=int(definition.maxLevel):
		HeroGuildPanelKit.caption_row(box,"최고 레벨이에요")
		return
	var spec: Dictionary = definition.levels[level]
	var duration := remaining(spec.durationMs/1000.0)
	HeroGuildPanelKit.caption_row(box,"Lv.%d로 올리려면" % (level+1),duration)
	HeroGuildPanelKit.cost_chips(box,spec.cost,meta.guild.wallet,meta.wallet)
	var reason := HeroGuildRules.check(Content.data,meta,"upgrade",{"id":id})
	HeroGuildPanelKit.action_button(box,"시설 강화",duration if reason.is_empty() else reason,func(): _command("upgrade",{"id":id}),reason.is_empty())

func _build_cards(box: Node) -> void:
	var g: Dictionary = meta.guild
	var shown := 0
	HeroGuildPanelKit.caption_row(box,"지을 시설을 고르세요")
	for key in Content.data.guildManagement.facilities:
		var f: Dictionary = Content.data.guildManagement.facilities[key]
		if key=="office" or g.facilities[key].level>0 or HeroGuildRules._has(g,["construction"],key): continue
		shown += 1
		var card := HeroGuildPanelKit.card_panel(box)
		var column := VBoxContainer.new(); column.add_theme_constant_override("separation",6); card.add_child(column)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); column.add_child(row)
		HeroGuildPanelKit.room_icon(row,world._texture(key+"_lv1"),Vector2(64,54))
		var info := VBoxContainer.new(); info.add_theme_constant_override("separation",1); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(info)
		HeroGuildPanelKit.label(info,str(f.name),16)
		var phrase := HeroGuildPanelKit.label(info,str(f.effect).split(" · ")[0],11,HeroGuildPanelKit.MUTED,"body")
		phrase.clip_text=true; phrase.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; phrase.custom_minimum_size.x=150
		HeroGuildPanelKit.label(info,"운영실 Lv.%d · 공사 %s" % [int(f.unlockOfficeLevel),remaining(f.levels[0].durationMs/1000.0)],11,HeroGuildPanelKit.MUTED,"body")
		HeroGuildPanelKit.cost_chips(column,f.levels[0].cost,g.wallet,meta.wallet)
		var args := {"id":key,"slot":view_state.slot}
		var reason := HeroGuildRules.check(Content.data,meta,"construct",args)
		HeroGuildPanelKit.action_button(column,"건설","" if reason.is_empty() else reason,func(): _command("construct",args),reason.is_empty(),"primary",Vector2(0,40))
	if shown==0: HeroGuildPanelKit.tiles(box,["지을 수 있는 시설을 모두 지었어요"])

# Same actor order as the people walking in the HQ rooms.
const PORTRAITS := ["hanSeoaSD","songJinwooSD","kangTaehoonSD","parkDojunSD","yoonHarinSD"]

static func portrait_for(index: int) -> Texture2D:
	return Content.trimmed_texture(str(PORTRAITS[posmod(index,PORTRAITS.size())]))

func _employee_index(id: String) -> int:
	for index in meta.guild.employees.size():
		if str(meta.guild.employees[index].id)==id: return index
	return 0

func _card_grid(box: Node) -> GridContainer:
	var grid := GridContainer.new(); grid.columns=3
	grid.add_theme_constant_override("h_separation",5); grid.add_theme_constant_override("v_separation",5)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	return grid

func _staff_cards(box: Node) -> void:
	var id := str(view_state.selectedFacility)
	var people := _staff_entries()
	var capacity := HeroGuildRules.staff_capacity(Content.data,meta.guild)
	var max_level := int(Content.data.guildManagement.balance.maxStaffLevel)
	HeroGuildPanelKit.caption_row(box,"전체 직원" if id=="office" else "이 방 직원","%d / %d명" % [meta.guild.employees.size(),capacity] if id=="office" else "%d명" % people.size())
	var grid := _card_grid(box)
	var selected := str(view_state.get("employee",""))
	for e in people:
		var definition: Dictionary = Content.data.guildManagement.employees[e.id]
		var specialist := str(definition.specialty)==id
		var note := "작업 중" if HeroGuildClock.busy(meta.guild,e.id) else "특기" if specialist else ""
		var employee_id := str(e.id)
		HeroGuildPanelKit.portrait_card(grid,portrait_for(_employee_index(employee_id)),str(definition.name),str(definition.role),int(e.level),max_level,specialist,employee_id==selected,func():
			view_state.employee = "" if str(view_state.get("employee",""))==employee_id else employee_id
			_render()
		,note)
	if id=="office": HeroGuildPanelKit.add_card(grid,"채용",func(): _select("hire"),meta.guild.employees.size()<capacity)
	else: HeroGuildPanelKit.add_card(grid,"배치",func(): view_state.officeDetail="assign"; _render())
	for e in people:
		if str(e.id)==selected: _staff_detail(box,e)

func _staff_detail(box: Node, e: Dictionary) -> void:
	var definition: Dictionary = Content.data.guildManagement.employees[e.id]
	var busy := HeroGuildClock.busy(meta.guild,e.id)
	var card := HeroGuildPanelKit.card_panel(box,HeroGuildPanelKit.MINT)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",6); card.add_child(column)
	HeroGuildPanelKit.caption_row(column,"%s · Lv.%d · 경험 %.1f" % [definition.name,int(e.level),float(e.experience)],"작업 중" if busy else "")
	var ids: Array = [""]+meta.guild.facilities.keys().filter(func(key): return meta.guild.facilities[key].level>0)
	_pick(column,ids.map(func(key): return "대기" if key=="" else "근무지 · "+str(Content.data.guildManagement.facilities[key].name)),ids.find(e.assignment),func(index): _command("assign",{"id":e.id,"facility":ids[index]}),busy)
	if int(e.level)<int(Content.data.guildManagement.balance.maxStaffLevel):
		HeroGuildPanelKit.cost_chips(column,Content.data.guildManagement.balance.educationCost,meta.guild.wallet,meta.wallet)
		var reason := HeroGuildRules.check(Content.data,meta,"train",{"id":e.id})
		HeroGuildPanelKit.action_button(column,"교육","2시간" if reason.is_empty() else reason,func(): _command("train",{"id":e.id}),reason.is_empty(),"secondary",Vector2(0,40))

func _assign_cards(box: Node) -> void:
	var id := str(view_state.selectedFacility)
	HeroGuildPanelKit.button(box,"‹ 직원 목록",func(): view_state.officeDetail=""; _render(),"secondary",15,Vector2(0,36))
	var available: Array=meta.guild.employees.filter(func(employee): return str(employee.assignment)!=id and not HeroGuildClock.busy(meta.guild,employee.id))
	if available.is_empty():
		HeroGuildPanelKit.tiles(box,["배치할 수 있는 직원이 없어요","운영실에서 채용해요"])
		return
	HeroGuildPanelKit.caption_row(box,"누르면 이 방으로 옮겨요")
	var grid := _card_grid(box)
	var max_level := int(Content.data.guildManagement.balance.maxStaffLevel)
	for e in available:
		var definition: Dictionary = Content.data.guildManagement.employees[e.id]
		var where := "대기" if str(e.assignment).is_empty() else str(Content.data.guildManagement.facilities[e.assignment].name)
		var employee_id := str(e.id)
		HeroGuildPanelKit.portrait_card(grid,portrait_for(_employee_index(employee_id)),str(definition.name),where,int(e.level),max_level,str(definition.specialty)==id,false,func():
			view_state.officeDetail=""
			_command("assign",{"id":employee_id,"facility":id})
		,"특기" if str(definition.specialty)==id else "")

func _hire(box: Node) -> void:
	var keys: Array = Content.data.guildManagement.employees.keys()
	var candidates: Array = keys.filter(func(key): return not meta.guild.employees.any(func(e): return e.id==key))
	if candidates.is_empty():
		HeroGuildPanelKit.tiles(box,["모든 지원자를 채용했어요"]); return
	var selected := str(view_state.get("hireCandidate",""))
	if selected not in candidates: selected = str(candidates[0])
	var grid := _card_grid(box)
	for key in candidates:
		var definition: Dictionary = Content.data.guildManagement.employees[key]
		var candidate := str(key)
		HeroGuildPanelKit.portrait_card(grid,portrait_for(keys.find(key)),str(definition.name),str(definition.role),1,int(Content.data.guildManagement.balance.maxStaffLevel),false,candidate==selected,func():
			view_state.hireCandidate=candidate; _render()
		,str(Content.data.guildManagement.facilities[definition.specialty].name))
	var chosen: Dictionary = Content.data.guildManagement.employees[selected]
	var card := HeroGuildPanelKit.card_panel(box,HeroGuildPanelKit.MINT)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",6); card.add_child(column)
	var about := HeroGuildPanelKit.label(column,"%s · %s" % [chosen.name,chosen.description],12,HeroGuildPanelKit.INK,"body")
	about.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; about.custom_minimum_size.x=270
	HeroGuildPanelKit.cost_chips(column,chosen.hireCost,meta.guild.wallet,meta.wallet)
	var reason := HeroGuildRules.check(Content.data,meta,"hire",{"id":selected})
	HeroGuildPanelKit.action_button(column,"채용","" if reason.is_empty() else reason,func(): _command("hire",{"id":selected}),reason.is_empty(),"primary",Vector2(0,40))

const JOB_KINDS := {"construction":"공사","research":"연구","expedition":"탐험","training":"교육","manufacture":"제조","itemUpgrade":"아이템 강화","recipe":"조합법 연구"}

func _job_cards(box: Node) -> void:
	var jobs := _job_entries()
	if jobs.is_empty():
		HeroGuildPanelKit.tiles(box,["진행 중인 작업이 없어요"]); return
	var config: Dictionary = Content.data.guildManagement
	var now := Time.get_unix_time_from_system()
	for job in jobs:
		var known: Dictionary = {"construction":config.facilities,"research":config.research,"expedition":config.expeditions,"training":config.employees,"manufacture":Content.data.revivalStones,"itemUpgrade":Content.data.items,"recipe":config.recipes}[job.type]
		var card := HeroGuildPanelKit.card_panel(box)
		var column := VBoxContainer.new(); column.add_theme_constant_override("separation",7); card.add_child(column)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); column.add_child(row)
		var facility := _job_facility(job)
		var art_level := maxi(1,HeroGuildRules.level(meta.guild,facility))
		var span := maxf(1.0,float(job.endsAt)-float(job.get("startedAt",now)))
		var ring := HeroGuildPanelKit.ring(row,84,clampf((now-float(job.get("startedAt",now)))/span,0.0,1.0),world._texture(_room_art_name(facility,art_level)))
		ring.add_to_group("guild_ring"); ring.set_meta("startedAt",float(job.get("startedAt",now))); ring.set_meta("endsAt",float(job.endsAt))
		var info := VBoxContainer.new(); info.add_theme_constant_override("separation",2); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; info.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(info)
		var title := HeroGuildPanelKit.label(info,str(known[job.targetId].name),16)
		title.clip_text=true; title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; title.custom_minimum_size.x=150
		HeroGuildPanelKit.label(info,str(JOB_KINDS.get(str(job.type),"작업"))+(" · 직원 %d명" % job.employeeIds.size() if not job.get("employeeIds",[]).is_empty() else ""),12,HeroGuildPanelKit.MUTED,"body")
		if job.has("targetLevel"): HeroGuildPanelKit.label(info,"Lv.%d → Lv.%d" % [int(job.targetLevel)-1,int(job.targetLevel)],14,HeroGuildPanelKit.GOLD)
		var time := HeroGuildPanelKit.label(info,remaining(float(job.endsAt)-now),20,HeroGuildPanelKit.MINT,"number")
		time.add_to_group("guild_time"); time.set_meta("endsAt",job.endsAt)
		var buttons := HBoxContainer.new(); buttons.add_theme_constant_override("separation",6); column.add_child(buttons)
		var tickets := int(meta.guild.wallet.speedupTickets)
		HeroGuildPanelKit.action_button(buttons,"×1","15분 단축",func(): _command("speedup",{"id":job.id,"method":"ticket"}),tickets>0,"secondary",Vector2(0,42),Content.trimmed_texture(str(Content.data.resources.speedupTickets.image)))
		var finish_cost := ceili(maxf(0.0,float(job.endsAt)-now)/60.0)*int(config.balance.speedupCoinsPerMinute)
		var finish := HeroGuildPanelKit.action_button(buttons,HeroUI.amount(finish_cost),"바로 완료",func(): _command("speedup",{"id":job.id,"method":"coins"}),int(meta.guild.wallet.coins)>=finish_cost,"primary",Vector2(0,42),Content.trimmed_texture(str(Content.data.resources.coins.image)))
		finish.add_to_group("guild_speedup_cost"); finish.set_meta("endsAt",job.endsAt)

func _office_actions(box: Node) -> void:
	var cards := claim_list(meta.guild.pendingRewards)
	HeroGuildPanelKit.caption_row(box,"보관 중인 보상","생산·탐험·제조")
	if cards.is_empty(): HeroGuildPanelKit.tiles(box,["받을 보상이 아직 없어요"])
	else: HeroGuildPanelKit.reward_chips(box,cards)
	HeroGuildPanelKit.action_button(box,"보상 수령","",func(): _command("claim"),not cards.is_empty())
	HeroGuildPanelKit.button(box,"출동 준비",deploy,"secondary",16,Vector2(0,40))

# Guild pending rewards → reward cards for the shared reward popup (blueprints are listed by name).
static func claim_list(reward: Dictionary) -> Array:
	var cards: Array = []
	for key in HeroGuildState.RESOURCES:
		if int(reward.get(key,0))>0: cards.append({"type":"guildResource","contentId":key,"amount":int(reward[key])})
	var kinds := {"characterFragments":"characterFragment","weaponFragments":"weaponFragment","blessingFragments":"blessingFragment"}
	for key in kinds:
		for content_id in reward.get(key,{}):
			if int(reward[key][content_id])>0: cards.append({"type":kinds[key],"contentId":str(content_id),"amount":int(reward[key][content_id])})
	for grade in reward.get("revivalStones",{}):
		if int(reward.revivalStones[grade])>0: cards.append({"type":"revivalStone","contentId":str(grade),"amount":int(reward.revivalStones[grade])})
	if int(reward.get("supplyTickets",0))>0: cards.append({"type":"supplyTicket","contentId":"","amount":int(reward.supplyTickets)})
	return cards

func _construction_at(slot: int) -> Dictionary:
	for job in meta.guild.jobs:
		if job.type=="construction" and int(job.slot)==slot: return job
	return {}

func _room_label(slot: int) -> String:
	return "%d층 · 사무실 %d" % [floori(slot/3.0)+1,slot%3+1]

func _job_facility(job: Dictionary) -> String:
	match str(job.type):
		"construction": return str(job.targetId)
		"research": return "research"
		"recipe","itemUpgrade": return "workshop"
		"expedition": return "expedition"
		"manufacture": return "revival"
		"training": return "office"
	return "office"

func _job_entries() -> Array:
	var id := str(view_state.selectedFacility)
	if id=="office": return meta.guild.jobs
	return meta.guild.jobs.filter(func(job): return _job_matches(job,id) or (id.is_empty() and job.type=="construction" and int(job.slot)==int(view_state.slot)))

func _job_matches(job: Dictionary, id: String) -> bool:
	if _job_facility(job)==id: return true
	if str(job.type)=="research": return str(Content.data.guildManagement.research[job.targetId].facility)==id
	if str(job.type)=="recipe": return id=="research"
	return false

func _staff_can_hire() -> bool:
	return str(view_state.selectedFacility)=="office"

func _staff_entries() -> Array:
	var id := str(view_state.selectedFacility)
	if id=="office": return meta.guild.employees
	return meta.guild.employees.filter(func(employee):
		if str(employee.assignment)==id: return true
		return meta.guild.jobs.any(func(job): return employee.id in job.employeeIds and _job_matches(job,id))
	)

func _copy(box: Node, caption: String, color: String = "ink") -> void:
	var label := HeroMetaScreens._native_copy(box,caption,14,color)
	label.custom_minimum_size.x=290 if box.get_parent() is HeroImageSkin.DragScroll else 0

func _button(box: Node, caption: String, command: Callable, disabled: bool = false, primary: bool = false) -> void:
	var button := HeroImageSkin.image_button(box,caption,Rect2(0,0,270,44),command,"ops/primary" if primary else "ops/secondary",16)
	button.custom_minimum_size.x=44
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.disabled=disabled

func _pick(box: Node, options: Array, selected: int, change: Callable, disabled: bool = false) -> void:
	super._pick(box,options,selected,change,disabled)
	var picker := box.get_child(box.get_child_count()-1) as OptionButton
	picker.custom_minimum_size=Vector2(44,44); picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item=false
	picker.clip_text=true; picker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for state in ["normal","hover","pressed","disabled","focus"]: picker.add_theme_stylebox_override(state,HeroImageSkin.style("ops/secondary",Vector4(12,4,24,4)))

func _building_point(point: Vector2) -> Vector2:
	return _building_view.get_global_transform_with_canvas().affine_inverse()*point

func _blocked_at(point: Vector2) -> bool:
	# Existing crafting/detail overlays share this input group with native controls.
	for control in get_tree().get_nodes_in_group("input_blocker"):
		if not control is Control or not control.is_visible_in_tree() or control.get_viewport()!=get_viewport(): continue
		var local: Vector2=control.get_global_transform_with_canvas().affine_inverse()*point
		if Rect2(Vector2.ZERO,control.size).has_point(local): return true
	return false

func _begin_pointer(point: Vector2, pointer: int) -> void:
	if _pointer!=NO_POINTER: return
	var local := _building_point(point)
	if not Rect2(Vector2.ZERO,BUILDING_RECT.size).has_point(local) or _blocked_at(point): return
	_pointer=pointer; _start=local; _start_scroll=float(view_state.officeScroll); _dragging=false
	get_viewport().set_input_as_handled()

func _move_pointer(point: Vector2) -> void:
	var delta := _building_point(point)-_start
	if delta.length()>=8: _dragging=true
	if _dragging: view_state.officeScroll=_start_scroll-delta.y; _apply_scroll()
	get_viewport().set_input_as_handled()

func _finish_pointer(point: Vector2, canceled: bool = false) -> void:
	var local := _building_point(point)
	var tapped := not canceled and not _dragging and local.distance_to(_start)<8 and Rect2(Vector2.ZERO,BUILDING_RECT.size).has_point(local) and not _blocked_at(point)
	_pointer=NO_POINTER; _dragging=false
	if tapped:
		Sound.prime(); Sound.cue("buttonClick")
		var world_point := local+Vector2(0,float(view_state.officeScroll))
		if world.reward_hit(world_point):
			_command("claim"); get_viewport().set_input_as_handled(); return
		var floor_number := world.floor_at(world_point)
		if floor_number>HeroGuildState.floors(Content.data,meta.guild):
			view_state.panelOpen=true; view_state.panel="locked"; view_state.officeLockedFloor=floor_number
			view_state.selectedFacility=""; view_state.officeDetail=""; action_message=""; _render()
		else:
			var slot := world.slot_at(world_point)
			if slot>=0: _select("facility",slot)
	get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(_building_view) or not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed: _begin_pointer(event.position,event.index)
		elif _pointer==event.index: _finish_pointer(event.position,event.canceled)
	elif event is InputEventScreenDrag and _pointer==event.index: _move_pointer(event.position)
	elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_pointer(event.position,-1)
			elif _pointer==-1: _finish_pointer(event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and Rect2(Vector2.ZERO,BUILDING_RECT.size).has_point(_building_point(event.position)) and not _blocked_at(event.position):
			view_state.officeScroll=float(view_state.officeScroll)+(48 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -48)
			_apply_scroll(); get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pointer==-1: _move_pointer(event.position)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_WM_WINDOW_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
		_pointer=NO_POINTER; _dragging=false
		if is_instance_valid(_pane):
			for child in _pane.get_children():
				if child is HeroImageSkin.DragScroll: child._finish()
