extends SceneTree
## A chest's treasure and boarding axe go into the bag (the axe off the quick slots); the axe equips from the bag
## and hits harder; the treasure banks in the ship's storage while the weapons stay in the bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "chest": [["treasure", 1], ["boarding_axe", 1]], "storage": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			# (what's in it as it is: the economy's roll is t/economy's)
			stage.chest.rolled = true
			stage.chest._on_picked_up(p)
			until = TK.wait_ticks(6)
		1:
			var inv = p.inventory_component
			check("picked up axe", inv.count("boarding_axe") == 1)
			check("axe isn't the quick item", inv.quick != "boarding_axe")
			check("loot counted", inv.get_loot_count() == 1)
			p.equip_weapon(inv.find_item("boarding_axe"), true)
			until = TK.wait_secs(0.6)
		2:
			check("equipping the axe from the bag", p.equipped_weapon != null and p.equipped_weapon.id == "boarding_axe" and p.armed)
			check("axe damage mult", is_equal_approx(p.damage_multiplier(), 1.4))
			var gm = root.get_node("GameManager")
			var inv = p.inventory_component
			stage.storage.store(p, inv.find_index("treasure"), -1)
			check("the treasure goes into the ship's storage", inv.count("treasure") == 0 and gm.stored_count("treasure") == 1)
			check("...the weapons stay in the bag", inv.count("boarding_axe") == 1 and inv.count("cutlass") == 1)
			return TK.done(fails)
	step += 1
	return false
