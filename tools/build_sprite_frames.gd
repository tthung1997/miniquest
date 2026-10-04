extends SceneTree
## Regenerates a SpriteFrames resource for every layer of each body rig.
##
## Run with:
##   godot --headless --path . --script res://tools/build_sprite_frames.gd
##
## A rig is a folder under assets/sprites whose layers all share one frame size
## and one clip structure, so a paper doll can drive every layer from a single
## animation and frame index. Each <name>_<clip>.png group in a rig becomes one
## resource: body_<clip>.png at the rig root is the base layer, and groups in
## subfolders, such as equipment/armour/mage/hat/01_walk.png, are drawn over it.
## Output mirrors the source tree under resources/<rig>/. A piece's
## <name>_icon.png is its inventory icon, not a clip, and is left alone.
##
## A layer may also own clips the body does not have, such as a weapon's
## <name>_attack.png. These play on the layer's own clock, so their frame
## counts are free; they are optional and never allowed on the body.
##
## Each listed effect, assets/sprites/effects/<name>.png, becomes
## resources/effects/<name>_frames.tres with one clip, "default". Effect
## frames are square, so a sheet's height is its frame size.
##
## Safe to re-run: each resource is rebuilt from scratch and keeps its uid.
## Re-run after adding or changing a sheet, rather than hand-editing a .tres
## that nests an AtlasTexture per frame.

const SPRITE_ROOT: String = "res://assets/sprites"
const OUTPUT_ROOT: String = "res://resources"
const RIGS: PackedStringArray = ["chibi"]
const BASE_LAYER: String = "body"
const FRAME_SIZE: Vector2i = Vector2i(64, 64)
## Suffix of an equipment piece's icon, which shares the sheets' folder.
const ICON_SUFFIX: String = "icon"
const EFFECT_ROOT: String = "res://assets/sprites/effects"
const EFFECT_OUTPUT: String = "res://resources/effects"
const EFFECT_CLIP: StringName = &"default"

## Frame counts come from each sheet's width, so file names do not carry them.
## Every layer has these, frame for frame with the body.
const CLIPS: Array[Dictionary] = [
	{"name": &"idle", "fps": 1.0, "loop": true},
	{"name": &"walk", "fps": 8.0, "loop": true},
]
## Optional clips a layer plays on its own clock, independent of the body.
const LAYER_CLIPS: Array[Dictionary] = [
	{"name": &"attack", "fps": 10.0, "loop": false},
]
## Effect sheets to build. Other images in the effects folder are left alone.
const EFFECTS: Array[Dictionary] = [
	{"name": "sword_slash", "fps": 15.0, "loop": false},
	{"name": "crossbow_bolt", "fps": 1.0, "loop": true},
	{"name": "magic_bolt", "fps": 12.0, "loop": true},
	{"name": "magic_burst", "fps": 14.0, "loop": false},
]


func _init() -> void:
	for rig: String in RIGS:
		if not _build_rig(rig):
			quit(1)
			return
	if not _build_effects():
		quit(1)
		return
	quit(0)


func _build_rig(rig: String) -> bool:
	var groups: Dictionary = {}
	_collect_sheets(SPRITE_ROOT.path_join(rig), "", groups)
	if not groups.has(BASE_LAYER):
		push_error("build_sprite_frames: rig '%s' has no %s sheets" % [rig, BASE_LAYER])
		return false

	# Base first, so every other layer can be checked against its frame counts.
	var keys: Array[String] = []
	keys.assign(groups.keys())
	keys.sort()
	keys.erase(BASE_LAYER)
	keys.push_front(BASE_LAYER)

	var base_counts: Dictionary = {}
	for key: String in keys:
		var frames: SpriteFrames = _build_frames(key, groups[key])
		if frames == null:
			return false
		if key == BASE_LAYER:
			for clip: Dictionary in CLIPS:
				base_counts[clip["name"]] = frames.get_frame_count(clip["name"])
		elif not _matches_base(key, frames, base_counts):
			return false

		if not _save(frames, "%s/%s/%s_frames.tres" % [OUTPUT_ROOT, rig, key]):
			return false

	print("Built %d layer(s) for rig '%s'." % [keys.size(), rig])
	return true


