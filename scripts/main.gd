class_name Main
extends Node
## Root of the game: shows one screen at a time and moves between them.
##
## Owns the active save slot and hero for this session, without an autoload.
## Screens report choices through signals; this swaps the next screen in.
## The scenes are exported so they are wired in the editor.

@export var character_select_scene: PackedScene
@export var hub_scene: PackedScene
@export var store_scene: PackedScene
@export var gacha_scene: PackedScene
@export var arena_run_scene: PackedScene

var _current: Node = null
var _slot: int = -1
var _hero: HeroData = null


func _ready() -> void:
	if (
		character_select_scene == null
		or hub_scene == null
		or store_scene == null
		or gacha_scene == null
		or arena_run_scene == null
	):
		push_error("Main: CharacterSelect, Hub, Store, Gacha and ArenaRun scenes must be wired.")
		return
	_show_character_select()


func _show_character_select() -> void:
	var screen: Node = character_select_scene.instantiate()
	if screen is not CharacterSelect:
		push_error("Main: character_select_scene must have a CharacterSelect root.")
		screen.free()
		return
	_slot = -1
	_hero = null
	screen.hero_chosen.connect(_on_hero_chosen)
	_swap_to(screen)


func _on_hero_chosen(slot: int, hero: HeroData) -> void:
	_slot = slot
	_hero = hero
	_show_hub()


func _show_hub() -> void:
	if _hero == null:
		push_error("Main: cannot open the hub without an active hero.")
		return
	var hub: Node = hub_scene.instantiate()
	if hub is not Hub:
		push_error("Main: hub_scene must have a Hub root.")
		hub.free()
		return
	hub.show_hero(_hero)
	hub.hero_changed.connect(_save_hero)
	hub.quest_requested.connect(_show_arena_run)
	hub.store_requested.connect(_show_store)
	hub.change_hero_requested.connect(_show_character_select)
	_swap_to(hub)


## The store saves the hero whenever they buy something.
func _show_store() -> void:
	var store: Node = store_scene.instantiate()
	if store is not Store:
		push_error("Main: store_scene must have a Store root.")
		store.free()
		return
	store.show_hero(_hero)
	store.hero_changed.connect(_save_hero)
	store.gacha_requested.connect(_show_gacha)
	store.back_requested.connect(_show_hub)
	_swap_to(store)


## The gacha saves the hero after every pull and merge.
func _show_gacha() -> void:
	var gacha: Node = gacha_scene.instantiate()
	if gacha is not Gacha:
		push_error("Main: gacha_scene must have a Gacha root.")
		gacha.free()
		return
	gacha.show_hero(_hero)
	gacha.hero_changed.connect(_save_hero)
	gacha.back_requested.connect(_show_store)
	_swap_to(gacha)


func _show_arena_run() -> void:
	var run: Node = arena_run_scene.instantiate()
	if run is not ArenaRun:
		push_error("Main: arena_run_scene must have an ArenaRun root.")
		run.free()
		return
	run.finished.connect(_on_run_finished)
	_swap_to(run)
	run.show_hero(_hero)


## Bank what the run earned, save it, and go home.
func _on_run_finished(result: RunResult) -> void:
	_hero.bank_run(result)
	_save_hero()
	_show_hub()


## HeroSaves reports its own failures; the hero stays usable in memory either way.
func _save_hero() -> void:
	if _slot < 0 or _hero == null:
		push_error("Main: no active save slot to save the hero to.")
		return
	HeroSaves.save_hero(_slot, _hero)


func _swap_to(next: Node) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)