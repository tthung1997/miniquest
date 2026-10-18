## One-shot tool: draws the 16x16 skill icons and the generic upgrade icons.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/build_skill_icons.gd
## Each icon is a few shapes in a small palette; a one-pixel dark outline is
## added around whatever is drawn. Safe to re-run: it rewrites every icon, so
## change the drawing here rather than the PNGs. Then re-run the import
## (--headless --path . --import) so the engine picks the PNGs up.
extends SceneTree

const SKILL_DIRECTORY: String = "res://assets/sprites/ui/skill_icons"
const UPGRADE_DIRECTORY: String = "res://assets/sprites/ui/upgrade_icons"
## The hub's Inventory button icon goes here.
const UI_DIRECTORY: String = "res://assets/sprites/ui"
const SIZE: int = 16
const OUTLINE: Color = Color("1b1220")
const PALETTE: Dictionary = {
	"w": Color("f6f2ea"),
	"g": Color("bfc5d0"),
	"G": Color("7d8597"),
	"r": Color("dc4a3d"),
	"R": Color("8f2b33"),
	"o": Color("f28a30"),
	"y": Color("ffd34d"),
	"Y": Color("c9922b"),
	"b": Color("4f93e6"),
	"B": Color("2d4f9c"),
	"c": Color("86e3f2"),
	"C": Color("3a9db8"),
	"p": Color("ab6fe6"),
	"P": Color("5f3b96"),
	"n": Color("62d06d"),
	"N": Color("2f8b4b"),
	"t": Color("a06c3a"),
	"T": Color("5e3a22"),
}

var _image: Image = null


func _init() -> void:
	var skills: Dictionary = {
		"whirl": _whirl,
		"second_wind": _second_wind,
		"cleave": _cleave,
		"bulwark": _bulwark,
		"firebolt": _firebolt,
		"frost_nova": _frost_nova,
		"piercing_shot": _piercing_shot,
		"swift_step": _swift_step,
		"whirlwind": _whirlwind,
		"blood_frenzy": _blood_frenzy,
		"meteor": _meteor,
		"arcane_surge": _arcane_surge,
		"shadow_strike": _shadow_strike,
		"vanish": _vanish,
		"flame_brand": _flame_brand,
		"rune_slash": _rune_slash,
		"enchanted_volley": _enchanted_volley,
		"sigil_trap": _sigil_trap,
		"flurry": _flurry,
		"riposte": _riposte,
	}
	var upgrades: Dictionary = {
		"move_speed": _move_speed,
		"damage": _damage,
		"heal": _heal,
		"pickup_radius": _pickup_radius,
	}
	var failed: bool = false
	for id: String in skills:
		failed = not _save(skills[id], SKILL_DIRECTORY, id) or failed
	for id: String in upgrades:
		failed = not _save(upgrades[id], UPGRADE_DIRECTORY, id) or failed
	failed = not _save(_bag, UI_DIRECTORY, "bag_icon") or failed
	quit(1 if failed else 0)


func _save(drawing: Callable, directory: String, id: String) -> bool:
	_image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	drawing.call()
	_outline()
	var path: String = "%s/%s.png" % [directory, id]
	if _image.save_png(path) != OK:
		printerr("Could not save %s." % path)
		return false
	print("Wrote %s" % path)
	return true


## Add a dark pixel beside every drawn pixel, so each icon is outlined.
func _outline() -> void:
	var outlined: Image = _image.duplicate()
	for y: int in SIZE:
		for x: int in SIZE:
			if _image.get_pixel(x, y).a > 0.0:
				continue
			for step: Vector2i in [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]:
				var at: Vector2i = Vector2i(x, y) + step
				if at.x < 0 or at.y < 0 or at.x >= SIZE or at.y >= SIZE:
					continue
				if _image.get_pixelv(at).a > 0.0:
					outlined.set_pixel(x, y, OUTLINE)
					break
	_image = outlined


# Drawing. Coordinates are continuous, 0 to 16, and a pixel is drawn when its
# centre is inside the shape.

func _put(x: int, y: int, key: String) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		_image.set_pixel(x, y, PALETTE[key])


func _rect(x: int, y: int, w: int, h: int, key: String) -> void:
	for yy: int in range(y, y + h):
		for xx: int in range(x, x + w):
			_put(xx, yy, key)


func _disc(cx: float, cy: float, radius: float, key: String) -> void:
	_ring(cx, cy, radius, 0.0, key)


