extends SceneTree
## The capital's rooftops are places (1.27, CapitalRoofs; Zach: "players will reach the roofs"): a flat roof is solid at
## its slabs, a pitched roof under its tiles (not the eaves' box below them), ladders climb from the lanes onto flat
## roofs, and the captain dropped onto a flat roof and onto a pitched one stays up there.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var p
var flat: Dictionary
var pitched: Dictionary
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


func _down(q: Vector2, y: float) -> Dictionary:
	var a: Vector3 = isl.city_global(q, y + 6.0)
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.DOWN * 12.0))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var D = load("res://scripts/island/capital_district.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(4)
		2:
			var tops: Array = D.lots().filter(func(l): return l.has("top_y"))
			var flats: Array = tops.filter(func(l): return str(l["roof"]) == "flat")
			var others: Array = tops.filter(func(l): return str(l["roof"]) != "flat")
			check("town houses with roofs to stand on (%d flat, %d pitched)" % [flats.size(), others.size()], flats.size() >= 15 and others.size() >= 30)
			var bad_f: Array = []
			for l in flats:
				var hit := _down(l["c"], float(l["top_y"]))
				var dy: float = (hit["position"].y if not hit.is_empty() else -INF) - isl.city_global(l["c"], float(l["top_y"])).y
				# (a prop up there, a skylight or the stair hut, is higher: only below the slabs is a hole)
				if dy < -0.35:
					bad_f.append("%s %.1f" % [(l["c"] as Vector2).round(), dy])
			check("every flat roof is solid at its slabs (%s)" % [bad_f.slice(0, 6)], bad_f.is_empty())
			var bad_p: Array = []
			for l in others:
				var hit := _down(l["c"], float(l["top_y"]))
				if hit.is_empty() or hit["position"].y < isl.city_global(l["c"], float(l["top_y"])).y + 0.5:
					bad_p.append(str((l["c"] as Vector2).round()))
			check("every pitched roof is solid under its tiles, not at the eaves (%s)" % [bad_p.slice(0, 6)], bad_p.is_empty())
			var lads: Array = isl.city.find_children("*", "Ladder", true, false)
			check("ladders up from the lanes (%d)" % lads.size(), lads.size() >= 3)
			flat = flats[flats.size() / 2]
			pitched = others[others.size() / 2]
			p = stage.player
			p.global_position = isl.city_global(flat["c"], float(flat["top_y"]) + 0.6)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		3:
			var y0: float = isl.city_global(flat["c"], float(flat["top_y"])).y
			check("the captain stands on a flat roof (%.2f over it)" % (p.global_position.y - y0), absf(p.global_position.y - y0) < 0.5)
			var q: Vector2 = pitched["c"]
			p.global_position = isl.city_global(q, float(pitched["top_y"]) + 3.5)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		4:
			var y0: float = isl.city_global(pitched["c"], float(pitched["top_y"])).y
			check("...and on a pitched one, up on its tiles (%.2f over the eaves)" % (p.global_position.y - y0), p.global_position.y - y0 > 0.2)
			return TK.done(fails)
	step += 1
	return false
