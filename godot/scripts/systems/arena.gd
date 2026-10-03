class_name HeroArena
extends RefCounted

static func footprint(object: Dictionary) -> Rect2:
	var size := Vector2(object.footprint.width,object.footprint.height)
	return Rect2(Vector2(object.position.x,object.position.y)-size*0.5,size)

static func resolve(point: Vector2, radius: float, map: Dictionary, clamp_boundary: bool = true) -> Vector2:
	for object in map.get("objects",[]):
		if not object.get("blocksMovement",true): continue
		var bounds := footprint(object).grow(radius)
		if not bounds.has_point(point): continue
		var distances := [point.x-bounds.position.x,bounds.end.x-point.x,point.y-bounds.position.y,bounds.end.y-point.y]
		var side := distances.find(distances.min())
		match side:
			0: point.x = bounds.position.x
			1: point.x = bounds.end.x
			2: point.y = bounds.position.y
			3: point.y = bounds.end.y
	if not clamp_boundary: return point
	var extent := Vector2(map.arenaWidth,map.arenaHeight)*0.5-Vector2.ONE*radius
	return point.clamp(-extent,extent)

static func approach(point: Vector2, target: Vector2, distance: float, radius: float, map: Dictionary, slide: bool) -> Vector2:
	var desired := point.move_toward(target,distance)
	var result := resolve(desired,radius,map,false)
	if not slide or result.is_equal_approx(desired): return result
	# Chase motion slides toward the nearest end of a plinth; a dash stops against it.
	var normal := (result-desired).normalized()
	var tangent := Vector2(-normal.y,normal.x)
	for object in map.get("objects",[]):
		if not object.get("blocksMovement",true): continue
		var bounds := footprint(object).grow(radius)
		if not bounds.has_point(desired): continue
		var horizontal := normal.x != 0 and ((normal.x < 0 and target.x > bounds.end.x) or (normal.x > 0 and target.x < bounds.position.x))
		var vertical := normal.y != 0 and ((normal.y < 0 and target.y > bounds.end.y) or (normal.y > 0 and target.y < bounds.position.y))
		var crosses := horizontal or vertical
		var along := tangent.dot(point-bounds.get_center() if crosses else target-point)
		if along < 0: tangent = -tangent
		return resolve(result+tangent*distance,radius,map,false)
	return result
