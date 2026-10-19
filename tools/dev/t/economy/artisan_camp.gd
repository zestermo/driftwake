extends SceneTree
## Artisans on generated islands: some islands have one (not all), camped off a trail away from the village and
## the dock; the same island seed gives the same artisan in the same spot with the same wares (co-op: every
## crewmate builds it alike); built, the camp has its fire and tent and the artisan trades (a shop in Shops.extra
## with a few goods and what they buy).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var step := 0
var until := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _prepared(n: Dictionary):
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.prepare(n)
	return isl


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var c = load("res://scripts/world/chain.gd").make(7, Vector2.ZERO, Vector2(0, -1))
			var with: Array = []
			var without := 0
			var isl = null
			var node := {}
			for id in range(mini(c.nodes.size(), 8)):
				var n: Dictionary = c.node(id)
				load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
				var gi = _prepared(n)
				if gi.artisan.is_empty():
					without += 1
					gi.free()
				else:
					with.append(gi.artisan["kind"])
					if isl == null:
						isl = gi
						node = n
					else:
						gi.free()
				if isl != null and without > 0:
					break
			print("   artisans: %s, %d islands without" % [with, without])
			check("some islands have an artisan, some don't", isl != null and without > 0)
			if isl == null:
				return TK.done(fails)
			var a: Dictionary = isl.artisan
			var v: Vector2 = isl.sites["village"]
			check("camped away from the village (%.0f m) and the dock (%.0f m), off the trail (%.1f m)" % [v.distance_to(a["at"]), isl.dock_shore.distance_to(a["at"]), isl.path_dist(a["at"])],
				v.distance_to(a["at"]) > 35.0 and isl.dock_shore.distance_to(a["at"]) > 25.0 and isl.path_dist(a["at"]) >= 2.0)
			var twin = _prepared(node)
			check("the same seed, the same artisan in the same spot", twin.artisan["kind"] == a["kind"] and twin.artisan["at"] == a["at"] and twin.artisan["seed"] == a["seed"])
			twin.free()
			isl.name = "ArtisanIsland"
			stage.add_child(isl)
			for s in load("res://scripts/island/artisans.gd").steps(isl):
				s[1].call()
			var camp: Node3D = isl.get_node_or_null("Artisan")
			var npcs: Array = camp.find_children("*", "NPC", true, false) if camp else []
			check("built: the camp with its fire, tent and the artisan", camp != null and npcs.size() == 1 and not camp.find_children("Tent*", "", true, false).is_empty())
			var sh: Dictionary = load("res://scripts/game/shops.gd").shop(npcs[0].shop_id) if npcs.size() == 1 else {}
			print("   %s: %s" % [sh.get("name", "?"), sh.get("stock", [])])
			check("...who trades a few goods and buys some", not sh.is_empty() and (sh["stock"] as Array).size() >= 2 and (sh["stock"] as Array).size() <= 3 and not (sh["buys"] as Dictionary).is_empty())
			isl.queue_free()
			return TK.done(fails)
	return false
