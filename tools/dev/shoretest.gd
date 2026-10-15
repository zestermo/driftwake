extends SceneTree
## Shore-aware water (ShoreMap, OceanManager's shore swell): every island built has a shore
## map in the sea, baked the same from the same land; along every coast the sea never rises
## over dry ground through a swell's worth of time (calm and in a storm); on Brinehollow's most
## sheltered beach the crests run in toward the sand, not along it or away; the open sea
## round the maps is the open swell to the last texel; waves still break on the beach (SeaSpray).
const TK = preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var until := 0
var fails := 0
var oc
var world
var p


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


## The worst places the sea stands over dry ground along a map's coast ([count, worst over, where]).
func _dry_over(map, ground: Callable, amp: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	oc.amp_mult = amp
	var over := 0
	var worst := 0.0
	var at := Vector2.ZERO
	var pts := 0
	var n: int = map.n
	for iz in range(n):
		for ix in range(n):
			var dep: float = map.data[(iz * n + ix) * 4]
			if dep > 0.3 or dep < -3.0:
				continue
			for k in range(2):
				var q := Vector2(map.rect.x + (ix + 0.5 + rng.randf_range(-0.5, 0.5)) * map.cell, map.rect.y + (iz + 0.5 + rng.randf_range(-0.5, 0.5)) * map.cell)
				var g: float = ground.call(q)
				if g <= 0.0:
					continue
				pts += 1
				var top := -INF
				for i in range(30):
					top = maxf(top, oc.get_wave_height(Vector3(q.x, 0.0, q.y), 500.0 + i * 0.7))
				if top > g:
					over += 1
					if top - g > worst:
						worst = top - g
						at = q
	oc.amp_mult = 1.0
	return [over, worst, at, pts]


## How the swell moves at P over half a minute: [along the normal vs along the shore (energy ratio),
## correlation of dh/dt with dh/dn (> 0: crests travelling toward -n, the shore)].
func _motion(P: Vector2, nrm: Vector2) -> Array:
	var al := Vector2(-nrm.y, nrm.x)
	var e := 0.4
	var dn2 := 0.0
	var da2 := 0.0
	var tn := 0.0
	var tt := 0.0
	for i in range(120):
		var ti := 800.0 + i * 0.25
		var h := func(q: Vector2, tq: float) -> float: return oc.get_wave_height(Vector3(q.x, 0.0, q.y), tq)
		var dn: float = (h.call(P + nrm * e, ti) - h.call(P - nrm * e, ti)) / (2.0 * e)
		var da: float = (h.call(P + al * e, ti) - h.call(P - al * e, ti)) / (2.0 * e)
		var dt: float = (h.call(P, ti + 0.05) - h.call(P, ti - 0.05)) / 0.1
		dn2 += dn * dn
		da2 += da * da
		tn += dt * dn
		tt += dt * dt
	return [dn2 / maxf(da2, 1e-9), tn / sqrt(maxf(tt * dn2, 1e-12))]


func _process(d: float) -> bool:
	t += d
	if t > 300.0:
		check("timed out at step %d" % step, false)
		return TK.done(fails)
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 1.5:
				return false
			world = root.get_node("World/Islands")
			if not world.chain_ready():
				return false
			oc = root.get_node("Ocean")
			p = get_first_node_in_group("player")
			var bh = world.starter_island
			var sc: Vector2 = world.starter_center
			check("Brinehollow's shore map is in the sea (%s)" % [oc.shores.keys()], oc.shores.has("brinehollow"))
			for id in world.chain_islands.keys():
				var isl = world.chain_islands[id]
				print("   %s: shore map %d px, baked in %d ms on the worker" % [isl.island_name, isl.shore.n, int(isl.build_ms.get("shore", -1))])
				check("%s's shore map is in the sea, over the island" % isl.island_name, oc.shores.get("isle%d" % id) == isl.shore
					and isl.shore.rect.x < isl.position.x and isl.shore.rect.x + isl.shore.rect.z > isl.position.x)
			# the same land bakes the same map (every screen in co-op)
			var t0 := Time.get_ticks_usec()
			var again = load("res://scripts/ocean/shore_map.gd").bake(bh.heights, bh.RES + 1, bh.CELL, Vector2(-bh.HALF, -bh.HALF), oc.swell_dir())
			print("   Brinehollow's shore map: %d px, baked in %d ms" % [again.n, (Time.get_ticks_usec() - t0) / 1000])
			check("the same land bakes the same shore map", again.data == oc.shores["brinehollow"].data)
			check("Brinehollow's middle is dry, the open sea far out deep and untouched", oc.shore_at(sc.x, sc.y).x < 0.0 and oc.shore_at(sc.x + 2000.0, sc.y) == load("res://scripts/ocean/shore_map.gd").NONE)
			# no water over dry ground along every coast, calm and in a storm
			var maps: Array = [["Brinehollow", oc.shores["brinehollow"], func(q: Vector2) -> float: return bh.height_at(q.x - sc.x, q.y - sc.y)]]
			for id in world.chain_islands.keys():
				var isl = world.chain_islands[id]
				maps.append([isl.island_name, isl.shore, func(q: Vector2) -> float:
					var l: Vector3 = isl.to_local(Vector3(q.x, 0.0, q.y))
					return isl.height_at(l.x, l.z)])
			var islet = load("res://scripts/world/sea_legs.gd").islet_shore()
			var ic := sc + Vector2(-1500.0, 1500.0)
			oc.set_shore("test_islet", islet, ic)
			maps.append(["an islet", islet, func(q: Vector2) -> float: return load("res://scripts/world/sea_legs.gd")._islet_ground(q.distance_to(ic))])
			for m in maps:
				for amp in [1.0, 1.8]:
					var r := _dry_over(m[1], m[2], amp)
					check("%s: the sea never rises over dry ground along the coast (amp %.1f; %d points, %d over, worst %.3f m at %s)" % [m[0], amp, r[3], r[0], r[1], r[2]], r[3] > 20 and r[0] == 0)
			oc.set_shore("test_islet", null)
			# the most sheltered beach: the open swell runs away from it
			var map = oc.shores["brinehollow"]
			var sw: Vector2 = oc.swell_dir()
			var best := -2.0
			var P := Vector2.ZERO
			var nrm := Vector2.ZERO
			for iz in range(0, map.n, 2):
				for ix in range(0, map.n, 2):
					var q := Vector2(map.rect.x + (ix + 0.5) * map.cell, map.rect.y + (iz + 0.5) * map.cell)
					var s: Vector4 = oc.shore_at(q.x, q.y)
					if s.x < 2.0 or s.x > 3.5 or s.z < 0.95:
						continue
					var gq := Vector2(oc.shore_at(q.x + 1.5, q.y).y - oc.shore_at(q.x - 1.5, q.y).y, oc.shore_at(q.x, q.y + 1.5).y - oc.shore_at(q.x, q.y - 1.5).y)
					if gq.length() < 0.5:
						continue
					var nq := gq.normalized()
					# (a beach: low, gently rising ground 15-25 m in)
					var g15: float = bh.height_at(q.x - nq.x * 15.0 - sc.x, q.y - nq.y * 15.0 - sc.y)
					var g25: float = bh.height_at(q.x - nq.x * 25.0 - sc.x, q.y - nq.y * 25.0 - sc.y)
					if g15 < 0.0 or g15 > 2.5 or g25 > 4.0:
						continue
					if nq.dot(sw) > best:
						best = nq.dot(sw)
						P = q
						nrm = nq
			print("   the most sheltered beach: %s (island %s), its offshore normal %s, the swell runs %s" % [P.round(), (P - sc).round(), nrm, sw])
			check("Brinehollow has a beach in the lee of the swell (%.2f)" % best, best > 0.4)
			var now := _motion(P, nrm)
			oc.set_shore("brinehollow", null)
			var was := _motion(P, nrm)
			oc.set_shore("brinehollow", map, sc)
			print("   open swell alone there: across/along %.2f, toward the shore %.2f; now %.2f, %.2f" % [was[0], was[1], now[0], now[1]])
			check("...where the open swell alone would run off it, not in (%.2f)" % was[1], was[1] < 0.3)
			check("...its crests run along the beach, not across it (slope across/along %.1f)" % now[0], now[0] > 4.0)
			check("...and travel in toward the sand (%.2f)" % now[1], now[1] > 0.7)
			# the map's edge is the open sea's to the last texel (no seam)
			var seam := 0.0
			for k in range(64):
				var u := k / 64.0
				for q in [Vector2(map.rect.x + 0.01, map.rect.y + u * map.rect.z), Vector2(map.rect.x + u * map.rect.z, map.rect.y + map.rect.z - 0.01)]:
					var hm: float = oc.get_wave_height(Vector3(q.x, 0.0, q.y), 300.0)
					oc._shore_list = []
					seam = maxf(seam, absf(hm - oc.get_wave_height(Vector3(q.x, 0.0, q.y), 300.0)))
					oc._shore_list = oc.shores.values()
			check("at its map's edge the sea is the open swell (%.5f m apart)" % seam, seam < 0.0005)
			# what a wave height costs now (the game asks for hundreds a frame)
			var cost := []
			for q in [P, sc + Vector2(2000.0, 0.0)]:
				var t1 := Time.get_ticks_usec()
				for i in range(5000):
					oc.get_wave_height(Vector3(q.x, 0.0, q.y), 100.0 + i * 0.01)
				cost.append(float(Time.get_ticks_usec() - t1) / 5000.0)
			oc._shore_list = []
			var t2 := Time.get_ticks_usec()
			for i in range(5000):
				oc.get_wave_height(Vector3(P.x, 0.0, P.y), 100.0 + i * 0.01)
			oc._shore_list = oc.shores.values()
			print("   a wave height: %.1f us by the shore, %.1f us at sea (%d maps), %.1f us with no maps" % [cost[0], cost[1], oc.shores.size(), float(Time.get_ticks_usec() - t2) / 5000.0])
			# waves still break on the beach you wake on
			var spray = root.get_node("Weather").find_child("SeaSpray", true, false)
			spray.breaks["beach"] = 0
			p.state_machine.force_state("Idle", {})
			p.global_position = bh.to_global(Vector3(-53.0, bh.height_at(-53.0, -163.0) + 1.0, -163.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(12.0)
			step = 1
		1:
			var spray = root.get_node("Weather").find_child("SeaSpray", true, false)
			check("waves break on the beach you wake on (%d)" % spray.breaks["beach"], int(spray.breaks["beach"]) > 0)
			return TK.done(fails)
	return false