## Pixels between two radii, optionally only between two angles in degrees
## (clockwise from east, as the screen goes).
func _ring(
	cx: float, cy: float, outer: float, inner: float, key: String,
	from_angle: float = 0.0, to_angle: float = 360.0,
) -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			var offset: Vector2 = Vector2(x + 0.5 - cx, y + 0.5 - cy)
			var distance: float = offset.length()
			if distance > outer or distance < inner:
				continue
			var angle: float = rad_to_deg(offset.angle())
			if fposmod(angle - from_angle, 360.0) <= to_angle - from_angle:
				_put(x, y, key)


func _line(x0: float, y0: float, x1: float, y1: float, key: String, thick: int = 1) -> void:
	var steps: int = int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
	for i: int in steps + 1:
		var at: Vector2 = Vector2(x0, y0).lerp(Vector2(x1, y1), float(i) / steps)
		for dy: int in thick:
			for dx: int in thick:
				_put(floori(at.x) + dx, floori(at.y) + dy, key)


func _tri(a: Vector2, b: Vector2, c: Vector2, key: String) -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var d1: float = (p - b).cross(a - b)
			var d2: float = (p - c).cross(b - c)
			var d3: float = (p - a).cross(c - a)
			var negative: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
			var positive: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
			if not (negative and positive):
				_put(x, y, key)


# Skills.

func _whirl() -> void:
	_ring(8, 8, 6.8, 4.4, "C", 60, 340)
	_ring(8, 8, 6.8, 5.8, "c", 60, 340)
	_tri(Vector2(15.8, 7.0), Vector2(11.0, 7.0), Vector2(13.4, 11.4), "w")


func _second_wind() -> void:
	_disc(5.4, 6.0, 3.6, "N")
	_disc(10.6, 6.0, 3.6, "N")
	_tri(Vector2(1.9, 7.4), Vector2(14.1, 7.4), Vector2(8, 14.6), "N")
	_disc(5.4, 5.6, 2.8, "n")
	_disc(10.6, 5.6, 2.8, "n")
	_tri(Vector2(3.0, 7.2), Vector2(13.0, 7.2), Vector2(8, 13.2), "n")
	_rect(4, 4, 2, 1, "w")
	_rect(4, 5, 1, 1, "w")


func _cleave() -> void:
	_ring(8, 15, 13.5, 8.5, "o", 205, 335)
	_ring(8, 15, 13.5, 11.5, "y", 215, 325)
	_ring(8, 15, 9.5, 8.5, "r", 205, 335)
	_line(11, 2, 14, 5, "w")


func _bulwark() -> void:
	_rect(3, 2, 10, 6, "B")
	_tri(Vector2(3, 8), Vector2(13, 8), Vector2(8, 15), "B")
	_rect(4, 3, 8, 5, "b")
	_tri(Vector2(4, 8), Vector2(12, 8), Vector2(8, 13.4), "b")
	_rect(7, 3, 2, 8, "w")
	_rect(4, 5, 8, 2, "w")
	_rect(7, 5, 2, 2, "y")


func _firebolt() -> void:
	_tri(Vector2(1, 15), Vector2(11, 5), Vector2(6, 10.5), "R")
	_line(2, 14, 9, 7, "r", 2)
	_line(3, 13, 8, 8, "o", 2)
	_disc(10.5, 5.5, 4.4, "o")
	_disc(10.5, 5.5, 2.9, "y")
	_disc(10.5, 5.5, 1.3, "w")


func _frost_nova() -> void:
	for angle: float in [0.0, 60.0, 120.0]:
		var d: Vector2 = Vector2.from_angle(deg_to_rad(angle)) * 6.6
		_line(8 - d.x, 8 - d.y, 8 + d.x, 8 + d.y, "c", 1)
	for angle: float in [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]:
		var tip: Vector2 = Vector2(8, 8) + Vector2.from_angle(deg_to_rad(angle)) * 4.2
		_disc(tip.x, tip.y, 1.1, "w")
	_disc(8, 8, 2.0, "w")
	_disc(8, 8, 1.0, "C")


func _piercing_shot() -> void:
	_line(2, 14, 12, 4, "t", 1)
	_tri(Vector2(15.5, 0.5), Vector2(15.5, 6.5), Vector2(9.5, 0.5), "g")
	_tri(Vector2(1, 11), Vector2(5, 15), Vector2(1, 15), "y")
	_line(1.5, 12.5, 4.5, 15, "r")
	_put(10, 5, "w")
	_put(11, 4, "w")


