class_name HeroLobbyScreen
extends RefCounted

class TerminalFlow extends Node:
	var material: ShaderMaterial
	var period := 2.4
	var clock := 0.0
	var _hidden := false
	func _ready() -> void:
		get_parent().visibility_changed.connect(_visibility_changed)
		_visibility_changed()
	func _visibility_changed() -> void:
		set_process(not _hidden and get_parent().is_visible_in_tree())
	func _process(delta: float) -> void:
		advance_for_capture(minf(delta,0.04))
	func advance_for_capture(seconds: float) -> void:
		clock = fmod(clock+seconds,period)
		material.set_shader_parameter("progress",clock/period)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): _visibility_changed()

# Audio truth stays in Sound; the cabinet and sound waves follow its visual crossfade.
class MusicStateIcon extends Control:
	const ART := "res://assets/ui/office-day-01/lobby-polish-01/"
	var _on: Texture2D
	var _off: Texture2D
	var _enabled := true
	var _level := 1.0
	var _start_level := 1.0
	var _transition := 0.15
	var _hidden := false
	var _capture_override := -1
	var clock := 0.0
	func _ready() -> void:
		_on = load(ART+"speaker_on.png")
		_off = load(ART+"speaker_off.png")
		visibility_changed.connect(_visibility_changed)
		_refresh()
		_level = 1.0 if _enabled else 0.0
		_start_level = _level
		_transition = 0.15
		_visibility_changed()
	func _visibility_changed() -> void:
		set_process(not _hidden and is_visible_in_tree())
	func _process(delta: float) -> void:
		_refresh()
		_transition = minf(0.15,_transition+minf(delta,0.05))
		_level = lerpf(_start_level,1.0 if _enabled else 0.0,smoothstep(0.0,0.15,_transition))
		advance_for_capture(minf(delta,0.05))
	func advance_for_capture(seconds: float) -> void:
		clock = fmod(clock+seconds,10000.0) if _level > 0.001 else 0.0
		queue_redraw()
	func _refresh() -> void:
		var enabled := bool(_capture_override) if _capture_override >= 0 else Sound.bgm_enabled()
		if enabled != _enabled:
			_start_level = _level
			_transition = 0.0
			_enabled = enabled
	func set_visual_for_capture(enabled: bool) -> void:
		if not OS.get_cmdline_user_args().has("--ui-preview"): return
		_capture_override = 1 if enabled else 0
		_enabled = enabled
		_level = 1.0 if enabled else 0.0
		_start_level = _level
		_transition = 0.15
		if not enabled: clock = 0.0
		queue_redraw()
	func _draw() -> void:
		var center := size*0.5
		var vibration := Vector2(sin(clock*TAU*7.0)*0.65,cos(clock*TAU*5.0)*0.25)*_level
		var pulse := 1.0+0.022*sin(clock*TAU*4.2)*_level
		draw_set_transform(center+vibration,sin(clock*TAU*3.4)*0.01*_level,Vector2.ONE*pulse)
		var rect := Rect2(-center,size)
		if _off and _level < 1.0: draw_texture_rect(_off,rect,false,Color(1,1,1,1.0-_level))
		if _on and _level > 0.0: draw_texture_rect(_on,rect,false,Color(1,1,1,_level))
		draw_set_transform(Vector2.ZERO)
		if _level <= 0.001: return
		for i in range(3):
			var phase := fmod(clock*1.05+float(i)/3.0,1.0)
			var radius := 12.0+phase*15.0
			var strength := pow(1.0-phase,1.25)*_level
			var origin := Vector2(size.x*0.44,size.y*0.57)
			draw_arc(origin,radius,-0.66,0.66,22,Color(0.35,1.0,0.85,0.20*strength),4.4,true)
			draw_arc(origin,radius,-0.66,0.66,22,Color(0.76,1.0,0.96,0.82*strength),1.3,true)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): _visibility_changed()

