class_name GachaPoster
extends Button
## The shop's poster for the gacha: a golden chest on a glow, a few twinkling
## sparks, and an invitation. Pressing it opens the gacha.
##
## Shows what it is told: `show_hero()` gives it the hero, so it can say when a
## pack's guaranteed Legendary is next.

const SPARK_COUNT: int = 5
const TWINKLE_SECONDS: float = 1.6
const GOLD: Color = Color(1.0, 0.78, 0.25, 1.0)
const TITLE_COLOR: Color = Color(1.0, 0.678, 0.333, 1.0)
const TEXT_COLOR: Color = Color(0.9, 0.85, 0.75, 1.0)
const CHEST_SCALE: int = 2
const PADDING: float = 6.0

var _seconds: float = 0.0
var _subtitle: String = ""
var _imminent: bool = false


func _init() -> void:
	theme_type_variation = &"QuietButton"
	custom_minimum_size = Vector2(0, 38)
	text = ""


func _process(delta: float) -> void:
	_seconds += delta
	queue_redraw()


## Tell the poster about `hero`: it mentions the cheapest pack, or that a
## guaranteed Legendary is on the next pull of some pack.
func show_hero(hero: HeroData) -> void:
	var packs: Array[PackData] = PackData.all()
	_imminent = false
	_subtitle = ""
	if packs.is_empty():
		visible = false
		return
	visible = true
	for pack: PackData in packs:
		if hero == null or pack.pity_limit <= 0:
			continue
		if GachaMachine.pulls_until_guarantee(hero, pack) <= 1:
			_imminent = true
	_subtitle = (
		"A guaranteed Legendary awaits!" if _imminent else "Packs from %d gold" % packs[0].price
	)
	queue_redraw()


func _draw() -> void:
	var lively: bool = is_hovered() or has_focus()
	var chest_size: Vector2 = Vector2.ONE * ChestArt.FRAME * CHEST_SCALE
	var chest_at: Vector2 = Vector2(PADDING, (size.y - chest_size.y) * 0.5).floor()

	var glow_size: Vector2 = Vector2.ONE * RarityData.GLOW_SIZE * 2.0
	var glow: Color = GOLD
	glow.a = 0.55 if _imminent or lively else 0.3
	draw_texture_rect(
		RarityData.glow_texture(), Rect2(chest_at + (chest_size - glow_size) * 0.5, glow_size),
		false, glow
	)
	var bob: float = -floorf(absf(sin(_seconds * 3.0)) * 2.0) if lively or _imminent else 0.0
	draw_texture_rect(
		ChestArt.texture(GOLD, lively or _imminent),
		Rect2(chest_at + Vector2(0.0, bob), chest_size), false
	)
	_draw_sparks(chest_at + chest_size * 0.5)

	var font: Font = get_theme_font(&"font")
	var font_size: int = get_theme_font_size(&"font_size")
	var left: float = chest_at.x + chest_size.x + PADDING
	draw_string(
		font, Vector2(left, size.y * 0.5 - 1.0), "TRY YOUR LUCK", HORIZONTAL_ALIGNMENT_LEFT,
		size.x - left - PADDING, font_size, TITLE_COLOR
	)
	var subtitle_color: Color = GOLD if _imminent else TEXT_COLOR
	draw_string(
		font, Vector2(left, size.y * 0.5 + font_size + 1.0), _subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, size.x - left - PADDING, font_size, subtitle_color
	)


## Small four-point sparks that fade in and out round the chest.
func _draw_sparks(centre: Vector2) -> void:
	for i: int in SPARK_COUNT:
		var phase: float = fmod(_seconds / TWINKLE_SECONDS + float(i) / SPARK_COUNT, 1.0)
		var strength: float = sin(phase * PI)
		if strength < 0.2:
			continue
		var angle: float = float(i) * TAU / SPARK_COUNT + 0.6
		var at: Vector2 = (centre + Vector2(cos(angle), sin(angle)) * 22.0).floor()
		var colour: Color = Color.WHITE
		colour.a = strength
		draw_rect(Rect2(at + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), colour)
		draw_rect(Rect2(at + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), colour)
