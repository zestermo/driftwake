extends SceneTree
## The coral atoll's harvest (1.30, AtollReef.harvest; Zach: "practically impossible to find the materials to craft the
## skimmer"): every atoll has plenty of giant clams (a Lagoon Pearl), coral outcrops (two Coral Spar), pen shells
## (Sea-silk) and urchin clusters, many times a Mk I skimmer's 4 spar, 2 silk and 1 pearl, spread over the lagoon's
## patches and thick in the deep basin, all in a diver's reach, each with a tell (it glints); cutting a pen shell's silk
## gives Sea-silk once, breaking a spar two Coral Spar, the urchins come off; and the pearl trader points to the deep reef.
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
	var v = load("res://scripts/island/themes/island_themes.gd").of("atoll")
	load("res://scripts/island/island_theme.gd").meshes("atoll")
	var R = load("res://scripts/island/themes/atoll_reef.gd")
	var isl
	var town: Array = []
	for cs in [11, 5, 23, 31]:
		var c = load("res://scripts/world/chain.gd").make(cs, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "atoll"
		n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
		isl = load("res://scripts/island/gen_island.gd").new()
		isl.prepare(n)
		town = isl.places.filter(func(pl): return pl["kind"] == "atoll_stilts")
		if not town.is_empty():
			break
		isl.free()
	isl.name = "AtollHarvest"
	stage.add_child(isl)
	for s in isl._theme.steps(isl):
		s[1].call()
	var reef: Node3D = isl.get_node("AtollReef")
	var by := {}
	for k in ["Clam_", "Spar_", "Pen_", "Urchins_"]:
		by[k] = reef.get_children().filter(func(m): return m.name.begins_with(k))
	var clams: int = by["Clam_"].size()
	var spars: int = by["Spar_"].size()
	var pens: int = by["Pen_"].size()
	check("plenty of every kind (%d clams, %d outcrops, %d pen shells, %d urchin clusters)" % [clams, spars, pens, by["Urchins_"].size()],
		clams >= R.CLAMS[0] and spars >= R.OUTCROPS[0] and pens >= R.PENS[0] and by["Urchins_"].size() >= R.URCHINS[0])
	check("...many Mk I skimmers' worth (%d spar, %d silk, %d lagoon pearls; one needs 4, 2, 1)" % [spars * 2, pens, clams], spars * 2 >= 12 and pens >= 6 and clams >= 3)
	var hole: Array = isl.land_plan["hole"]
	var hc: Vector2 = hole[0]
	var all: Array = by["Clam_"] + by["Spar_"] + by["Pen_"] + by["Urchins_"]
	var in_basin := 0
	var deepest := 0.0
	var reach_ok := true
	for m in all:
		var p: Vector3 = (m as Node3D).position
		if Vector2(p.x, p.z).distance_to(hc) < float(hole[1]) * 1.15:
			in_basin += 1
		deepest = minf(deepest, p.y)
		var it = (m as Node).get_node("Take")
		reach_ok = reach_ok and bool(it.usable_in_water) and p.y < -0.5
	check("...spread over the lagoon and thick in the deep basin (%d of %d in it)" % [in_basin, all.size()], in_basin >= all.size() / 3 and all.size() - in_basin >= 10)
	check("...all under the water, in a diver's reach (deepest %.1f m), F works swimming" % deepest, reach_ok and deepest > -38.0)
	var glints: Node = reef.get_node("Glints")
	check("...each with a tell: it glints (%d)" % glints.items.size(), glints.items.size() == all.size())
	var p = stage.player
	var inv = p.inventory_component
	var pen: Node3D = by["Pen_"][0]
	var silk: Node3D = pen.get_node("Silk")
	var s0: int = inv.count("sea_silk")
	R._take(p, pen.name.trim_prefix("Pen_"), R.PEN_LOOT, "x", silk)
	check("cutting a pen shell's silk gives Sea-silk (%d -> %d), its silk gone" % [s0, inv.count("sea_silk")], inv.count("sea_silk") == s0 + 1 and not silk.visible)
	R._take(p, pen.name.trim_prefix("Pen_"), R.PEN_LOOT, "x", silk)
	check("...once", inv.count("sea_silk") == s0 + 1)
	var spar: Node3D = by["Spar_"][0]
	var c0: int = inv.count("coral_spar")
	R._take(p, spar.name.trim_prefix("Spar_"), R.SPAR_LOOT, "x", spar.get_node("Spar"))
	check("breaking a spar gives two Coral Spar (%d -> %d)" % [c0, inv.count("coral_spar")], inv.count("coral_spar") == c0 + 2)
	var ur: Node3D = by["Urchins_"][0]
	var u0: int = inv.count("sea_urchin")
	R._take(p, ur.name.trim_prefix("Urchins_"), R.URCHIN_LOOT, "x", ur.get_node("Urchins"))
	check("gathering urchins gives sea urchins (%d -> %d)" % [u0, inv.count("sea_urchin")], inv.count("sea_urchin") >= u0 + 2)
	check("sharks prowl the basin, morays in its walls", isl.get_node("AtollDeepLife").get_children().filter(func(m): return m.name.begins_with("Shark")).size() >= 2
		and reef.get_children().filter(func(m): return m.name.begins_with("Moray")).size() >= 10)
	if not town.is_empty():
		for s in load("res://scripts/island/kit/kit_landmarks.gd").steps(isl):
			if s[0] == "atoll_stilts":
				s[1].call()
		var shop: Dictionary = load("res://scripts/game/shops.gd").extra.get(isl.save_key("pearl_trader"), {})
		check("the pearl trader points to the deep reef: \"%s\"" % str(shop.get("line", "")), str(shop.get("line", "")).contains("deep reef") and str(shop.get("line", "")).contains("to the "))
	else:
		check("a stilt town to ask in", false)
	isl.queue_free()
	return TK.done(fails)