# Each plate owns its tweens and clock, so rapid hover changes cannot leave it offset.
class HoloMotion extends Node:
	var button: Button
	var body: Control
	var face: Control
	var material: ShaderMaterial
	var clock := 0.0
	var _hidden := false
	var _hover_tween: Tween
	var _sweep_tween: Tween
	func setup(owner_button: Button, plate_body: Control, plate_face: Control, mat: ShaderMaterial) -> void:
		button = owner_button; body = plate_body; face = plate_face; material = mat
	func _ready() -> void:
		button.visibility_changed.connect(_visibility_changed)
		button.mouse_entered.connect(_enter)
		button.mouse_exited.connect(func(): _hover_to(0.0))
		button.button_down.connect(func(): _pressed(true))
		button.button_up.connect(func(): _pressed(false))
		_visibility_changed()
	func _process(delta: float) -> void:
		advance_for_capture(minf(delta,0.05))
	func advance_for_capture(seconds: float) -> void:
		clock = fmod(clock+seconds,10000.0)
		material.set_shader_parameter("motion_time",clock)
		var menu_icon := face.get_node_or_null("MenuIcon") as TextureRect
		if menu_icon: menu_icon.position.y = 7.0+sin(clock*TAU/3.4)*0.9
		var gate_icon := face.get_node_or_null("GateIcon") as TextureRect
		if gate_icon:
			gate_icon.pivot_offset = gate_icon.size*0.5
			gate_icon.scale = Vector2.ONE*(1.0+0.025*sin(clock*TAU/2.8))
	func _visibility_changed() -> void:
		var active := not _hidden and button.is_visible_in_tree()
		set_process(active)
		if not active: _reset()
	func _stop_hover() -> void:
		if _hover_tween and _hover_tween.is_valid(): _hover_tween.kill()
		_hover_tween = null
	func _stop_sweep() -> void:
		if _sweep_tween and _sweep_tween.is_valid(): _sweep_tween.kill()
		_sweep_tween = null
	func _reset() -> void:
		_stop_hover(); _stop_sweep()
		body.position = Vector2.ZERO; face.position = Vector2.ZERO
		var menu_icon := face.get_node_or_null("MenuIcon") as TextureRect
		if menu_icon: menu_icon.position.y = 7.0
		var gate_icon := face.get_node_or_null("GateIcon") as TextureRect
		if gate_icon: gate_icon.scale = Vector2.ONE
		material.set_shader_parameter("hover",0.0)
		material.set_shader_parameter("sweep",-1.0)
		material.set_shader_parameter("pressed",0.0)
	func _hover_to(target: float) -> void:
		_stop_hover()
		if target < 0.5:
			_stop_sweep(); material.set_shader_parameter("sweep",-1.0)
		if not is_inside_tree() or _hidden:
			material.set_shader_parameter("hover",target)
			body.position.x = -12.0*target; face.position.x = -12.0*target
			return
		_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_method(func(v: float): material.set_shader_parameter("hover",v),float(material.get_shader_parameter("hover")),target,0.18)
		_hover_tween.tween_property(body,"position:x",-12.0*target,0.18)
		_hover_tween.tween_property(face,"position:x",-12.0*target,0.18)
	func _enter() -> void:
		_hover_to(1.0)
		_stop_sweep()
		if not is_inside_tree() or _hidden: return
		_sweep_tween = create_tween()
		_sweep_tween.tween_method(func(v: float): material.set_shader_parameter("sweep",v),-0.3,1.3,0.5)
		_sweep_tween.tween_callback(func(): material.set_shader_parameter("sweep",-1.0))
	func _pressed(down: bool) -> void:
		body.position.y = 1.5 if down else 0.0
		face.position.y = body.position.y
		material.set_shader_parameter("pressed",1.0 if down else 0.0)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_hidden = true; set_process(false)
			if is_node_ready(): _reset()
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): _visibility_changed()

# Thin tech rail beside the menu stack: a vertical line with ticks, a diamond per plate in the
# plate's colour joined by a short connector, a header line and a blinking "ready" dot at the foot.
class MenuRail extends Control:
	const X := 614.0
	const TOP := 56.0
	const FOOT := 314.0
	const INK := Color(0.14,0.22,0.36,0.45)
	var stops: Array = []
	var clock := 0.0
	var _hidden := false
	func _ready() -> void:
		visibility_changed.connect(func(): set_process(not _hidden and is_visible_in_tree()))
		set_process(not _hidden and is_visible_in_tree())
	func _process(delta: float) -> void:
		advance_for_capture(minf(delta,0.05))
	func advance_for_capture(seconds: float) -> void:
		clock = fmod(clock+seconds,10000.0); queue_redraw()
	func _draw() -> void:
		draw_line(Vector2(X,TOP),Vector2(X,FOOT),INK,1.0)
		var y := TOP+6.0
		while y < FOOT-4.0:
			draw_line(Vector2(X-3.0,y),Vector2(X,y),Color(INK,0.28),1.0); y += 8.0
		draw_line(Vector2(X,TOP),Vector2(621.0,TOP),INK,1.0)
		for i in range(stops.size()):
			var stop: Array = stops[i]
			var at := Vector2(X,float(stop[0]))
			var tint: Color = stop[2]
			var breath := 0.65+0.35*sin(clock*TAU/2.8-float(i)*0.75)
			draw_line(at,Vector2(float(stop[1]),at.y),Color(tint,0.55),1.0)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-5),at+Vector2(5,0),at+Vector2(0,5),at+Vector2(-5,0)]),Color(1,1,1,0.85))
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-3.5),at+Vector2(3.5,0),at+Vector2(0,3.5),at+Vector2(-3.5,0)]),tint)
			draw_circle(at,8.0,Color(tint,0.12*breath))
			var phase := fmod(clock/2.8+float(i)*0.23,1.0)
			var packet := at.lerp(Vector2(float(stop[1]),at.y),phase)
			draw_circle(packet,3.2,Color(tint,0.18*sin(phase*PI)))
			draw_circle(packet,1.2,Color(tint,0.85*sin(phase*PI)))
		var rail_packet := Vector2(X,lerpf(TOP,FOOT,fmod(clock/4.2,1.0)))
		draw_circle(rail_packet,4.0,Color(0.48,0.9,1.0,0.16))
		draw_circle(rail_packet,1.4,Color(0.84,0.97,1.0,0.75))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): set_process(is_visible_in_tree())

