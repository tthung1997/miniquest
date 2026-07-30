extends SceneTree
## Regenerates res://resources/hero_frames.tres from the hero sprite sheets.
##
## Run with:
##   godot --headless --path . --script res://tools/build_hero_frames.gd
##
## Safe to re-run: the resource is rebuilt from scratch each time. Re-run it
## whenever a sheet's frame count or layout changes, rather than hand-editing
## the .tres, which nests an AtlasTexture per frame.

const OUTPUT_PATH: String = "res://resources/hero_frames.tres"
const FRAME_SIZE: Vector2i = Vector2i(64, 64)

const CLIPS: Array[Dictionary] = [
	{"name": &"idle", "sheet": "res://assets/sprites/hero/hero_idle.png", "fps": 1.0},
	{"name": &"walk", "sheet": "res://assets/sprites/hero/hero_walk_4f.png", "fps": 8.0},
]


func _init() -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")

	for clip: Dictionary in CLIPS:
		var path: String = clip["sheet"]
		if not ResourceLoader.exists(path):
			push_error("build_hero_frames: missing sheet %s" % path)
			quit(1)
			return

		var sheet: Texture2D = load(path)
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

		print("  %s: %d frame(s)" % [clip_name, columns])

	var error: Error = ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("build_hero_frames: save failed (%d)" % error)
		quit(1)
		return

	print("Wrote %s" % OUTPUT_PATH)
	quit(0)