func _swift_step() -> void:
	_rect(7, 2, 4, 7, "T")
	_rect(7, 8, 7, 5, "T")
	_rect(8, 2, 3, 6, "t")
	_rect(8, 9, 6, 3, "t")
	_rect(7, 12, 8, 2, "g")
	_rect(1, 4, 4, 1, "y")
	_rect(2, 7, 4, 1, "y")
	_rect(0, 10, 5, 1, "y")


func _whirlwind() -> void:
	_ring(8, 8, 7.0, 5.2, "r", 0, 270)
	_ring(8, 8, 4.4, 2.8, "o", 180, 450)
	_disc(8, 8, 1.4, "y")
	_tri(Vector2(11.2, 15.0), Vector2(15.8, 12.4), Vector2(12.4, 9.4), "r")


func _blood_frenzy() -> void:
	_tri(Vector2(8, 0.8), Vector2(2.6, 9.4), Vector2(13.4, 9.4), "R")
	_disc(8, 9.4, 5.4, "R")
	_tri(Vector2(8, 2.4), Vector2(4.0, 9.0), Vector2(12.0, 9.0), "r")
	_disc(8, 9.4, 4.0, "r")
	_rect(5, 8, 1, 3, "w")
	_rect(6, 7, 1, 1, "w")
	_tri(Vector2(5.5, 12.4), Vector2(7.5, 12.4), Vector2(6.5, 15.0), "w")
	_tri(Vector2(8.5, 12.4), Vector2(10.5, 12.4), Vector2(9.5, 15.0), "w")


func _meteor() -> void:
	_tri(Vector2(0.5, 0.5), Vector2(12, 6), Vector2(6, 12), "r")
	_tri(Vector2(1.5, 1.5), Vector2(10, 6.5), Vector2(6.5, 10), "o")
	_tri(Vector2(2.5, 2.5), Vector2(8, 6.0), Vector2(6.0, 8), "y")
	_disc(10.2, 10.2, 5.0, "G")
	_disc(10.0, 10.0, 4.0, "g")
	_rect(11, 8, 2, 2, "G")
	_rect(8, 11, 2, 1, "G")
	_rect(8, 8, 1, 1, "w")


func _arcane_surge() -> void:
	_ring(8, 8, 7.2, 5.6, "p")
	_disc(8, 8, 4.6, "P")
	_disc(8, 8, 3.2, "p")
	_disc(8, 8, 1.6, "c")
	_line(8, 0.5, 8, 3, "w")
	_line(8, 13, 8, 15.5, "w")
	_line(0.5, 8, 3, 8, "w")
	_line(13, 8, 15.5, 8, "w")


func _shadow_strike() -> void:
	_disc(5.0, 11.0, 4.2, "P")
	_disc(8.0, 9.0, 3.6, "p")
	_line(5, 11, 12, 4, "g", 2)
	_line(6, 11, 12, 5, "w")
	_tri(Vector2(15, 1), Vector2(14.5, 6), Vector2(10, 1.5), "w")
	_rect(3, 10, 4, 2, "Y")
	_line(3, 13, 5, 11, "T", 2)


func _vanish() -> void:
	_disc(8, 6.2, 4.8, "g")
	_rect(3, 6, 10, 7, "g")
	_rect(3, 13, 2, 2, "g")
	_rect(7, 13, 2, 2, "g")
	_rect(11, 13, 2, 2, "g")
	_disc(8, 6.2, 3.6, "w")
	_rect(4, 7, 8, 6, "w")
	_rect(5, 5, 2, 3, "P")
	_rect(9, 5, 2, 3, "P")
	_rect(7, 9, 2, 2, "P")


func _flame_brand() -> void:
	_rect(7, 2, 2, 9, "g")
	_rect(7, 2, 1, 9, "w")
	_tri(Vector2(7, 2), Vector2(9, 2), Vector2(8, 0.4), "w")
	_rect(4, 11, 8, 1, "Y")
	_rect(7, 12, 2, 3, "t")
	_disc(5.4, 4.4, 2.0, "o")
	_disc(10.8, 6.0, 2.2, "o")
	_disc(5.6, 8.4, 1.6, "r")
	_disc(5.4, 4.6, 1.0, "y")
	_disc(10.8, 6.2, 1.2, "y")


func _rune_slash() -> void:
	_ring(8, 8, 7.4, 5.8, "p")
	_ring(8, 8, 7.4, 6.6, "c")
	_line(4, 11, 7, 8, "P")
	_line(9, 6, 11, 4, "P")
	_line(3, 13, 13, 3, "w", 2)
	_line(2, 14, 14, 2, "o")


