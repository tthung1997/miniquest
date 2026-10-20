class_name PackCard
extends Button
## One pack on the shelf: its chest in the pack's colour on a glow, its name,
## a gem for each tier, and its price. The chest opens and bobs while the pack
## is picked or hovered.
##
## A toggle button: put the cards in one ButtonGroup so one is picked at a time.
## Shows what it is told and changes nothing.

const PIP: Texture2D = preload("res://assets/sprites/ui/tier/pip.png")
const COIN: Texture2D = preload("res://assets/packs/ninja_adventure/items/gold_coin.png")
const CHEST_SCALE: int = 3
const PIP_SCALE: int = 2
const COIN_SIZE: float = 12.0
const PADDING: float = 6.0
## Seconds for one up-and-down of the bob.
const BOB_SECONDS: float = 0.8
const PICKED_COLOR: Color = Color(1.0, 0.678, 0.333, 1.0)
const DIM_COLOR: Color = Color(0.9, 0.85, 0.75, 1.0)

var pack: PackData = null:
	set(value):
		pack = value
		queue_redraw()

var _seconds: float = 0.0


func _init() -> void:
	toggle_mode = true
	theme_type_variation = &"QuietButton"
	custom_minimum_size = Vector2(150, 58)
	set_process(false)


func _ready() -> void:
	toggled.connect(_on_state_changed.unbind(1))
	mouse_entered.connect(_on_state_changed)
	mouse_exited.connect(_on_state_changed)
	focus_entered.connect(_on_state_changed)
	focus_exited.connect(_on_state_changed)
	_on_state_changed()


func _process(delta: float) -> void:
	_seconds += delta
	queue_redraw()


func _draw() -> void:
	if pack == null:
		return
	var lively: bool = button_pressed or is_hovered() or has_focus()
	var chest_size: Vector2 = Vector2.ONE * ChestArt.FRAME * CHEST_SCALE
	var chest_at: Vector2 = Vector2(PADDING, (size.y - chest_size.y) * 0.5).floor()

	var glow_size: Vector2 = Vector2.ONE * RarityData.GLOW_SIZE * 2.0
	var glow: Color = pack.color
	glow.a = 0.7 if button_pressed else 0.3
	draw_texture_rect(
		RarityData.glow_texture(),
		Rect2(chest_at + (chest_size - glow_size) * 0.5, glow_size), false, glow
	)
	var bob: float = 0.0
	if button_pressed:
		bob = -floorf(absf(sin(_seconds * TAU / BOB_SECONDS)) * 2.0) * 2.0
	draw_texture_rect(
		ChestArt.texture(pack.color, lively), Rect2(chest_at + Vector2(0.0, bob), chest_size), false
	)

	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var left: float = chest_at.x + chest_size.x + PADDING
	var text_color: Color = PICKED_COLOR if button_pressed else DIM_COLOR
	draw_string(
		font, Vector2(left, PADDING + font_size), pack.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT, size.x - left - PADDING, font_size, text_color
	)
	_draw_pips(Vector2(left, PADDING + font_size + 5.0))
	var base_y: float = size.y - PADDING
	draw_texture_rect(
		COIN, Rect2(left, base_y - COIN_SIZE + 1.0, COIN_SIZE, COIN_SIZE), false
	)
	draw_string(
		font, Vector2(left + COIN_SIZE + 3.0, base_y), str(pack.price),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color
	)


## A gem for each tier of the pack, in its colour.
func _draw_pips(at: Vector2) -> void:
	var pip_size: Vector2 = Vector2(PIP.get_size()) * PIP_SCALE
	for i: int in pack.order + 1:
		draw_texture_rect(
			PIP, Rect2(at + Vector2((pip_size.x - 1.0) * i, 0.0), pip_size), false,
			pack.color.lerp(Color.WHITE, 0.3)
		)


func _on_state_changed() -> void:
	set_process(button_pressed)
	queue_redraw()
