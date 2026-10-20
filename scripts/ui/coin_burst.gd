class_name CoinBurst
extends Control
## A handful of gold coins flying in an arc from one place to another, for
## when gold is spent or earned. Covers its parent and ignores the mouse.
##
## `fly()` takes global positions. Coins leave one after another and each
## shrinks away as it lands.

signal finished

const COIN: Texture2D = preload("res://assets/packs/ninja_adventure/items/gold_coin.png")
const COIN_SIZE: float = 10.0
## Seconds one coin takes to fly, and between one leaving and the next.
const FLIGHT_SECONDS: float = 0.55
const STAGGER_SECONDS: float = 0.05
## How high the arc rises above the straight line, at most, and how far to the
## side each coin's start scatters.
const ARC_HEIGHT: float = 40.0
const SCATTER: float = 8.0

var _coins: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _process(delta: float) -> void:
	var flying: Array[Dictionary] = []
	for coin: Dictionary in _coins:
		coin[&"age"] += delta
		if coin[&"age"] < _total(coin):
			flying.append(coin)
	var before: int = _coins.size()
	_coins = flying
	queue_redraw()
	if _coins.is_empty() and before > 0:
		set_process(false)
		finished.emit()


## Send `count` coins from `from` to `to`, both in global coordinates.
func fly(from: Vector2, to: Vector2, count: int) -> void:
	var inverse: Transform2D = get_global_transform().affine_inverse()
	var start: Vector2 = inverse * from
	var end: Vector2 = inverse * to
	for i: int in count:
		var origin: Vector2 = start + Vector2(
			randf_range(-SCATTER, SCATTER), randf_range(-SCATTER, SCATTER)
		)
		var lift: float = ARC_HEIGHT * randf_range(0.6, 1.0)
		_coins.append({
			&"from": origin,
			&"to": end,
			&"control": (origin + end) * 0.5 + Vector2(randf_range(-20.0, 20.0), -lift),
			&"delay": i * STAGGER_SECONDS,
			&"age": 0.0,
		})
	set_process(true)


func _total(coin: Dictionary) -> float:
	return coin[&"delay"] + FLIGHT_SECONDS


func _draw() -> void:
	for coin: Dictionary in _coins:
		var t: float = (coin[&"age"] - coin[&"delay"]) / FLIGHT_SECONDS
		if t < 0.0:
			continue
		var eased: float = t * t * (3.0 - 2.0 * t)
		var a: Vector2 = (coin[&"from"] as Vector2).lerp(coin[&"control"], eased)
		var b: Vector2 = (coin[&"control"] as Vector2).lerp(coin[&"to"], eased)
		var at: Vector2 = a.lerp(b, eased).floor()
		var scale_now: float = 1.0 - maxf(t - 0.7, 0.0) / 0.3 * 0.6
		var drawn: Vector2 = Vector2.ONE * floorf(COIN_SIZE * scale_now)
		draw_texture_rect(COIN, Rect2(at - drawn * 0.5, drawn), false)
