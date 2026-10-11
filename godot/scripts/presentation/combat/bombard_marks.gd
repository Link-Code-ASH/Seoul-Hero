class_name HeroBombardMarks
extends Node2D

# Ground layer for bombard shells: a painted rift that opens under the landing spot, plus a soft shadow.
const MARK_TEXTURE = preload("res://assets/effects/effect_bombard_mark_01.png")
const SHADOW_TEXTURE = preload("res://assets/visuals/vfx/contact_shadow.png")
var _marks: Array[Dictionary] = []

func show_marks(marks: Array[Dictionary]) -> void:
	if marks.is_empty() and _marks.is_empty(): return
	_marks = marks; queue_redraw()

func _draw() -> void:
	for mark in _marks:
		var approach: float = mark.approach
		var fuse: float = mark.fuse
		var radius: float = mark.radius
		var target: Vector2 = mark.target
		# Telegraph: a faint rift appears during the lob, then opens to the blast size and darkens.
		var grow := 0.55+0.45*smoothstep(0.0,1.0,fuse)
		var alpha := 0.22*smoothstep(0.2,1.0,approach)+0.5*fuse
		var spin := fuse*0.6
		draw_set_transform(target,spin,Vector2.ONE*radius*grow*2.0/MARK_TEXTURE.get_width())
		draw_texture(MARK_TEXTURE,-MARK_TEXTURE.get_size()*0.5,Color(1,1,1,alpha))
		# Shadow shrinks and fades as the shell rises, so the lob reads as height.
		var height: float = mark.height
		var size := 64.0*(1.0-0.45*height)
		draw_set_transform(mark.ground,0.0,Vector2(size,size*0.42)/SHADOW_TEXTURE.get_size())
		draw_texture(SHADOW_TEXTURE,-SHADOW_TEXTURE.get_size()*0.5,Color(1,1,1,0.75*(1.0-0.55*height)))
	draw_set_transform(Vector2.ZERO)