## Group every <name>_<clip>.png under `path` by name, keyed relative to the rig.
func _collect_sheets(path: String, relative: String, groups: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("build_sprite_frames: cannot open %s" % path)
		return

	for sub: String in dir.get_directories():
		_collect_sheets(path.path_join(sub), _join(relative, sub), groups)

	for file: String in dir.get_files():
		if file.get_extension().to_lower() != "png":
			continue
		var stem: String = file.get_basename()
		var cut: int = stem.rfind("_")
		var clip: String = stem.substr(cut + 1) if cut > 0 else ""
		if clip == ICON_SUFFIX:
			continue
		if not _is_clip(clip):
			push_warning(
				"build_sprite_frames: %s is not named <name>_<clip>.png; skipped"
				% path.path_join(file)
			)
			continue
		var key: String = _join(relative, stem.substr(0, cut))
		if not groups.has(key):
			groups[key] = {}
		groups[key][clip] = path.path_join(file)


func _build_frames(key: String, sheets: Dictionary) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	for clip: Dictionary in CLIPS:
		var clip_name: StringName = clip["name"]
		if not sheets.has(String(clip_name)):
			push_error("build_sprite_frames: layer '%s' has no %s sheet" % [key, clip_name])
			return null
		if not _add_clip(frames, clip, sheets[String(clip_name)], FRAME_SIZE):
			return null

	for clip: Dictionary in LAYER_CLIPS:
		var clip_name: StringName = clip["name"]
		if not sheets.has(String(clip_name)):
			continue
		if key == BASE_LAYER:
			push_error(
				"build_sprite_frames: %s cannot own a %s clip; every layer follows its clips"
				% [BASE_LAYER, clip_name]
			)
			return null
		if not _add_clip(frames, clip, sheets[String(clip_name)], FRAME_SIZE):
			return null

	return frames


## Slice `path` into `frame_size` frames left to right as clip `clip`.
func _add_clip(
	frames: SpriteFrames, clip: Dictionary, path: String, frame_size: Vector2i
) -> bool:
	var clip_name: StringName = clip["name"]
	var sheet: Texture2D = load(path)
	if sheet == null:
		push_error("build_sprite_frames: cannot load %s" % path)
		return false
	var columns: int = maxi(sheet.get_width() / frame_size.x, 1)

	if not frames.has_animation(clip_name):
		frames.add_animation(clip_name)
	frames.set_animation_speed(clip_name, clip["fps"])
	frames.set_animation_loop(clip_name, clip["loop"])

	for i in columns:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(i * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y)
		)
		frames.add_frame(clip_name, atlas)
	return true


func _build_effects() -> bool:
	for effect: Dictionary in EFFECTS:
		var effect_name: String = effect["name"]
		var path: String = EFFECT_ROOT.path_join("%s.png" % effect_name)
		if not ResourceLoader.exists(path):
			push_error("build_sprite_frames: effect sheet %s is missing" % path)
			return false
		var sheet: Texture2D = load(path)
		if sheet == null:
			push_error("build_sprite_frames: cannot load %s" % path)
			return false

		var side: int = sheet.get_height()
		if sheet.get_width() % side != 0:
			push_error(
				"build_sprite_frames: %s is %dx%d; effect frames must be square"
				% [path, sheet.get_width(), side]
			)
			return false

		var frames: SpriteFrames = SpriteFrames.new()
		var clip: Dictionary = {"name": EFFECT_CLIP, "fps": effect["fps"], "loop": effect["loop"]}
		if not _add_clip(frames, clip, path, Vector2i(side, side)):
			return false
		if not _save(frames, EFFECT_OUTPUT.path_join("%s_frames.tres" % effect_name)):
			return false

	print("Built %d effect(s)." % EFFECTS.size())
	return true


## Every layer is driven from the body's frame index, so a layer with a
## different frame count would drift or index past its last frame.
func _matches_base(key: String, frames: SpriteFrames, base_counts: Dictionary) -> bool:
	for clip: Dictionary in CLIPS:
		var clip_name: StringName = clip["name"]
		var count: int = frames.get_frame_count(clip_name)
		if count != base_counts[clip_name]:
			push_error(
				"build_sprite_frames: '%s' %s has %d frame(s), %s has %d; they must match"
				% [key, clip_name, count, BASE_LAYER, base_counts[clip_name]]
			)
			return false
	return true


func _save(frames: SpriteFrames, output: String) -> bool:
	# Scenes reference these resources by uid, and ResourceSaver drops the uid
	# line when it rewrites a file headlessly. Capture it first and restore it,
	# or regenerating a layer silently breaks every scene pointing at it.
	var uid_text: String = ""
	if FileAccess.file_exists(output):
		var existing: int = ResourceLoader.get_resource_uid(output)
		if existing != ResourceUID.INVALID_ID:
			uid_text = ResourceUID.id_to_text(existing)

	var folder: String = ProjectSettings.globalize_path(output.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("build_sprite_frames: cannot create %s" % output.get_base_dir())
		return false

	var error: Error = ResourceSaver.save(frames, output)
	if error != OK:
		push_error("build_sprite_frames: saving %s failed (%d)" % [output, error])
		return false

	if not uid_text.is_empty() and not _restore_uid(output, uid_text):
		return false

	print("built %s%s" % [output, "" if uid_text.is_empty() else " (uid kept)"])
	return true


## Put `uid_text` back on the [gd_resource] header if ResourceSaver left it off.
func _restore_uid(path: String, uid_text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("build_sprite_frames: cannot reopen %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	if text.contains("uid=\""):
		return true

	var marker: String = "[gd_resource "
	var start: int = text.find(marker)
	var end: int = text.find("]", start)
	if start < 0 or end < 0:
		push_error("build_sprite_frames: no resource header in %s" % path)
		return false

	text = "%s uid=\"%s\"%s" % [text.substr(0, end), uid_text, text.substr(end)]

	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("build_sprite_frames: cannot rewrite %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _is_clip(suffix: String) -> bool:
	for clip: Dictionary in CLIPS + LAYER_CLIPS:
		if String(clip["name"]) == suffix:
			return true
	return false


func _join(base: String, part: String) -> String:
	return part if base.is_empty() else base.path_join(part)
