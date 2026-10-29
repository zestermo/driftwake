extends SceneTree
## Admiralty outposts always stand where they roll (1.26, docs/v1_26_plan.md "Admiralty outposts": the playtest met
## none in two hours; a rolled outpost used to be skipped when its three rings round the plaza had no flat ground):
## over the first islands of a few chains, every village that rolls one gets a spot (MarineOutpost.spot_for), and on
## the pier's side of the village more often than not.
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [11, 4242, 777, 90210]
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
	var CH = load("res://scripts/world/chain.gd")
	var MO = load("res://scripts/island/marine_outpost.gd")
	var rolled := 0
	var placed := 0
	var pier_side := 0
	for sd in SEEDS:
		var c = CH.make(sd, Vector2.ZERO, Vector2(0, -1))
		var ids: Array = [int(c.start_next[0])]
		for nx in c.node(ids[0]).get("next", []):
			ids.append(int(nx))
		for id in ids.slice(0, 3):
			var n: Dictionary = c.node(id).duplicate(true)
			load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
			var isl = load("res://scripts/island/gen_island.gd").new()
			isl.prepare(n)
			if not MO.rolls(isl):
				isl.free()
				continue
			rolled += 1
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([int(n["seed"]), 5109])
			rng.randf()
			var at: Array = MO.spot_for(isl, rng)
			if not at.is_empty():
				placed += 1
				if isl.sites.has("dock_end"):
					var vc: Vector2 = isl.village_plan["c"]
					var to_pier: Vector2 = Vector2(isl.sites["dock_end"]) - vc
					if (at[0] - vc).normalized().dot(to_pier.normalized()) > 0.0:
						pier_side += 1
			print("   seed %d isle %d (%s): outpost %s; village %s, dock %s" % [sd, id, n["theme"], "at %s" % [at[0]] if not at.is_empty() else "NONE", isl.village_plan.get("c"), isl.sites.get("dock_end", "none")])
			isl.free()
	check("some villages roll an outpost (%d)" % rolled, rolled >= 2)
	check("...and every one that rolls gets a spot (%d of %d)" % [placed, rolled], placed == rolled)
	check("...mostly on the pier's side (%d of %d)" % [pier_side, placed], pier_side * 2 >= placed)
	return TK.done(fails)