# Authored acrylic corners, light streaks and a repeating warning ribbon. They share one
# slow breathing phase with the gate halo and status lamp.
# Coordinates are the deploy rect's own (plate corners TL (SLANT,0) TR (W,0) BR (W-SLANT,H) BL (0,H)).
class DeployDecor extends Control:
	const ART := "res://assets/ui/office-day-01/lobby-polish-01/"
	const W := 284.0
	const H := 112.0
	const SLANT := 32.0
	const RED := Color(1.0,0.24,0.34)
	var clock := 0.0
	var halo: TextureRect
	var _corner: Texture2D
	var _warning: Texture2D
	var _streak: Texture2D
	var _hidden := false
	func _ready() -> void:
		_corner = load(ART+"deploy_corner.png")
		_warning = load(ART+"deploy_warning_tile.png")
		_streak = load(ART+"deploy_streak.png")
		visibility_changed.connect(func(): set_process(not _hidden and is_visible_in_tree()))
		set_process(not _hidden and is_visible_in_tree())
	func _process(delta: float) -> void:
		clock += minf(delta,0.05); queue_redraw()
	func _draw() -> void:
		var breath := 0.5+0.5*sin(clock*TAU/2.8)
		var o := 10.0+2.0*(breath-0.5)
		var tint := Color(1,1,1,0.75+0.2*breath)
		if _corner:
			draw_texture_rect(_corner,Rect2(SLANT-o*0.7,-o,32,32),false,tint)
			draw_texture_rect(_corner,Rect2(W+o*0.4-32.0,-o,-32,32),false,tint)
			draw_texture_rect(_corner,Rect2(W-SLANT+o*0.7-32.0,H+o-32.0,-32,-32),false,tint)
			draw_texture_rect(_corner,Rect2(-o*0.4,H+o-32.0,32,-32),false,tint)
		if halo: halo.modulate.a = 0.35+0.35*breath
		for i in range(3):
			var phase := fmod(clock*0.9+i*0.37,1.0)
			var y := 26.0+i*30.0
			var lead := SLANT*(1.0-y/H)-8.0-phase*70.0
			if _streak: draw_texture_rect(_streak,Rect2(lead,y-4.0,56,8),false,Color(1,1,1,(1.0-phase)*0.8))
		if _warning:
			var shift := fmod(clock*20.0,24.0)
			var x := 122.0-shift
			while x < 270.0:
				var left := maxf(x,122.0)
				var right := minf(x+24.0,270.0)
				draw_texture_rect_region(_warning,Rect2(left,126.0,right-left,10.0),Rect2((left-x)*2.0,0.0,(right-left)*2.0,20.0))
				x += 24.0
		draw_circle(Vector2(32,131),4.5,Color(RED,0.16*(0.65+0.35*breath)))
		draw_circle(Vector2(32,131),2.6,Color(RED,0.65+0.35*breath))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): set_process(is_visible_in_tree())

const OFFICE := "res://assets/ui/office-day-01/"
const POLISH := OFFICE+"lobby-polish-01/"
# Operator 한서아's line of the day, picked once per launch.
const OPERATOR_LINES := [
	"오늘 목표는 칼퇴예요. 게이트가 협조만 해 준다면요...",
	"커피는 제 책상에, 각성은 현장에. 다녀오세요!",
	"협회장님이 무리하지 말래요. 물론 실적은 내라고도 하셨고요.",
	"광화문 게이트 날씨: 맑음, 가끔 괴물.",
	"출동 전 체크! 장비, 물, 그리고 퇴근 의지.",
	"'괴물 퇴치용 김밥' 영수증은 경비 처리 안 된대요.",
	"오늘 점심 메뉴는 살아서 돌아오면 정해요.",
	"보고서에 오타 내면 제가 포스트잇 붙일 거예요.",
	"위험하면 도망치는 것도 실력이에요. 협회 규정 3조.",
	"몬스터한테 명함 주지 마세요. 지난번에 진짜 줬죠?",
	"엘리베이터 고장이래요. 게이트까지 계단 화이팅!",
	"오늘의 운세: 동쪽에서 귀인이, 서쪽에서 몬스터가.",
	"야근 수당은 없지만 마력석은 있어요!",
	"출동 기록 1등 하면 커피 쏠게요. 믹스커피로요.",
	"부장님 화분에 물 준 사람? 화분이 각성했어요.",
	"서류 결재는 끝났어요. 이제 몬스터 결재만 남았네요.",
	"다치면 바로 말해요. 참으면 보고서가 길어져요.",
	"오늘도 서울은 평화로... 아, 방금 경보 울렸네요.",
	"출근 도장 찍으셨죠? 현장 도장도 찍고 오세요.",
	"장비 반납은 내일까지예요. 부서진 채로라도요.",
]
static var _launch_line := ""

