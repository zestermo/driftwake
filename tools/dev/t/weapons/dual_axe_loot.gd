extends SceneTree
## Twin axes are found and sold: every axe design is an item with its model and icon (the tomahawk and the reaver's
## axe new), those two carried in pairs: a chest that rolls one gives two; Haldor's forge can stock them; and
## Shift+F10 (debug) puts the new weapon kinds' rack in the bag: every polearm and hammer, every axe twice.
const TK := preload("res://tools/dev/test_kit.gd")
const NEW := ["tomahawk", "reavers_axe"]
var stage
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
	var WD = load("res://scripts/props/weapon_designs.gd")
	var ok := true
	for id in WD.item_ids("axe"):
		var it = ItemDB.get_item(id)
		ok = ok and it != null and it.weapon_model == "axe" and it.icon != null and Props.weapon_mesh(it.model()).get_meta("model", "") == it.model()
	check("every axe design is an item with its model and icon %s" % str(WD.item_ids("axe")), ok and NEW.all(func(x): return x in WD.item_ids("axe")))
	check("the tomahawk and the reaver's axe come in pairs, the others singly",
		NEW.all(func(x): return WD.comes_paired(x)) and not WD.comes_paired("boarding_axe") and not WD.comes_paired("hatchet"))
	var Loot = load("res://scripts/items/loot.gd")
	var paired := 0
	var single := 0
	for i in 400:
		var st := ItemStack.new()
		st.item = ItemDB.get_item("boarding_axe")
		st.quantity = 1
		var contents: Array[ItemStack] = [st]
		for got in Loot.chest(contents, "axe_chest_%d" % i, false):
			if got.item.weapon_model != "axe":
				continue
			if WD.comes_paired(got.item.id.get_slice("+", 0).get_slice("@", 0)):
				paired += 1 if got.quantity == 2 else -1000
			else:
				single += 1 if got.quantity == 1 else -1000
	check("a chest's tomahawk or reaver's axe comes as two, any other axe as one (%d pairs, %d singles)" % [paired, single], paired > 0 and single > 0)
	var forge: Array = load("res://scripts/game/shops.gd").SHOPS["haldor"]["pool"].map(func(e): return str(e[0]).get_slice("@", 0))
	check("Haldor's forge can stock them", NEW.all(func(x): return x in forge))
	var p = stage.player
	# (a big bag: the whole rack fits; in a small one the rest lands at your feet)
	p.inventory_component.bonus_slots = 40
	var ev := InputEventKey.new()
	ev.keycode = KEY_F10
	ev.pressed = true
	ev.shift_pressed = true
	p._unhandled_input(ev)
	var inv = p.inventory_component
	var rack := true
	for kind in ["polearm", "hammer"]:
		for id in WD.item_ids(kind):
			rack = rack and inv.count(id) >= 1
	for id in WD.item_ids("axe"):
		rack = rack and inv.count(id) >= 2
	check("Shift+F10: every polearm and hammer, every axe twice", rack)
	return TK.done(fails)
