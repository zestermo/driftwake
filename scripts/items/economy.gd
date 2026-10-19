class_name Economy
extends RefCounted
## The economy's one price curve (v1.18). Everything a captain buys is priced on it, so a price
## always says the same thing about what it buys:
##   an item's worth = its value x STEP^tier (ItemData.worth: a tier up is x1.6),
##   a trader asks worth x BUY_K (by kind) and pays worth x their rate (Shops: about half),
##   a ship upgrade's level n costs its line's base x STEP^n (ShipLines.price).
## Prices come out rounded to a "nice" number (5s, then 10s, then 50s). Tuned in play.

const STEP := 1.6
const BUY_K := {"weapon": 4.0, "gear": 4.0, "consumable": 2.5, "loot": 3.0}
const KINDS := ["loot", "weapon", "consumable", "gear"]


static func tier_k(tier: int) -> float:
	return pow(STEP, tier)


static func nice(x: float) -> int:
	if x < 10.0:
		return maxi(roundi(x), 1)
	if x < 100.0:
		return roundi(x / 5.0) * 5
	if x < 1000.0:
		return roundi(x / 10.0) * 10
	return roundi(x / 50.0) * 50


## What a trader asks for one `item`.
static func price(item: ItemData) -> int:
	return nice(item.value * tier_k(int(item.rarity)) * float(BUY_K[KINDS[int(item.item_type)]]))


## A ship upgrade line's level `lv` (0-based) when its first level costs `base`.
static func upgrade_price(base: int, lv: int) -> int:
	return nice(base * tier_k(lv))