# Owned awakeners potter around the office floor as small full-body SDs, using the same
# leg-split walk as combat. Now and then one of them says something in a speech bubble.
class OfficeCoworkers extends Control:
	const HEIGHT := 148.0
	const SPEED := 34.0
	const LINES := [
		"커피 누가 다 마셨어?",
		"보고서 언제 내지...",
		"오늘 칼퇴 가능?",
		"게이트 또 열렸대.",
		"점심 뭐 먹지?",
		"어제 몬스터 꿈 꿨어.",
		"출장비 정산 언제 돼요?",
		"프린터 또 고장 났어.",
		"야근은 싫은데...",
		"마력석 시세 올랐대.",
		"회의 5분 전!",
		"부장님 어디 가셨어?",
		"택배 왔어요~",
		"허리 아프다...",
	]
	# Feet stay on the lit floor, left of the menu card.
	var floor_rect := Rect2(40,336,540,56)
	var walkers: Array = []
	var bubble: Control
	var bubble_label: Label
	var bubble_owner := -1
	var bubble_left := 0.0
	var next_bubble := 2.5
	var _last_line := ""
	var _clock := 0.0
	var _hidden := false
	func setup(actors: Array, speech: Control, speech_label: Label) -> void:
		bubble = speech; bubble_label = speech_label
		for i in range(actors.size()):
			var id := str(actors[i])
			var visual: Dictionary = Content.visuals.characters.get(id,Content.visuals.characters.awakener)
			var node := HeroSDVisual.new()
			node.name = "Coworker_"+id
			add_child(node)
			node.configure(id,visual)
			var lane := (float(i)+0.5)/float(actors.size())
			var pos := Vector2(lerpf(floor_rect.position.x+30,floor_rect.end.x-30,lane)+randf_range(-24,24),randf_range(floor_rect.position.y,floor_rect.end.y))
			walkers.append({"id":id,"node":node,"pos":pos,"goal":pos,"facing":-1.0 if randf() < 0.5 else 1.0,"rest":randf_range(0.3,2.6),"phase":randf()*6.0})
		move_child(bubble,-1)
	func _ready() -> void:
		visibility_changed.connect(func(): set_process(not _hidden and is_visible_in_tree()))
		step(0.0)
	func _process(delta: float) -> void:
		step(minf(delta,0.05))
	func _pick_goal(from: Vector2) -> Vector2:
		var goal := from
		for attempt in range(6):
			goal = Vector2(randf_range(floor_rect.position.x,floor_rect.end.x),randf_range(floor_rect.position.y,floor_rect.end.y))
			if absf(goal.x-from.x) > 70.0: break
		return goal
	func step(delta: float) -> void:
		_clock += delta
		for w: Dictionary in walkers:
			var pos: Vector2 = w.pos
			if float(w.rest) > 0.0:
				w.rest = float(w.rest)-delta
				if float(w.rest) <= 0.0: w.goal = _pick_goal(pos)
			else:
				var to: Vector2 = Vector2(w.goal)-pos
				var distance := to.length()
				var move := minf(distance,SPEED*delta)
				if distance > 0.01:
					w.pos = pos+to/distance*move
					if absf(to.x) > 1.0: w.facing = signf(to.x)
				if distance-move < 0.5: w.rest = randf_range(1.6,4.8)
			# Farther back on the floor reads a little smaller.
			var depth := inverse_lerp(floor_rect.position.y,floor_rect.end.y,Vector2(w.pos).y)
			w.node.update_state({"pos":w.pos,"facing":w.facing,"age":_clock+float(w.phase),"action":"idle" if float(w.rest) > 0.0 else "move"},delta,HEIGHT*lerpf(0.9,1.0,depth))
		# Painter's order: whoever stands lower on screen draws in front.
		var order := walkers.duplicate()
		order.sort_custom(func(a, b): return Vector2(a.pos).y < Vector2(b.pos).y)
		for i in range(order.size()): move_child(order[i].node,i)
		move_child(bubble,-1)
		_speech(delta)
	func _speech(delta: float) -> void:
		if walkers.is_empty(): bubble.visible = false; return
		if bubble_owner < 0:
			bubble.visible = false
			next_bubble -= delta
			if next_bubble > 0.0: return
			bubble_owner = randi_range(0,walkers.size()-1)
			var line := _last_line
			while line == _last_line: line = str(LINES.pick_random())
			_last_line = line
			bubble_label.text = line
			bubble_left = 3.2
		bubble_left -= delta
		if bubble_left <= 0.0:
			bubble_owner = -1; bubble.visible = false
			next_bubble = randf_range(3.5,7.5)
			return
		var w: Dictionary = walkers[bubble_owner]
		var node: HeroSDVisual = w.node
		var head := Vector2(w.pos)-Vector2(0,node._height+2)
		bubble.visible = true
		bubble.position = Vector2(clampf(head.x-bubble.size.x*0.5,4.0,630.0-bubble.size.x),head.y-bubble.size.y)
		bubble.modulate.a = clampf(minf(3.2-bubble_left,bubble_left)/0.2,0.0,1.0)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT: _hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): set_process(is_visible_in_tree())

