class_name HeroAssociationFeedback
extends Control

# This layer only presents a result that the caller has already saved.
# It never chooses, grants, purchases, or writes a profile.
const DRAW_DURATION := 2.0
const BUY_DURATION := 0.8
const SUCCESS_HOLD := 2.0
const GLINT := "res://assets/ui/office-day-01/lobby-polish-01/operator_glint.png"
const BLUE := "#347bce"
const MINT := "#1e8276"
var capture_clock := false
var mode := ""
var payload: Dictionary = {}
var _age := 0.0
var _settled := false
var _focused := true
var _revealed := false
var _closed := false
var _frame: Control
var _art: TextureRect
var _name_label: Label
var _status_label: Label
var _confirm: Button
var _glint: TextureRect
var _burst: TextureRect
var _particles: Array[Dictionary] = []
var _center := Vector2.ZERO
var _value: Label
var _saved_value_text := ""
var _saved_value_color := Color.WHITE
var _value_restored := false

static func _existing(root: Control) -> HeroAssociationFeedback:
	if not is_instance_valid(root): return null
	return root.get_node_or_null("AssociationFeedback") as HeroAssociationFeedback

static func is_busy(root: Control) -> bool:
	var feedback := _existing(root)
	return feedback != null and not feedback._closed and (feedback.mode == "draw" or feedback._age < BUY_DURATION)

static func close_or_reveal(root: Control) -> bool:
	var feedback := _existing(root)
	if feedback == null or feedback._closed or feedback.mode != "draw": return false
	feedback._confirm_result()
	return true

static func _attach(root: Control, sequence: String) -> HeroAssociationFeedback:
	var old := _existing(root)
	if old != null:
		old._restore_value()
		root.remove_child(old)
		old.queue_free()
	var feedback := HeroAssociationFeedback.new()
	feedback.name = "AssociationFeedback"
	feedback.mode = sequence
	feedback.capture_clock = "--ui-preview" in OS.get_cmdline_user_args()
	feedback.mouse_filter = Control.MOUSE_FILTER_STOP if sequence == "draw" else Control.MOUSE_FILTER_IGNORE
	feedback.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	feedback.z_index = 30
	root.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sequence == "draw": feedback.add_to_group("input_blocker")
	return feedback

static func draw(root: Control, kind: String, id: String) -> HeroAssociationFeedback:
	var feedback := _attach(root,"draw")
	feedback.payload = {"kind":kind,"id":id}
	feedback._build_draw(kind,id)
	feedback._cue("supplyLatch")
	feedback._update_visuals()
	return feedback

# payload: id/name/type, old_level/new_level and old_bonus/new_bonus.
# Optional reward_kind/content_id lets an unlock use its existing content image.
static func play(root: Control, result: Dictionary) -> HeroAssociationFeedback:
	var feedback := _attach(root,"buy")
	feedback.payload = result.duplicate(true)
	feedback._build_buy(root)
	feedback._cue("purchase")
	feedback._update_visuals()
	return feedback

func _content_art(kind: String, id: String) -> Texture2D:
	match kind:
		"character":
			if Content.data.characters.has(id): return Content.actor_preview("characters",id,Content.data.characters[id].portraitSprite)
		"weapon":
			if Content.data.weapons.has(id): return Content.weapon_icon(id)
		"blessing":
			if Content.data.blessings.has(id): return Content.trimmed_texture(Content.data.blessings[id].image)
	return null

func _content_name(kind: String, id: String) -> String:
	var collection: Dictionary = Content.data.get({"character":"characters","weapon":"weapons","blessing":"blessings"}.get(kind,""),{})
	return str(collection[id].name) if collection.has(id) else id

