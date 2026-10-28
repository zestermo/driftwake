extends SceneTree
## The 1.25 designs (Sharkfin Cutlass, Marlinspike, Whaler's Harpoon, Musketoon): each an item of its kind with its
## model and icon, building at every tier, in its kind's loot rolls (WeaponDesigns.item_ids, what chests and the
## treasure merchants roll from) and on Haldor's forge (and so a village smith's); the harpoon reaches further than the
## spear, the musketoon scatters less wide than the blunderbuss.
const TK := preload("res://tools/dev/test_kit.gd")
const NEW := {"sharkfin_cutlass": "cutlass", "marlinspike": "dagger", "whalers_harpoon": "polearm", "musketoon": "longgun"}
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
	var forge: Array = load("res://scripts/game/shops.gd").SHOPS["haldor"]["pool"].map(func(e): return str(e[0]).get_slice("@", 0))
	for id in NEW.keys():
		var kind: String = NEW[id]
		var it = ItemDB.get_item(id)
		var built: bool = it != null and it.weapon_model == kind and it.icon != null
		for t in range(7):
			built = built and Props.weapon_mesh(ItemDB.tiered(id, t).model()).get_surface_count() > 0
		check("%s is a %s with its model at every tier and an icon" % [id, kind], built)
		check("%s rolls as loot and sits on the forge" % id, id in WD.item_ids(kind) and id in forge)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var seen := false
		for i in 3000:
			seen = seen or WD.pick_id(kind, rng) == id
		check("%s turns up in its kind's rolls" % id, seen)
	check("the harpoon reaches further than the spear", WD.pole("harpoon", "reach") > WD.pole("", "reach"))
	var gk = load("res://scripts/weapons/gun_kinds.gd")
	check("the musketoon's scatter is tighter than the blunderbuss's", gk.design(ItemDB.get_item("musketoon"), "cone", 0.0) < gk.design(ItemDB.get_item("blunderbuss"), "cone", 0.0))
	return TK.done(fails)