# Raster optical layers surround 한서아; live signal motion stays below the native text.
class OperatorHologram extends Control:
	const ART := "res://assets/ui/office-day-01/lobby-polish-01/operator_surface.png"
	const EFFECTS := "res://assets/ui/office-day-01/lobby-polish-01/"
	const LAMP := Vector2(86,13)
	const WAVE_X := 302.0
	var clock := 0.0
	var _surface: Texture2D
	var _halo: Texture2D
	var _glint: Texture2D
	var _portrait: TextureRect
	var _portrait_rest := Vector2.ZERO
	var _hidden := false
	func _ready() -> void:
		_surface = load(ART)
		_halo = load(EFFECTS+"operator_halo.png")
		_glint = load(EFFECTS+"operator_glint.png")
		_portrait = get_node_or_null("OperatorFace") as TextureRect
		if _portrait:
			_portrait_rest = _portrait.position
			_portrait.pivot_offset = _portrait.size*0.5
		visibility_changed.connect(func(): set_process(not _hidden and is_visible_in_tree()))
		set_process(not _hidden and is_visible_in_tree())
	func _process(delta: float) -> void:
		advance_for_capture(minf(delta,0.05))
	func advance_for_capture(seconds: float) -> void:
		clock = fmod(clock+seconds,10000.0)
		if _portrait:
			_portrait.position.y = _portrait_rest.y+sin(clock*TAU/2.4)*1.1
			_portrait.scale = Vector2.ONE*(1.0+0.015*sin(clock*TAU/3.2))
		queue_redraw()
	func _draw() -> void:
		if _surface: draw_texture_rect(_surface,Rect2(Vector2(-8,-8),size+Vector2(16,16)),false,Color(1,1,1,0.6))
		var breath := 0.5+0.5*sin(clock*TAU/2.8)
		if _halo:
			draw_set_transform(Vector2(41,41),clock*0.32)
			draw_texture_rect(_halo,Rect2(-43,-43,86,86),false,Color(1,1,1,0.65+0.25*breath))
			draw_set_transform(Vector2.ZERO)
		if _glint:
			var phase := fmod(clock/3.6,1.0)
			var left := lerpf(-124.0,size.x+4.0,phase)
			var clipped_left := maxf(left,3.0)
			var clipped_right := minf(left+124.0,size.x-3.0)
			if clipped_right > clipped_left:
				var strip := Rect2(clipped_left,3,clipped_right-clipped_left,size.y-6)
				var source := Rect2((clipped_left-left)/124.0*256.0,0,(clipped_right-clipped_left)/124.0*256.0,64)
				draw_texture_rect_region(_glint,strip,source,Color(1,1,1,0.28),false,true)
		var lamp := 0.55+0.45*sin(clock*4.2)
		draw_circle(LAMP,6.5,Color(1,0.36,0.32,0.2*lamp))
		draw_circle(LAMP,3.6,Color(1,0.36,0.32,lamp))
		var transmit := fmod(clock/1.4,1.0)
		draw_arc(LAMP,4.0+transmit*8.0,0,TAU,32,Color(1,0.45,0.39,0.55*(1.0-transmit)),1.0,true)
		for i in range(9):
			var level := 0.3*absf(sin(clock*2.3+i*1.7))+0.7*absf(sin(clock*6.0+i*0.9))
			var height := 3.0+level*10.0
			draw_rect(Rect2(WAVE_X+i*5.0,13.0-height*0.5,3.0,height),Color(1,1,1,0.85))
			if level > 0.65: draw_circle(Vector2(WAVE_X+i*5.0+1.5,13.0-height*0.5),2.2,Color(0.65,1.0,0.9,0.24))
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT: _hidden = true; set_process(false)
		elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_hidden = false
			if is_node_ready(): set_process(is_visible_in_tree())

