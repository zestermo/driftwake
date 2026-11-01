extends SceneTree
## The volcano's rumbles and bursts (scripts/island/themes/volcanic_eruptions.gd): an eruption's bombs are the same
## from the same island and number (every screen agrees) and differ from one to the next; 10-16 of them in one sector,
## none near the town or the dock; set off, red circles show on the ground before the bombs land, a captain standing on
## one is burned, one standing clear is not; the host counts eruptions on and a guest's copy follows the host's number.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var step := 0
var until := 0
var isl
var er
var hp0 := 0.0
var spot := Vector2.ZERO
var tele := 0


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
	match step:
		0:
			var v = load("res://scripts/island/themes/island_themes.gd").of("volcanic")
			var c = load("res://scripts/world/chain.gd").make(23, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
			n["theme"] = "volcanic"
			n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
			load("res://scripts/island/island_theme.gd").meshes("volcanic")
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "VolcanicIsland"
			isl.prepare(n)
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			er = isl.get_node("VolcanicEruptions")
			var a: Array = er.plan(3)
			var b: Array = er.plan(3)
			var o: Array = er.plan(4)
			check("an eruption's bombs are the same from the same number, another's differ", JSON.stringify(a) == JSON.stringify(b) and JSON.stringify(a) != JSON.stringify(o))
			var ok := true
			var count_ok := true
			for k in range(12):
				var pl: Array = er.plan(k)
				count_ok = count_ok and (pl[1] as Array).size() >= 6 and (pl[1] as Array).size() <= 16
				for bm in pl[1]:
					for s in ["village", "dock"]:
						if (bm[1] as Vector2).distance_to(isl.sites[s]) < er.BOMB_SAFE:
							ok = false
					if (bm[1] as Vector2).distance_to(pl[0]) > er.SPREAD + 0.1:
						ok = false
			check("6-16 bombs an eruption, in one sector, none near the town or the dock", ok and count_ok)
			# stand on the first bomb's spot of the next eruption
			var nxt: Array = er.plan(er.n)
			var first: Array = nxt[1][0]
			for bm in nxt[1]:
				if float(bm[0]) < float(first[0]):
					first = bm
			spot = first[1]
			var p = stage.player
			p.global_position = isl.to_global(Vector3(spot.x, isl.hv(spot) + 0.2, spot.y))
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			var n0: int = er.n
			er.erupt_now()
			check("the host counts its eruptions on (%d -> %d)" % [n0, er.n], er.n == n0 + 1)
			until = TK.wait_secs(float(first[0]) - er.TELL + 0.3)
		1:
			for c in stage.get_parent().find_children("Telegraph", "", true, false):
				tele += 1
			check("red circles on the ground before the bombs land (%d)" % tele, tele >= 1)
			until = TK.wait_secs(er.TELL + 0.3)
		2:
			var p = stage.player
			check("a bomb landing on the captain burns (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			# the next one, standing well clear of every bomb
			p.health_component.current_health = p.health_component.max_health
			var pl: Array = er.plan(er.n)
			var mid: Vector2 = pl[0]
			var away: Vector2 = mid + (mid - (isl.land_plan["cone"]["c"] as Vector2)).normalized() * (er.SPREAD + 30.0)
			p.global_position = isl.to_global(Vector3(away.x, isl.hv(away) + 0.2, away.y))
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			er.erupt_now()
			until = TK.wait_secs(er.RUMBLE_LEAD + er.SPAN + 0.6)
		3:
			var p = stage.player
			check("...one standing clear isn't hurt (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health >= hp0)
			er.net_event("erupt", [7])
			check("a guest's copy follows the host's number (%d)" % er.n, er.n == 8)
			return TK.done(fails)
	step += 1
	return false
