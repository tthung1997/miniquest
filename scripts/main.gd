class_name Main
extends Node
## Root of the game: shows one screen at a time and moves between them.
##
## Owns the active save slot and hero for this session, without an autoload.
## Screens report choices through signals; this swaps the next screen in.
## The scenes are exported so they are wired in the editor.

@export var character_select_scene: PackedScene
@export var hub_scene: PackedScene
@export var playground_scene: PackedScene

var _current: Node = null
var _slot: int = -1
var _hero: HeroData = null


func _ready() -> void:
	if character_select_scene == null or hub_scene == null or playground_scene == null:
		push_error("Main: CharacterSelect, Hub and Playground scenes must be wired.")
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
	hub.quest_requested.connect(_show_playground)
	hub.change_hero_requested.connect(_show_character_select)
	_swap_to(hub)


func _show_playground() -> void:
	var playground: Node = playground_scene.instantiate()
	if playground is not Playground:
		push_error("Main: playground_scene must have a Playground root.")
		playground.free()
		return
	playground.back_requested.connect(_show_hub)
	_swap_to(playground)
	playground.show_hero(_hero)


func _swap_to(next: Node) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)