static func build(go: Callable, scene_id: String = "", can_resume: bool = false) -> Control:
	var root := HeroImageSkin.root()
	if scene_id.is_empty(): scene_id = str(Content.data.premiumUI.scenes.pick_random())
	root.set_meta("lobbyAmbience", _environment_cue(scene_id))
	var backdrop := TextureRect.new()
	backdrop.name = "OfficeBackdrop"
	backdrop.texture = load(OFFICE+"lobby_office_bg_soft.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_meta("full_bleed",true)
	root.add_child(backdrop); HeroUI.place(backdrop,Rect2(0,0,915,412))
	_coworkers(root)
	_operator(root)
	# Right-hand menu: slanted frosted plates (white hologram), one accent colour per destination.
	var rail := MenuRail.new()
	rail.name = "MenuRail"
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.stops = [[104.0,650.0,Color("#8c5cf0")],[162.0,650.0,Color("#f2a516")],[220.0,650.0,Color("#2f7bf5")],[314.0,624.0,Color("#ff3d57")]]
	root.add_child(rail); HeroUI.place(rail,Rect2(0,0,915,412))
	# Light text with a dark shadow: it sits over both the dark ceiling beam and the bright lights.
	_glass_text(_sharp_text(root,"SEOUL AWAKENER ASSOCIATION",Rect2(626,48,220,16),SHARP_TAG,10,"#f5f8fa",HORIZONTAL_ALIGNMENT_LEFT,2))
	# Sound toggle is just the icon, no plate; hover only brightens it.
	var music := HeroImageSkin.button(root,"",Rect2(858,10,44,44),func():
		Profile.meta.settings.muted = not Profile.meta.settings.muted
		Sound.apply_settings(); Profile.save()
	,"plain")
	music.name = "LobbyMusic"
	var music_face := Control.new()
	music_face.name = "Face"
	music_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music.add_child(music_face); HeroUI.place(music_face,Rect2(0,0,44,44))
	music.mouse_entered.connect(func(): music_face.modulate = Color(1.25,1.25,1.25))
	music.mouse_exited.connect(func(): music_face.modulate = Color.WHITE)
	var music_art := MusicStateIcon.new()
	music_art.name = "MusicStateIcon"
	music_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	music_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_face.add_child(music_art); HeroUI.place(music_art,Rect2(6,6,32,32))
	music.pressed.connect(music_art._refresh)
	var menu := [
		["settings","설정","SETTINGS","icon_settings","LobbySettings","#8c5cf0","#6a3fd0"],
		["archive","자료집","ARCHIVE","icon_archive","LobbyArchive","#f2a516","#a86a00"],
		["association","협회","ASSOCIATION","icon_association","LobbyAssociation","#2f7bf5","#1f5fc8"],
	]
	for i in range(menu.size()):
		var entry: Array = menu[i]
		var target := str(entry[0])
		var row := _holo_button(root,Rect2(650,80+i*58,252,48),14.0,Color(str(entry[5])),false,func(): go.call(target),str(entry[2]))
		row.name = str(entry[4])
		var face: Control = row.get_node("Face")
		var menu_icon := HeroUI.fixed_art(face,load(OFFICE+"icons/"+str(entry[3])+".png"),Rect2(26,7,34,34))
		menu_icon.name = "MenuIcon"
		menu_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var title := _sharp_text(face,str(entry[1]),Rect2(70,0,92,48),SHARP_TITLE,19,str(entry[6]),HORIZONTAL_ALIGNMENT_LEFT,0)
		title.name = "Title"
		_sharp_text(face,str(entry[2]),Rect2(120,0,104,48),SHARP_TAG,11,str(entry[6]),HORIZONTAL_ALIGNMENT_RIGHT,2)
	# No title screen: an unfinished run is resumed from the lobby's deploy button.
	var deploy := _holo_button(root,Rect2(620,258,284,112),32.0,Color("#ff3d57"),true,func(): go.call("resume" if can_resume else "gate"),"DEPLOY")
	deploy.name = "LobbyDeploy"
	var decor := DeployDecor.new()
	decor.name = "DeployDecor"
	decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var deploy_body: Control = deploy.get_node("Body")
	deploy_body.add_child(decor); HeroUI.place(decor,Rect2(0,0,284,112))
	deploy_body.move_child(decor,0)
	_sharp_text(deploy_body,"GATE OPEN",Rect2(42,124,78,14),SHARP_TAG,10,"#d8344a",HORIZONTAL_ALIGNMENT_LEFT,3).name = "GateOpenLabel"
	var dface: Control = deploy.get_node("Face")
	dface.name = "DeployFace"
	# Its pulse shares the decor clock, instead of competing with a second looping Tween.
	var halo := TextureRect.new()
	halo.name = "GateHalo"
	halo.texture = load(OFFICE+"soft_shadow.png")
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = add
	halo.modulate = Color(1.0,0.42,0.5,0.5)
	dface.add_child(halo); HeroUI.place(halo,Rect2(14,-6,124,124))
	decor.halo = halo
	var gate_icon := HeroUI.fixed_art(dface,load(OFFICE+"icons/icon_deploy_gate.png"),Rect2(40,20,72,72))
	gate_icon.name = "GateIcon"
	gate_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Only the word "출동": no kicker or subtitle.
	var go_title := _sharp_text(dface,"출동",Rect2(126,18,130,76),SHARP_TITLE,44,"#ffffff",HORIZONTAL_ALIGNMENT_LEFT,4)
	go_title.name = "Title"
	_glass_text(go_title)
	return root

# Authored raster glass over a blurred backdrop; the shader supplies its exact mask and
# moving reflections. Native icon/type layers and the clipped watermark stay independent.

static func _holo_button(parent: Node, rect: Rect2, slant: float, accent: Color, dark: bool, action: Callable, watermark: String = "") -> Button:
	var button := HeroImageSkin.button(parent,"",rect,action,"plain")
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(body); HeroUI.place(body,Rect2(Vector2.ZERO,rect.size))
	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := 18.0 if dark else 14.0
	var plate_size := rect.size+Vector2(pad,pad)*2.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lobby_plate.gdshader")
	mat.set_shader_parameter("rect_size",plate_size)
	mat.set_shader_parameter("pad",pad)
	mat.set_shader_parameter("slant",slant)
	mat.set_shader_parameter("dark",dark)
	mat.set_shader_parameter("accent",accent)
	var surface_file := "deploy_surface" if dark else "menu_"+watermark.to_lower()
	mat.set_shader_parameter("surface_texture",load(POLISH+surface_file+".png"))
	mat.set_shader_parameter("hover",0.0)
	mat.set_shader_parameter("sweep",-1.0)
	if dark:
		mat.set_shader_parameter("beam_speed",60.0)
		mat.set_shader_parameter("run_light",1.0)
		mat.set_shader_parameter("auto_sweep",true)
	plate.material = mat
	body.add_child(plate); HeroUI.place(plate,Rect2(-Vector2(pad,pad),plate_size))
	if not watermark.is_empty():
		# Clip only native glyph alpha; a canvas clip group would replace the glass backbuffer.
		var mask_material := ShaderMaterial.new()
		mask_material.shader = load("res://shaders/lobby_plate_mask.gdshader")
		mask_material.set_shader_parameter("rect_size",plate_size)
		mask_material.set_shader_parameter("pad",pad)
		mask_material.set_shader_parameter("slant",slant)
		mask_material.set_shader_parameter("label_offset",Vector2(pad,pad+2.0))
		var ink := Color(1,1,1,0.08) if dark else Color(accent.r*0.35,accent.g*0.35,accent.b*0.4,0.1)
		var mark_size := 84 if dark else 44
		var mark := _sharp_text(body,watermark,Rect2(0,2.0,rect.size.x-slant*0.5-6.0,rect.size.y),SHARP_TAG,mark_size,"#ffffff",HORIZONTAL_ALIGNMENT_RIGHT,0)
		mark.name = "Watermark"
		mark.material = mask_material
		mark.add_theme_color_override("font_color",ink)
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face); HeroUI.place(face,Rect2(Vector2.ZERO,rect.size))
	var motion := HoloMotion.new()
	motion.name = "HoloMotion"
	motion.setup(button,body,face,mat)
	button.add_child(motion)
	return button

