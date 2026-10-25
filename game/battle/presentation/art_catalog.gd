extends RefCounted
## One replaceable mapping; battle rules never reference these paths.
const ROOT := "res://assets/reference/"
var cache: Dictionary = {}
var variant: bool = false
var warnings: Array = []
var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/visuals.json"))

func source_facing(visual: String) -> String:
	return visuals.actors.get(visual, {}).get("source_facing", visuals.default_source_facing)

func texture(visual: String, pose: String = "idle") -> Texture2D:
	var file := visual + "_" + pose
	if visual == "warden" and pose == "idle" and variant: file = "warden_variant"
	if cache.has(file): return cache[file]
	var path := ROOT + file + ".png"
	if ResourceLoader.exists(path):
		cache[file] = load(path)
		return cache[file]
	if not file in warnings:
		warnings.append(file)
		push_warning("Missing optional art: " + file)
	if pose != "idle": return texture(visual, "idle")
	return null

func portrait(visual: String) -> Texture2D:
	if ResourceLoader.exists(ROOT + visual + "_portrait.png"): return texture(visual, "portrait")
	return texture(visual)

func skill_icon(visual: String, index: int) -> Texture2D:
	return texture(visual, ["one", "two", "three"][index])
