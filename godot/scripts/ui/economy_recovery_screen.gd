class_name HeroEconomyRecoveryScreen
extends HeroRecoveryScreen

# The existing request/claim animation remains owned by HeroRecoveryScreen.
static func build(navigate: Callable, action: Callable) -> HeroRecoveryScreen:
	var screen := HeroEconomyRecoveryScreen.new()
	screen.kind = "recovery"
	screen.go = navigate
	screen.act = action
	screen.set_meta("economy_ui_preview",true)
	return screen

func build_info() -> void:
	var pending: Dictionary = Profile.meta.offlineReward.pendingRewards
	var ready := _has_rewards(pending)
	if state != "claimed" or ready: state = "ready" if ready else "empty"
	var panel := info_panel()
	heading(panel,"회수품 정산",Rect2(580,108,194,28),18)
	_status = copy(panel,"정산 완료" if state == "claimed" else "도착 완료" if ready else "대기 중",Rect2(778,110,91,24),"body",13,"accent",HORIZONTAL_ALIGNMENT_RIGHT)
	var scroll := HeroImageSkin.scroll(panel,Rect2(580,145,290,160))
	scroll.name = "RecoveryRewardCollection"
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation",4)
	scroll.add_child(rows)
	for key in Content.data.offline.baseRewards:
		var definition: Dictionary = Content.data.resources[key]
		_reward_row(rows,str(definition.name),Content.trimmed_texture(str(definition.image)),int(pending.get(key,0)))
	for grade in pending.get("revivalStones",{}):
		if int(pending.revivalStones[grade]) <= 0: continue
		var stone: Dictionary = Content.data.revivalStones[grade]
		_reward_row(rows,str(stone.name),Content.trimmed_texture(str(stone.image)),int(pending.revivalStones[grade]))
	for pair in [["characterFragments","characters"],["weaponFragments","weapons"],["blessingFragments","blessings"]]:
		for id in pending.get(pair[0],{}):
			if int(pending[pair[0]][id]) <= 0: continue
			var definition: Dictionary = Content.data[pair[1]][id]
			var texture := Content.weapon_icon(id) if pair[1] == "weapons" else Content.actor_preview("characters",id,definition.portraitSprite) if pair[1] == "characters" else Content.trimmed_texture(str(definition.image))
			_reward_row(rows,str(definition.name)+" 조각",texture,int(pending[pair[0]][id]))
	var stored := float(Profile.meta.offlineReward.get("accumulatedSeconds",0.0))
	var cap := float(HeroGuildSupport.effects(Content.data,Profile.meta.guild).offlineCapHours)
	var interval := float(Content.data.offline.coinIntervalMinutes)*60.0
	var next_minutes := ceili((interval-fmod(stored,interval))/60.0)
	var stored_minutes := floori(stored/60.0)
	var duration := "%d시간" % (stored_minutes/60)
	if stored_minutes%60 > 0: duration += "%d분" % (stored_minutes%60)
	copy(panel,"%s / %d시간 · %s" % [duration,int(cap),"보관 상한 도달" if stored >= cap*3600.0 else "다음 회수 %d분" % next_minutes],Rect2(580,307,290,22),"body",13,"muted",HORIZONTAL_ALIGNMENT_CENTER)
	_claim = button(panel,"보상 수령" if ready else "정산 완료" if state == "claimed" else "회수품 대기 중",Rect2(580,330,290,44),start_claim,16,true)
	_claim.name = "RecoveryClaim"
	_claim.disabled = not ready or _requesting or is_busy()
	if not presentation.claim_finished.is_connected(_claim_finished): presentation.claim_finished.connect(_claim_finished)
	_build_developer_actions()

func _has_rewards(_pending: Dictionary) -> bool:
	return HeroMeta.has_offline_rewards(Profile.meta)

func _reward_row(parent: Node, caption: String, texture: Texture2D, amount: int) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(276,36)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	art(row,texture,Rect2(2,3,30,30)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	copy(row,caption,Rect2(41,3,150,30),"body",14)
	copy(row,HeroUI.amount(amount),Rect2(191,3,80,30),"number",18,"ink",HORIZONTAL_ALIGNMENT_RIGHT)
