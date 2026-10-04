class_name HeroSaves
extends RefCounted
## The three hero save slots, each a HeroData saved to its own file.
##
## Slots are fully isolated (DESIGN.md section 5.1): deleting or overwriting
## one never touches another. Slot indices run from 0 to SLOT_COUNT - 1.
##
## Files are Godot text resources. A resource file can embed a script, so these
## are only safe to load because they are the player's own files in user://;
## never load a save that came from anywhere else.

const SLOT_COUNT: int = 3
const DIRECTORY: String = "user://heroes"


static func path_for(slot: int) -> String:
	return DIRECTORY.path_join("slot_%d.tres" % (slot + 1))


static func has_hero(slot: int) -> bool:
	return _is_valid(slot) and FileAccess.file_exists(path_for(slot))


## The hero in `slot`, or null if the slot is empty. A slot whose file exists
## but cannot be read as a hero is an error, not an empty slot. A hero saved by
## an older version is upgraded and written back, so it upgrades only once.
static func load_hero(slot: int) -> HeroData:
	if not has_hero(slot):
		return null

	var path: String = path_for(slot)
	# Ignore the cache so a reload always reflects what is on disk.
	var loaded: Resource = ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	if loaded is not HeroData:
		push_error("HeroSaves: %s is not a readable hero." % path)
		return null
	var hero: HeroData = loaded
	if hero.upgrade():
		save_hero(slot, hero)
	return hero


static func save_hero(slot: int, hero: HeroData) -> Error:
	if not _is_valid(slot):
		return ERR_PARAMETER_RANGE_ERROR
	if hero == null:
		push_error("HeroSaves: cannot save an empty hero to slot %d." % slot)
		return ERR_INVALID_PARAMETER

	var made: Error = DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if made != OK:
		push_error("HeroSaves: cannot create %s (%s)." % [DIRECTORY, error_string(made)])
		return made

	var saved: Error = ResourceSaver.save(hero, path_for(slot))
	if saved != OK:
		push_error("HeroSaves: saving slot %d failed (%s)." % [slot, error_string(saved)])
	return saved


static func delete_hero(slot: int) -> Error:
	if not has_hero(slot):
		return OK
	var removed: Error = DirAccess.remove_absolute(path_for(slot))
	if removed != OK:
		push_error("HeroSaves: deleting slot %d failed (%s)." % [slot, error_string(removed)])
	return removed


static func _is_valid(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_error("HeroSaves: slot %d is out of range 0-%d." % [slot, SLOT_COUNT - 1])
		return false
	return true
