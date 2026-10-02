class_name ArmourItem
extends Resource
## One Armour item: the art pool it was rolled from and the piece worn on each
## layer.
##
## Each piece is rolled separately from its base class's pool when the item is
## acquired, and the piece numbers are stored here rather than re-rolled. That
## is what keeps an existing item looking the same after art is added to a
## pool. A piece id is the zero-padded number in the art's file name, so ids
## are never renumbered or reused; 0 means the item has no such piece.

enum Piece { HAT, SHIRT, PANTS }

const FRAMES_ROOT: String = "res://resources/chibi/equipment/armour"
## Folder names under a pool, indexed by Piece.
const PIECE_FOLDERS: PackedStringArray = ["hat", "shirt", "pants"]
const FRAMES_SUFFIX: String = "_frames.tres"
const NO_PIECE: int = 0

## Base class whose art this item was rolled from, such as &"mage".
@export var pool: StringName = &""
@export_range(0, 99) var hat_id: int = NO_PIECE
@export_range(0, 99) var shirt_id: int = NO_PIECE
@export_range(0, 99) var pants_id: int = NO_PIECE


## Roll each piece independently from `pool_id`'s art. A piece with no art in
## the pool is left empty, which is how Novice armour comes out hatless.
static func roll(pool_id: StringName, rng: RandomNumberGenerator = null) -> ArmourItem:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	var item: ArmourItem = ArmourItem.new()
	item.pool = pool_id
	item.hat_id = _roll_piece(pool_id, Piece.HAT, rng)
	item.shirt_id = _roll_piece(pool_id, Piece.SHIRT, rng)
	item.pants_id = _roll_piece(pool_id, Piece.PANTS, rng)

	if item.hat_id == NO_PIECE and item.shirt_id == NO_PIECE and item.pants_id == NO_PIECE:
		push_error("ArmourItem: pool '%s' has no armour art to roll from." % pool_id)
		return null
	return item


## Every piece id with built frames for `piece` in `pool_id`, in ascending order.
static func available_ids(pool_id: StringName, piece: Piece) -> PackedInt32Array:
	var ids: PackedInt32Array = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(_piece_folder(pool_id, piece)):
		if not file.ends_with(FRAMES_SUFFIX):
			continue
		var stem: String = file.trim_suffix(FRAMES_SUFFIX)
		if stem.is_valid_int() and stem.to_int() > NO_PIECE:
			ids.append(stem.to_int())
	ids.sort()
	return ids


func piece_id(piece: Piece) -> int:
	match piece:
		Piece.HAT:
			return hat_id
		Piece.SHIRT:
			return shirt_id
		Piece.PANTS:
			return pants_id
	return NO_PIECE


## The frames to draw for `piece`, or null when this item has no such piece.
func frames_for(piece: Piece) -> SpriteFrames:
	var id: int = piece_id(piece)
	if id == NO_PIECE:
		return null

	var path: String = "%s/%02d%s" % [_piece_folder(pool, piece), id, FRAMES_SUFFIX]
	if not ResourceLoader.exists(path):
		push_error("ArmourItem: missing frames %s." % path)
		return null
	var frames: SpriteFrames = load(path) as SpriteFrames
	if frames == null:
		push_error("ArmourItem: %s is not a SpriteFrames." % path)
	return frames


static func _roll_piece(pool_id: StringName, piece: Piece, rng: RandomNumberGenerator) -> int:
	var ids: PackedInt32Array = available_ids(pool_id, piece)
	if ids.is_empty():
		return NO_PIECE
	return ids[rng.randi_range(0, ids.size() - 1)]


static func _piece_folder(pool_id: StringName, piece: Piece) -> String:
	return FRAMES_ROOT.path_join(String(pool_id)).path_join(PIECE_FOLDERS[piece])
