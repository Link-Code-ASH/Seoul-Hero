class_name HeroRecoveryScreen
extends HeroSupportScreen

var _claim: Button
var _status: Label
var _developer_buttons: Array[Button] = []

static func build(navigate: Callable, action: Callable) -> HeroRecoveryScreen:
	var screen := HeroRecoveryScreen.new()
	screen.kind = "recovery"
	screen.go = navigate
	screen.act = action
	return screen

func build_info() -> void:
	var pending: Dictionary = Profile.meta.offlineReward.pendingRewards
	var ready := _has_rewards(pending)
	if state != "claimed" or ready:
		state = "ready" if ready else "empty"
	var panel := info_panel()
	heading(panel,"회수품 정산",Rect2(580,108,194,28),18)
	_status = copy(panel,"정산 완료" if state == "claimed" else "도착 완료" if ready else "대기 중",Rect2(778,110,91,24),"aux",13,"accent",HORIZONTAL_ALIGNMENT_RIGHT)
	var entries: Array[Dictionary] = [{"name":"협회 코인","texture":Content.trimmed_texture("associationCoin"),"amount":int(pending.associationCoins)}]
	for grade in ["low","mid","high"]:
		var stone: Dictionary = Content.data.revivalStones[grade]
		entries.append({"name":str(stone.name),"texture":Content.trimmed_texture(str(stone.image)),"amount":int(pending.revivalStones.get(grade,0))})
	if int(pending.supplyTickets) > 0:
		entries.append({"name":"보급권","texture":Content.trimmed_texture("supplyTicket"),"amount":int(pending.supplyTickets)})
	for index in range(entries.size()):
		var row: Dictionary = entries[index]
		var y := 145.0 + index * 36.0
		art(panel,row.texture,Rect2(583,y,30,30))
		copy(panel,str(row.name),Rect2(625,y,138,30),"body",14)
		copy(panel,HeroUI.amount(int(row.amount)),Rect2(770,y,92,30),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
	if entries.size() < 5:
		copy(panel,"다음 회수품은 자동으로 모입니다",Rect2(582,301,286,22),"aux",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_claim = button(panel,"보상 수령" if ready else "정산 완료" if state == "claimed" else "회수품 대기 중",Rect2(580,330,290,44),start_claim,16,true)
	_claim.name = "RecoveryClaim"
	_claim.disabled = not ready or _requesting or is_busy()
	if not presentation.claim_finished.is_connected(_claim_finished):
		presentation.claim_finished.connect(_claim_finished)
	_build_developer_actions()

func _has_rewards(pending: Dictionary) -> bool:
	if int(pending.associationCoins) > 0 or int(pending.supplyTickets) > 0:
		return true
	for amount in pending.revivalStones.values():
		if int(amount) > 0:
			return true
	return false

func start_claim() -> void:
	if _requesting or is_busy() or not is_instance_valid(_claim) or _claim.disabled:
		return
	_requesting = true
	_claim.disabled = true
	_set_developer_disabled(true)
	# The existing action grants and saves once before animation begins.
	var claimed: Variant = act.call("claimOffline","")
	_requesting = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not claimed is Dictionary or claimed.is_empty():
		state = "empty"
		build_info()
		return
	state = "claiming"
	_status.text = "수령 중"
	_claim.text = "수령 중"
	presentation.start_claim()

func _claim_finished() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	# Completion updates only presentation; rewards were already granted.
	state = "claimed"
	build_info()

func _build_developer_actions() -> void:
	for control in _developer_buttons:
		if is_instance_valid(control):
			control.hide()
			control.queue_free()
	_developer_buttons.clear()
	if not bool(Profile.meta.settings.developerMode):
		return
	_developer_buttons.append(button(self,"개발 · +1시간",Rect2(22,356,155,44),func(): _advance_offline(3600),16))
	_developer_buttons.append(button(self,"+24시간",Rect2(185,356,128,44),func(): _advance_offline(86400),16))
	_set_developer_disabled(_requesting or is_busy())

func _set_developer_disabled(value: bool) -> void:
	for control in _developer_buttons:
		if is_instance_valid(control):
			control.disabled = value

func _advance_offline(seconds: int) -> void:
	if _requesting or is_busy():
		return
	act.call("offlineAdvance",seconds)
