## Builds a SpriteFrames for each Meadow monster.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/build_enemy_frames.gd
## Run `--headless --path . --import` first so the sheets are imported. Safe to
## re-run; it overwrites resources/enemies/<id>_frames.tres.
##
## Each sheet is a horizontal strip of four square, right-facing frames, drawn
## at native scale with the ground point at the bottom center.
extends SceneTree

const FRAME_COUNT: int = 4
const WALK_CLIP: StringName = &"walk"
const WALK_FPS: float = 6.0
const OUTPUT_DIRECTORY: String = "res://resources/enemies"
const MONSTERS: Dictionary[StringName, int] = {
	&"bamboo": 32,
	&"blue_bat": 32,
	&"spider_red": 32,
	&"panda": 44,
	&"bear": 76,
}


func _init() -> void:
	var failed: bool = false
	for id: StringName in MONSTERS:
		if not _build(id, MONSTERS[id]):
			failed = true
	quit(1 if failed else 0)


func _build(id: StringName, frame_size: int) -> bool:
	var sheet_path: String = "res://assets/sprites/enemies/%s_walk.png" % id
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		printerr("build_enemy_frames: cannot load %s (run --import first?)" % sheet_path)
		return false
	var needed: Vector2i = Vector2i(FRAME_COUNT * frame_size, frame_size)
	if Vector2i(sheet.get_size()) != needed:
		printerr("build_enemy_frames: %s has invalid dimensions, expected %s" % [sheet_path, needed])
		return false

	var frames: SpriteFrames = SpriteFrames.new()
	frames.rename_animation(&"default", WALK_CLIP)
	frames.set_animation_speed(WALK_CLIP, WALK_FPS)
	frames.set_animation_loop(WALK_CLIP, true)
	for index: int in FRAME_COUNT:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(index * frame_size, 0, frame_size, frame_size)
		frame.filter_clip = true
		frames.add_frame(WALK_CLIP, frame)

	var path: String = OUTPUT_DIRECTORY.path_join("%s_frames.tres" % id)
	var err: Error = ResourceSaver.save(frames, path)
	if err != OK:
		printerr("build_enemy_frames: cannot save %s (error %d)" % [path, err])
		return false
	print("Wrote %s" % path)
	return true
