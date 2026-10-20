class_name ChestArt
extends RefCounted
## The treasure chest, recoloured for a pack.
##
## The chest sheet has one chest, closed and open. Each pixel's brightness is
## mapped onto a dark-to-light ramp of the pack's colour, so the outline and
## shading survive and every pack gets its own chest from the one drawing.
## Textures are built once per colour and kept.

const SHEET: Texture2D = preload("res://assets/packs/ninja_adventure/items/treasure_chest.png")
## Side of one chest frame in the sheet: closed on the left, open on the right.
const FRAME: int = 16
## How dark the ramp's low end is, and how far its high end is lightened
## towards white, as fractions.
const SHADOW: float = 0.3
const HIGHLIGHT: float = 0.55

static var _cache: Dictionary[String, Texture2D] = {}


## The chest in `tint`, open or closed.
static func texture(tint: Color, open: bool) -> Texture2D:
	var key: String = "%s%s" % [tint.to_html(false), open]
	if _cache.has(key):
		return _cache[key]
	var image: Image = SHEET.get_image()
	if image.is_compressed():
		image.decompress()
	var frame: Image = image.get_region(Rect2i(FRAME if open else 0, 0, FRAME, FRAME))
	var dark: Color = tint * SHADOW
	var light: Color = tint.lerp(Color.WHITE, HIGHLIGHT)
	for y: int in FRAME:
		for x: int in FRAME:
			var pixel: Color = frame.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var level: float = pixel.get_luminance()
			var ramped: Color = (
				dark.lerp(tint, level * 2.0) if level < 0.5
				else tint.lerp(light, (level - 0.5) * 2.0)
			)
			ramped.a = pixel.a
			frame.set_pixel(x, y, ramped)
	var made: ImageTexture = ImageTexture.create_from_image(frame)
	_cache[key] = made
	return made
