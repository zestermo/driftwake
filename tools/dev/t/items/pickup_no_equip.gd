extends SceneTree
## A weapon picked up (loose, from a chest) or bought goes into the bag and nothing changes in your hands:
## not the main hand, not the off hand (no more automatic dual wield), not the loadout, not worn gear.
## Food still fills an empty quick item (that's a selection, not equipping).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hands := []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "chest": [["boarding_axe", 1], ["pistol", 1]]})


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
			var inv = p.inventory_component
			if inv.count("cutlass") == 0:
				inv.add_item(item("cutlass"), 1)
			p.equip_weapon(inv.find_item("cutlass"), false)
			hands = p.hands_slot()
			var slot_before: Array = p.loadouts[p.loadout_at].duplicate()
			check("starts holding the cutlass alone", hands == ["cutlass", ""])
			inv.add_item(item("cutlass"), 1)
			check("a second cutlass goes in the bag", inv.count("cutlass") == 2)
			check("...and isn't dual wielded", p.offhand_weapon == null and p.style() == "sword")
			for id in ["dagger", "pistol", "katana"]:
				inv.add_item(item(id), 1)
			check("a dagger, pistol and katana go in the bag", inv.count("dagger") == 1 and inv.count("pistol") == 1 and inv.count("katana") == 1)
			check("the main hand is untouched", p.equipped_weapon != null and p.equipped_weapon.id == "cutlass")
			check("the off hand is empty", p.offhand_weapon == null)
			check("the loadout in use is untouched", p.hands_slot() == hands and p.loadouts[p.loadout_at] == slot_before)
			stage.chest.rolled = true
			stage.chest._on_picked_up(p)
			until = TK.wait_ticks(6)
		1:
			var inv = p.inventory_component
			check("a chest's axe and pistol land in the bag", inv.count("boarding_axe") == 1 and inv.count("pistol") == 2)
			check("...hands and loadout unchanged", p.hands_slot() == hands and p.loadouts[p.loadout_at] == hands)
			p.unequip_weapon()
			check("fists", p.equipped_weapon == null and p.hands_slot() == ["", ""])
			inv.add_item(item("katana"), 1)
			check("a weapon found while bare-handed isn't picked up into the hand", p.equipped_weapon == null and p.offhand_weapon == null and p.style() == "fist")
			check("...the fists loadout is untouched", p.loadouts[p.loadout_at] == ["", ""])
			inv.select_quick("")
			inv.add_item(item("biscuit"), 2)
			check("food fills the empty quick item", inv.quick == "biscuit")
			check("...and equips nothing", p.equipped_weapon == null and p.offhand_weapon == null)
			return TK.done(fails)
	step += 1
	return false
