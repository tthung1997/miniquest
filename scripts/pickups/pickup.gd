class_name Pickup
extends Area2D
## Something left on the ground for the hero to collect by walking close: a
## handful of gold, or an item.
##
## It only sits there, bobbing. The hero's pickup radius notices it, and the
## run decides what collecting it means and then calls collect(). Call
## set_gold() or set_item() before adding it to the tree.

enum Kind { GOLD, ITEM }

const COIN_SCALE: float = 2.0
const ITEM_SCALE: float = 2.0
const BOB_HEIGHT: float = 2.0
const BOB_SPEED: float = 4.0
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.25)
const GLOW_COLOR: Color = Color(1.0, 0.92, 0.55, 0.35)
## Gold of at least this much is drawn as two coins stacked, so a big drop
## reads as bigger than a small one.
const BIG_GOLD: int = 4

@export var coin_texture: Texture2D

var kind: Kind = Kind.GOLD
var gold: int = 0
var item: EquipmentItem = null

var _age: float = randf() * TAU
var _collected: bool = false


func _process(delta: float) -> void:
	_age += delta * BOB_SPEED
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 5.0, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var lift: float = (sin(_age) + 1.0) * 0.5 * BOB_HEIGHT
	if kind == Kind.ITEM:
		_draw_item(lift)
	else:
		_draw_coins(lift)


func set_gold(amount: int) -> void:
	kind = Kind.GOLD
	gold = amount
	item = null


func set_item(dropped: EquipmentItem) -> void:
	kind = Kind.ITEM
	item = dropped
	gold = 0


## Take this pickup out of the world. Does nothing the second time.
func collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred(&"monitorable", false)
	queue_free()


func is_collected() -> bool:
	return _collected


func _draw_coins(lift: float) -> void:
	if coin_texture == null:
		return
	var size: Vector2 = coin_texture.get_size() * COIN_SCALE
	var origin: Vector2 = Vector2(-size.x * 0.5, -size.y - 2.0 - lift).floor()
	draw_texture_rect(coin_texture, Rect2(origin, size), false)
	if gold >= BIG_GOLD:
		draw_texture_rect(coin_texture, Rect2(origin + Vector2(3.0, -3.0), size), false)


func _draw_item(lift: float) -> void:
	if item == null:
		return
	var size: Vector2 = Vector2(EquipmentItem.ICON_SIZE) * ITEM_SCALE
	var origin: Vector2 = Vector2(-size.x * 0.5, -size.y - 2.0 - lift).floor()
	# A glow so an item stands out from the coins and the grass, in its rarity's
	# colour and pulsing when the rarity does.
	var glow: Color = GLOW_COLOR
	var radius: float = size.x * 0.6
	var rarity: RarityData = item.get_rarity()
	if rarity != null and rarity.glow_strength > 0.0:
		glow = rarity.color
		glow.a = GLOW_COLOR.a + rarity.glow_at(_age / BOB_SPEED) * 0.2
		radius *= 1.0 + rarity.glow_strength * 0.25
	draw_circle(origin + size * 0.5, radius, glow)
	for layer: Texture2D in item.get_icon_layers():
		draw_texture_rect(layer, Rect2(origin, size), false)
