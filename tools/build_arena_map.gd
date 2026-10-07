extends SceneTree
## Generates the meadow arena: its TileSet and its scene.
##
## Run with:
##   godot --headless --path . --script res://tools/build_arena_map.gd
##
## The map is not hand-painted. Every tile comes from the constants below and
## SEED, so the same inputs always give the same map, and a change to the arena
## shows up as a readable diff here instead of an opaque tile_map_data blob.
## Hand edits to the generated scene are overwritten by the next run.
##
## Pack tiles are 16x16 and every layer is scaled by SCALE, so a cell is 32px on
## screen beside the 1x hero. Positions and sizes below are in cells unless
## named otherwise; atlas coordinates are in 16px pack tiles.
##
## The scene is a y-sorted root holding the Ground and Decor layers, which sit
## below everything, a y-sorted Trees layer, and Bounds, one wall per side
## outside the playable field. Each tree is anchored at its trunk, so whatever
## stands below a trunk is drawn in front of that tree and anything above it
## passes behind.
##
## Safe to re-run: both files are rebuilt from scratch and keep their uids.

enum Source { FLOOR, NATURE, DETAIL }

const TILESET_PATH: String = "res://resources/arena/meadow_tileset.tres"
const SCENE_PATH: String = "res://scenes/arena/meadow.tscn"
const TEXTURES: Dictionary = {
	Source.FLOOR: "res://assets/packs/ninja_adventure/tilesets/tileset_floor.png",
	Source.NATURE: "res://assets/packs/ninja_adventure/tilesets/tileset_nature.png",
	Source.DETAIL: "res://assets/packs/ninja_adventure/tilesets/tileset_floor_detail.png",
}

const TILE: int = 16
const SCALE: int = 2
## The ground the hero can stand on.
const FIELD: Vector2i = Vector2i(48, 27)
## Depth of the tree line around FIELD. The map is FIELD plus this on every side.
const BORDER: int = 4
## Rows of open grass between FIELD's bottom edge and the first trunks there.
## The trees on that side are drawn in front of the hero, so their canopies
## reach up over the hero's feet; this keeps them from hiding the whole hero.
const BOTTOM_SETBACK: int = 1
const SEED: int = 20261006

## Plain grass, weighted so the unmarked tile dominates.
const GRASS: Array[Dictionary] = [
	{"at": Vector2i(0, 12), "weight": 60},
	{"at": Vector2i(1, 12), "weight": 2},
	{"at": Vector2i(2, 12), "weight": 2},
	{"at": Vector2i(3, 12), "weight": 2},
	{"at": Vector2i(2, 11), "weight": 1},
	{"at": Vector2i(3, 11), "weight": 1},
]

## Top-left of the pack's 3x3 dirt-in-grass blob. Its corners, edges and centre
## are stretched over each patch, so a patch is never smaller than 2x2.
const DIRT_BLOB: Vector2i = Vector2i(0, 7)
const DIRT_PATCHES: int = 7
const DIRT_MIN: Vector2i = Vector2i(2, 2)
const DIRT_MAX: Vector2i = Vector2i(6, 4)
## Clear cells kept between a patch and FIELD's edge or another patch.
const DIRT_MARGIN: int = 2

## `base` is the trunk's row in the tile's own pixels; the tile is drawn so that
## row sits on its cell. `radius` is how close, in cells, another trunk may be.
const TREES: Array[Dictionary] = [
	{"at": Vector2i(0, 0), "size": Vector2i(2, 2), "base": 28, "radius": 0.55, "weight": 6},
	{"at": Vector2i(2, 0), "size": Vector2i(2, 2), "base": 28, "radius": 0.55, "weight": 5},
	{"at": Vector2i(16, 0), "size": Vector2i(2, 2), "base": 28, "radius": 0.55, "weight": 6},
	{"at": Vector2i(18, 0), "size": Vector2i(2, 2), "base": 28, "radius": 0.55, "weight": 2},
	{"at": Vector2i(0, 2), "size": Vector2i(4, 3), "base": 44, "radius": 1.1, "weight": 2},
	{"at": Vector2i(4, 2), "size": Vector2i(4, 3), "base": 44, "radius": 1.1, "weight": 2},
	{"at": Vector2i(16, 2), "size": Vector2i(4, 3), "base": 44, "radius": 1.1, "weight": 2},
]

