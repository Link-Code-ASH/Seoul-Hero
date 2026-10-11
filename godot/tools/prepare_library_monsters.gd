extends SceneTree

# One-off asset step: copies the art-library monster originals used in combat into
# assets/monsters-library, downscaled to 640 px high with colour bled under the
# transparent edge. Prints the reviewed visible region of every file as JSON for
# data/visuals/actors.json. The art-library originals are never modified.
# Run: Godot --headless --path godot --script res://tools/prepare_library_monsters.gd -- --ui-preview
const FAMILIES := {"rift":1,"glass":3}
const SHAPES := 10
const TEXTURE_HEIGHT := 640

func _init() -> void:
	var project := ProjectSettings.globalize_path("res://")
	var library := project.path_join("../art-library").simplify_path()
	var output := project.path_join("../assets/monsters-library").simplify_path()
	DirAccess.make_dir_recursive_absolute(output)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(library.path_join("catalog.json")))
	var assets := {}
	for asset in catalog.assets: assets[asset.id] = asset
	var regions := {}
	var records: Array = []
	for family in FAMILIES:
		for shape in range(SHAPES):
			var id := "monster-%03d" % (int(FAMILIES[family]) + shape * 16)
			var asset: Dictionary = assets[id]
			var source: Dictionary = asset.record.files[0]
			var image := Image.load_from_file(library.path_join(source.path))
			image.convert(Image.FORMAT_RGBA8)
			image.resize(roundi(image.get_width() * float(TEXTURE_HEIGHT) / image.get_height()),TEXTURE_HEIGHT,Image.INTERPOLATE_LANCZOS)
			image.fix_alpha_edges()
			image.save_png(output.path_join(id + ".png"))
			regions[id] = _visible_region(image)
			records.append({"file":id + ".png","libraryId":id,"nameKo":asset.nameKo,"family":asset.family,"source":"art-library/" + str(source.path),"sourceSha256":source.sha256,"size":[image.get_width(),image.get_height()]})
	var provenance := {"description":"Art-library monster originals prepared for combat: Lanczos downscale to 640 px high and Image.fix_alpha_edges(). Originals, prompts and reviews stay in art-library.","tool":"godot/tools/prepare_library_monsters.gd","files":records}
	var file := FileAccess.open(output.path_join("provenance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(provenance,"  ") + "\n")
	file.close()
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