func _enchanted_volley() -> void:
	for tip: Vector2 in [Vector2(2.5, 2.5), Vector2(8, 1), Vector2(13.5, 2.5)]:
		_line(8, 15, tip.x, tip.y + 2, "t")
		_disc(tip.x, tip.y + 0.5, 1.9, "p")
		_disc(tip.x, tip.y + 0.5, 0.9, "c")
	_rect(6, 13, 4, 2, "y")


func _sigil_trap() -> void:
	_ring(8, 8, 7.4, 6.0, "p")
	var points: Array[Vector2] = []
	for i: int in 5:
		points.append(Vector2(8, 8) + Vector2.from_angle(deg_to_rad(-90.0 + i * 72.0)) * 5.4)
	for i: int in 5:
		var next: Vector2 = points[(i + 2) % 5]
		_line(points[i].x, points[i].y, next.x, next.y, "c")
	_disc(8, 8, 1.2, "w")


func _flurry() -> void:
	var lines: Array[PackedFloat32Array] = [
		PackedFloat32Array([1.5, 8.5, 8.5, 1.5]),
		PackedFloat32Array([2.5, 13.5, 13.5, 2.5]),
		PackedFloat32Array([7.5, 14.5, 14.5, 7.5]),
	]
	for coords: PackedFloat32Array in lines:
		_line(coords[0], coords[1], coords[2], coords[3], "w")
		_disc(coords[2] + 0.5, coords[3] - 0.5, 1.1, "y")
	_rect(1, 12, 2, 3, "t")


func _riposte() -> void:
	_line(2, 2, 12, 12, "w", 2)
	_line(14, 2, 4, 12, "g", 2)
	_rect(10, 11, 5, 2, "Y")
	_rect(1, 11, 5, 2, "Y")
	_rect(12, 12, 2, 3, "t")
	_rect(2, 12, 2, 3, "t")
	_disc(8, 7, 1.6, "r")


# Other icons.

## A tied cloth sack, for the Inventory button.
func _bag() -> void:
	_tri(Vector2(7.4, 4.0), Vector2(2.6, 1.0), Vector2(8.0, 2.0), "Y")
	_tri(Vector2(8.6, 4.0), Vector2(13.4, 1.0), Vector2(8.0, 2.0), "Y")
	_rect(6, 3, 4, 3, "Y")
	_disc(8, 10.8, 5.8, "t")
	_disc(8, 10.4, 4.8, "Y")
	_rect(5, 5, 6, 1, "T")
	_rect(5, 6, 1, 2, "T")
	_rect(10, 6, 1, 2, "T")
	_rect(5, 9, 1, 3, "y")
	_rect(6, 8, 1, 1, "y")
	_rect(9, 11, 1, 1, "T")
	_rect(10, 12, 1, 1, "T")
	_rect(10, 11, 1, 1, "t")


# Generic upgrades.

func _move_speed() -> void:
	for x: int in [2, 6, 10]:
		_tri(Vector2(x, 2), Vector2(x + 4, 8), Vector2(x, 14), "y")
		_tri(Vector2(x + 1, 5), Vector2(x + 3, 8), Vector2(x + 1, 11), "Y")


func _damage() -> void:
	_line(3, 13, 12, 4, "g", 2)
	_line(4, 13, 12, 5, "w")
	_tri(Vector2(15, 1), Vector2(14, 6.5), Vector2(9.5, 2), "w")
	_rect(2, 11, 5, 2, "R")
	_line(2, 13, 4, 11, "T", 2)
	_disc(4.5, 12, 1.0, "r")


func _heal() -> void:
	_rect(6, 1, 4, 3, "t")
	_rect(6, 4, 4, 3, "g")
	_disc(8, 10.6, 5.0, "R")
	_disc(8, 10.6, 4.0, "r")
	_rect(4, 10, 8, 3, "r")
	_rect(5, 9, 2, 1, "w")
	_rect(5, 10, 1, 2, "w")


func _pickup_radius() -> void:
	_ring(8, 7, 6.6, 3.4, "r", 180, 360)
	_rect(1, 7, 3, 4, "r")
	_rect(12, 7, 3, 4, "r")
	_rect(1, 11, 3, 3, "g")
	_rect(12, 11, 3, 3, "g")
	_rect(2, 6, 1, 4, "o")
