extends RefCounted
## Brinehollow's town life (2026-10-17, docs/brinehollow_polish_plan.md step 3), built at the end of
## StarterIsland.build (its LIFE hook) from `town_spots`: the townsfolk on routines (BrinehollowCast.townsfolk,
## made in that order with fixed names; where each is follows Weather.hour, so a guest's town matches the
## host's with no messages). They walk the town's walk graph (Town: the paths, a ring round the plaza, the long
## stair, the upper lanes) between spots resolved by id (_spot: shop and stall counters and fronts, the plaza
## and its benches, the Salted Gull's bar, seats and fire, the upper town's doors, the quay, the stair).
## The town's sound and light (TownLife, brinehollow_town.gd): the market's murmur, the Gull's room, Haldor's
## hammer, paper lanterns strung across the market street (two lit from the light budget), a lantern post on the
## long stair, smoke from the new houses' chimneys ("Chimney" markers).

const Folk := preload("res://scripts/island/brinehollow_folk.gd")
const TownLife := preload("res://scripts/island/brinehollow_town.gd")
const RING_R := 9.5
const JOIN := 3.2
## The walk graph's reach from the plaza (the quay to the shrine terrace).
const REACH := 140.0
const BRIDGE := 9.0
const LANTERN_UP := 4.3


static func build(isl: StarterIsland) -> void:
	var life := TownLife.new()
	life.name = "TownLife"
	isl.add_child(life)
	var made: Array = []
	isl.kit.timed("life walks", func(): made.append(Town.new(isl)))
	isl.kit.timed("life people", func(): _people(isl, made[0]))
	isl.kit.timed("life lights", func(): _lights(isl, life))
	_sounds(isl, life)
	for m in isl.find_children("Chimney", "Marker3D", true, false):
		life.chimneys.append([m, null])


