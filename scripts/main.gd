class_name Main
extends Node
## Root of the game: shows one screen at a time and moves between them.
##
## Keeps no global state. Each screen reports what the player chose through a
## signal, and this swaps the next screen in. The screens are exported so they
## are wired in the editor rather than preloaded by path.

@export var character_select_scene: PackedScene
@export var playground_scene: PackedScene

var _current: Node = null


func _ready() -> void:
	_show_character_select()


func _show_character_select() -> void:
	var screen: CharacterSelect = character_select_scene.instantiate() as CharacterSelect
	screen.hero_chosen.connect(_on_hero_chosen)
	_swap_to(screen)


func _on_hero_chosen(_slot: int, hero: HeroData) -> void:
	var playground: Playground = playground_scene.instantiate() as Playground
	playground.back_requested.connect(_show_character_select)
	_swap_to(playground)
	playground.show_hero(hero)


func _swap_to(next: Node) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
	_current = next
	add_child(next)