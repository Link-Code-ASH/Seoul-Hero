class_name HeroSDPreview
extends HeroMobileScreen

# A disposable run drives the same body / attack VFX path as combat.
# It never enters Main's active run and never writes the profile or checkpoint.
var back: Callable
var _run: HeroRun
var _grid := HeroSpatial.new()
var _attacks := HeroAttacks.new(_grid)
var _presentations: Array[HeroCombatPresentation] = []
var _stage_labels: Array[Label] = []
var _target: Dictionary
var _age := 0.0
var _moving := true
var _paused := false
var _auto_attack := true
var _facing := 1.0
var _dead := false
var _status: Label
var _auto_button: Button
var _motion_buttons: Dictionary = {}
var _weapon_buttons: Dictionary = {}

func _ready() -> void:
	theme = HeroUI.theme()
	HeroUI.background(self,Content.visuals.maps.seoul.texture,Color(0.48,0.57,0.66))
	HeroUI.framed_button(self,"이전",Rect2(14,10,72,44),func(): if back.is_valid(): back.call())
	HeroUI.fixed_text(self,"송진우 · SD 캐릭터 샘플",Rect2(102,10,365,44),21,HeroUI.ink(self,"scene"))
	_status = HeroUI.fixed_text(self,"이동",Rect2(476,10,102,44),14,HeroUI.ink(self,"scene"))
	HeroUI.framed_button(self,"정지 / 재생",Rect2(581,10,125,44),func(): _paused = not _paused)
	_auto_button = HeroUI.framed_button(self,"자동 공격 끄기",Rect2(714,10,187,44),_toggle_attack)

	_run = HeroRun.new(Content.data,{"map":"seoul","depth":1,"character":"awakener","weapon":"manaSword","blessing":"","weekly":"hardened"},Profile.meta)
	_target = HeroSpawn.spawn(_run,"copperCrab",false,1.0,0.0,[],Vector2(105,0))
	_target.hp = 1000000.0; _target.maxHp = _target.hp; _target.rewardEligible = false
	_target.action = "idle"
	_grid.rebuild(_run.enemies)
	_stage(Rect2(14,64,432,243),Vector2(148,211),1.8,"확대 보기")
	_stage(Rect2(458,64,443,243),Vector2(183,164),412.0/float(_run.map.arenaHeight),"전투 화면 크기 · 915×412 기준")
	for preview in _presentations: preview.sync(0.0)

	var motions := [["idle","대기"],["move","이동"],["hit","피격"],["death","사망"],["attack","공격 반응"]]
	for i in range(motions.size()):
		var kind: String = motions[i][0]
		_motion_buttons[kind] = HeroUI.framed_button(self,motions[i][1],Rect2(14+i*138,315,130,44),func(): _motion(kind),kind == "move")
	HeroUI.framed_button(self,"좌우 전환",Rect2(714,315,187,44),_flip)
	HeroUI.fixed_text(self,"공격 효과",Rect2(16,367,98,44),14,HeroUI.ink(self,"scene"))
	var weapons := [["manaSword","검기"],["manaShotgun","산탄"],["guardianDaggers","회전 마력"],["chainLightning","번개"]]
	for i in range(weapons.size()):
		var id: String = weapons[i][0]
		_weapon_buttons[id] = HeroUI.framed_button(self,weapons[i][1],Rect2(120+i*136,367,128,44),func(): _weapon(id),id == "manaSword")
	HeroUI.fixed_text(self,"캐릭터 주변에서 효과 발동",Rect2(668,367,233,44),13,HeroUI.ink(self,"scene"))
	super._ready()

func _stage(rect: Rect2, anchor: Vector2, factor: float, label: String) -> void:
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	add_child(stage); HeroUI.place(stage,rect)
	HeroUI.sheet(stage,"glass",Rect2(Vector2.ZERO,rect.size))
	_stage_labels.append(HeroUI.fixed_text(stage,label,Rect2(16,4,rect.size.x-32,36),14))
	var preview := HeroCombatPresentation.new()
	stage.add_child(preview)
	preview.position = anchor; preview.scale = Vector2.ONE*factor
	preview.set_meta("anchor",anchor)
	preview.set_meta("stage_size",rect.size)
	preview.visible_world = Rect2(-anchor/factor,rect.size/factor)
	preview.bind(_run)
	_presentations.append(preview)

