class_name HeroSupplyScreen
extends HeroSupportScreen

var _open_one: Button
var _open_ten: Button
var _amount: Label
var _developer: Button
var _results: Array = []
var _showing_results := false
var _open_count := 1
var _shower: HeroLootShower

static func build(back: Callable, action: Callable) -> HeroSupplyScreen:
	var result := HeroSupplyScreen.new()
	result.kind = "supply"
	result.go = back
	result.act = action
	return result

func build_info() -> void:
	presentation.opening_finished.connect(_show_results)
	_build_ready()
	if Profile.meta.settings.developerMode:
		_developer = button(self,"보급권 +10",Rect2(22,356,155,44),func(): act.call("devTickets",10),16)

func _build_ready() -> void:
	_showing_results = false
	var info := info_panel()
	heading(info,"오늘의 보급",Rect2(580,109,286,30),18)
	art(info,Content.trimmed_texture("supplyTicket"),Rect2(584,155,34,34))
	copy(info,"보급권",Rect2(630,155,67,34))
	_amount = copy(info,HeroUI.amount(int(Profile.meta.wallet.supplyTickets)),Rect2(704,154,151,35),"number",18)
	copy(info,"지원 물자를 개봉해 성장 재료를 받아요",Rect2(580,207,289,52),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
	if HeroMetaScreens.ECONOMY_UI_APPROVED:
		button(self,"보급 확률",Rect2(190,356,140,44),func(): HeroEconomyUI.probabilities(self),16)
	_open_one = button(info,"1회 개봉",Rect2(580,282,290,44),func(): _open(1),16,true)
	_open_one.name = "SupplyOpen1"
	_open_ten = button(info,"10회 개봉",Rect2(580,330,290,44),func(): _open(10),16,true)
	_open_ten.name = "SupplyOpen10"
	var tickets := int(Profile.meta.wallet.supplyTickets)
	var cost := int(Content.data.supply.ticketCost)
	_open_one.disabled = tickets < cost
	_open_ten.disabled = tickets < cost*10
	state = "ready" if tickets >= cost else "insufficient"
	if tickets < cost: copy(info,"보급권이 필요해요",Rect2(580,251,290,22),"aux",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)

func _open(count: int) -> void:
	if _requesting or is_busy() or count not in [1,10]: return
	if (count == 1 and _open_one.disabled) or (count == 10 and _open_ten.disabled): return
	_requesting = true
	_open_one.disabled = true
	_open_ten.disabled = true
	# The synchronous callback pays+saves first. Store only returned actual results.
	var accepted = act.call("supplyOpen",count) if act.is_valid() else null
	_requesting = false
	if not accepted is Array or accepted.is_empty():
		_build_ready()
		return
	_results = accepted.duplicate(true)
	_open_count = count
	state = "opening"
	_amount.text = HeroUI.amount(int(Profile.meta.wallet.supplyTickets))
	if is_instance_valid(_developer): _developer.disabled = true
	presentation.start_open()

func is_busy() -> bool:
	return _showing_results or super.is_busy()

func _show_results() -> void:
	_showing_results = true
	state = "result10" if _open_count == 10 else "result1"
	var info := info_panel()
	heading(info,"보급 도착",Rect2(580,109,286,30),18)
	copy(info,"1회 개봉 결과" if _open_count == 1 else "10회 개봉 · 같은 보상은 합산",Rect2(580,143,286,22),"aux",13,"muted")
	var grouped := {}
	for reward: Dictionary in _results:
		var key := str(reward.type)+":"+str(reward.get("contentId",""))
		if not grouped.has(key): grouped[key] = reward.duplicate(true)
		else: grouped[key].amount += reward.amount
	var shower_groups: Array = []
	var scroll := HeroImageSkin.scroll(info,Rect2(580,174,290,150))
	scroll.name = "SupplyResults"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",0)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for reward: Dictionary in grouped.values():
		var display := HeroMetaScreens.reward_display(reward)
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 30
		row.add_theme_constant_override("separation",12)
		rows.add_child(row)
		var icon := art(row,display.texture,Rect2(0,0,28,28))
		if reward.type == "guildResource": icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.custom_minimum_size = Vector2(28,28)
		icon.modulate.a = 0.15
		shower_groups.append({"texture":display.texture,"amount":int(reward.amount),"target":icon})
		var caption := copy(row,display.name,Rect2(0,0,174,30),"body",14,"ink",HORIZONTAL_ALIGNMENT_LEFT,true)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.custom_minimum_size.y = 30
		var count := copy(row,"×"+HeroUI.amount(int(reward.amount)),Rect2(0,0,52,30),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
		count.custom_minimum_size = Vector2(52,30)
	var confirm := button(info,"확인",Rect2(580,330,290,44),_confirm,16,true)
	confirm.name = "SupplyResultsConfirm"
	# Loot pours out of the open box and lands on each result row.
	_shower = HeroLootShower.play(self,presentation.find_child("SupplyBody",true,false) as Control,shower_groups,func(index: int):
		var icon = shower_groups[index].target
		if is_instance_valid(icon): icon.modulate.a = 1.0
	,_open_count*31)
	_shower.capture_clock = capture_clock
	_fade_results()

func _process(_dt: float) -> void:
	_fade_results()

func advance_for_capture(dt: float) -> void:
	super.advance_for_capture(dt)
	if is_instance_valid(_shower): _shower.advance(dt)
	_fade_results()

func _fade_results() -> void:
	if _showing_results and is_instance_valid(_info):
		_info.modulate.a = smoothstep(0.85,1.0,presentation.action_age)

func _confirm() -> void:
	# Confirmation only dismisses presentation; it never invokes the payout.
	_results.clear()
	if is_instance_valid(_shower): _shower.queue_free()
	presentation.reset()
	if is_instance_valid(_developer): _developer.disabled = false
	_build_ready()