# Glass button drawn from the glass/ art set. The art is authored at 2x, so the plate is
# stretched to the button rect; pressed swaps in the darker art and nudges the face 1.5px
# (the art moves 3px). `Face` holds icon and text so they sink with the plate.
# Hover only lights the glass: an additive copy of the same art fades in on top, so nothing in
# the plate moves or changes shape (the authored _hover art moved its highlight, which read as
# the contents resizing).
static func _glass_button(parent: Node, rect: Rect2, file: String, _has_hover: bool, action: Callable) -> Button:
	var button := HeroImageSkin.button(parent,"",rect,action,"plain")
	var normal: Texture2D = load(OFFICE+"glass/"+file+"_normal.png")
	var pressed: Texture2D = load(OFFICE+"glass/"+file+"_pressed.png")
	var plate := TextureRect.new()
	plate.name = "Plate"
	plate.texture = normal
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate); HeroUI.place(plate,Rect2(Vector2.ZERO,rect.size))
	var light := TextureRect.new()
	light.name = "Light"
	light.texture = normal
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = additive
	light.modulate = Color(0.55,0.95,0.88,0.0)
	button.add_child(light); HeroUI.place(light,Rect2(Vector2.ZERO,rect.size))
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face); HeroUI.place(face,Rect2(Vector2.ZERO,rect.size))
	var fade := func(target: float):
		if not button.is_inside_tree(): light.modulate.a = target; return
		button.create_tween().tween_property(light,"modulate:a",target,0.12)
	button.button_down.connect(func():
		plate.texture = pressed; face.position.y = 1.5
	)
	button.button_up.connect(func():
		plate.texture = normal; face.position.y = 0.0
	)
	button.mouse_entered.connect(func(): fade.call(0.42))
	button.mouse_exited.connect(func(): fade.call(0.0))
	return button

# Lobby type is squarer and tighter than the round brand face (BMJUA): Paperlogy ExtraBold for
# Korean titles, spaced Barlow Condensed for English tags.
const SHARP_TITLE := "Paperlogy-8ExtraBold.ttf"
const SHARP_LINE := "Paperlogy-6SemiBold.ttf"
const SHARP_TAG := "BarlowCondensed-Bold.ttf"
static var _sharp_fonts: Dictionary = {}

static func _sharp_font(file: String, spacing: int = 0) -> Font:
	var key := file+"@"+str(spacing)
	if not _sharp_fonts.has(key):
		var face := FontVariation.new()
		face.base_font = load("res://assets/ui/fonts/"+file)
		face.spacing_glyph = spacing
		face.fallbacks = [HeroImageSkin.font("body")]
		_sharp_fonts[key] = face
	return _sharp_fonts[key]

static func _sharp_text(parent: Node, caption: String, rect: Rect2, file: String, font_size: int, color: String, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, spacing: int = 0, wrap: bool = false, options: Dictionary = {}) -> Label:
	if not options.has("valign"): options["valign"] = VERTICAL_ALIGNMENT_CENTER
	var label := HeroImageSkin.text(parent,caption,rect,"body",font_size,color,align,wrap,options)
	label.add_theme_font_override("font",_sharp_font(file,spacing))
	return label

static func _sharp_fit(caption: String, file: String, largest: int, width: float, smallest: int) -> int:
	var face := _sharp_font(file)
	var result := largest
	while result > smallest and face.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,result).x > width: result -= 1
	return result

# Breaks only at spaces; Godot would otherwise split a Korean word between syllables.
static func _sharp_wrap(caption: String, file: String, font_size: int, width: float) -> String:
	var face := _sharp_font(file)
	var lines: Array[String] = []
	var current := ""
	for word in caption.split(" ",false):
		var trial := word if current.is_empty() else current+" "+word
		if not current.is_empty() and face.get_string_size(trial,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width:
			lines.append(current)
			current = word
		else:
			current = trial
	if not current.is_empty(): lines.append(current)
	return "\n".join(lines)

static func _glass_text(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color",Color(0.04,0.08,0.14,0.55))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)

static func _coworkers(root: Control) -> void:
	var owned: Array = Content.data.characters.keys().filter(func(id): return Profile.meta.characters.get(id,{}).get("unlocked",false))
	if owned.is_empty(): owned = ["awakener"]
	owned.shuffle()
	var crew := OfficeCoworkers.new()
	crew.name = "OfficeCoworkers"
	crew.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crew); HeroUI.place(crew,Rect2(0,0,915,412))
	var bubble := Control.new()
	bubble.name = "CoworkerBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.visible = false
	crew.add_child(bubble); HeroUI.place(bubble,Rect2(0,0,128,54))
	_nine(bubble,"tooltip_bubble",Rect2(0,0,128,54),Vector4(28,24,28,40),0.32)
	var label := HeroImageSkin.text(bubble,"",Rect2(8,5,112,32),"control",11,"#24395c",HORIZONTAL_ALIGNMENT_CENTER,true,{"lines":2,"valign":VERTICAL_ALIGNMENT_CENTER})
	label.name = "CoworkerLine"
	crew.setup(owned.slice(0,5),bubble,label)

static func _operator(root: Control) -> void:
	if _launch_line.is_empty(): _launch_line = str(OPERATOR_LINES.pick_random())
	var window := OperatorHologram.new()
	window.name = "OperatorHologram"
	window.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(window); HeroUI.place(window,Rect2(12,10,360,82))
	# Square crop centred on her head so the face sits in the middle of the well.
	var face := AtlasTexture.new()
	face.atlas = load(str(Content.data.images.hanSeoaSD.url))
	face.region = Rect2(268,90,760,760)
	var portrait := HeroUI.fixed_art(window,face,Rect2(9,9,64,64))
	portrait.name = "OperatorFace"
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sharp_text(window,"통신 중 · 오퍼레이터 한서아",Rect2(95,5,200,17),SHARP_LINE,11,"#146068")
	# Two lines at most, centred in the space under the caption; long lines step the size down.
	var size := _sharp_fit(_launch_line,SHARP_LINE,14,470.0,12)
	var line := _sharp_text(window,_sharp_wrap(_launch_line,SHARP_LINE,size,258.0),Rect2(84,24,262,50),SHARP_LINE,size,"#19324b",HORIZONTAL_ALIGNMENT_LEFT,0,true,{"lines":2})
	line.name = "OperatorLine"

# Nine-slice frame from the office-day-01 set. Margins are authored at full texture size,
# so the patch is laid out at size/scale and drawn scaled to keep corners in proportion.
static func _nine(parent: Node, file: String, rect: Rect2, margins: Vector4, art_scale: float) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.texture = load(OFFICE+file+".png")
	patch.patch_margin_left = int(margins.x); patch.patch_margin_top = int(margins.y)
	patch.patch_margin_right = int(margins.z); patch.patch_margin_bottom = int(margins.w)
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(patch)
	patch.position = rect.position
	patch.size = rect.size/art_scale
	patch.scale = Vector2(art_scale,art_scale)
	return patch

static func _plate_button(parent: Node, file: String, rect: Rect2, margins: Vector4, art_scale: float, action: Callable) -> Button:
	var button := HeroImageSkin.button(parent,"",rect,action,"plain")
	var plate := _nine(button,file+"_normal",Rect2(Vector2.ZERO,rect.size),margins,art_scale)
	plate.name = "Plate"
	button.move_child(plate,0)
	var normal: Texture2D = plate.texture
	var pressed: Texture2D = load(OFFICE+file+"_pressed.png")
	button.button_down.connect(func(): plate.texture = pressed)
	button.button_up.connect(func(): plate.texture = normal)
	button.mouse_entered.connect(func(): plate.modulate = Color(1.05,1.05,1.05))
	button.mouse_exited.connect(func(): plate.modulate = Color.WHITE)
	return button

static func _environment_cue(scene_id: String) -> String:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HeroLobbyAtmosphere.CATALOG))
	var definition: Dictionary = catalog.get(scene_id, {})
	var environment := str(definition.get("environment", ""))
	var backgrounds: Dictionary = Content.data.get("audioConnections", {}).get("lobbyBackgrounds", {})
	return str(backgrounds.get(environment, ""))