## Tufts, sprouts and flowers scattered over the grass. Decoration only: nothing
## here collides.
const DECOR: Array[Dictionary] = [
	{"source": Source.DETAIL, "at": Vector2i(0, 2), "weight": 4},
	{"source": Source.DETAIL, "at": Vector2i(1, 2), "weight": 3},
	{"source": Source.DETAIL, "at": Vector2i(2, 2), "weight": 3},
	{"source": Source.DETAIL, "at": Vector2i(3, 2), "weight": 5},
	{"source": Source.DETAIL, "at": Vector2i(4, 2), "weight": 2},
	{"source": Source.DETAIL, "at": Vector2i(5, 2), "weight": 1},
	{"source": Source.DETAIL, "at": Vector2i(6, 2), "weight": 2},
	{"source": Source.DETAIL, "at": Vector2i(7, 2), "weight": 2},
	{"source": Source.NATURE, "at": Vector2i(0, 11), "weight": 1},
	{"source": Source.NATURE, "at": Vector2i(1, 11), "weight": 1},
]
const DECOR_CHANCE: float = 0.06

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = SEED

	var tile_set: TileSet = _build_tile_set()
	if tile_set == null or not _save(tile_set, TILESET_PATH):
		quit(1)
		return
	# Reload so the scene refers to the saved file instead of embedding a copy.
	tile_set = ResourceLoader.load(TILESET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)

	var arena: ArenaMap = _build_arena(tile_set)
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(arena)
	arena.free()
	if error != OK:
		push_error("build_arena_map: packing the scene failed (%d)" % error)
		quit(1)
		return
	if not _save(scene, SCENE_PATH):
		quit(1)
		return
	quit(0)


func _build_tile_set() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)

	var atlases: Dictionary = {}
	for source: int in TEXTURES:
		var path: String = TEXTURES[source]
		if not ResourceLoader.exists(path):
			push_error("build_arena_map: missing texture %s; run --import first" % path)
			return null
		var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
		atlas.texture = load(path)
		atlas.texture_region_size = Vector2i(TILE, TILE)
		tile_set.add_source(atlas, source)
		atlases[source] = atlas

	var floor_atlas: TileSetAtlasSource = atlases[Source.FLOOR]
	for grass: Dictionary in GRASS:
		floor_atlas.create_tile(grass["at"])
	for y in 3:
		for x in 3:
			floor_atlas.create_tile(DIRT_BLOB + Vector2i(x, y))

	var nature_atlas: TileSetAtlasSource = atlases[Source.NATURE]
	for tree: Dictionary in TREES:
		var at: Vector2i = tree["at"]
		var size: Vector2i = tree["size"]
		nature_atlas.create_tile(at, size)
		# A tile is drawn centred on its cell; lift it so the trunk is there.
		var data: TileData = nature_atlas.get_tile_data(at, 0)
		data.texture_origin = Vector2i(0, int(tree["base"]) - size.y * TILE / 2)

	for decor: Dictionary in DECOR:
		var atlas: TileSetAtlasSource = atlases[decor["source"]]
		atlas.create_tile(decor["at"])

	return tile_set


