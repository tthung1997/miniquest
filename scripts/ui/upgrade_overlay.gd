class_name UpgradeOverlay
extends Control
## The level-up choice, drawn over a paused run: a few separate cards to pick
## from, each clickable.
##
## It only reports which one was picked. Pausing the tree, rolling the offers
## and applying the pick are the run's business. Must keep processing while the
## tree is paused, so whoever instances it sets its process mode to Always.
## The cards stay off for a moment after it opens, so a skill key pressed just
## as the level-up lands does not pick something by accident.

signal offer_chosen(offer: UpgradeOffer)

## Seconds the cards ignore input after the overlay opens.
const INPUT_GRACE: float = 0.4
## Seconds between one card starting to appear and the next.
const INTRO_STAGGER: float = 0.08

## One UpgradeOption per offer.
@export var option_scene: PackedScene

var _options: Array[UpgradeOption] = []
var _offers: Array[UpgradeOffer] = []
var _unlocked: bool = false

@onready var _title_label: Label = %TitleLabel
@onready var _option_row: HBoxContainer = %OptionRow


func _ready() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _unlocked:
		return
	for i: int in mini(_offers.size(), SkillCaster.CAST_ACTIONS.size()):
		if event.is_action_pressed(SkillCaster.CAST_ACTIONS[i]) and not event.is_echo():
			get_viewport().set_input_as_handled()
			_pick(_offers[i])
			return


## Show `offers` for a hero who just reached run level `level`.
func open(offers: Array[UpgradeOffer], level: int) -> void:
	if option_scene == null:
		push_error("UpgradeOverlay: option_scene must be wired to show the offers.")
		return
	_clear_options()
	_offers = offers
	for i: int in offers.size():
		var node: Node = option_scene.instantiate()
		if node is not UpgradeOption:
			push_error("UpgradeOverlay: option_scene must have an UpgradeOption root.")
			node.free()
			return
		var option: UpgradeOption = node
		_option_row.add_child(option)
		option.show_offer(offers[i])
		option.set_enabled(false)
		option.play_intro(i * INTRO_STAGGER)
		option.chosen.connect(_pick)
		_options.append(option)
	_title_label.text = "LEVEL %d" % level
	_unlocked = false
	show()
	get_tree().create_timer(INPUT_GRACE).timeout.connect(_unlock)


func close() -> void:
	_unlocked = false
	hide()
	_clear_options()


func _unlock() -> void:
	if not visible or _options.is_empty():
		return
	_unlocked = true
	for option: UpgradeOption in _options:
		option.set_enabled(true)
	_options[0].grab_focus()


func _pick(offer: UpgradeOffer) -> void:
	if not _unlocked:
		return
	_unlocked = false
	offer_chosen.emit(offer)


func _clear_options() -> void:
	for option: UpgradeOption in _options:
		option.queue_free()
	_options.clear()
	_offers = []
