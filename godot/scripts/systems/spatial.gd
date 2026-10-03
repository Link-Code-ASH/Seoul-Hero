class_name HeroSpatial
extends RefCounted

var cells: Dictionary = {}
var cell_size := 96.0

func rebuild(enemies: Array) -> void:
	cells.clear()
	for enemy in enemies:
		if enemy.hp <= 0: continue
		var key := Vector2i(floori(enemy.pos.x / cell_size), floori(enemy.pos.y / cell_size))
		if not cells.has(key): cells[key] = []
		cells[key].append(enemy)

func nearby(position: Vector2, radius: float) -> Array:
	var result: Array = []
	var low := Vector2i(floori((position.x - radius) / cell_size), floori((position.y - radius) / cell_size))
	var high := Vector2i(floori((position.x + radius) / cell_size), floori((position.y + radius) / cell_size))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			result.append_array(cells.get(Vector2i(x, y), []))
	return result
