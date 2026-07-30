extends SceneTree
## Regenerates the SpriteFrames resources for the hero and any equipment layers.
##
## Run with:
##   godot --headless --path . --script res://tools/build_hero_frames.gd
##
## Every layer shares one clip structure - same names, same frame counts - so a
## paper doll can drive them all from a single animation and frame index. A
## layer whose sheets are absent is skipped rather than failing the run, since
## equipment is added over time.
##
## Safe to re-run: each resource is rebuilt from scratch. Re-run whenever a
## sheet's layout changes, rather than hand-editing a .tres that nests an
## AtlasTexture per frame.

const SPRITE_DIR: String = "res://assets/sprites/hero"
const OUTPUT_DIR: String = "res://resources"
const FRAME_SIZE: Vector2i = Vector2i(64, 64)

const CLIPS: Array[Dictionary] = [
	{"name": &"idle", "suffix": "idle", "fps": 1.0},
	{"name": &"walk", "suffix": "walk_4f", "fps": 8.0},
]

## slug -> the sheets are <slug>_<suffix>.png. "hero" is the base body; the
## rest are equipment layers drawn over it.
const LAYERS: Array[Dictionary] = [
	{"slug": "hero", "required": true},
	{"slug": "hat", "required": false},
	{"slug": "shirt", "required": false},
]


func _init() -> void:
	var built: int = 0

	for layer: Dictionary in LAYERS:
		var slug: String = layer["slug"]
		var missing: PackedStringArray = _missing_sheets(slug)

		if not missing.is_empty():
			if layer["required"]:
				push_error(
					"build_hero_frames: layer '%s' is required but missing %s"
					% [slug, ", ".join(missing)]
				)
				quit(1)
				return
			print("skip %s (no sheets yet)" % slug)
			continue

		if not _build_layer(slug):
			quit(1)
			return
		built += 1

	print("Built %d layer(s)." % built)
	quit(0)


func _missing_sheets(slug: String) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for clip: Dictionary in CLIPS:
		var path: String = _sheet_path(slug, clip["suffix"])
		if not ResourceLoader.exists(path):
			missing.append(path)
	return missing


func _build_layer(slug: String) -> bool:
	var output: String = "%s/%s_frames.tres" % [OUTPUT_DIR, slug]

	# Scenes reference these resources by uid, and ResourceSaver drops the uid
	# line when it rewrites a file headlessly. Capture it first and restore it,
	# or regenerating a layer silently breaks every scene pointing at it.
	var uid_text: String = ""
	if FileAccess.file_exists(output):
		var existing: int = ResourceLoader.get_resource_uid(output)
		if existing != ResourceUID.INVALID_ID:
			uid_text = ResourceUID.id_to_text(existing)

	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	for clip: Dictionary in CLIPS:
		var sheet: Texture2D = load(_sheet_path(slug, clip["suffix"]))
		var columns: int = maxi(sheet.get_width() / FRAME_SIZE.x, 1)
		var clip_name: StringName = clip["name"]

		frames.add_animation(clip_name)
		frames.set_animation_speed(clip_name, clip["fps"])
		frames.set_animation_loop(clip_name, true)

		for i in columns:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				float(i * FRAME_SIZE.x), 0.0, float(FRAME_SIZE.x), float(FRAME_SIZE.y)
			)
			frames.add_frame(clip_name, atlas)

	var error: Error = ResourceSaver.save(frames, output)
	if error != OK:
		push_error("build_hero_frames: saving %s failed (%d)" % [output, error])
		return false

	if not uid_text.is_empty() and not _restore_uid(output, uid_text):
		return false

	print("built %s%s" % [output, "" if uid_text.is_empty() else " (uid kept)"])
	return true


## Put `uid_text` back on the [gd_resource] header if ResourceSaver left it off.
func _restore_uid(path: String, uid_text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("build_hero_frames: cannot reopen %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	if text.contains("uid=\""):
		return true

	var marker: String = "[gd_resource "
	var start: int = text.find(marker)
	var end: int = text.find("]", start)
	if start < 0 or end < 0:
		push_error("build_hero_frames: no resource header in %s" % path)
		return false

	text = "%s uid=\"%s\"%s" % [text.substr(0, end), uid_text, text.substr(end)]

	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("build_hero_frames: cannot rewrite %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _sheet_path(slug: String, suffix: String) -> String:
	return "%s/%s_%s.png" % [SPRITE_DIR, slug, suffix]