func _build_arena(tile_set: TileSet) -> ArenaMap:
	var arena: ArenaMap = ArenaMap.new()
	arena.name = &"Meadow"
	arena.y_sort_enabled = true

	var cell: float = float(TILE * SCALE)
	var map: Vector2i = FIELD + Vector2i(BORDER, BORDER) * 2
	arena.map_rect = Rect2(Vector2.ZERO, Vector2(map) * cell)
	arena.playable_rect = Rect2(Vector2(BORDER, BORDER) * cell, Vector2(FIELD) * cell)

	var ground: TileMapLayer = _add_layer(arena, &"Ground", tile_set, -2)
	var decor: TileMapLayer = _add_layer(arena, &"Decor", tile_set, -1)
	var trees: TileMapLayer = _add_layer(arena, &"Trees", tile_set, 0)
	trees.y_sort_enabled = true

	var dirt: Dictionary = _paint_ground(ground, map)
	_paint_decor(decor, map, dirt)
	_plant_trees(trees, map)
	_add_bounds(arena)
	return arena


func _add_layer(
	arena: ArenaMap, layer_name: StringName, tile_set: TileSet, z: int
) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.scale = Vector2(SCALE, SCALE)
	layer.z_index = z
	arena.add_child(layer)
	layer.owner = arena
	return layer


## Fill the map with grass and stamp dirt patches inside the field. Returns the
## dirt cells, so decoration can keep off them.
func _paint_ground(ground: TileMapLayer, map: Vector2i) -> Dictionary:
	for y in map.y:
		for x in map.x:
			ground.set_cell(Vector2i(x, y), Source.FLOOR, _pick(GRASS)["at"])

	var dirt: Dictionary = {}
	var inner: Rect2i = Rect2i(Vector2i(BORDER, BORDER), FIELD).grow(-DIRT_MARGIN)
	var patches: Array[Rect2i] = []
	var attempts: int = 0
	while patches.size() < DIRT_PATCHES and attempts < 500:
		attempts += 1
		var size: Vector2i = Vector2i(
			_rng.randi_range(DIRT_MIN.x, DIRT_MAX.x), _rng.randi_range(DIRT_MIN.y, DIRT_MAX.y)
		)
		var origin: Vector2i = Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - size.x),
			_rng.randi_range(inner.position.y, inner.end.y - size.y),
		)
		var patch: Rect2i = Rect2i(origin, size)
		var touching: bool = patches.any(
			func(other: Rect2i) -> bool: return other.grow(DIRT_MARGIN).intersects(patch)
		)
		if touching:
			continue
		patches.append(patch)

	if patches.size() < DIRT_PATCHES:
		push_warning(
			"build_arena_map: only %d of %d dirt patches fit" % [patches.size(), DIRT_PATCHES]
		)

	for patch: Rect2i in patches:
		for y in range(patch.position.y, patch.end.y):
			for x in range(patch.position.x, patch.end.x):
				var part: Vector2i = Vector2i(
					_blob_part(x, patch.position.x, patch.end.x - 1),
					_blob_part(y, patch.position.y, patch.end.y - 1),
				)
				ground.set_cell(Vector2i(x, y), Source.FLOOR, DIRT_BLOB + part)
				dirt[Vector2i(x, y)] = true
	return dirt


func _paint_decor(decor: TileMapLayer, map: Vector2i, dirt: Dictionary) -> void:
	for y in map.y:
		for x in map.x:
			var at: Vector2i = Vector2i(x, y)
			if dirt.has(at) or _rng.randf() >= DECOR_CHANCE:
				continue
			var pick: Dictionary = _pick(DECOR)
			decor.set_cell(at, pick["source"], pick["at"])


