extends SceneTree

# One-off asset step for the weekly monster pool: prepares the two art-library
# originals exactly like prepare_library_monsters.gd (640 px high, colour bled under
# the transparent edge) and prints the visible region of every new monster PNG as
# JSON for data/visuals/actors.json. Originals are never modified.
# Run: Godot --headless --path godot --script res://tools/prepare_weekly_monsters.gd -- --ui-preview
const LIBRARY := {"monster-002":"originals/monster/monster-002/v01/original.png","monster-014":"originals/monster/monster-014/v02/original.png"}
const GAME_READY := ["haetaeHead","lampFirefly","paperCrane","tileTortoise","fenceSerpent","riverEel"]
const TEXTURE_HEIGHT := 640

func _init() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var library := project.path_join("../art-library").simplify_path()
	var regions := {}
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(library.path_join("catalog.json")))
	var assets := {}
	for asset in catalog.assets: assets[asset.id] = asset
	var provenance_path := project.path_join("../assets/monsters-library/provenance.json").simplify_path()
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(provenance_path))
	for id in LIBRARY:
		var image := Image.load_from_file(library.path_join(LIBRARY[id]))
		image.convert(Image.FORMAT_RGBA8)
		image.resize(roundi(image.get_width() * float(TEXTURE_HEIGHT) / image.get_height()),TEXTURE_HEIGHT,Image.INTERPOLATE_LANCZOS)
		image.fix_alpha_edges()
		# The exporter copies source art over the Godot copy; both must be identical.
		for folder in ["../assets/monsters-library","assets/monsters-library"]:
			image.save_png(project.path_join(folder).simplify_path().path_join(id + ".png"))
		regions[id] = _visible_region(image)
		provenance.files = provenance.files.filter(func(entry): return entry.libraryId != id)
		var asset: Dictionary = assets.get(id,{})
		provenance.files.append({"file":id + ".png","libraryId":id,"nameKo":asset.get("nameKo",""),"family":asset.get("family",""),"source":"art-library/" + str(LIBRARY[id]),"sourceSha256":FileAccess.get_sha256(library.path_join(LIBRARY[id])),"size":[image.get_width(),image.get_height()],"tool":"godot/tools/prepare_weekly_monsters.gd"})
	var file := FileAccess.open(provenance_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(provenance,"  ") + "\n")
	file.close()
	for id in GAME_READY:
		regions[id] = _visible_region(Image.load_from_file(project.path_join("assets/monsters-sd/%s_sd_01.png" % id)))
	print("REGIONS " + JSON.stringify(regions))
	quit()

# Ignores almost-transparent generator specks, like the reviewed regions in actors.json.
func _visible_region(image: Image) -> Array:
	var low := Vector2i(image.get_width(),image.get_height())
	var high := Vector2i(-1,-1)
	for y in range(0,image.get_height(),2):
		for x in range(0,image.get_width(),2):
			if image.get_pixel(x,y).a > 0.12:
				low = low.min(Vector2i(x,y)); high = high.max(Vector2i(x,y))
	low = (low - Vector2i(4,4)).max(Vector2i.ZERO)
	high = (high + Vector2i(4,4)).min(Vector2i(image.get_width(),image.get_height()))
	return [low.x,low.y,high.x - low.x,high.y - low.y]
