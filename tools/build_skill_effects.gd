## One-shot tool: draws the skill effect sheets under assets/sprites/effects/skills/.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/build_skill_effects.gd
## Each sheet is a row of square frames. Every effect is a few shapes in the skills'
## shared palette, drawn pixel by pixel with no antialiasing, and fades by dithering
## so it stays crisp. Art that is directional faces right. Safe to re-run: it
## rewrites every sheet, so change the drawing here rather than the PNGs. Then
## re-run the import (--headless --path . --import), and tools/build_sprite_frames.gd
## to rebuild the SpriteFrames.
##
## A hero-centred effect has the body centre at the middle of its frame and the
## feet 12 px below it, the same offset SkillData.cast_effect_offset applies.
extends SceneTree

const DIRECTORY: String = "res://assets/sprites/effects/skills"

const WHITE: Color = Color("f6f2ea")
const SILVER: Color = Color("bfc5d0")
const STEEL: Color = Color("7d8597")
const RED: Color = Color("dc4a3d")
const MAROON: Color = Color("8f2b33")
const ORANGE: Color = Color("f28a30")
const YELLOW: Color = Color("ffd34d")
const GOLD: Color = Color("c9922b")
const HOT: Color = Color("fff3b0")
const BLUE: Color = Color("4f93e6")
const NAVY: Color = Color("2d4f9c")
const CYAN: Color = Color("86e3f2")
const TEAL: Color = Color("3a9db8")
const PURPLE: Color = Color("ab6fe6")
const VIOLET: Color = Color("5f3b96")
const DARK: Color = Color("2a1740")
const PALE_PURPLE: Color = Color("e0c8ff")
const GREEN: Color = Color("62d06d")
const FOREST: Color = Color("2f8b4b")
const PALE_GREEN: Color = Color("c6f7bd")
const DUST: Color = Color("e3d2a0")
const ROCK: Color = Color("5e3a22")
const SOOT: Color = Color("4a3a3a")

## Colours of a crescent, from its bright outer edge down to its tail.
const SLASH_WHITE: Array[Color] = [WHITE, WHITE, SILVER, STEEL]
const SLASH_FIRE: Array[Color] = [HOT, YELLOW, ORANGE, RED]
const SLASH_RED: Array[Color] = [HOT, ORANGE, RED, MAROON]
const SLASH_ICE: Array[Color] = [WHITE, CYAN, BLUE, NAVY]

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _img: Image = null
var _size: int = 0


func _init() -> void:
	var failed: bool = false
	for effect: Dictionary in _effects():
		failed = not _build(effect) or failed
	quit(1 if failed else 0)


## Every sheet: its file name, frame size, frame count and drawing.
func _effects() -> Array[Dictionary]:
	return [
		{"id": "whirl", "size": 96, "frames": 6, "draw": _whirl},
		{"id": "second_wind", "size": 48, "frames": 8, "draw": _second_wind},
		{"id": "cleave", "size": 112, "frames": 6, "draw": _cleave},
		{"id": "bulwark", "size": 48, "frames": 8, "draw": _bulwark},
		{"id": "firebolt", "size": 24, "frames": 4, "draw": _firebolt},
		{"id": "firebolt_burst", "size": 48, "frames": 7, "draw": _firebolt_burst},
		{"id": "frost_nova", "size": 144, "frames": 8, "draw": _frost_nova},
		{"id": "piercing_arrow", "size": 32, "frames": 4, "draw": _piercing_arrow},
		{"id": "piercing_spark", "size": 24, "frames": 5, "draw": _piercing_spark},
		{"id": "swift_step", "size": 48, "frames": 8, "draw": _swift_step},
		{"id": "whirlwind", "size": 128, "frames": 32, "draw": _whirlwind},
		{"id": "blood_frenzy", "size": 48, "frames": 8, "draw": _blood_frenzy},
		{"id": "meteor", "size": 160, "frames": 20, "draw": _meteor},
		{"id": "arcane_surge", "size": 64, "frames": 10, "draw": _arcane_surge},
		{"id": "shadow_depart", "size": 48, "frames": 8, "draw": _shadow_depart},
		{"id": "shadow_hit", "size": 56, "frames": 7, "draw": _shadow_hit},
		{"id": "vanish", "size": 48, "frames": 8, "draw": _vanish},
		{"id": "flame_brand", "size": 48, "frames": 8, "draw": _flame_brand},
		{"id": "rune_slash", "size": 128, "frames": 8, "draw": _rune_slash},
		{"id": "enchanted_arrow", "size": 32, "frames": 4, "draw": _enchanted_arrow},
		{"id": "volley_burst", "size": 40, "frames": 6, "draw": _volley_burst},
		{"id": "sigil_rune", "size": 80, "frames": 6, "draw": _sigil_rune},
		{"id": "sigil_burst", "size": 96, "frames": 8, "draw": _sigil_burst},
		{"id": "flurry", "size": 56, "frames": 12, "draw": _flurry},
		{"id": "riposte", "size": 48, "frames": 8, "draw": _riposte},
		{"id": "bulwark_aura", "size": 48, "frames": 8, "draw": _bulwark_aura},
		{"id": "swift_step_aura", "size": 48, "frames": 8, "draw": _swift_step_aura},
		{"id": "blood_frenzy_aura", "size": 48, "frames": 8, "draw": _blood_frenzy_aura},
		{"id": "arcane_surge_aura", "size": 64, "frames": 10, "draw": _arcane_surge_aura},
		{"id": "flame_brand_aura", "size": 48, "frames": 8, "draw": _flame_brand_aura},
		{"id": "riposte_aura", "size": 48, "frames": 8, "draw": _riposte_aura},
		{"id": "vanish_aura", "size": 48, "frames": 8, "draw": _vanish_aura},
	]


