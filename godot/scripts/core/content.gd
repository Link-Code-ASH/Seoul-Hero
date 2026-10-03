extends Node

var data: Dictionary = {}
var visuals: Dictionary = {}
var ui_materials: Dictionary = {}
var _textures: Dictionary = {}
var _trimmed: Dictionary = {}
var _regions: Dictionary = {}

func _ready() -> void:
	ui_materials = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/ui_materials.json"))
	visuals = JSON.parse_string(FileAccess.get_file_as_string("res://data/visuals/actors.json"))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("콘텐츠를 읽을 수 없습니다. export-godot-content.mjs를 실행하세요.")

func texture(id: String) -> Texture2D:
	if _textures.has(id): return _textures[id]
	var url: String = id if id.begins_with("res://") else data.get("images", {}).get(id, {}).get("url", "")
	url = visuals.get("resources", {}).get(id, url)
	var result: Texture2D = load(url) if not url.is_empty() and ResourceLoader.exists(url) else null
	_textures[id] = result
	return result

func actor_preview(group: String, id: String, fallback: String) -> Texture2D:
	var visual: Dictionary = visuals.get(group,{}).get(id,{})
	if visual.get("rig","") in ["sd","legless"]: return actor_texture(visual)
	var path: String = visual.get("portrait", "")
	return trimmed_texture(path) if not path.is_empty() and ResourceLoader.exists(path) else trimmed_texture(fallback)

func actor_texture(visual: Dictionary) -> Texture2D:
	var id: String = visual.sprite
	var region: Array = visual.get("region",[])
	if region.size() != 4: return trimmed_texture(id)
	# Reviewed visible bounds exclude almost-transparent generator specks. The PNG
	# remains intact, and portrait/foot pivot/weapon clearance use identical bounds.
	var key := id+str(region)
	if _regions.has(key): return _regions[key]
	var atlas := AtlasTexture.new()
	atlas.atlas = texture(id)
	atlas.region = Rect2(region[0],region[1],region[2],region[3])
	atlas.filter_clip = true
	_regions[key] = atlas
	return atlas

func trimmed_texture(id: String) -> Texture2D:
	if _trimmed.has(id): return _trimmed[id]
	var original := texture(id)
	if original == null: return null
	var image := original.get_image()
	var authored_region: Array = data.get("images",{}).get(id,{}).get("region",[])
	var rect := image.get_used_rect()
	if authored_region.size() == 4:
		# Atlas entries own their reviewed source cell; trim only within that cell.
		var cell := Rect2i(authored_region[0],authored_region[1],authored_region[2],authored_region[3])
		var used := image.get_region(cell).get_used_rect()
		rect = Rect2i(cell.position+used.position,used.size)
	if rect.size.x == 0 or rect.size.y == 0: return original
	var atlas := AtlasTexture.new()
	atlas.atlas = original
	atlas.region = Rect2(rect)
	atlas.filter_clip = true
	_trimmed[id] = atlas
	return atlas

func weapon_icon(id: String) -> Texture2D:
	return trimmed_texture(data.weaponArt.get(id, "weaponManaBolt"))

func item_icon(id: String) -> Texture2D:
	var icon: String = data.items.get(id, {}).get("icon", "")
	if data.images.has(icon): return trimmed_texture(icon)
	var ids := ["energyDrink","riceBall","runningShoes","scope","luckyCharm","vest","bandage","wallet","notebook","magnet","gloves","sight","lens","spring","timer","battery","wideLens","criticalEye","sharpStone","umbrella","bloodPack","swordManual","toolbox","conductor","splitter","mineCase","cursedStone","hunterCoat","bloodCircuit","commandCore","stormCore"]
	var index := maxi(0, ids.find(id))
	var atlas := AtlasTexture.new()
	atlas.atlas = texture("inventoryAtlasTransparent")
	var size := atlas.atlas.get_size() / Vector2(8, 6)
	atlas.region = Rect2(Vector2(index % 8, floori(index / 8.0)) * size, size)
	atlas.filter_clip = true
	return atlas
