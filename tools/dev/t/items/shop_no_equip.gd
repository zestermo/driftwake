extends SceneTree
## Buying a weapon or a piece of clothing puts it in the bag: the hands, the loadout and what you wear stay as they were.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var gm = root.get_node("GameMenu")
			var inv = p.inventory_component
			if inv.count("cutlass") == 0:
				inv.add_item(item("cutlass"), 1)
			p.equip_weapon(inv.find_item("cutlass"), false)
			inv.add_item(item("gold"), 5000)
			var hands: Array = p.hands_slot()
			var worn: Dictionary = {}
			for s in p.equipment.slots.keys():
				worn[s] = p.equipment.get_item(s)
			gm._shop.open_shop("haldor")
			for e in SHOPS.stock("haldor"):
				if SHOPS.item_of(e).is_weapon():
					gm._shop.buy(e)
			check("bought a cutlass among the stock: two now", inv.count("cutlass") == 2)
			check("the forge's weapons are all in the bag", inv.count("dagger") >= 1 and inv.count("pistol") >= 1)
			check("main hand unchanged", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			check("no off hand: the second cutlass isn't dual wielded", p.offhand_weapon == null)
			check("hands and loadout unchanged", p.hands_slot() == hands and p.loadouts[p.loadout_at] == hands)
			gm._shop.open_shop("sela")
			var gear := 0
			for e in SHOPS.stock("sela"):
				if e.size() > 2:
					var it: ItemData = SHOPS.item_of(e)
					var before: int = inv.count(it.id)
					gm._shop.buy(e)
					gear += 1 if inv.count(it.id) > before else 0
			check("bought clothes (%d)" % gear, gear > 0)
			var same := true
			for s in worn.keys():
				same = same and p.equipment.get_item(s) == worn[s]
			check("nothing bought is worn", same)
			return TK.done(fails)
	step += 1
	return false
