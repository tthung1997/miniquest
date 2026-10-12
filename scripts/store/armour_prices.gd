class_name ArmourPrices
extends Resource
## What the store asks for each armour piece, whichever class's art it is.
##
## Armour pieces carry no stats yet, so a piece costs by what it is rather than
## by which variant it is. An Armour item is one item made of its pieces, so
## its price is the sum of the pieces it has. Placeholders until the economy
## is tuned.

const PATH: String = "res://resources/store/armour_prices.tres"

@export_range(0, 100000, 5, "suffix:gold") var hat: int = 0
@export_range(0, 100000, 5, "suffix:gold") var shirt: int = 0
@export_range(0, 100000, 5, "suffix:gold") var pants: int = 0


## The shared prices, or null with an error if the file is missing.
static func load_default() -> ArmourPrices:
	if not ResourceLoader.exists(PATH):
		push_error("ArmourPrices: missing %s." % PATH)
		return null
	var prices: ArmourPrices = load(PATH) as ArmourPrices
	if prices == null:
		push_error("ArmourPrices: %s is not an ArmourPrices." % PATH)
	return prices


func price_for(piece: ArmourItem.Piece) -> int:
	match piece:
		ArmourItem.Piece.HAT:
			return hat
		ArmourItem.Piece.SHIRT:
			return shirt
		ArmourItem.Piece.PANTS:
			return pants
	return 0