func _flip() -> void:
	_facing *= -1.0; _run.player.facing = _facing
	_target.pos = _run.player.pos-(_target.pos-_run.player.pos)
	for preview in _presentations:
		var anchor: Vector2 = preview.get_meta("anchor")
		var stage_size: Vector2 = preview.get_meta("stage_size")
		preview.position.x = anchor.x if _facing > 0 else stage_size.x-anchor.x
		preview.visible_world = Rect2(-preview.position/preview.scale.x,stage_size/preview.scale.x)
		preview.sync(0.0)

func _process(dt: float) -> void:
	if _run == null or _paused: return
	_age += dt
	_run.combat_time += dt
	if _moving and not _dead:
		_run.player.pos = Vector2(sin(_age*1.8)*22.0,0)
	_run.player.moving = _moving and not _dead
	_run.player.facing = _facing
	_target.age = _age
	_target.hp = _target.maxHp
	var slot: Dictionary = _run.owned[0]
	var stats := _run.weapon_stats(slot)
	_target.pos = _run.player.pos+Vector2(minf(105.0,stats.range*0.82)*_facing,0)
	_target.flash = maxf(0.0,float(_target.flash)-dt)
	_grid.rebuild(_run.enemies)
	if _auto_attack and not _dead:
		_attacks.update(_run,dt)
	else:
		# Existing flights finish, but orbit/cooldowns create no new attacks.
		_attacks._process_pending(_run,dt)
		_attacks._projectiles(_run,dt)
	# The preview only needs the presentation event stream, not an effects history.
	_run.effects.clear()
	for preview in _presentations: preview.sync(dt)

func _toggle_attack() -> void:
	_auto_attack = not _auto_attack
	_auto_button.text = "자동 공격 끄기" if _auto_attack else "자동 공격 켜기"
	if _auto_attack: _run.owned[0].cooldown = 0.0

func _restore() -> void:
	if not _dead: return
	_dead = false
	_run.player.hp = _run.stats.maxHp
	for preview in _presentations: preview.sync(0.0)

func _motion(kind: String) -> void:
	_restore()
	match kind:
		"idle","move":
			_moving = kind == "move"
			_status.text = "이동" if _moving else "대기"
		"hit":
			_status.text = "피격"
			_run.visual_event.emit({"kind":"actorHit","actorId":"player","direction":Vector2(-_facing,0),"pos":_run.player.pos})
		"death":
			_dead = true; _status.text = "사망"
			_run.player.hp = 0.0
			_run.visual_event.emit({"kind":"actorDeath","actorId":"player","pos":_run.player.pos})
		"attack":
			_status.text = "공용 공격"
			_run.owned[0].cooldown = 0.0
			_attacks.update(_run,0.001)
			# Orbit is continuously active and reuses the same optional body reaction.
			if _run.data.weapons[_run.owned[0].id].behavior == "orbit":
				_run.visual_event.emit({"kind":"actorAttack","actorId":"player","pos":_run.player.pos,"angle":0.0,"weaponId":_run.owned[0].id})
	for id in _motion_buttons:
		_motion_buttons[id].add_theme_stylebox_override("normal",HeroUI.material("control",-1,"normal",id == kind))
	for preview in _presentations: preview.sync(0.0)

func _weapon(id: String) -> void:
	_restore()
	_run.clear_combat()
	_run.owned = [{"id":id,"level":1,"branch":"","cooldown":0.0}]
	_run.enemies = [_target]
	var enlarged := _presentations[0]
	var orbit: bool = _run.data.weapons[id].behavior == "orbit"
	var factor := minf(0.9,97.0/(_run.weapon_stats(_run.owned[0]).range+20.0)) if orbit else 1.8
	enlarged.scale = Vector2.ONE*factor
	var anchor := Vector2(216,143) if orbit else Vector2(148,211)
	enlarged.set_meta("anchor",anchor)
	enlarged.position = Vector2(anchor.x if _facing > 0 else 432-anchor.x,anchor.y)
	enlarged.visible_world = Rect2(-enlarged.position/factor,Vector2(432,243)/factor)
	_stage_labels[0].text = "회전 효과 범위 보기" if orbit else "확대 보기"
	for preview in _presentations: preview.sync(0.0)
	for weapon_id in _weapon_buttons:
		_weapon_buttons[weapon_id].add_theme_stylebox_override("normal",HeroUI.material("control",-1,"normal",weapon_id == id))
