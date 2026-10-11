class_name HeroDamageNumbers
extends Node2D

# Presentation-only hit numbers. Ages with the combat dt, so pause freezes them.
const MAX_NUMBERS := 40
const LIFE := 0.62
const CRIT_LIFE := 0.82
const SIZE := 17
const CRIT_SIZE := 24
const RISE := 26.0
const NORMAL_COLOR := Color("ffffff")
const CRIT_COLOR := Color("f2b233")
const PLAYER_COLOR := Color("ef7a6d")
const OUTLINE_COLOR := Color(0.05,0.10,0.16,0.9)
var _numbers: Array[Dictionary] = []
var _serial := 0
var _font: Font

func _ready() -> void:
	_font = HeroImageSkin.font("number")

func add(point: Vector2, value: float, critical: bool = false, hostile: bool = false) -> void:
	var amount := maxi(1,roundi(value))
	if _numbers.size() >= MAX_NUMBERS: _numbers.pop_front()
	_serial += 1
	# Fixed spread pattern keeps stacked hits on one enemy from overlapping exactly.
	var spread := float((_serial*7)%5-2)*6.0
	_numbers.append({"pos":point,"text":str(amount),"critical":critical,"hostile":hostile,"age":0.0,"drift":spread})
	queue_redraw()

func tick(dt: float) -> void:
	if _numbers.is_empty() or dt <= 0.0: return
	for entry in _numbers: entry.age += dt
	_numbers = _numbers.filter(func(entry): return float(entry.age) < (CRIT_LIFE if entry.critical else LIFE))
	queue_redraw()

func clear() -> void:
	_numbers.clear(); queue_redraw()

func count() -> int:
	return _numbers.size()

func _draw() -> void:
	if _font == null: return
	# Numbers keep a constant screen size whatever the arena fit scale is.
	var world_scale := maxf(0.001,get_global_transform().get_scale().x)
	for entry in _numbers:
		var critical: bool = entry.critical
		var life := CRIT_LIFE if critical else LIFE
		var t := clampf(float(entry.age)/life,0.0,1.0)
		var pop := 1.0+(1.0-smoothstep(0.0,0.16,t))*(0.55 if critical else 0.3)
		var size := int(round((CRIT_SIZE if critical else SIZE)*pop))
		var color: Color = PLAYER_COLOR if entry.hostile else CRIT_COLOR if critical else NORMAL_COLOR
		color.a = 1.0-smoothstep(0.65,1.0,t)
		var outline := OUTLINE_COLOR; outline.a *= color.a
		var rise := RISE*(1.0-pow(1.0-t,3.0))
		var text: String = entry.text
		var width := _font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		draw_set_transform(entry.pos,0.0,Vector2.ONE/world_scale)
		var origin := Vector2(-width*0.5+float(entry.drift)*t,-rise)
		draw_string_outline(_font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,4,outline)
		draw_string(_font,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	draw_set_transform(Vector2.ZERO)