func _build(effect: Dictionary) -> bool:
	var id: String = effect["id"]
	_size = effect["size"]
	var count: int = effect["frames"]
	var draw: Callable = effect["draw"]
	var sheet: Image = Image.create_empty(_size * count, _size, false, Image.FORMAT_RGBA8)
	for f: int in count:
		_img = Image.create_empty(_size, _size, false, Image.FORMAT_RGBA8)
		draw.call(f, count)
		sheet.blit_rect(_img, Rect2i(0, 0, _size, _size), Vector2i(f * _size, 0))
	var folder: String = ProjectSettings.globalize_path(DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		printerr("Could not create %s." % DIRECTORY)
		return false
	var path: String = "%s/%s.png" % [DIRECTORY, id]
	if sheet.save_png(path) != OK:
		printerr("Could not save %s." % path)
		return false
	print("Wrote %s (%d x %d, %d frames)" % [path, _size, _size, count])
	return true


# Drawing primitives. A pixel is drawn when its centre is inside the shape. `vis`
# below 1.0 thins a shape out with an ordered dither, so a fade stays pixel art.

func _put(x: int, y: int, col: Color, vis: float = 1.0) -> void:
	if x < 0 or y < 0 or x >= _size or y >= _size or vis <= 0.0:
		return
	if vis < 1.0 and float(BAYER[(y & 3) * 4 + (x & 3)]) >= vis * 16.0:
		return
	# Color.blend lays its argument over the colour it is called on.
	_img.set_pixel(x, y, _img.get_pixel(x, y).blend(col))


func _disc(cx: float, cy: float, r: float, col: Color, vis: float = 1.0) -> void:
	for y: int in range(int(floorf(cy - r)), int(ceilf(cy + r)) + 1):
		for x: int in range(int(floorf(cx - r)), int(ceilf(cx + r)) + 1):
			var dx: float = x + 0.5 - cx
			var dy: float = y + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				_put(x, y, col, vis)


func _ring(cx: float, cy: float, r: float, thick: float, col: Color, vis: float = 1.0) -> void:
	_ellipse_ring(cx, cy, r, r, thick, col, vis)


func _ellipse_ring(
	cx: float, cy: float, rx: float, ry: float, thick: float, col: Color, vis: float = 1.0
) -> void:
	var reach_x: int = int(ceilf(rx + thick))
	var reach_y: int = int(ceilf(ry + thick))
	for y: int in range(int(cy) - reach_y, int(cy) + reach_y + 1):
		for x: int in range(int(cx) - reach_x, int(cx) + reach_x + 1):
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			var d: float = sqrt(dx * dx + dy * dy)
			if absf(d - 1.0) * minf(rx, ry) <= thick * 0.5:
				_put(x, y, col, vis)


func _ellipse(cx: float, cy: float, rx: float, ry: float, col: Color, vis: float = 1.0) -> void:
	for y: int in range(int(floorf(cy - ry)), int(ceilf(cy + ry)) + 1):
		for x: int in range(int(floorf(cx - rx)), int(ceilf(cx + rx)) + 1):
			var dx: float = (x + 0.5 - cx) / rx
			var dy: float = (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(x, y, col, vis)


func _line(a: Vector2, b: Vector2, thick: float, col: Color, vis: float = 1.0) -> void:
	var steps: int = int(ceilf(a.distance_to(b) * 2.0)) + 1
	for i: int in steps + 1:
		var p: Vector2 = a.lerp(b, float(i) / steps)
		_disc(p.x, p.y, maxf(thick * 0.5, 0.6), col, vis)


## A line that narrows from `w0` at `a` to `w1` at `b`.
func _taper(a: Vector2, b: Vector2, w0: float, w1: float, col: Color, vis: float = 1.0) -> void:
	var steps: int = int(ceilf(a.distance_to(b) * 2.0)) + 1
	for i: int in steps + 1:
		var u: float = float(i) / steps
		var p: Vector2 = a.lerp(b, u)
		_disc(p.x, p.y, maxf(lerpf(w0, w1, u) * 0.5, 0.6), col, vis)


## A tongue of flame standing on `base`, narrowing to a tip `height` above.
func _flame(base: Vector2, height: float, width: float, vis: float = 1.0) -> void:
	for i: int in int(height) + 1:
		var u: float = i / maxf(height, 1.0)
		var half: float = width * 0.5 * pow(1.0 - u, 0.8) + 0.4
		var col: Color = YELLOW
		if u < 0.25:
			col = MAROON
		elif u < 0.5:
			col = RED
		elif u < 0.8:
			col = ORANGE
		var y: float = base.y - i
		_line(Vector2(base.x - half, y), Vector2(base.x + half, y), 1.0, col, vis)
	_disc(base.x, base.y - height * 0.3, width * 0.18, YELLOW, vis)


## A four-pointed sparkle.
func _star(cx: float, cy: float, r: float, col: Color, vis: float = 1.0) -> void:
	_line(Vector2(cx - r, cy), Vector2(cx + r, cy), 1.0, col, vis)
	_line(Vector2(cx, cy - r), Vector2(cx, cy + r), 1.0, col, vis)
	_disc(cx, cy, maxf(r * 0.3, 0.8), col, vis)


func _plus(cx: float, cy: float, arm: float, col: Color, vis: float = 1.0) -> void:
	_line(Vector2(cx - arm, cy), Vector2(cx + arm, cy), 1.0, col, vis)
	_line(Vector2(cx, cy - arm), Vector2(cx, cy + arm), 1.0, col, vis)


## A sweep of `a_tail` to `a_head` (radians) at `r_out`, thickest mid-way and
## brightest at the head. `cols` is the edge, head, middle and tail colour.
func _crescent(
	cx: float,
	cy: float,
	r_out: float,
	width: float,
	a_tail: float,
	a_head: float,
	cols: Array[Color],
	vis: float = 1.0,
) -> void:
	var span: float = a_head - a_tail
	if span <= 0.0 or span >= TAU:
		return
	var reach: int = int(ceilf(r_out)) + 1
	for y: int in range(int(cy) - reach, int(cy) + reach + 1):
		for x: int in range(int(cx) - reach, int(cx) + reach + 1):
			var dx: float = x + 0.5 - cx
			var dy: float = y + 0.5 - cy
			var r: float = sqrt(dx * dx + dy * dy)
			if r > r_out or r < r_out - width:
				continue
			var d: float = wrapf(atan2(dy, dx) - a_tail, 0.0, TAU)
			if d > span:
				continue
			var u: float = d / span
			if r < r_out - width * pow(sin(PI * u), 0.8):
				continue
			var col: Color = cols[3]
			if r > r_out - 1.4 and u > 0.15:
				col = cols[0]
			elif u > 0.66:
				col = cols[1]
			elif u > 0.33:
				col = cols[2]
			_put(x, y, col, vis)


## A stable pseudo-random number in 0..1 for `key`, so a scatter of sparks is the
## same in every frame of a sheet.
func _rnd(key: int) -> float:
	return fposmod(sin(float(key) * 12.9898 + 4.1414) * 43758.5453, 1.0)


func _polar(cx: float, cy: float, r: float, angle: float) -> Vector2:
	return Vector2(cx + cos(angle) * r, cy + sin(angle) * r)


## Progress through a sheet, 0.0 on the first frame to 1.0 on the last.
func _t(f: int, n: int) -> float:
	return f / (n - 1.0)


func _out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _in(t: float) -> float:
	return t * t


## Visibility that thins over the last `frames` frames of a sheet.
func _fade_end(f: int, n: int, frames: int) -> float:
	return clampf((n - f) / float(frames + 1), 0.0, 1.0)


## Visibility that rises over the first `frames` frames of a sheet.
func _fade_in(f: int, frames: int) -> float:
	return clampf((f + 1) / float(frames + 1), 0.0, 1.0)


# Novice

func _whirl(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var r: float = lerpf(22.0, 40.0, _out(t))
	var vis: float = _fade_end(f, n, 2)
	for k: int in 3:
		var head: float = t * TAU * 0.85 + k * TAU / 3.0
		_crescent(48.0, 48.0, r, 7.0, head - 1.5, head, SLASH_WHITE, vis)
	for k: int in 6:
		var a: float = k * TAU / 6.0 + t * 3.0
		var p: Vector2 = _polar(48.0, 48.0, r + 5.0 + t * 4.0, a)
		_put(int(p.x), int(p.y), WHITE, vis * 0.8)


func _second_wind(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var life: float = minf(_fade_in(f, 1), _fade_end(f, n, 3))
	var ring_y: float = lerpf(36.0, 8.0, t)
	_ellipse_ring(24.0, ring_y, 13.0, 4.0, 2.0, GREEN, life)
	_ellipse_ring(24.0, ring_y, 13.0, 4.0, 1.0, PALE_GREEN, life)
	_ellipse_ring(24.0, ring_y + 5.0, 10.0, 3.0, 1.0, FOREST, life * 0.7)
	for i: int in 6:
		var x: float = 24.0 + (i - 2.5) * 6.0 + (_rnd(i) - 0.5) * 3.0
		var y: float = 40.0 - _rnd(i + 20) * 10.0 - t * (18.0 + _rnd(i + 9) * 12.0)
		var vis: float = minf(1.0, t * 5.0) * (1.0 - t * 0.5) * life
		_plus(x, y, 2.0, PALE_GREEN if i % 2 == 0 else GREEN, vis)
	for i: int in 8:
		var x: float = 24.0 + (_rnd(i + 40) - 0.5) * 30.0
		var y: float = 42.0 - _rnd(i + 60) * 8.0 - t * (10.0 + _rnd(i + 80) * 24.0)
		_put(int(x), int(y), WHITE, life)


func _cleave(f: int, n: int) -> void:
	var from: float = deg_to_rad(-85.0)
	var span: float = deg_to_rad(170.0)
	var head_p: float = minf(1.0, (f + 1) / 4.0)
	var tail_p: float = 0.0 if f <= 1 else (f - 1) * 0.2
	var vis: float = _fade_end(f, n, 2)
	var head: float = from + span * head_p
	var tail: float = from + span * tail_p
	_crescent(56.0, 56.0, 50.0, 14.0, tail, head, SLASH_FIRE, vis)
	_crescent(56.0, 56.0, 38.0, 5.0, tail + 0.25, head - 0.1, SLASH_FIRE, vis * 0.7)
	if head_p > 0.0:
		for i: int in 5:
			var a: float = head + (_rnd(i) - 0.3) * 0.5
			var p: Vector2 = _polar(56.0, 56.0, 52.0 + _rnd(i + 7) * 7.0 + f, a)
			_put(int(p.x), int(p.y), HOT if i % 2 == 0 else YELLOW, vis)


# Warrior

func _bulwark(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var grow: float = lerpf(1.2, 1.0, minf(1.0, f / 3.0))
	var vis: float = minf(_fade_in(f, 1), _fade_end(f, n, 2))
	var rx: float = 15.0 * grow
	var ry: float = 20.0 * grow
	_ellipse(24.0, 23.0, rx, ry, Color(BLUE, 0.2), 1.0)
	_ellipse_ring(24.0, 23.0, rx, ry, 2.0, BLUE, vis)
	_ellipse_ring(24.0, 23.0, rx - 1.0, ry - 1.0, 1.0, NAVY, vis * 0.8)
	_crescent(24.0, 23.0, ry, 4.0, deg_to_rad(200.0), deg_to_rad(265.0), SLASH_ICE, vis)
	var glint: float = deg_to_rad(210.0) + t * TAU * 0.6
	var spot: Vector2 = _polar(24.0, 23.0, ry, glint)
	_star(spot.x * 1.0, spot.y * 1.0, 2.0, WHITE, vis)
	for i: int in 4:
		var a: float = i * TAU / 4.0 + 0.8
		var p: Vector2 = _polar(24.0, 23.0, ry + 2.0 + t * 3.0, a)
		_put(int(p.x), int(p.y), CYAN, vis * (1.0 - t))


# Mage

func _firebolt(f: int, _n: int) -> void:
	for i: int in 6:
		var x: float = 12.0 - i * 2.1
		var y: float = 12.0 + sin(f * 1.6 + i * 1.1) * 1.3
		var r: float = 3.2 - i * 0.45
		var col: Color = ORANGE if i < 3 else RED
		_disc(x, y, r, col, 1.0 - i * 0.1)
	_disc(15.0, 12.0, 4.2, RED)
	_disc(15.0, 12.0, 3.2, ORANGE)
	_disc(15.5, 12.0, 2.0, YELLOW)
	_disc(16.0, 12.0, 1.0, HOT)
	for i: int in 2:
		var x: float = 4.0 - i * 3.0 - f
		_put(int(x) + 8, 9 + (f + i * 3) % 6, YELLOW)


func _firebolt_burst(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 2)
	var r: float = lerpf(5.0, 21.0, _out(t))
	if f < 4:
		_disc(24.0, 24.0, r, RED, vis)
		_disc(24.0, 24.0, r * 0.75, ORANGE, vis)
		_disc(24.0, 24.0, r * 0.45, YELLOW, vis)
		_disc(24.0, 24.0, r * 0.2, HOT, vis)
	else:
		_ring(24.0, 24.0, r, 4.0 - t * 2.0, RED, vis)
		_ring(24.0, 24.0, r - 1.5, 2.0, ORANGE, vis)
	for i: int in 9:
		var a: float = i * TAU / 9.0 + _rnd(i) * 0.5
		var d: float = r * (0.7 + _rnd(i + 3) * 0.6) + t * 6.0
		var p: Vector2 = _polar(24.0, 24.0, d, a)
		_put(int(p.x), int(p.y), YELLOW if i % 2 == 0 else ORANGE, vis)


func _frost_nova(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var r: float = lerpf(8.0, 60.0, _out(minf(1.0, t * 1.25)))
	var vis: float = _fade_end(f, n, 2)
	_disc(72.0, 72.0, r, Color(CYAN, 0.16 * vis))
	_ring(72.0, 72.0, r, lerpf(7.0, 3.0, t), BLUE, vis)
	_ring(72.0, 72.0, r + 1.0, 3.0, CYAN, vis)
	_ring(72.0, 72.0, r + 2.0, 1.0, WHITE, vis)
	for k: int in 10:
		var a: float = k * TAU / 10.0 + 0.3
		var reach: float = r if f < 5 else 60.0
		if f == 0:
			continue
		var base: Vector2 = _polar(72.0, 72.0, reach - 2.0, a)
		var tip: Vector2 = _polar(72.0, 72.0, reach + 6.0 + _rnd(k) * 5.0, a)
		_line(base, tip, 3.0, CYAN, vis)
		_line(base, tip, 1.0, WHITE, vis)
	for i: int in 7:
		var a: float = _rnd(i + 50) * TAU
		var d: float = r * _rnd(i + 70)
		var p: Vector2 = _polar(72.0, 72.0, d, a)
		_star(p.x, p.y, 2.0, WHITE, vis * (1.0 - t * 0.4))


# Ranger

func _piercing_arrow(f: int, _n: int) -> void:
	for i: int in 22:
		var x: float = 22.0 - i
		var spread: float = 1.0 + i * 0.12
		var fade: float = 1.0 - i / 22.0
		_disc(x, 16.0, spread, YELLOW, fade * 0.5)
	_line(Vector2(7.0, 16.0), Vector2(24.0, 16.0), 2.0, WHITE)
	_line(Vector2(7.0, 16.0), Vector2(24.0, 16.0), 1.0, HOT)
	for y: int in range(11, 22):
		for x: int in range(24, 31):
			if absf(y + 0.5 - 16.0) <= (30.0 - x) * 0.7:
				_put(x, y, WHITE if x > 26 else SILVER)
	_put(30, 16, WHITE)
	_line(Vector2(5.0, 12.0), Vector2(9.0, 16.0), 1.0, GOLD)
	_line(Vector2(5.0, 20.0), Vector2(9.0, 16.0), 1.0, GOLD)
	var ring_x: float = 8.0 + (f * 5.0)
	_line(Vector2(ring_x, 13.0), Vector2(ring_x, 19.0), 1.0, HOT, 0.9)
	for i: int in 4:
		_put(2 + int(_rnd(i + f * 5) * 14.0), 12 + int(_rnd(i + 9 + f * 3) * 8.0), YELLOW)


func _piercing_spark(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 2)
	_star(12.0, 12.0, lerpf(9.0, 4.0, t), HOT, vis)
	_ring(12.0, 12.0, lerpf(3.0, 10.0, _out(t)), 1.0, YELLOW, vis)
	for i: int in 6:
		var a: float = i * TAU / 6.0 + 0.4
		var p: Vector2 = _polar(12.0, 12.0, lerpf(3.0, 11.0, _out(t)), a)
		_put(int(p.x), int(p.y), WHITE, vis)


func _swift_step(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var life: float = _fade_end(f, n, 2)
	var puff: float = _out(t)
	for side: int in [-1, 1]:
		var x: float = 24.0 + side * lerpf(4.0, 17.0, puff)
		var y: float = 36.0 - puff * 3.0
		_ellipse(x, y, lerpf(3.0, 6.0, puff), lerpf(2.0, 4.0, puff), DUST, life)
		_ellipse(x - side, y - 1.0, lerpf(2.0, 3.5, puff), lerpf(1.0, 2.0, puff), WHITE, life)
	for rise: int in 3:
		var phase: float = fposmod(t * 1.6 - rise * 0.3, 1.0)
		if t * 1.6 < rise * 0.3:
			continue
		var y: float = lerpf(40.0, 4.0, phase)
		var bright: float = sin(phase * PI) * life
		for arm: int in 3:
			var inset: float = arm * 1.0
			_line(
				Vector2(24.0 - 9.0, y + 7.0 + inset), Vector2(24.0, y + inset),
				2.0, YELLOW if arm < 2 else HOT, bright
			)
			_line(
				Vector2(24.0, y + inset), Vector2(24.0 + 9.0, y + 7.0 + inset),
				2.0, YELLOW if arm < 2 else HOT, bright
			)
	_ellipse_ring(24.0, 37.0, lerpf(6.0, 18.0, puff), lerpf(2.0, 6.0, puff), 1.0, GOLD, life)


# Berserker

func _whirlwind(f: int, n: int) -> void:
	var vis: float = minf(_fade_in(f, 2), _fade_end(f, n, 3))
	var spin: float = f * deg_to_rad(33.0)
	var layers: Array[Dictionary] = [
		{"r": 57.0, "w": 9.0, "span": 1.5, "turn": 1.0, "cols": SLASH_RED},
		{"r": 46.0, "w": 7.0, "span": 1.3, "turn": -1.35, "cols": SLASH_FIRE},
		{"r": 34.0, "w": 5.0, "span": 1.1, "turn": 1.7, "cols": SLASH_WHITE},
	]
	for layer: Dictionary in layers:
		var turn: float = layer["turn"]
		for k: int in 3:
			var head: float = spin * turn + k * TAU / 3.0
			_crescent(
				64.0, 64.0, layer["r"], layer["w"], head - float(layer["span"]), head,
				layer["cols"], vis
			)
	var since_hit: int = f % 8
	if since_hit < 3:
		var r: float = lerpf(22.0, 58.0, since_hit / 2.0)
		_ring(64.0, 64.0, r, 2.0, HOT, vis * (1.0 - since_hit / 3.0))
	for i: int in 8:
		var a: float = spin * 0.5 + i * TAU / 8.0
		var p: Vector2 = _polar(64.0, 64.0, 40.0 + _rnd(i) * 18.0, a)
		_put(int(p.x), int(p.y), YELLOW, vis)


func _blood_frenzy(f: int, n: int) -> void:
	var life: float = minf(_fade_in(f, 1), _fade_end(f, n, 2))
	var pulse: float = fposmod(f / 4.0, 1.0)
	var r: float = lerpf(6.0, 22.0, _out(pulse))
	_ring(24.0, 23.0, r, 3.0 - pulse * 2.0, RED, life * (1.0 - pulse * 0.5))
	_ring(24.0, 23.0, r - 2.0, 1.0, MAROON, life * (1.0 - pulse * 0.5))
	for k: int in 10:
		var a: float = k * TAU / 10.0 + 0.2
		var inner: float = r + 1.0
		var outer: float = r + 4.0 + (k % 2) * 4.0 * (1.0 - pulse)
		_line(_polar(24.0, 23.0, inner, a), _polar(24.0, 23.0, outer, a), 1.0, ORANGE, life)
	for side: int in [-1, 1]:
		for j: int in 2:
			var x: float = 24.0 + side * (9.0 + j * 6.0)
			var height: float = 9.0 + 5.0 * sin(f * 1.7 + j + side) - j * 2.0
			_flame(Vector2(x, 40.0 - j * 3.0), height, 6.0 - j, life)


# Archmage

func _meteor(f: int, _n: int) -> void:
	var impact: Vector2 = Vector2(80.0, 82.0)
	if f < 12:
		_meteor_fall(f, impact)
	else:
		_meteor_blast(f - 12, impact)


func _meteor_fall(f: int, impact: Vector2) -> void:
	var p: float = (f + 1) / 12.0
	var pos: Vector2 = impact + Vector2(46.0, -80.0) * (1.0 - p)
	var heading: Vector2 = Vector2(-46.0, 80.0).normalized()
	if f >= 5:
		_ellipse(impact.x, impact.y, lerpf(10.0, 30.0, p), lerpf(4.0, 12.0, p), ORANGE, 0.25)
	for i: int in 16:
		var d: float = i * 3.0
		var at: Vector2 = pos - heading * d
		var col: Color = YELLOW if i < 3 else (ORANGE if i < 8 else (RED if i < 12 else SOOT))
		var size: float = maxf(1.0, lerpf(7.0, 2.0, i / 15.0))
		_disc(at.x + sin(f + i) * 1.2, at.y, size, col, 1.0 - i * 0.04)
	_disc(pos.x, pos.y, lerpf(6.0, 9.0, p), ORANGE)
	_disc(pos.x, pos.y, lerpf(5.0, 7.5, p), ROCK)
	_disc(pos.x - 1.0, pos.y - 1.0, lerpf(2.5, 4.0, p), MAROON)
	_disc(pos.x + 2.0, pos.y + 1.0, 2.0, YELLOW, 0.8)


func _meteor_blast(k: int, centre: Vector2) -> void:
	var u: float = k / 7.0
	var vis: float = _fade_end(k, 8, 3)
	var r: float = lerpf(8.0, 40.0, _out(u))
	var up: Vector2 = Vector2(0.0, -r * 0.1)
	_disc(centre.x, centre.y + up.y, r, RED, vis)
	_disc(centre.x, centre.y + up.y, r * 0.8, ORANGE, vis)
	_disc(centre.x, centre.y + up.y, r * 0.55 * (1.0 - u * 0.5), YELLOW, vis)
	_disc(centre.x, centre.y + up.y, r * 0.3 * (1.0 - u), HOT, vis)
	if k < 5:
		_ring(centre.x, centre.y, lerpf(10.0, 47.0, _out(u)), 3.0 - u * 2.0, HOT, vis)
	for i: int in 9:
		var a: float = i * TAU / 9.0 + _rnd(i) * 0.6
		var d: float = lerpf(8.0, 36.0 + _rnd(i + 3) * 10.0, _out(u))
		var at: Vector2 = _polar(centre.x, centre.y, d, a) + Vector2(0.0, u * u * 14.0)
		_disc(at.x, at.y, 1.6, ROCK if i % 2 == 0 else ORANGE)
	if k >= 3:
		for i: int in 5:
			var drift: float = centre.y - 12.0 - (k - 2) * 6.0 - _rnd(i) * 8.0
			var at: Vector2 = Vector2(centre.x + (_rnd(i + 30) - 0.5) * 50.0, drift)
			_disc(at.x, at.y, 4.0, SOOT, vis * 0.5)


func _arcane_surge(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var life: float = minf(_fade_in(f, 1), _fade_end(f, n, 2))
	var feet: float = 44.0
	_ellipse(32.0, feet, 24.0, 8.0, Color(VIOLET, 0.3 * life))
	_ellipse_ring(32.0, feet, 26.0, 9.0, 2.0, PURPLE, life)
	_ellipse_ring(32.0, feet, 17.0, 6.0, 1.0, PALE_PURPLE, life * 0.8)
	for k: int in 12:
		var a: float = k * TAU / 12.0 + t * 1.6
		var p: Vector2 = Vector2(32.0 + cos(a) * 26.0, feet + sin(a) * 9.0)
		_put(int(p.x), int(p.y) - 2, WHITE if k % 3 == 0 else PALE_PURPLE, life)
		_put(int(p.x), int(p.y) - 3, PURPLE, life * 0.8)
	for c: int in 5:
		var a: float = c * TAU / 5.0 + 0.5
		var x: float = 32.0 + cos(a) * 21.0
		var base: float = feet + sin(a) * 7.0
		var height: float = minf(1.0, t * 3.0) * (14.0 + _rnd(c) * 10.0)
		_line(Vector2(x, base), Vector2(x, base - height), 1.0, PURPLE, life * 0.7)
	for i: int in 9:
		var x: float = 32.0 + (_rnd(i + 5) - 0.5) * 36.0
		var y: float = 46.0 - _rnd(i + 25) * 12.0 - t * (14.0 + _rnd(i + 45) * 22.0)
		_star(x, y, 1.0, WHITE, life)


# Assassin

func _shadow_depart(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 3)
	for i: int in 8:
		var a: float = i * TAU / 8.0 + _rnd(i) * 0.4
		var d: float = lerpf(3.0, 14.0 + _rnd(i + 4) * 6.0, _out(t))
		var r: float = lerpf(4.0, 7.0, t)
		var at: Vector2 = _polar(24.0, 24.0, d, a) + Vector2(0.0, -t * 5.0)
		_disc(at.x, at.y, r, DARK, vis)
		_disc(at.x - 1.0, at.y - 1.0, r * 0.65, VIOLET, vis)
		_disc(at.x - 2.0, at.y - 2.0, r * 0.3, PURPLE, vis * 0.9)
	_disc(24.0, 24.0, lerpf(9.0, 3.0, t), DARK, vis)
	for i: int in 5:
		var p: Vector2 = _polar(24.0, 24.0, lerpf(6.0, 20.0, _out(t)), i * TAU / 5.0 + 1.0)
		_star(p.x, p.y, 1.0, PALE_PURPLE, vis * (1.0 - t))


func _shadow_hit(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 2)
	var slashes: Array[Array] = [
		[Vector2(6.0, 8.0), Vector2(50.0, 48.0), 0],
		[Vector2(50.0, 8.0), Vector2(6.0, 48.0), 1],
	]
	if f >= 1 and f <= 3:
		_disc(28.0, 28.0, 10.0, DARK, 0.6)
	for slash: Array in slashes:
		var delay: int = slash[2]
		var p: float = clampf((f - delay + 1) / 2.0, 0.0, 1.0)
		if p <= 0.0:
			continue
		var from: Vector2 = slash[0]
		var to: Vector2 = from.lerp(slash[1], p)
		var thick: float = 4.0 - t * 2.5
		_line(from, to, thick + 2.0, VIOLET, vis)
		_line(from, to, thick, PURPLE, vis)
		_line(from, to, maxf(thick - 2.0, 1.0), WHITE, vis)
	if f >= 2 and f <= 4:
		_star(28.0, 28.0, 9.0 - f, WHITE, vis)
	if f >= 3:
		for i: int in 8:
			var p: Vector2 = _polar(28.0, 28.0, 8.0 + (f - 2) * 4.0 + _rnd(i) * 6.0, i * TAU / 8.0)
			_put(int(p.x), int(p.y), PALE_PURPLE if i % 2 == 0 else PURPLE, vis)


func _vanish(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var gather: float = minf(1.0, t / 0.75)
	var vis: float = _fade_end(f, n, 1)
	for i: int in 9:
		var a: float = i * TAU / 9.0 + t * 2.5
		var d: float = lerpf(16.0, 1.0, _in(gather))
		var r: float = lerpf(5.0, 2.0, gather)
		var at: Vector2 = _polar(24.0, 23.0, d, a)
		if gather < 1.0:
			_disc(at.x, at.y, r, DARK, vis)
			_disc(at.x - 1.0, at.y - 1.0, r * 0.6, VIOLET, vis)
			_put(int(at.x - 1.0), int(at.y - 1.0), PURPLE, vis)
	if f >= 5:
		var burst: float = (f - 5) / 2.0
		_star(24.0, 23.0, lerpf(4.0, 10.0, burst), WHITE, vis * (1.0 - burst * 0.5))
		_ring(24.0, 23.0, lerpf(3.0, 14.0, burst), 1.0, PURPLE, vis * (1.0 - burst * 0.6))


# Spellblade

func _flame_brand(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var life: float = minf(_fade_in(f, 1), _fade_end(f, n, 2))
	var rise: float = minf(1.0, f / 3.0)
	_ellipse_ring(24.0, 37.0, 16.0, 5.0, 1.0, ORANGE, life * 0.8)
	for k: int in 7:
		var a: float = k * TAU / 7.0 + t * 1.2
		var x: float = 24.0 + cos(a) * 14.0
		var base: float = 37.0 + sin(a) * 5.0
		var height: float = (7.0 + 6.0 * _rnd(k) + 3.0 * sin(f * 1.9 + k)) * rise
		_flame(Vector2(x, base), height, 5.0, life)
	for i: int in 7:
		var x: float = 24.0 + (_rnd(i + 3) - 0.5) * 28.0
		var y: float = 34.0 - _rnd(i + 9) * 8.0 - t * (10.0 + _rnd(i + 20) * 22.0)
		_put(int(x), int(y), YELLOW if i % 2 == 0 else ORANGE, life)


func _rune_slash(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var sweep: float = _out(minf(1.0, (f + 1) / 3.0))
	var head: float = lerpf(deg_to_rad(-100.0), deg_to_rad(260.0), sweep)
	var slash_vis: float = _fade_end(f, 5, 2) if f < 5 else 0.0
	_crescent(64.0, 64.0, 54.0, 10.0, head - 2.6, head, SLASH_FIRE, slash_vis)
	if f < 2:
		return
	var life: float = minf(_fade_in(f - 2, 1), _fade_end(f, n, 2))
	var grow: float = _out(minf(1.0, (f - 1) / 2.0))
	var r: float = lerpf(12.0, 27.0, grow)
	var flicker: float = 1.0 if f % 2 == 0 else 0.8
	_disc(64.0, 64.0, r, Color(ORANGE, 0.14 * life))
	_ring(64.0, 64.0, r, 2.0, ORANGE, life * flicker)
	_ring(64.0, 64.0, r - 4.0, 1.0, YELLOW, life * 0.8)
	var turn: float = t * 0.7
	for tri: int in 2:
		var pts: Array[Vector2] = []
		for v: int in 3:
			pts.append(_polar(64.0, 64.0, r * 0.78, turn + tri * PI / 3.0 + v * TAU / 3.0))
		for v: int in 3:
			_line(pts[v], pts[(v + 1) % 3], 1.0, YELLOW if tri == 0 else HOT, life)
	for k: int in 8:
		var a: float = k * TAU / 8.0 + turn
		_line(_polar(64.0, 64.0, r + 1.0, a), _polar(64.0, 64.0, r + 4.0, a), 1.0, ORANGE, life)
	_disc(64.0, 64.0, 2.0, HOT, life)
	for i: int in 8:
		var a: float = i * TAU / 8.0 + _rnd(i) * 0.5
		var p: Vector2 = _polar(64.0, 64.0, r + 2.0 + _rnd(i + 5) * 6.0, a) + Vector2(0.0, -t * 6.0)
		_put(int(p.x), int(p.y), YELLOW, life)


# Arcane Archer

func _enchanted_arrow(f: int, _n: int) -> void:
	for i: int in 22:
		var wobble: float = sin(f * 1.5 + i * 0.7) * 1.2
		_disc(22.0 - i, 16.0 + wobble, 1.0 + i * 0.1, PURPLE, (1.0 - i / 22.0) * 0.55)
	_line(Vector2(7.0, 16.0), Vector2(24.0, 16.0), 2.0, PALE_PURPLE)
	_line(Vector2(7.0, 16.0), Vector2(24.0, 16.0), 1.0, WHITE)
	for y: int in range(11, 22):
		for x: int in range(24, 31):
			if absf(y + 0.5 - 16.0) <= (30.0 - x) * 0.7:
				_put(x, y, WHITE if x > 26 else PALE_PURPLE)
	_put(30, 16, WHITE)
	_line(Vector2(5.0, 12.0), Vector2(9.0, 16.0), 1.0, PURPLE)
	_line(Vector2(5.0, 20.0), Vector2(9.0, 16.0), 1.0, PURPLE)
	for i: int in 3:
		var x: float = 4.0 + fposmod(f * 6.0 + i * 8.0, 20.0)
		var y: float = 16.0 + (i - 1) * 4.0 + sin(f + i) * 1.5
		_star(x, y, 1.0, WHITE)
	_star(26.0, 16.0, 3.0, PALE_PURPLE, 0.8)


func _volley_burst(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 2)
	if f < 3:
		_disc(20.0, 20.0, 5.0 - f, PURPLE, vis)
		_star(20.0, 20.0, 10.0 - f * 2.0, WHITE, vis)
	for i: int in 8:
		var a: float = i * TAU / 8.0 + 0.2
		var near: float = lerpf(2.0, 11.0, _out(t))
		var far: float = lerpf(4.0, 18.0, _out(t))
		_line(_polar(20.0, 20.0, near, a), _polar(20.0, 20.0, far, a), 1.0, PALE_PURPLE, vis)
		var tip: Vector2 = _polar(20.0, 20.0, far, a)
		_star(tip.x, tip.y, 1.0, WHITE if i % 2 == 0 else PURPLE, vis)
	_ring(20.0, 20.0, lerpf(3.0, 14.0, _out(t)), 1.0, PURPLE, vis * 0.8)


func _sigil_rune(f: int, _n: int) -> void:
	var turn: float = f * deg_to_rad(10.0)
	var pulse: float = 1.0 if f % 2 == 0 else 0.8
	_disc(40.0, 40.0, 28.0, Color(PURPLE, 0.12))
	_ring(40.0, 40.0, 28.0, 2.0, PURPLE, pulse)
	_ring(40.0, 40.0, 22.0, 1.0, VIOLET)
	for k: int in 12:
		var a: float = k * TAU / 12.0 - turn * 3.0
		var reach: float = 3.0 if k % 2 == 0 else 1.0
		_line(_polar(40.0, 40.0, 23.0, a), _polar(40.0, 40.0, 23.0 + reach, a), 1.0, PALE_PURPLE)
	for tri: int in 2:
		var pts: Array[Vector2] = []
		for v: int in 3:
			pts.append(_polar(40.0, 40.0, 18.0, turn + tri * PI / 3.0 + v * TAU / 3.0 - PI / 2.0))
		for v: int in 3:
			_line(pts[v], pts[(v + 1) % 3], 1.0, PURPLE if tri == 0 else PALE_PURPLE)
	_disc(40.0, 40.0, 3.0, VIOLET)
	_disc(40.0, 40.0, 2.0 if f % 2 == 0 else 1.5, WHITE)


func _sigil_burst(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 3)
	var r: float = lerpf(24.0, 40.0, _out(t))
	_disc(48.0, 48.0, 30.0 * (1.0 - t * 0.4), PURPLE, vis * (1.0 - t))
	_disc(48.0, 48.0, 20.0 * (1.0 - t), WHITE, vis * (1.0 - t))
	_ring(48.0, 48.0, r, 5.0 - t * 3.0, PURPLE, vis)
	_ring(48.0, 48.0, r, 2.0, WHITE, vis)
	if f < 6:
		for k: int in 8:
			var a: float = k * TAU / 8.0 + 0.2
			var from: float = r
			var to: float = r + lerpf(14.0, 4.0, t)
			_line(_polar(48.0, 48.0, from, a), _polar(48.0, 48.0, to, a), 2.0, PALE_PURPLE, vis)
	for i: int in 10:
		var a: float = i * TAU / 10.0 + _rnd(i) * 0.6
		var p: Vector2 = _polar(48.0, 48.0, 10.0 + t * (22.0 + _rnd(i + 4) * 14.0), a)
		_star(p.x, p.y, 1.0, WHITE if i % 2 == 0 else PURPLE, vis)


# Duelist

func _flurry(f: int, n: int) -> void:
	var angles: Array[float] = [-35.0, 25.0, -12.0, 42.0, 5.0]
	var starts: Array[int] = [0, 2, 5, 7, 10]
	var vis: float = _fade_end(f, n, 1)
	for k: int in 5:
		var age: int = f - starts[k]
		if age < 0 or age > 2:
			continue
		var a: float = deg_to_rad(angles[k])
		var reach: float = 24.0 if age == 0 else 20.0
		var from: Vector2 = _polar(28.0, 28.0, reach, a + PI)
		var to: Vector2 = _polar(28.0, 28.0, reach * 0.35, a)
		var fade: float = 1.0 - age * 0.35
		var width: float = 5.0 - age * 1.5
		_taper(from, to, 1.0, width, CYAN, vis * fade)
		_taper(from, to, 0.6, maxf(width - 2.5, 1.0), WHITE, vis * fade)
		if age == 0:
			_star(28.0, 28.0, 7.0, HOT, vis)
			_disc(28.0, 28.0, 2.5, WHITE, vis)
		elif age == 1:
			_star(28.0, 28.0, 4.0, CYAN, vis * 0.8)
		for i: int in 3:
			var p: Vector2 = _polar(
				28.0, 28.0, 8.0 + age * 4.0 + _rnd(i + k * 5) * 5.0, a + (i - 1) * 0.7
			)
			_put(int(p.x), int(p.y), WHITE, vis * fade)


func _riposte(f: int, n: int) -> void:
	var t: float = _t(f, n)
	var vis: float = _fade_end(f, n, 2)
	if f < 4:
		_ring(24.0, 23.0, lerpf(21.0, 12.0, _out(f / 3.0)), 1.0, SILVER, vis)
		_ring(24.0, 23.0, lerpf(19.0, 10.0, _out(f / 3.0)), 1.0, WHITE, vis * 0.6)
	if f >= 1 and f <= 6:
		var cross: float = minf(1.0, f / 2.0)
		var reach: float = 17.0 * cross
		for flip: int in [-1, 1]:
			var from: Vector2 = Vector2(24.0 - reach, 23.0 + reach * flip)
			var to: Vector2 = Vector2(24.0 + reach, 23.0 - reach * flip)
			_line(from, to, 2.0, SILVER, vis)
			_line(from, to, 1.0, WHITE, vis)
			var guard: Vector2 = from.lerp(to, 0.25)
			var side: Vector2 = Vector2(-(to - from).y, (to - from).x).normalized() * 3.0
			_line(guard - side, guard + side, 1.0, GOLD, vis)
	if f >= 3 and f <= 5:
		_star(24.0, 23.0, 14.0 - (f - 3) * 3.0, WHITE, vis)
		_star(24.0, 23.0, 7.0, CYAN, vis)
	for i: int in 6:
		var p: Vector2 = _polar(24.0, 23.0, 8.0 + t * 14.0 + _rnd(i) * 4.0, i * TAU / 6.0 + 0.3)
		_put(int(p.x), int(p.y), WHITE, vis * (1.0 - t * 0.5))


# Auras. These loop on the hero for as long as a buff lasts, so each is periodic
# in its own frame count and the last frame leads straight back into the first.

## Where a thing that rises is in its climb, 0.0 at the bottom to 1.0 at the top,
## for item `i` of `count` spread evenly through the loop.
func _climb(f: int, n: int, i: int, count: int) -> float:
	return fposmod(f / float(n) + i / float(count), 1.0)


func _bulwark_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	_ellipse(24.0, 23.0, 15.0, 20.0, Color(BLUE, 0.1))
	_ellipse_ring(24.0, 23.0, 15.0, 20.0, 1.0, BLUE, 0.5 + 0.15 * sin(p * TAU))
	for k: int in 3:
		var a: float = deg_to_rad(210.0) + p * TAU - k * 0.35
		var spot: Vector2 = Vector2(24.0 + cos(a) * 15.0, 23.0 + sin(a) * 20.0)
		_star(spot.x, spot.y, 2.0 if k == 0 else 1.0, WHITE if k == 0 else CYAN, 1.0 - k * 0.3)


func _swift_step_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	_ellipse_ring(24.0, 37.0, 12.0 + 2.0 * sin(p * TAU), 4.0, 1.0, GOLD, 0.6)
	for i: int in 5:
		var climb: float = _climb(f, n, i, 5)
		var x: float = 24.0 + (i - 2) * 6.5 + (_rnd(i) - 0.5) * 2.0
		var y: float = lerpf(40.0, 6.0, climb)
		var bright: float = sin(climb * PI)
		_line(Vector2(x, y), Vector2(x, y + 5.0), 1.0, YELLOW, bright)
		_put(int(x), int(y), HOT, bright)


func _blood_frenzy_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	var radius: float = lerpf(12.0, 21.0, p)
	_ring(24.0, 23.0, radius, 1.0, RED, 1.0 - p)
	_ring(24.0, 23.0, radius - 2.0, 1.0, MAROON, 1.0 - p)
	for side: int in [-1, 1]:
		for j: int in 2:
			var height: float = 5.0 + 2.0 * sin(p * TAU + j * 2.0 + side)
			_flame(Vector2(24.0 + side * (9.0 + j * 5.0), 40.0 - j * 2.0), height, 4.0)
	for i: int in 4:
		var climb: float = _climb(f, n, i, 4)
		var x: float = 24.0 + (_rnd(i + 11) - 0.5) * 24.0
		_put(int(x), int(lerpf(38.0, 8.0, climb)), ORANGE, sin(climb * PI))


func _arcane_surge_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	var feet: float = 44.0
	_ellipse(32.0, feet, 24.0, 8.0, Color(VIOLET, 0.18))
	_ellipse_ring(32.0, feet, 26.0, 9.0, 1.0, PURPLE, 0.9)
	_ellipse_ring(32.0, feet, 17.0, 6.0, 1.0, PALE_PURPLE, 0.6)
	for k: int in 12:
		# Turned one tick's width over the loop, so it meets itself.
		var a: float = (k + p) * TAU / 12.0
		var at: Vector2 = Vector2(32.0 + cos(a) * 26.0, feet + sin(a) * 9.0)
		_put(int(at.x), int(at.y) - 2, WHITE if k % 3 == 0 else PALE_PURPLE)
	for i: int in 6:
		var climb: float = _climb(f, n, i, 6)
		var x: float = 32.0 + (_rnd(i + 5) - 0.5) * 36.0
		_star(x, lerpf(feet, 8.0, climb), 1.0, WHITE, sin(climb * PI))


func _flame_brand_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	_ellipse_ring(24.0, 37.0, 16.0, 5.0, 1.0, ORANGE, 0.7)
	for k: int in 7:
		var a: float = k * TAU / 7.0
		var x: float = 24.0 + cos(a) * 14.0
		var base: float = 37.0 + sin(a) * 5.0
		var height: float = 6.0 + 2.0 * _rnd(k) + 2.5 * sin(p * TAU + k * 1.7)
		_flame(Vector2(x, base), height, 5.0)
	for i: int in 5:
		var climb: float = _climb(f, n, i, 5)
		var x: float = 24.0 + (_rnd(i + 3) - 0.5) * 28.0
		var ember: Color = YELLOW if i % 2 == 0 else ORANGE
		_put(int(x), int(lerpf(34.0, 6.0, climb)), ember, sin(climb * PI))


func _riposte_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	_ring(24.0, 23.0, 17.0, 1.0, SILVER, 0.35)
	for k: int in 8:
		var a: float = (k + p) * TAU / 8.0
		var at: Vector2 = _polar(24.0, 23.0, 17.0, a)
		_put(int(at.x), int(at.y), WHITE)
	for k: int in 4:
		var twinkle: float = sin(p * TAU + k * 1.6)
		if twinkle > 0.2:
			var at: Vector2 = _polar(24.0, 23.0, 14.0, PI / 4.0 + k * PI / 2.0)
			_star(at.x, at.y, 1.0 + twinkle * 2.0, WHITE if k % 2 == 0 else CYAN)


func _vanish_aura(f: int, n: int) -> void:
	var p: float = f / float(n)
	for i: int in 5:
		var a: float = i * TAU / 5.0 + p * TAU
		var at: Vector2 = _polar(24.0, 24.0, 12.0, a)
		at.y = 24.0 + (at.y - 24.0) * 0.8
		_disc(at.x, at.y, 4.0, DARK, 0.6)
		_disc(at.x - 1.0, at.y - 1.0, 2.5, VIOLET, 0.6)
	for i: int in 3:
		var climb: float = _climb(f, n, i, 3)
		var x: float = 24.0 + (_rnd(i + 21) - 0.5) * 20.0
		_disc(x, lerpf(36.0, 6.0, climb), 3.0, DARK, sin(climb * PI) * 0.5)
