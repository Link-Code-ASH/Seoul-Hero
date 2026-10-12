class_name HeroGraphicsPreview
extends Control

const VFX = preload("res://scenes/combat/timed_vfx.tscn")
var back: Callable
var _actors: Array = []
var _states: Array = []
var _effects: Array = []
var _age := 0.0
var _paused := false
var _direction := Vector2.RIGHT
var _preset: Dictionary = {}
var _labels: Array = []
var _rows: Array = []
var _pages: Array = []
var _human_pages := 0
var _page := 0
var _page_button: Button
var _motion := "move"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := TextureRect.new()
	background.texture = Content.texture(Content.visuals.maps.seoul.texture)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(background)
	_preset = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/effects.json"))
	var humans: Array = []
	for id in Content.data.characters:
		humans.append(["characters",id,Content.data.characters[id].name,108.0])
	if Content.visuals.get("npcs",{}).has("hanSeoa"): humans.append(["npcs","hanSeoa","한서아",108.0])
	for offset in range(0,humans.size(),5): _pages.append(humans.slice(offset,offset+5))
	_human_pages = _pages.size()
	var monsters: Array = []
	for id in Content.data.enemies:
		var data: Dictionary = Content.data.enemies[id]
		monsters.append(["enemies",id,data.name,float(data.radius)*3.4])
		if monsters.size() == 5: _pages.append(monsters); monsters = []
	if not monsters.is_empty(): _pages.append(monsters)
	var ui := HeroUI.root(); add_child(ui)
	HeroUI.framed_button(ui,"이전",Rect2(14,10,72,44),func(): if back.is_valid(): back.call())
	HeroUI.fixed_text(ui,"그래픽 확인",Rect2(104,12,185,44),20,HeroUI.ink(ui,"scene"))
	_page_button = HeroUI.framed_button(ui,"",Rect2(300,10,326,44),func(): _show_page((_page+1)%_pages.size()))
	HeroUI.framed_button(ui,"정지 / 재생",Rect2(742,10,155,44),func(): _paused = not _paused)
	for i in range(5):
		var caption := HeroUI.fixed_text(ui,"",Rect2(28+i*178,270,146,41),14,HeroUI.ink(ui,"scene"),true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_labels.append(caption)
	var controls := [["←",Vector2.LEFT],["↑",Vector2.UP],["↓",Vector2.DOWN],["→",Vector2.RIGHT]]
	for i in range(controls.size()):
		var vector: Vector2 = controls[i][1]
		HeroUI.framed_button(ui,controls[i][0],Rect2(18+i*58,315,52,44),func(): _direction = vector)
	var motions := [["대기","idle"],["이동","move"],["돌진","charge"],["공격","attack"],["피격","hit"],["사망","death"]]
	for i in range(motions.size()):
		var mode: String = motions[i][1]
		HeroUI.framed_button(ui,motions[i][0],Rect2(275+i*104,315,98,44),func(): _set_motion(mode))
	var kinds := {"발사":"muzzle","적중":"impact","검격":"slash","폭격":"explosion","지뢰":"mine","번개":"chain","치명타":"critical","사망":"death"}
	var index := 0
	for label in kinds:
		var kind: String = kinds[label]
		HeroUI.framed_button(ui,label,Rect2(18+index*110,362,104,44),func(): play_effect(kind))
		index += 1
	_show_page(0)

func _show_page(index: int) -> void:
	_page = index
	for actor in _actors: actor.queue_free()
	_actors.clear(); _states.clear(); _rows = _pages[index]
	for effect in _effects: effect.queue_free()
	_effects.clear(); _motion = "move"
	_page_button.text = "인간형 · %d / %d  →" % [index+1,_human_pages] if index < _human_pages else "몬스터 · %d / %d  →" % [index-_human_pages+1,_pages.size()-_human_pages]
	for i in range(5):
		_labels[i].text = _rows[i][2] if i < _rows.size() else ""
	for i in range(_rows.size()):
		var row: Array = _rows[i]
		var profile: Dictionary = Content.visuals.get(row[0],{}).get(row[1],{})
		var actor: Node2D
		if profile.get("rig","") == "sd": actor = HeroSDVisual.new()
		else: actor = HeroGroundedVisual.new()
		add_child(actor); _configure_actor(actor,row)
		var state := {"id":i,"pos":Vector2(101+i*178,252),"hp":100.0,"maxHp":100.0,"age":0.0,"action":"move","facing":1.0}
		_actors.append(actor); _states.append(state); actor.set_meta("height",row[3])
		actor.update_state(state,0,row[3])

func _configure_actor(actor: Node2D, row: Array) -> void:
	if actor is HeroGroundedVisual: actor.configure(row[1])
	else: actor.configure(row[1],Content.visuals[row[0]][row[1]])

func _set_motion(mode: String) -> void:
	if mode in ["attack","hit","death"]:
		var event: String = {"attack":"actorAttack","hit":"actorHit","death":"actorDeath"}[mode]
		for actor in _actors: actor.action(event,{"direction":_direction})
	else: _motion = mode

func _process(dt: float) -> void:
	advance(0.0 if _paused else dt)

func advance(dt: float) -> void:
	_age += dt
	for i in range(_actors.size()):
		var actor: Node2D = _actors[i]; var state: Dictionary = _states[i]
		if actor.dead and actor.death_age > .85: _configure_actor(actor,_rows[i])
		var cycle := fmod(_age,4.0)
		state.action = "warning" if _motion == "charge" and cycle > 2.5 and cycle < 3.2 else "dash" if _motion == "charge" and cycle >= 3.2 else "idle" if _motion == "idle" else "move"
		if state.action != "idle" and state.action != "warning" and not actor.dead:
			state.pos += _direction*(230.0 if state.action == "dash" else 105.0)*dt
		var origin := Vector2(101+i*178,252)
		if state.pos.distance_to(origin) > 28.0: state.pos = origin-_direction*22.0
		if _direction.x != 0: state.facing = _direction.x
		state.age = _age
		actor.update_state(state,dt,float(actor.get_meta("height")))
	for effect in _effects: effect.tick(dt)
	for effect in _effects.duplicate():
		if effect.finished: _effects.erase(effect); effect.queue_free()

func play_effect(kind: String) -> void:
	var effect: HeroTimedVfx = VFX.instantiate(); add_child(effect)
	effect.configure({"kind":kind,"pos":Vector2(455,215),"target":Vector2(670,215),"radius":65.0 if kind in ["explosion","mine","slash"] else 30.0,"angle":0.0,"arc":PI/3},_preset[kind])
	_effects.append(effect)
	if kind in ["muzzle","slash"] and not _actors.is_empty(): _actors[0].action("actorAttack",{})
	if kind in ["impact","critical"] and _actors.size()>2: _actors[2].action("actorHit",{"direction":Vector2.RIGHT})
	if kind == "death" and _actors.size()>2: _actors[2].action("actorDeath",{})
