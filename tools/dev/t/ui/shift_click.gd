extends SceneTree
## Shift+click in the inventory: a bag stack goes whole into the open chest (the ship's storage here), a chest
## stack comes back with a click; with no chest open it equips (food: becomes the quick item). In a shop it
## sells the whole stack.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var inv
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "storage": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


func cell_of(id: String) -> int:
	return gm._inventory._view.find(inv.find_index(id))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gm = root.get_node("GameMenu")
			inv = p.inventory_component
			if inv.count("cutlass") == 0:
				inv.add_item(item("cutlass"), 1)
			p.equip_weapon(inv.find_item("cutlass"), false)
			inv.add_item(item("treasure"), 7)
			inv.add_item(item("boarding_axe"), 1)
			gm.open_container(stage.storage)
			until = TK.wait_ticks(6)
		1:
			var ui = gm._inventory
			check("the chest is open beside the bag", ui.has_container() and cell_of("treasure") >= 0)
			ui._click_bag(cell_of("treasure"), true)
			check("shift+click moves all 7 treasure into the chest", inv.count("treasure") == 0 and root.get_node("GameManager").stored_count("treasure") == 7)
			ui._click_bag(cell_of("boarding_axe"), true)
			check("...a weapon too", inv.count("boarding_axe") == 0 and stage.storage.contents.any(func(s): return s.item.id == "boarding_axe"))
			check("...the cutlass in hand stays", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			var at: int = stage.storage.contents.find(stage.storage.contents.filter(func(s): return s.item.id == "treasure")[0])
			ui._click_loot(at, false)
			check("a plain click on the chest's stack takes one", inv.count("treasure") == 1 and root.get_node("GameManager").stored_count("treasure") == 6)
			at = stage.storage.contents.find(stage.storage.contents.filter(func(s): return s.item.id == "treasure")[0])
			ui._click_loot(at, true)
			check("shift+click on the chest's stack brings the rest back", inv.count("treasure") == 7 and root.get_node("GameManager").stored_count("treasure") == 0)
			ui._click_bag(cell_of("treasure"), false)
			check("a plain click on a bag stack with the chest open stores nothing", root.get_node("GameManager").stored_count("treasure") == 0)
			gm.close()
			until = TK.wait_ticks(6)
		2:
			var ui = gm._inventory
			check("the chest is closed", not ui.has_container())
			inv.add_item(item("katana"), 1)
			gm.open("inventory")
			until = TK.wait_ticks(4)
		3:
			var ui = gm._inventory
			ui._click_bag(cell_of("katana"), true)
			check("with no chest, shift+click equips the weapon", p.equipped_weapon != null and p.equipped_weapon.id == "katana")
			inv.select_quick("")
			inv.add_item(item("biscuit"), 1)
			inv.add_item(item("stew"), 1)
			ui.refresh()
			check("food filled the quick item first", inv.quick == "biscuit")
			ui._click_bag(cell_of("stew"), true)
			check("shift+click on other food makes it the quick item, eating nothing", inv.quick == "stew" and inv.count("stew") == 1)
			gm.close()
			until = TK.wait_ticks(4)
		4:
			var shop = gm._shop
			gm.open_shop("nessa")
			inv.add_item(item("treasure"), 5)
			shop._refresh()
			var gold0: int = inv.count("gold")
			var held: int = inv.count("treasure")
			var k: int = shop._view.find(inv.find_index("treasure"))
			shop.quick_act("bag", k, false)
			check("a plain click on a bag stack only picks it", inv.count("treasure") == held and held >= 5)
			shop.quick_act("bag", k, true)
			check("shift+click sells the whole stack (%d G)" % (inv.count("gold") - gold0), inv.count("treasure") == 0 and inv.count("gold") > gold0)
			return TK.done(fails)
	step += 1
	return false