static func _scan(parent: Node, rect: Rect2) -> void:
	var pulse := HeroImageSkin.material(parent,"spy/pulse",rect)
	pulse.name = "OperationScan"
	var presets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HeroUIEffects.PRESETS))
	var definition: Dictionary = presets.terminal
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ui_vfx.gdshader")
	material.set_shader_parameter("strength",float(definition.strength))
	material.set_shader_parameter("accent",Color(str(definition.color)))
	material.set_shader_parameter("band_width",float(definition.bandWidth))
	for surface in pulse.get_children(true):
		if surface is HeroImageSkin.ImageSurface:
			surface.material = material
			HeroUIEffects.texture_bounds(material,surface.texture,surface.region_rect)
	var flow := TerminalFlow.new()
	flow.name = "OperationFlow"; flow.material = material
	flow.period = float(definition.duration)
	pulse.add_child(flow)

static func _icon_button(parent: Node, key: String, rect: Rect2, action: Callable) -> Button:
	var button := HeroImageSkin.button(parent,"",rect,action,"plain")
	HeroUI.fixed_art(button,HeroUI.icon_texture(key),Rect2(2,2,40,40)).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return button

static func _readable(label: Label) -> void:
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color(0.03,0.07,0.12,0.85))
	label.add_theme_constant_override("shadow_offset_y",1)

static func _wallet(parent: Node, image_id: String, value: int, center: Vector2, node_name: String) -> void:
	var caption := HeroUI.amount(value)
	var number_width := ceilf(HeroImageSkin.font("number").get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x)+2.0
	var left := center.x-(22.0+6.0+number_width)*0.5
	HeroUI.fixed_art(parent,Content.trimmed_texture(image_id),Rect2(left,center.y-11,22,22))
	var amount := HeroImageSkin.text(parent,caption,Rect2(left+28,center.y-16,number_width,32),"number",18,"scene")
	amount.name = node_name
	_readable(amount)

# Once-a-day gift. The offer is shown before claiming so the player sees today's fragment target.
static func daily_popup(root: Control, offer: Dictionary, streak_day: int, streak_days: int, claim: Callable) -> void:
	var box := HeroCombatUI.popup(root,"오늘의 선물 · %d일째" % streak_day,520,320)
	var display := HeroMetaScreens.reward_display({"type":str(offer.kind)+"Fragment","contentId":offer.id,"amount":int(offer.amount)})
	var card := HeroUI.column(box)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var art := HeroUI.image(card,display.texture,96,80)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HeroMetaScreens._heading(card,"%s ×%d" % [display.name,int(offer.amount)],18)
	var bonus := "협회 코인 %d · 길드 코인 %d" % [int(Content.data.daily.associationCoins),int(Content.data.daily.guildCoins)] if Content.enabled("guild") else "협회 코인 %d" % int(Content.data.daily.associationCoins)
	var left := streak_days - ((streak_day - 1) % streak_days) - 1
	bonus += "\n%d일 연속 보너스까지 %d일" % [streak_days,left] if left > 0 else "\n오늘은 %d일 연속 보너스도 함께 받아요" % streak_days
	HeroMetaScreens._heading(card,bonus,14)
	var actions := HeroUI.row(box)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	HeroImageSkin.image_button(actions,"나중에",Rect2(0,0,120,44),func(): box.get_meta("overlay").queue_free(),"ops/secondary",16)
	HeroImageSkin.image_button(actions,"받기",Rect2(0,0,160,44),func():
		box.get_meta("overlay").queue_free()
		claim.call()
	,"ops/primary",16)

