extends SceneTree
## The item icon redo (2026-11-11): every item's picture is 32 px, shown as drawn in an inventory slot. The painted
## ones (gen_item_icons.py) have a 16 and a 48 px rendering beside them and ItemData.sized picks the nearest; the ones
## the game draws (a weapon's from its model, gear's from its colours) are 32 px too.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (by path: these reach the autoloads)
	var DB = load("res://scripts/loot/item_db.gd")
	var ID = load("res://scripts/loot/item_data.gd")
	var G = load("res://scripts/loot/gear.gd")
	DB.get_item("cutlass")
	var painted := 0
	var drawn := 0
	var bad: Array = []
	var unsized: Array = []
	for id in DB._items.keys():
		var it = DB._items[id]
		if it.icon == null:
			continue
		if it.icon.get_width() != 32 or it.icon.get_height() != 32:
			bad.append("%s %dx%d" % [id, it.icon.get_width(), it.icon.get_height()])
		if it.icon.resource_path.ends_with(".png"):
			painted += 1
			for px in [16, 48]:
				var t: Texture2D = ID.sized(it.icon, float(px))
				if t == null or t.get_width() != px or t.get_height() != px:
					unsized.append("%s@%d" % [id, px])
		else:
			drawn += 1
	print("   %d painted, %d drawn by the game" % [painted, drawn])
	check("every item's picture is 32 px (%d items; not: %s)" % [painted + drawn, str(bad.slice(0, 6))], painted > 60 and drawn > 100 and bad.is_empty())
	check("every painted one has its 16 and 48 px rendering (missing: %s)" % str(unsized.slice(0, 6)), unsized.is_empty())
	var rum = DB.get_item("rum")
	check("sized picks the nearest: 12 -> 16, 24 and 36 -> 32, 48 -> 48",
		ID.sized(rum.icon, 12.0).get_width() == 16 and ID.sized(rum.icon, 24.0) == rum.icon and ID.sized(rum.icon, 36.0) == rum.icon and ID.sized(rum.icon, 48.0).get_width() == 48)
	var sword = DB.get_item("cutlass")
	check("a picture the game drew is given back as it is at any size", ID.sized(sword.icon, 16.0) == sword.icon and ID.sized(sword.icon, 48.0) == sword.icon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var gear_ok := true
	for k in range(12):
		var g = G.random_piece(rng, k % 3)
		gear_ok = gear_ok and g != null and g.icon != null and g.icon.get_width() == 32
	check("generated gear's picture is 32 px", gear_ok)
	var INV = load("res://scripts/ui/inventory_screen.gd")
	check("an inventory slot shows the picture as drawn (%d in a %d px slot)" % [int(INV.ICON), int(INV.SLOT)], int(INV.ICON) == 32 and int(INV.SLOT) >= 36)
	return TK.done(fails)
