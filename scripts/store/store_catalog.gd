class_name StoreCatalog
extends RefCounted
## Everything the store sells, and what each thing costs.
##
## Only lists and prices: nothing here touches a hero. Weapons and boots are
## fixed templates that carry their own price. Armour is sold by the piece, but
## an Armour item is one item made of its pieces, so its price is the sum of
## the pieces it has.

## The order weapon kinds are listed in.
const WEAPON_FAMILIES: Array[StringName] = [&"sword", &"crossbow", &"wand"]
## The pools armour art is drawn from, in display order.
const ARMOUR_POOLS: Array[StringName] = [&"novice", &"mage", &"ranger", &"warrior"]
const ARMOUR_PIECES: Array[ArmourItem.Piece] = [
	ArmourItem.Piece.HAT, ArmourItem.Piece.SHIRT, ArmourItem.Piece.PANTS
]


## Every weapon of `family`, cheapest first.
static func weapons(family: StringName) -> Array[WeaponItem]:
	var listed: Array[WeaponItem] = []
	for weapon_id: StringName in WeaponData.all_ids():
		var data: WeaponData = WeaponData.find(weapon_id)
		if data != null and data.family == family:
			var item: WeaponItem = WeaponItem.create(weapon_id)
			if item != null:
				listed.append(item)
	listed.sort_custom(_cheaper_first)
	return listed


## Every pair of boots, cheapest first.
static func boots() -> Array[BootsItem]:
	var listed: Array[BootsItem] = []
	for boots_id: StringName in BootsData.all_ids():
		var item: BootsItem = BootsItem.create(boots_id)
		if item != null:
			listed.append(item)
	listed.sort_custom(_cheaper_first)
	return listed


## An Armour item holding only variant `piece_id` of `piece` from `pool`, which
## is how a single piece is shown and priced on its own.
static func armour_piece(pool: StringName, piece: ArmourItem.Piece, piece_id: int) -> ArmourItem:
	var item: ArmourItem = ArmourItem.new()
	item.pool = pool
	item.set_piece_id(piece, piece_id)
	return item


## What `item` costs, or zero with an error if the store does not sell that
## kind of thing.
static func price_of(item: EquipmentItem) -> int:
	if item is WeaponItem:
		var weapon: WeaponData = (item as WeaponItem).data()
		return weapon.price if weapon != null else 0
	if item is BootsItem:
		var pair: BootsData = (item as BootsItem).data()
		return pair.price if pair != null else 0
	if item is ArmourItem:
		return _armour_price(item as ArmourItem)
	push_error("StoreCatalog: the store does not sell %s." % item)
	return 0


## What the store pays for `item`: its Common store price times its rarity's
## `sell_fraction`, at least 1 gold for anything the store would price. Always
## less than the store's price for the same item, so buying to sell loses.
static func sell_price_of(item: EquipmentItem) -> int:
	var base: int = price_of(item)
	if base <= 0:
		return 0
	var rarity: RarityData = item.get_rarity()
	var fraction: float = rarity.sell_fraction if rarity != null else 0.0
	return maxi(floori(base * fraction), 1)


static func _armour_price(armour: ArmourItem) -> int:
	var prices: ArmourPrices = ArmourPrices.load_default()
	if prices == null:
		return 0
	var total: int = 0
	for piece: ArmourItem.Piece in ARMOUR_PIECES:
		if armour.piece_id(piece) != ArmourItem.NO_PIECE:
			total += prices.price_for(piece)
	return total


static func _cheaper_first(a: EquipmentItem, b: EquipmentItem) -> bool:
	var price_a: int = price_of(a)
	var price_b: int = price_of(b)
	if price_a != price_b:
		return price_a < price_b
	return a.get_display_name() < b.get_display_name()
