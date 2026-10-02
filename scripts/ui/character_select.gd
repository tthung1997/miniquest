class_name CharacterSelect
extends Control
## The hero selection screen: three save slots, each empty or holding a hero.
##
## Owns the HeroSaves calls for this screen. The cards and dialogs only report
## what the player pressed; this decides what it means, writes it to disk and
## refreshes the card. Choosing Play hands the loaded hero to whoever is
## listening, so this screen does not know what comes next.

signal hero_chosen(slot: int, hero: HeroData)

var _cards: Array[HeroSlotCard] = []
var _pending_slot: int = -1

@onready var _card_row: HBoxContainer = %Cards
@onready var _name_dialog: NameDialog = %NameDialog
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog


func _ready() -> void:
	for child: Node in _card_row.get_children():
		if child is HeroSlotCard:
			_cards.append(child as HeroSlotCard)

	if _cards.size() != HeroSaves.SLOT_COUNT:
		push_error(
			"CharacterSelect: %d card(s) for %d slot(s)." % [_cards.size(), HeroSaves.SLOT_COUNT]
		)

	for i: int in _cards.size():
		var card: HeroSlotCard = _cards[i]
		card.slot = i
		card.play_pressed.connect(_on_play_pressed)
		card.delete_pressed.connect(_on_delete_pressed)
		card.create_pressed.connect(_on_create_pressed)
		_refresh_slot(i)

	_name_dialog.confirmed.connect(_on_name_confirmed)
	_name_dialog.cancelled.connect(_close_dialog)
	_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	_confirm_dialog.cancelled.connect(_close_dialog)

	_cards[0].focus_primary()


func _refresh_slot(slot: int) -> void:
	var card: HeroSlotCard = _cards[slot]
	if not HeroSaves.has_hero(slot):
		card.show_empty()
		return

	var hero: HeroData = HeroSaves.load_hero(slot)
	if hero == null:
		card.show_unreadable()
	else:
		card.show_hero(hero)


func _open_dialog(slot: int) -> void:
	_pending_slot = slot
	for card: HeroSlotCard in _cards:
		card.set_interactive(false)


## Return to the slot that opened a dialog, whether or not anything changed.
func _close_dialog() -> void:
	for card: HeroSlotCard in _cards:
		card.set_interactive(true)
	if _pending_slot >= 0:
		_cards[_pending_slot].focus_primary()
	_pending_slot = -1


func _on_create_pressed(slot: int) -> void:
	_open_dialog(slot)
	_name_dialog.open()


func _on_name_confirmed(hero_name: String) -> void:
	var slot: int = _pending_slot
	var hero: HeroData = HeroData.create(hero_name)
	if hero != null:
		HeroSaves.save_hero(slot, hero)
	_refresh_slot(slot)
	_close_dialog()


func _on_delete_pressed(slot: int) -> void:
	var hero: HeroData = HeroSaves.load_hero(slot)
	var who: String = hero.hero_name if hero != null else "this save"
	_open_dialog(slot)
	_confirm_dialog.open("Delete %s?\nThis cannot be undone." % who, "DELETE", "KEEP")


func _on_delete_confirmed() -> void:
	var slot: int = _pending_slot
	HeroSaves.delete_hero(slot)
	_refresh_slot(slot)
	_close_dialog()


func _on_play_pressed(slot: int) -> void:
	var hero: HeroData = HeroSaves.load_hero(slot)
	if hero == null:
		_refresh_slot(slot)
		return
	hero_chosen.emit(slot, hero)
