## One-shot tool: builds a SpriteFrames for each pack monster listed in MONSTERS.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/build_enemy_frames.gd
## Run `--headless --path . --import` first so the sheets are imported. Safe to
## re-run; it overwrites resources/enemies/<id>_frames.tres.
##
## The pack's monster sheets are a grid of 16x16 frames: one column per facing
## (down, up, left, right) and one row per walk frame. Enemies are side-on, so
## only the right-facing column is used; the enemy mirrors it to face left.
extends SceneTree

const FRAME_SIZE: int = 16
const RIGHT_COLUMN: int = 3
const FRAME_COUNT: int = 4
const WALK_CLIP: StringName = &"walk"
const WALK_FPS: float = 6.0
const OUTPUT_DIRECTORY: String = "res://resources/enemies"
const MONSTERS: Dictionary[StringName, String] = {
	&"bamboo": "res://assets/packs/ninja_adventure/monsters/bamboo.png",
}


func _init() -> void:
	var failed: bool = false
	for id: StringName in MONSTERS:
		if not _build(id, MONSTERS[id]):
			failed = true
	quit(1 if failed else 0)


func _build(id: StringName, sheet_path: String) -> bool:
	var sheet: Texture2D = load(sheet_path) as Texture2D
	if sheet == null:
		printerr("build_enemy_frames: cannot load %s (run --import first?)" % sheet_path)
		return false
	var needed: Vector2i = Vector2i((RIGHT_COLUMN + 1) * FRAME_SIZE, FRAME_COUNT * FRAME_SIZE)
	if sheet.get_width() < needed.x or sheet.get_height() < needed.y:
		printerr("build_enemy_frames: %s is smaller than %s" % [sheet_path, needed])
		return false

	var frames: SpriteFrames = SpriteFrames.new()
	frames.rename_animation(&"default", WALK_CLIP)
	frames.set_animation_speed(WALK_CLIP, WALK_FPS)
	frames.set_animation_loop(WALK_CLIP, true)
	for row: int in FRAME_COUNT:
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			RIGHT_COLUMN * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE
		)
		frames.add_frame(WALK_CLIP, frame)

	var path: String = OUTPUT_DIRECTORY.path_join("%s_frames.tres" % id)
	var err: Error = ResourceSaver.save(frames, path)
	if err != OK:
		printerr("build_enemy_frames: cannot save %s (error %d)" % [path, err])
		return false
	print("Wrote %s" % path)
	return true