## Scatter trees over every cell outside the field, one row past the map's edge
## so canopies rooted off-map still fill it. Candidates are visited in a seeded
## random order and a tree is kept only where no other trunk is too close.
func _plant_trees(trees: TileMapLayer, map: Vector2i) -> void:
	var clearing: Rect2i = Rect2i(
		Vector2i(BORDER, BORDER), FIELD + Vector2i(0, BOTTOM_SETBACK)
	)
	var candidates: Array[Vector2i] = []
	for y in range(-1, map.y + 1):
		for x in range(-1, map.x + 1):
			var at: Vector2i = Vector2i(x, y)
			if not clearing.has_point(at):
				candidates.append(at)

	for i in range(candidates.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Vector2i = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap

	var planted: Array[Dictionary] = []
	for at: Vector2i in candidates:
		var tree: Dictionary = _pick(TREES)
		var radius: float = tree["radius"]
		var crowded: bool = planted.any(
			func(other: Dictionary) -> bool:
				var gap: float = Vector2(at).distance_to(Vector2(other["at"]))
				return gap < radius + float(other["radius"])
		)
		if crowded:
			continue
		trees.set_cell(at, Source.NATURE, tree["at"])
		planted.append({"at": at, "radius": radius})


## One wall per side, filling the tree line from the field's edge to the map's.
func _add_bounds(arena: ArenaMap) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = &"Bounds"
	arena.add_child(body)
	body.owner = arena

	var outer: Rect2 = arena.map_rect
	var inner: Rect2 = arena.playable_rect
	var walls: Dictionary[StringName, Rect2] = {
		&"Top": Rect2(outer.position, Vector2(outer.size.x, inner.position.y - outer.position.y)),
		&"Bottom": Rect2(outer.position.x, inner.end.y, outer.size.x, outer.end.y - inner.end.y),
		&"Left": Rect2(
			outer.position.x, inner.position.y, inner.position.x - outer.position.x, inner.size.y
		),
		&"Right": Rect2(inner.end.x, inner.position.y, outer.end.x - inner.end.x, inner.size.y),
	}
	for side: StringName in walls:
		var wall: Rect2 = walls[side]
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = wall.size
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.name = side
		collider.shape = shape
		collider.position = wall.get_center()
		body.add_child(collider)
		collider.owner = arena


## 0, 1 or 2: the blob column (or row) for `value` along a patch from `first`
## to `last`, so the patch's edges get the blob's edges and the rest its centre.
func _blob_part(value: int, first: int, last: int) -> int:
	if value == first:
		return 0
	if value == last:
		return 2
	return 1


func _pick(options: Array[Dictionary]) -> Dictionary:
	var total: int = 0
	for option: Dictionary in options:
		total += int(option["weight"])
	var roll: int = _rng.randi_range(1, total)
	for option: Dictionary in options:
		roll -= int(option["weight"])
		if roll <= 0:
			return option
	return options.back()


## Save `resource` at `path`, keeping the uid other files refer to it by.
func _save(resource: Resource, path: String) -> bool:
	var uid: int = _existing_uid(path)
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()

	var folder: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		push_error("build_arena_map: cannot create %s" % path.get_base_dir())
		return false

	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("build_arena_map: saving %s failed (%d)" % [path, error])
		return false
	error = ResourceSaver.set_uid(path, uid)
	if error != OK:
		push_error("build_arena_map: setting the uid of %s failed (%d)" % [path, error])
		return false
	if path.get_extension() == "tscn" and not _strip_unique_ids(path):
		return false

	print("built %s" % path)
	return true


## The uid in `path`'s header. Read from the file itself, because the engine's
## uid cache only knows files the editor has scanned, and a file this tool made
## headlessly has never been scanned.
func _existing_uid(path: String) -> int:
	if not FileAccess.file_exists(path):
		return ResourceUID.INVALID_ID
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ResourceUID.INVALID_ID
	var found: RegExMatch = RegEx.create_from_string("uid=\"(uid://[^\"]+)\"").search(
		file.get_line()
	)
	file.close()
	return ResourceUID.text_to_id(found.get_string(1)) if found else ResourceUID.INVALID_ID


## Node unique_ids are random on every save, so they would turn each re-run into
## a diff. A scene loads fine without them, and nothing instanced from this one
## overrides its nodes, so they are dropped and the output depends on SEED alone.
func _strip_unique_ids(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("build_arena_map: cannot reopen %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	text = RegEx.create_from_string(" unique_id=\\d+").sub(text, "", true)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("build_arena_map: cannot rewrite %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true
