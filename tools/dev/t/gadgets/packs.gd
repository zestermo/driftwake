extends SceneTree
## (1.30) Ready-made gadget packs ("kit_<gadget>"): carried, a pack of a gadget not built yet becomes it, Mk I on the
## belt with full charges; more packs stay in the bag and refill it when it runs dry (U). Sold by chandlers and
## Nessa at modest prices; the stronghold's supply crates roll them (Gadgets.supply_crate).
const TK := preload("res://tools/dev/test_kit.gd")
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var b = p.gadgets if p else null
	match step:
		0:
			p = stage.player
			p.inventory_component.add_item(ItemDB.get_item("kit_smoke"), 3)
			until = TK.wait_ticks(3)
		1:
			check("a smoke pack becomes the pellet, Mk I (%s)" % str(b.owned), b.tier_of("smoke") == 0)
			check("...on the belt with full charges (%s)" % str(b.slots), "smoke" in b.slots and b.charges("smoke") == b.max_charges("smoke"))
			check("...its blueprint known", Gadgets.knows(p, "smoke"))
			check("...one pack used, two kept (%d)" % b.packs("smoke"), b.packs("smoke") == 2)
			b.owned["smoke"]["charges"] = 0
			check("dry, U opens a fresh pack and throws", b.fire())
			check("...refilled less the throw (%d)" % b.charges("smoke"), b.charges("smoke") == b.max_charges("smoke") - 1)
			check("...one pack left (%d)" % b.packs("smoke"), b.packs("smoke") == 1)
			var kits := ["kit_smoke", "kit_flash", "kit_grapple"]
			for k in kits:
				var it := ItemDB.get_item(k)
				check("%s priced modestly (%d)" % [k, Economy.price(it)], it != null and Economy.price(it) > 0 and Economy.price(it) <= 160)
			var ch: Array = (load("res://scripts/island/harbour_vendor.gd").CHANDLER_STOCK as Array).map(func(e): return e[0])
			check("chandlers sell the packs", kits.all(func(k): return k in ch))
			var ne: Array = (load("res://scripts/game/shops.gd").SHOPS["nessa"]["stock"] as Array).map(func(e): return e[0])
			check("...and so does Nessa", kits.all(func(k): return k in ne))
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var got := {}
			for i in range(30):
				var out: Array = []
				Gadgets.supply_crate(out, rng)
				for st in out:
					got[st.item.id] = true
			check("supply crates roll smoke and flash packs (%s)" % str(got.keys()), got.has("kit_smoke") and got.has("kit_flash"))
			until = TK.wait_secs(1.0)
		2:
			p.inventory_component.add_item(ItemDB.get_item("kit_flash"), 1)
			until = TK.wait_ticks(3)
		3:
			check("a flash pack with the belt full builds it off the slots (%s)" % str(b.slots), b.tier_of("flash") == 0 and not "flash" in b.slots and b.packs("flash") == 0)
			return TK.done(fails)
	step += 1
	return false