func _build_draw(kind: String, id: String) -> void:
	var dim := ColorRect.new()
	dim.name = "AssociationFeedbackDim"
	dim.color = Color(0.05,0.09,0.14,0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = HeroDesk.panel(self,Rect2(87.5,38.5,740,335),"AssociationFeedbackFrame")
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var kind_name: String = {"character":"각성자 모집","weapon":"무기 보급","blessing":"축복 계승"}.get(kind,"협회 뽑기")
	HeroDesk.text(_frame,kind_name+" 결과",Rect2(28,12,684,32),"brand",22,BLUE,HORIZONTAL_ALIGNMENT_CENTER).name = "AssociationFeedbackTitle"
	_center = Vector2(457.5,169.5)
	_burst = _image(_frame,Content.trimmed_texture("supplyOpeningBurst"),Rect2(258,25,224,224),"AssociationFeedbackBurst")
	_burst.modulate = Color(0.59,0.84,1.0,0.0)
	_art = _image(_frame,_content_art(kind,id),Rect2(283,51,174,160),"AssociationFeedbackArt")
	_name_label = HeroDesk.text(_frame,_content_name(kind,id),Rect2(42,218,656,34),"brand",HeroDesk.fit(_content_name(kind,id),"brand",25,656),HeroDesk.INK,HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "AssociationFeedbackName"
	_status_label = HeroDesk.text(_frame,"새로운 %s 해금 완료" % {"character":"각성자","weapon":"무기","blessing":"축복"}.get(kind,"콘텐츠"),Rect2(42,254,656,24),"control",14,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.name = "AssociationFeedbackStatus"
	_confirm = HeroDesk.key(_frame,"바로 보기",Rect2(290,286,160,44),_confirm_result,"navy",16)
	_confirm.name = "AssociationFeedbackConfirm"
	_glint = _image(self,load(GLINT),Rect2(315,74,76,180),"AssociationFeedbackGlint")
	_glint.modulate = Color(0.54,0.78,1.0,0.0)
	_make_particles(12,110.0,BLUE)

func _build_buy(root: Control) -> void:
	var target := root.find_child("CurrentEffect",true,false) as Control
	var is_stat: bool = str(payload.get("type","stat")) == "stat"
	if is_stat:
		_value = root.find_child("CurrentEffectValue",true,false) as Label
		if is_instance_valid(_value):
			_saved_value_text = _value.text
			_saved_value_color = _value.modulate
			_value.text = _bonus(float(payload.get("old_bonus",0.0)))
	if target == null: target = root.find_child("AssociationDetailTitle",true,false) as Control
	var area := _relative_rect(target) if is_instance_valid(target) else Rect2(392,204,464,38)
	_center = area.get_center()
	_glint = _image(self,load(GLINT),Rect2(area.position-Vector2(26,7),Vector2(80,area.size.y+14)),"AssociationFeedbackGlint")
	_glint.modulate = Color(0.49,0.82,1.0,0.0)
	_glint.set_meta("sequence_area",area)
	_burst = _image(self,Content.trimmed_texture("supplyOpeningBurst"),Rect2(_center-Vector2(70,70),Vector2(140,140)),"AssociationFeedbackBurst")
	_burst.modulate = Color(0.47,0.84,0.9,0.0)
	_make_particles(8,48.0,MINT)
	var banner := HeroDesk.panel(self,Rect2(392,282,464,54),"AssociationFeedbackSuccess")
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption := "강화 완료 · %d회 → %d회" % [int(payload.get("old_level",0)),int(payload.get("new_level",1))] if is_stat else "해금 완료 · "+str(payload.get("name","협회 지원"))
	var text_left := 16.0
	if not is_stat:
		var content := _content_art(str(payload.get("reward_kind","")),str(payload.get("content_id","")))
		if content != null:
			_art = _image(banner,content,Rect2(10,6,42,42),"AssociationFeedbackArt")
			text_left = 58.0
	_status_label = HeroDesk.text(banner,caption,Rect2(text_left,4,448-text_left,24),"control",15,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.name = "AssociationFeedbackStatus"
	var change := "현재 효과 %s → %s" % [_bonus(float(payload.get("old_bonus",0.0))),_bonus(float(payload.get("new_bonus",0.0)))] if is_stat else "다음 출동부터 사용할 수 있습니다."
	_name_label = HeroDesk.text(banner,change,Rect2(text_left,28,448-text_left,20),"body",12,HeroDesk.INK,HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "AssociationFeedbackChange"

func _image(parent: Node, texture: Texture2D, area: Rect2, node_name: String) -> TextureRect:
	var image := HeroUI.fixed_art(parent,texture,area)
	image.name = node_name
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return image

func _make_particles(count: int, travel: float, tint: String) -> void:
	var texture := Content.trimmed_texture("supplyOpeningBurst")
	for index in count:
		var direction := Vector2.from_angle(TAU*float(index)/float(count)-PI*0.5)
		var diameter := 9.0+float(index%3)*2.0
		var spark := _image(self,texture,Rect2(_center-Vector2.ONE*diameter*0.5,Vector2.ONE*diameter),"AssociationFeedbackSpark_%d" % index)
		spark.modulate = Color(tint)
		spark.modulate.a = 0.0
		_particles.append({"node":spark,"travel":direction*travel,"diameter":diameter})

func _relative_rect(target: Control) -> Rect2:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var rect := target.get_global_rect()
	return Rect2(inverse*rect.position,inverse.basis_xform(rect.size))

func _bonus(value: float) -> String:
	var id := str(payload.get("id",""))
	if Content.data.upgrades.has(id): return HeroEconomyUI._bonus(Content.data.upgrades[id],value)
	return "+"+("%.2f" % value).rstrip("0").rstrip(".")+str(payload.get("bonus_suffix",""))

func _process(dt: float) -> void:
	if not capture_clock: advance_for_capture(minf(dt,0.05))

func advance_for_capture(dt: float) -> void:
	if _closed or not _focused: return
	_age += maxf(0.0,dt)
	if mode == "draw" and not _revealed and _age >= 0.55:
		_revealed = true
		_cue("supplyFanfare")
	if mode == "draw" and _age >= DRAW_DURATION: _settled = true
	if mode == "buy" and _age >= BUY_DURATION:
		_settled = true
		_restore_value()
	_update_visuals()
	if mode == "buy" and _age >= BUY_DURATION+SUCCESS_HOLD: _close()

func _update_visuals() -> void:
	if not is_instance_valid(_glint): return
	var duration := DRAW_DURATION if mode == "draw" else BUY_DURATION
	var reveal := smoothstep(0.55,0.73,_age) if mode == "draw" else smoothstep(0.0,0.18,_age)
	if is_instance_valid(_art): _art.modulate.a = reveal
	if is_instance_valid(_name_label): _name_label.modulate.a = reveal
	if is_instance_valid(_status_label): _status_label.modulate.a = reveal
	var scan := clampf(_age/(0.55 if mode == "draw" else BUY_DURATION),0.0,1.0)
	if mode == "draw":
		_glint.position.x = lerpf(330.0,515.0,scan)
	else:
		var area: Rect2 = _glint.get_meta("sequence_area")
		_glint.position.x = lerpf(area.position.x-26.0,area.end.x-50.0,scan)
		if is_instance_valid(_value) and not _value_restored:
			_value.text = _bonus(lerpf(float(payload.get("old_bonus",0.0)),float(payload.get("new_bonus",0.0)),smoothstep(0.1,BUY_DURATION,_age)))
			_value.modulate = _saved_value_color.lerp(Color(0.4,0.85,0.92),sin(clampf(_age/BUY_DURATION,0.0,1.0)*PI)*0.5)
	_glint.modulate.a = sin(scan*PI)*0.5 if not _settled else 0.0
	var burst_start := 0.55 if mode == "draw" else 0.0
	var burst_span := 0.7 if mode == "draw" else BUY_DURATION
	var particle_age := clampf((_age-burst_start)/burst_span,0.0,1.0)
	var glow := sin(particle_age*PI)*0.32 if _age >= burst_start and not _settled else 0.0
	if is_instance_valid(_burst): _burst.modulate.a = glow
	for particle: Dictionary in _particles:
		var spark: TextureRect = particle.node
		spark.position = _center+Vector2(particle.travel)*(1.0-pow(1.0-particle_age,2.0))-Vector2.ONE*float(particle.diameter)*0.5
		spark.modulate.a = sin(particle_age*PI)*0.65 if _age >= burst_start and not _settled else 0.0
	if is_instance_valid(_confirm):
		var caption := HeroDesk.key_label(_confirm)
		if caption != null: caption.text = "확인" if _settled else "바로 보기"
	if _age >= duration: _restore_value()

func _confirm_result() -> void:
	if _closed: return
	if not _settled:
		_settle(true)
	else:
		_close()

func _settle(with_sound: bool) -> void:
	if mode == "draw" and not _revealed:
		_revealed = true
		if with_sound: _cue("supplyFanfare")
	_age = DRAW_DURATION if mode == "draw" else BUY_DURATION
	_settled = true
	_restore_value()
	_update_visuals()

func _cue(cue: String) -> void:
	if _focused and "--ui-preview" not in OS.get_cmdline_user_args(): Sound.cue(cue)

func _restore_value() -> void:
	if _value_restored: return
	_value_restored = true
	if is_instance_valid(_value):
		_value.text = _saved_value_text
		_value.modulate = _saved_value_color

func _close() -> void:
	_closed = true
	_restore_value()
	set_process(false)
	queue_free()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_focused = false
		if is_inside_tree(): _settle(false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_focused = true

func _exit_tree() -> void:
	_restore_value()
	_closed = true
	set_process(false)