# --------------------------------------------------------------------------
# Sound and light
# --------------------------------------------------------------------------
static func _bed(life: TownLife, file: String, at: Vector3, kind: String, base_db: float, unit: float, reach: float) -> void:
	var p := AudioStreamPlayer3D.new()
	var s := (load("res://assets/audio/%s.wav" % file) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	# (in frames: the imported data is QOA-compressed, so its byte count says nothing)
	s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.stream = s
	p.unit_size = unit
	p.max_distance = reach
	p.bus = "Ambience"
	p.position = at
	life.add_child(p)
	life.beds.append([p, kind, base_db])


## A point `frac` of the way along a polyline.
static func _along(pl: PackedVector2Array, frac: float) -> Vector2:
	var cum := KitLife.measure(pl)
	return KitLife.sample(pl, cum, cum[cum.size() - 1] * frac)[0]


static func _sounds(isl: StarterIsland, life: TownLife) -> void:
	var kit := isl.kit
	for frac: float in [0.35, 0.7]:
		var q := _along(isl.paths[0], frac)
		_bed(life, "market_murmur_loop", Vector3(q.x, kit.hv(q) + 1.8, q.y), "day", -4.0, 7.0, 45.0)
	_bed(life, "market_murmur_loop", Vector3(StarterIsland.MARKET.x, kit.hv(StarterIsland.MARKET) + 1.8, StarterIsland.MARKET.y), "day", -8.0, 5.0, 35.0)
	var tav: Node3D = isl._tavern
	var tq := kit.local_point(tav, Vector3.ZERO)
	_bed(life, "tavern_room_loop", Vector3(tq.x, kit.marker_y(tav, "Barkeep") + 1.5, tq.y), "night", -2.0, 4.0, 26.0)
	var anvil := AudioStreamPlayer3D.new()
	var takes := AudioStreamRandomizer.new()
	takes.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	takes.random_pitch = 1.04
	for k in range(4):
		takes.add_stream(-1, load("res://assets/audio/anvil_%d.wav" % (k + 1)))
	anvil.stream = takes
	anvil.unit_size = 5.0
	anvil.max_distance = 60.0
	anvil.volume_db = -3.0
	anvil.bus = "SFX"
	var sq := kit.marker_point(isl._smithy, "Smith")
	anvil.position = Vector3(sq.x, kit.marker_y(isl._smithy, "Smith") + 1.0, sq.y)
	life.add_child(anvil)
	life.anvil = anvil


## Paper lanterns strung between the market street's shopfronts facing each other (a string from each one to the
## nearest across the street), glowing after dark; real light from the budget at the middle of the two longest;
## a lantern post by the long stair's middle landing, lit.
static func _lights(isl: StarterIsland, life: TownLife) -> void:
	var kit := isl.kit
	var road: PackedVector2Array = isl.paths[0]
	var fronts: Array = []
	for s: Node3D in isl.town_spots["shops"]:
		if not str(s.name).begins_with("Shop"):
			continue
		var c: Vector3 = (s.get_node("Customer") as Node3D).position
		var w := kit.local_point(s, Vector3(0, 0, c.z - 2.2))
		var near := road[0]
		for q in road:
			if q.distance_squared_to(w) < near.distance_squared_to(w):
				near = q
		fronts.append([w, near, s.position.y + LANTERN_UP])
	var strings: Array = []
	for i in range(fronts.size()):
		var best := -1
		for j in range(fronts.size()):
			var across: bool = (fronts[i][0] - fronts[i][1]).dot(fronts[j][0] - fronts[j][1]) < 0.0
			if across and fronts[i][0].distance_to(fronts[j][0]) < 18.0 and (best < 0 or fronts[i][0].distance_to(fronts[j][0]) < fronts[i][0].distance_to(fronts[best][0])):
				best = j
		if best >= 0 and not strings.any(func(p): return p == [best, i] or p == [i, best]):
			strings.append([i, best])
	var rope := MeshBuilder.new()
	var day := MeshBuilder.new()
	var night := MeshBuilder.new()
	var cord := PSXMat.lit("planks_dark")
	var cols := [Color(0.85, 0.3, 0.2), Color(0.95, 0.75, 0.4), Color(0.9, 0.55, 0.25)]
	var mids: Array = []
	for st in strings:
		var a: Array = fronts[st[0]]
		var b: Array = fronts[st[1]]
		var A := Vector3(a[0].x, a[2], a[0].y)
		var B := Vector3(b[0].x, b[2], b[0].y)
		var n := 8
		var prev := A
		for k in range(1, n + 1):
			var t := float(k) / n
			var q := A.lerp(B, t) - Vector3.UP * 0.7 * 4.0 * t * (1.0 - t)
			Buildings.beam_between(rope, cord, prev, q, 0.03)
			prev = q
		var count := int(A.distance_to(B) / 1.5)
		for k in range(1, count):
			var t := float(k) / count
			var q := A.lerp(B, t) - Vector3.UP * (0.7 * 4.0 * t * (1.0 - t) + 0.28)
			var col: Color = cols[(k + st[0]) % cols.size()]
			for mb_mat in [[day, PSXMat.lit("fabric", col)], [night, PSXMat.glow(col, 2.2)]]:
				(mb_mat[0] as MeshBuilder).add_cylinder(mb_mat[1], Transform3D(Basis(), q - Vector3.UP * 0.15), 0.13, 0.15, 0.3, 6, 1.0)
		mids.append([A.distance_to(B), A.lerp(B, 0.5) - Vector3.UP * 0.9])
	for mb_name in [[rope, "LanternCords"], [day, "LanternsDay"], [night, "LanternsNight"]]:
		var mi: MeshInstance3D = (mb_name[0] as MeshBuilder).to_instance(mb_name[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 160.0
		life.add_child(mi)
	life.lanterns_day = life.get_node("LanternsDay")
	life.lanterns_night = life.get_node("LanternsNight")
	life.lanterns_night.visible = false
	mids.sort_custom(func(x, y): return x[0] > y[0])
	for m in mids.slice(0, 2):
		KitLights.light(kit, life, m[1], 1.4, 9.0)
	# the long stair's middle landing: a newel post at its corner where the flight comes up, its arm over the landing
	var landing: Vector3 = isl.town_spots["stair"][3]
	var post := Props.lantern_post(2.6)
	kit.put(post, Vector3(landing.x + 1.35, landing.y, landing.z + 0.2), PI)
	KitLights.light(kit, post, Vector3(0.55, 2.0, 0.0), 1.4)
	life.stair_post = post


# --------------------------------------------------------------------------
# The walk graph and the town's floors
# --------------------------------------------------------------------------
class Town:
	extends RefCounted
	var isl: StarterIsland
	var graph := AStar2D.new()
	var stair: PackedVector3Array
	## [island -> local Transform3D, half extents Vector2, floor y]
	var floors: Array = []
	var ring_ids: Array = []
	var grid := {}
	var space: PhysicsDirectSpaceState3D

	func _init(island: StarterIsland) -> void:
		isl = island
		space = isl.get_world_3d().direct_space_state
		stair = isl.town_spots["stair"]
		var tav: Node3D = isl._tavern
		floors.append([tav.transform.affine_inverse(), Vector2(5.8, 4.3), isl.kit.marker_y(tav, "Barkeep")])
		var lines: Array = isl.paths.duplicate()
		lines.append_array(isl.town_spots["lanes"])
		var flat := PackedVector2Array()
		for q in stair:
			flat.append(Vector2(q.x, q.z))
		lines.append(flat)
		var ring := PackedVector2Array()
		for k in range(25):
			ring.append(StarterIsland.VILLAGE + Vector2.from_angle(TAU * k / 24.0) * RING_R)
		lines.append(ring)
		var owner := {}
		var edges: Array = []
		for li in range(lines.size()):
			var pts := _dense(lines[li])
			var prev := -1
			for q in pts:
				if q.distance_to(StarterIsland.VILLAGE) > REACH:
					prev = -1
					continue
				var id := graph.get_point_count()
				graph.add_point(id, q)
				owner[id] = li
				if li == lines.size() - 1:
					ring_ids.append(id)
				var cell := Vector2i(floori(q.x / JOIN), floori(q.y / JOIN))
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append(id)
				if prev >= 0:
					edges.append([prev, id])
				prev = id
		# lines that touch: points of different lines within JOIN of each other
		for cell in grid:
			for id in grid[cell]:
				var q := graph.get_point_position(id)
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						for o in grid.get(cell + Vector2i(dx, dz), []):
							if o > id and owner[o] != owner[id] and graph.get_point_position(o).distance_to(q) < JOIN:
								edges.append([id, o])
		# the ends that come into the plaza (and the stair's foot) onto the ring
		for li in range(lines.size() - 1):
			var pl: PackedVector2Array = lines[li]
			for q in [pl[0], pl[pl.size() - 1]]:
				if q.distance_to(StarterIsland.VILLAGE) < 25.0:
					edges.append([_nearest(q, owner, li), _ring_near(q)])
		# only where nothing's built in the way
		for e in edges:
			if clear(graph.get_point_position(e[0]), graph.get_point_position(e[1])):
				graph.connect_points(e[0], e[1])
		_bridge()

	## Pieces cut off by something standing on a path (a lamp at a path's end): joined to the rest at the
	## nearest clear step, up to BRIDGE m, until nothing more joins.
	func _bridge() -> void:
		while true:
			var comps := _components()
			var main: Array = comps[0]
			var in_main := {}
			for id in main:
				in_main[id] = true
			var joined := false
			for comp in comps.slice(1):
				var best := []
				for id in comp:
					var p := graph.get_point_position(id)
					var c := Vector2i(floori(p.x / JOIN), floori(p.y / JOIN))
					for dx in range(-3, 4):
						for dz in range(-3, 4):
							for o in grid.get(c + Vector2i(dx, dz), []):
								var d := graph.get_point_position(o).distance_to(p)
								if in_main.has(o) and d < BRIDGE and (best.is_empty() or d < best[2]) and clear(p, graph.get_point_position(o)):
									best = [id, o, d]
				if not best.is_empty():
					graph.connect_points(best[0], best[1])
					joined = true
			if not joined:
				return

	## The graph's connected pieces, biggest first.
	func _components() -> Array:
		var seen := {}
		var out: Array = []
		for id in range(graph.get_point_count()):
			if seen.has(id):
				continue
			var stack := [id]
			var comp: Array = []
			seen[id] = true
			while not stack.is_empty():
				var x: int = stack.pop_back()
				comp.append(x)
				for y in graph.get_point_connections(x):
					if not seen.has(y):
						seen[y] = true
						stack.append(y)
			out.append(comp)
		out.sort_custom(func(a, b): return a.size() > b.size())
		return out

	## Nothing built between a and b at waist height (rays against the island's colliders).
	func clear(a: Vector2, b: Vector2) -> bool:
		var ga := isl.to_global(Vector3(a.x, y_at(a, isl.hv(a)) + 0.9, a.y))
		var gb := isl.to_global(Vector3(b.x, y_at(b, isl.hv(b)) + 0.9, b.y))
		# (both ways: a ray starting inside a collider doesn't see it)
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(ga, gb)).is_empty() and space.intersect_ray(PhysicsRayQueryParameters3D.create(gb, ga)).is_empty()

	## Nothing built standing at p (waist height).
	func free_at(p: Vector2) -> bool:
		var q := PhysicsPointQueryParameters3D.new()
		q.position = isl.to_global(Vector3(p.x, y_at(p, isl.hv(p)) + 0.9, p.y))
		return space.intersect_point(q, 1).is_empty()

	## The graph point to step onto from p: the nearest one in clear sight (within 12 m), else the nearest.
	func entry(p: Vector2) -> int:
		var c := Vector2i(floori(p.x / JOIN), floori(p.y / JOIN))
		var near: Array = []
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				near.append_array(grid.get(c + Vector2i(dx, dz), []))
		near.sort_custom(func(x, y): return graph.get_point_position(x).distance_squared_to(p) < graph.get_point_position(y).distance_squared_to(p))
		for id in near:
			if graph.get_point_connections(id).size() > 0 and clear(p, graph.get_point_position(id)):
				return id
		return graph.get_closest_point(p)

	func _dense(pl: PackedVector2Array) -> PackedVector2Array:
		var out := PackedVector2Array([pl[0]])
		for i in range(1, pl.size()):
			var n := maxi(int(ceil(pl[i - 1].distance_to(pl[i]) / 2.5)), 1)
			for k in range(1, n + 1):
				out.append(pl[i - 1].lerp(pl[i], float(k) / n))
		return out

	func _nearest(q: Vector2, owner: Dictionary, li: int) -> int:
		var best := -1
		for id in owner:
			if owner[id] == li and (best < 0 or graph.get_point_position(id).distance_squared_to(q) < graph.get_point_position(best).distance_squared_to(q)):
				best = id
		return best

	func _ring_near(q: Vector2) -> int:
		var best: int = ring_ids[0]
		for id in ring_ids:
			if graph.get_point_position(id).distance_squared_to(q) < graph.get_point_position(best).distance_squared_to(q):
				best = id
		return best

	## The walk from island point a to b over the graph (a and b at its ends).
	func route(a: Vector2, b: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array([a])
		out.append_array(graph.get_point_path(entry(a), entry(b)))
		out.append(b)
		return out

	## The height of what's walked on at p: the long stair's treads, a building's floor, else `ground`.
	func y_at(p: Vector2, ground: float) -> float:
		if absf(p.x - StarterIsland.UP_X) < 1.6 and p.y > stair[0].z and p.y < stair[stair.size() - 1].z:
			for i in range(1, stair.size()):
				if p.y <= stair[i].z:
					return lerpf(stair[i - 1].y, stair[i].y, (p.y - stair[i - 1].z) / maxf(stair[i].z - stair[i - 1].z, 0.01))
		for f in floors:
			var l: Vector3 = f[0] * Vector3(p.x, 0, p.y)
			if absf(l.x) < f[1].x and absf(l.z) < f[1].y:
				return f[2]
		return ground


# --------------------------------------------------------------------------
# Spots: {"at", "face", "act", "kind", "lane" (island points from the spot out to the street), "y", "seat_y"}
# --------------------------------------------------------------------------
static func _named(list: Array, n: String) -> Node3D:
	for s in list:
		if s.name == n:
			return s
	push_error("BrinehollowLife: no %s in the town" % n)
	return null


static func _old_stall(isl: StarterIsland, i: int) -> Node3D:
	return [isl._stall_a, isl._stall_fish, isl._stall_cloth, isl._stall_pots][i]


static func _counter(isl: StarterIsland, n: String) -> Node3D:
	if n.begins_with("market"):
		return _old_stall(isl, int(n.substr(6)))
	if n.begins_with("Shop"):
		return _named(isl.town_spots["shops"], n)
	return _named(isl.town_spots["stalls"], n)


## Behind a counter, and the way round it to the front ("front": where a customer stands).
static func _at_counter(isl: StarterIsland, node: Node3D, front: bool) -> Dictionary:
	var kit := isl.kit
	var lp := func(v: Vector3) -> Vector2: return kit.local_point(node, v)
	var face := kit.marker_face(node, "Vendor")
	if node.has_node("Counter"):
		var v: Vector3 = (node.get_node("Vendor") as Node3D).position
		var c: Vector3 = (node.get_node("Customer") as Node3D).position
		var dx := float(node.get_node("Door").position.x)
		var out_x := v.x + signf(v.x - dx) * 1.45
		if front:
			return {"at": lp.call(c), "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(c + Vector3(0, 0, 1.2))])}
		return {"at": lp.call(v), "face": face, "act": "stand", "kind": "vendor",
			"lane": PackedVector2Array([lp.call(Vector3(out_x, 0, v.z)), lp.call(Vector3(out_x, 0, c.z)), lp.call(c + Vector3(0, 0, 1.2))])}
	# (the street's meshes are folded together: a rug's vendor sits on a stool, a barrow's stands by its handles)
	var rug: bool = node.has_node("Customer") and (node.get_node("Vendor") as Node3D).position.y > 0.2
	if node.has_node("Customer") and not rug:
		var c := lp.call(Vector3(0.1, 0, 1.4)) as Vector2
		if front:
			return {"at": c, "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(Vector3(0.1, 0, 2.6))])}
		return {"at": kit.marker_point(node, "Vendor"), "face": face, "act": "stand", "kind": "vendor",
			"lane": PackedVector2Array([c, lp.call(Vector3(0.1, 0, 2.6))])}
	if rug:
		if front:
			return {"at": lp.call(Vector3(0, 0, 1.3)), "face": kit.marker_face(node, "Customer"), "act": "stand", "kind": "front",
				"lane": PackedVector2Array([lp.call(Vector3(0, 0, 2.5))])}
		return {"at": kit.marker_point(node, "Vendor"), "face": lp.call(Vector3(0, 0, -1.2)).direction_to(lp.call(Vector3(0, 0, 1.0))), "act": "sit", "kind": "vendor",
			"seat_y": 0.42, "lane": PackedVector2Array([lp.call(Vector3(1.5, 0, -1.2)), lp.call(Vector3(1.5, 0, 1.3)), lp.call(Vector3(0, 0, 2.5))])}
	# a market stall: its counter along local X, the vendor behind
	var w := 3.2
	if front:
		return {"at": lp.call(Vector3(0, 0, 1.6)), "face": -face, "act": "stand", "kind": "front", "lane": PackedVector2Array([lp.call(Vector3(0, 0, 2.6))])}
	return {"at": kit.marker_point(node, "Vendor"), "face": face, "act": "stand", "kind": "vendor",
		"lane": PackedVector2Array([lp.call(Vector3(w * 0.5 + 0.7, 0, -0.75)), lp.call(Vector3(w * 0.5 + 0.7, 0, 1.6)), lp.call(Vector3(0, 0, 2.6))])}


## The Salted Gull inside (local): five places along the bar, eight free seats at the tables, two by the fire.
const BAR := [Vector3(2.5, 0, -1.1), Vector3(3.2, 0, -1.1), Vector3(3.9, 0, -1.1), Vector3(4.6, 0, -1.1), Vector3(5.3, 0, -1.1)]
const SEATS := [[Vector3(-2.15, 0, 2.25), -1.0], [Vector3(-2.95, 0, 0.55), 1.0], [Vector3(-2.15, 0, 0.55), 1.0],
	[Vector3(2.05, 0, 2.85), -1.0], [Vector3(1.25, 0, 1.15), 1.0], [Vector3(2.05, 0, 1.15), 1.0],
	[Vector3(-2.65, 0, -3.25), 1.0], [Vector3(-2.55, 0, -1.55), -1.0]]
const FIRE := [Vector3(-4.3, 0, 1.5), Vector3(-4.3, 0, -1.3)]


static func _in_tavern(isl: StarterIsland, what: String, i: int) -> Dictionary:
	var kit := isl.kit
	var tav: Node3D = isl._tavern
	var lp := func(v: Vector3) -> Vector2: return kit.local_point(tav, v)
	var y := kit.marker_y(tav, "Barkeep")
	var lane := PackedVector2Array([lp.call(Vector3(-0.5, 0, 0.0)), lp.call(Vector3(-1.6, 0, 3.4)), kit.marker_point(tav, "Door")])
	var out := {"y": y, "kind": "tavern", "act": "talk"}
	match what:
		"bar":
			var b: Vector3 = BAR[i]
			out.merge({"at": lp.call(b), "face": lp.call(b).direction_to(lp.call(b - Vector3(0, 0, 1)))})
		"seat":
			var s: Array = SEATS[i]
			var v: Vector3 = s[0]
			out.merge({"at": lp.call(v), "face": lp.call(v).direction_to(lp.call(v + Vector3(0, 0, float(s[1])))), "act": "sit"})
		_:
			var f: Vector3 = FIRE[i]
			out.merge({"at": lp.call(f), "face": lp.call(f).direction_to(lp.call(Vector3(-5.4, 0, 0)))})
	out["lane"] = lane
	return out


## Seats on the plaza's benches (two a bench, facing the well), in order round it.
static func _bench_seats(isl: StarterIsland) -> Array:
	var out: Array = []
	# (KitVillage.benches_round's, 5.5 m out: their names are the engine's once the first Bench is taken)
	for n in isl.find_children("*", "StaticBody3D", false, false):
		var c: Vector2 = isl.kit.local_point(n, Vector3.ZERO)
		if absf(c.distance_to(StarterIsland.VILLAGE) - 5.5) < 0.3:
			var along: Vector2 = isl.kit.local_point(n, Vector3.RIGHT) - c
			var face := c.direction_to(StarterIsland.VILLAGE)
			for s: float in [-0.45, 0.45]:
				out.append({"at": c + along * s, "face": face, "act": "sit", "kind": "plaza", "seat_y": 0.47, "lane": PackedVector2Array([c - face * 1.2])})
	return out


## Where `id` is ("vendor:Shop0", "front:market2", "bench:3", "plaza:7", "tavern:bar:1", "home:UpperHouse4", ...).
static func _spot(isl: StarterIsland, id: String, cache: Dictionary) -> Dictionary:
	var parts := id.split(":")
	var kit := isl.kit
	match parts[0]:
		"vendor", "front":
			return _at_counter(isl, _counter(isl, parts[1]), parts[0] == "front")
		"bench":
			if not cache.has("benches"):
				cache["benches"] = _bench_seats(isl)
			return cache["benches"][int(parts[1])]
		"plaza":
			# five knots of three round the well, between its benches and the ring
			var n := int(parts[1])
			var c := StarterIsland.VILLAGE + Vector2.from_angle(0.6 + (n / 3) * TAU / 5.0) * 7.6
			var at := c + Vector2.from_angle(n * 2.1) * 0.85
			return {"at": at, "face": at.direction_to(c), "act": "talk", "kind": "plaza", "lane": PackedVector2Array()}
		"tavern":
			return _in_tavern(isl, parts[1], int(parts[2]))
		"home":
			var h: Node3D = _named(isl.town_spots["houses"], parts[1])
			return {"at": kit.marker_point(h, "Door"), "face": kit.marker_face(h, "Door"), "act": "home", "kind": "home", "lane": PackedVector2Array()}
		"stair":
			# on a lane beside the stair's landing (off the flight)
			var q: Vector3 = isl.town_spots["stair"][1 + int(parts[1]) * 2]
			var at := Vector2(q.x + 3.4, q.z + 1.5)
			return {"at": at, "face": Vector2(0, -1), "act": "stand", "kind": "stair", "lane": PackedVector2Array()}
		"quay":
			if not cache.has("quay"):
				cache["quay"] = _quay_spots(isl, cache["town"])
			return cache["quay"][int(parts[1])]
	push_error("BrinehollowLife: no spot %s" % id)
	return {}


## Where the porters take up their loads on the quay: clear spots by the foot of the street.
static func _quay_spots(isl: StarterIsland, town: Town) -> Array:
	var h: KitHarbour = isl.harbour
	var out: Array = []
	for s: float in [-6.0, 7.0, -10.0, 11.0, -3.0, 4.0]:
		for d: float in [9.0, 10.5, 12.0, 7.5]:
			var p := h.quay_pt(s, d)
			if not isl.kit.excluded(p, 0.7, 4.0) and town.free_at(p) and out.all(func(o): return o["at"].distance_to(p) > 2.5):
				out.append({"at": p, "face": h.quay_pt(s, d - 3.0) - p, "act": "kneel", "kind": "quay", "lane": PackedVector2Array()})
				break
	return out


# --------------------------------------------------------------------------
# The people
# --------------------------------------------------------------------------
const AMBIENT := {
	"day": ["Lovely morning for it.", "Mind the cobbles, they're slick by the quay.", "Busy, busy.", "Have you tried Ida's hardtack? Don't."],
	"evening": ["Is it that late already?", "Gus'll have the stew on.", "The lamps are lit. Must be time for a drink."],
	"night": ["Shouldn't you be in bed?", "Quiet tonight.", "Hear that? Just the sea."],
	"vendor": ["Fresh today!", "Best prices on the street!", "Come and look, no charge for looking!", "Two for one, while it lasts!"],
	"front": ["Hmm. Too dear.", "I'll take two. No, one.", "Is this the same as yesterday's?"],
	"tavern": ["Another round!", "Gus! Gus. Gus, the jug.", "Sing it again, Corin!", "To Brinehollow!"],
	"plaza": ["Did you hear about the Morrow's men?", "Lovely day by the well.", "Tilly's been at the bunting again."],
	"quay": ["Heave!", "Mind your back.", "Last one. Said that an hour ago."],
	"stair": ["Race you to the top!", "Bet you can't jump three!"],
}


static func _people(isl: StarterIsland, town: Town) -> void:
	var cache := {"town": town}
	for e in BrinehollowCast.townsfolk():
		var stays: Array = []
		for p in e["plan"]:
			var sp: Dictionary = _spot(isl, str(p[1]), cache)
			var st := {"h": float(p[0]), "kind": sp["kind"], "at": sp["at"], "face": (sp["face"] as Vector2).normalized(),
				"act": str(p[2]) if p.size() > 2 else str(sp["act"]), "lane": sp["lane"]}
			for k in ["y", "seat_y"]:
				if sp.has(k):
					st[k] = sp[k]
			if p.size() > 3:
				st["carry"] = p[3]
			stays.append(st)
		var walks: Array = []
		for k in range(stays.size()):
			var a: Dictionary = stays[k - 1]
			var b: Dictionary = stays[k]
			var w := PackedVector2Array([a["at"]])
			w.append_array(a["lane"])
			var back: PackedVector2Array = b["lane"].duplicate()
			back.reverse()
			w.append_array(town.route(w[w.size() - 1], back[0] if not back.is_empty() else b["at"]).slice(1))
			if not back.is_empty():
				w.append_array(back.slice(1))
				w.append(b["at"])
			walks.append(w)
		var cfg: Dictionary = e["cfg"]
		var f := Folk.new()
		f.setup(cfg)
		f.town = town
		f.follow(isl, stays, walks, AMBIENT)
		if e.get("carry", false):
			f.load_node = _sack()
			f.humanoid.torso.add_child(f.load_node)
		var first: Dictionary = stays[0]
		f.position = Vector3(first["at"].x, isl.hv(first["at"]), first["at"].y)
		isl.add_child(f)


## A sack on the left shoulder (the torso's space).
static func _sack() -> Node3D:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	mb.add_blob(PSXMat.lit("fabric", Color(0.78, 0.68, 0.5)), Transform3D(Basis(Vector3.BACK, 0.3), Vector3.ZERO), Vector3(0.36, 0.22, 0.24), rng, 0.12, 2, 6, 1.0)
	var mi := mb.to_instance("Load")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-0.2, 0.62, 0.02)
	mi.visible = false
	return mi
