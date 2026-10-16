class_name KitDungeons
extends RefCounted
## A generated island's interiors: one to three caves from the pool (no kind
## twice), and the ruined temple (KitTemple) on some. Each sits in its own spot well clear of
## the village, the dock and the sites, with a path from the paths to its mouth.
## plan() works it all out as data in GenIsland.prepare (a worker): where, the
## rooms and tunnels, the rock's mesh and collider faces (CaveMesher). steps()
## puts each in the world a few frames at a time; a Dungeon node runs it there.
## GenIsland.interiors is the island's POI data too (see `poi`).
##   bug_tunnels      - burrows, egg sacs and glowing fungus, spitters hanging from
##                      the roof, the brood mother in the last chamber (her hoard
##                      once per captain)
##   smugglers_grotto - a crew among their contraband, their boss and his stash at the end
##   flooded_ruin     - drowned halls of an older people: bugs in the water,
##                      scavengers and their chief at the altar with what they dug up
##   root_cavern      - under a giant tree whose roots come down through the rock;
##                      bugs and spitters in the roots, a nest of big ones at the end
##   bat_roost        - tall chambers, guano, things hanging from the roof (spitters
##                      for now: the roof slots are the fauna's bats)
##   sunken_shrine    - a small drowned shrine, an idol over still water, divers looting it
##   beast_den        - bones and a nest of branches; big bugs hold it until a beast
##                      (the end room's boss slot) moves in
## Each plan's rooms carry free "slots" (floor points, roof points) and the plan a
## "boss_slot", all in island space, for creatures and minibosses placed later.

const POOL := ["bug_tunnels", "smugglers_grotto", "flooded_ruin", "root_cavern", "bat_roost", "sunken_shrine", "beast_den"]
## How many caves an island gets: 1, 2 or 3 (the extras only where they fit).
const COUNT_WEIGHTS := [0.5, 0.38, 0.12]
const TEMPLE_CHANCE := 0.4
## Tools and tests set this to plan the temple on every island built after (where it fits).
static var force_temple := false
## Who holds the end room: the brood mother, a named captain and his crew, or a nest of big bugs.
const BOSS := {"bug_tunnels": "queen", "smugglers_grotto": "captain", "flooded_ruin": "captain", "sunken_shrine": "captain",
	"root_cavern": "nest", "bat_roost": "nest", "beast_den": "nest"}
const CELL := 1.5
## How far a cave's middle keeps from each site (m, plus its own radius / 2).
const KEEP := {"village": 105.0, "dock": 90.0, "camp": 55.0, "lair": 50.0, "ruins": 45.0, "boss": 65.0, "summit": 35.0}
## Rooms in order in [radius min, max, height]; a side room off the second; tunnels.
const SHAPES := {
	"bug_tunnels": {"rooms": [[6.5, 7.5, 6.0], [8.0, 9.0, 7.0], [12.0, 12.5, 9.0]], "side": [5.5, 6.5, 5.5], "side_chance": 0.75,
		"w": 2.3, "h": 4.2, "len": [6.0, 10.0]},
	"smugglers_grotto": {"rooms": [[6.5, 7.5, 6.0], [8.5, 9.5, 7.0], [9.0, 10.0, 7.5]], "side": [5.5, 6.5, 5.5], "side_chance": 0.85,
		"w": 2.6, "h": 4.6, "len": [5.0, 9.0]},
	"flooded_ruin": {"rooms": [[7.0, 8.0, 6.5], [9.0, 10.0, 8.0], [9.0, 10.0, 8.0]], "side": [6.0, 7.0, 6.0], "side_chance": 0.6,
		"w": 2.7, "h": 4.8, "len": [6.0, 10.0]},
	"root_cavern": {"rooms": [[8.0, 9.0, 7.5], [10.0, 11.5, 9.5]], "side": [6.0, 7.0, 6.0], "side_chance": 0.5,
		"w": 2.6, "h": 4.8, "len": [5.0, 8.0]},
	"bat_roost": {"rooms": [[7.0, 8.0, 10.0], [9.0, 10.0, 13.0], [8.0, 9.0, 11.0]], "side": [6.0, 7.0, 9.0], "side_chance": 0.4,
		"w": 2.4, "h": 5.0, "len": [5.0, 9.0]},
	"sunken_shrine": {"rooms": [[7.0, 8.0, 6.5], [8.0, 9.0, 7.5]], "side": [5.5, 6.5, 6.0], "side_chance": 0.3,
		"w": 2.6, "h": 4.6, "len": [5.0, 8.0]},
	"beast_den": {"rooms": [[7.0, 8.0, 6.0], [11.0, 12.0, 8.0]], "side": [5.5, 6.5, 5.5], "side_chance": 0.35,
		"w": 2.9, "h": 5.0, "len": [5.0, 8.0]},
}
## A chance of one more middle room before the end (2-room kinds grow to 3, 3 to 4).
const EXTRA_ROOM := 0.35
const TITLES := {
	"bug_tunnels": [["The Chittering Deep", "Something skitters in the dark"], ["The Brood Warren", "The walls are crawling"],
		["Gnawbone Hollow", "Bones and burrows"]],
	"smugglers_grotto": [["Smugglers' Grotto", "Contraband, and the cutthroats guarding it"], ["The Rumrunners' Hole", "Lanterns, crates and knives"],
		["Blackwick's Cache", "A smuggler's hidden stash"]],
	"flooded_ruin": [["The Drowned Vault", "Halls of an older people, half under water"], ["The Sunken Halls", "Water drips on carved stone"],
		["Tidewater Crypt", "Someone's digging down here"]],
	"root_cavern": [["The Rootdeep", "Roots as thick as masts through the rock"], ["Under the Old Tree", "Something lives among the roots"],
		["The Tanglehollow", "The tree above drinks from down here"]],
	"bat_roost": [["The Roost", "Wings in the dark, and the smell"], ["Shriekhollow", "The roof moves"],
		["The Guano Caves", "Mind your step"]],
	"sunken_shrine": [["The Sunken Shrine", "A drowned god's house"], ["The Idol's Pool", "Someone left offerings here"],
		["The Still Water Shrine", "The water hasn't moved in centuries"]],
	"beast_den": [["The Den", "Gnawed bones at the door"], ["The Lair of Bones", "Whatever lives here eats well"],
		["Clawmark Cave", "Fresh marks on the stone"]],
	"temple": [["The Temple of the Coiled Serpent", "Old stone, older gods"], ["The Jade Sanctum", "Something still keeps watch"],
		["The Temple of Tides", "The jungle has nearly swallowed it"]],
}
## Surfaces: [texture, tint]; the light inside.
const LOOK := {
	"bug_tunnels": {"rock": ["rock", Color(0.64, 0.6, 0.55)], "moss": ["rock", Color(0.55, 0.66, 0.45)], "turf": ["grass", Color(0.9, 1.0, 0.88)],
		"wall": ["rock", Color(0.62, 0.6, 0.56)], "floor": ["dirt", Color(0.9, 0.8, 0.66)], "light": Color(0.62, 1.0, 0.82), "energy": 1.6},
	"smugglers_grotto": {"rock": ["rock", Color(0.7, 0.66, 0.6)], "moss": ["rock", Color(0.6, 0.66, 0.48)], "turf": ["grass", Color(0.92, 1.0, 0.86)],
		"wall": ["rock", Color(0.6, 0.55, 0.5)], "floor": ["sand", Color(0.74, 0.68, 0.58)], "light": Color(1.0, 0.72, 0.4)},
	"flooded_ruin": {"rock": ["rock", Color(0.6, 0.66, 0.62)], "moss": ["rock", Color(0.5, 0.64, 0.48)], "turf": ["grass", Color(0.86, 1.0, 0.86)],
		"wall": ["stone_brick", Color(0.5, 0.58, 0.55)], "floor": ["cobbles", Color(0.56, 0.64, 0.6)], "light": Color(0.45, 0.82, 0.95)},
	"root_cavern": {"rock": ["rock", Color(0.6, 0.58, 0.5)], "moss": ["rock", Color(0.5, 0.66, 0.42)], "turf": ["grass", Color(0.88, 1.0, 0.84)],
		"wall": ["rock", Color(0.6, 0.54, 0.46)], "floor": ["dirt", Color(0.85, 0.74, 0.6)], "light": Color(0.75, 1.0, 0.55), "energy": 1.4},
	"bat_roost": {"rock": ["rock", Color(0.62, 0.6, 0.58)], "moss": ["rock", Color(0.56, 0.64, 0.48)], "turf": ["grass", Color(0.9, 1.0, 0.88)],
		"wall": ["rock", Color(0.64, 0.62, 0.6)], "floor": ["dirt", Color(0.9, 0.86, 0.74)], "light": Color(0.8, 0.82, 1.0), "energy": 1.9},
	"sunken_shrine": {"rock": ["rock", Color(0.6, 0.66, 0.62)], "moss": ["rock", Color(0.48, 0.66, 0.5)], "turf": ["grass", Color(0.86, 1.0, 0.86)],
		"wall": ["stone_brick", Color(0.52, 0.6, 0.62)], "floor": ["cobbles", Color(0.58, 0.66, 0.66)], "light": Color(0.5, 0.95, 0.9)},
	"beast_den": {"rock": ["rock", Color(0.64, 0.6, 0.55)], "moss": ["rock", Color(0.55, 0.64, 0.45)], "turf": ["grass", Color(0.9, 1.0, 0.86)],
		"wall": ["rock", Color(0.62, 0.56, 0.5)], "floor": ["dirt", Color(0.86, 0.74, 0.6)], "light": Color(1.0, 0.7, 0.45), "energy": 1.3},
}
const LIGHTS := 3


# ==========================================================================
# The plan (data: GenIsland.prepare, a worker thread)
# ==========================================================================
static func plan(isl: GenIsland) -> Array:
	var t0 := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), 7177])
	var out: Array = []
	var kinds := POOL.duplicate()
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var roll := rng.randf()
	var count := 1 if roll < COUNT_WEIGHTS[0] else (2 if roll < COUNT_WEIGHTS[0] + COUNT_WEIGHTS[1] else 3)
	for kind in kinds:
		if out.size() >= count:
			break
		var cave := _plan_cave(isl, rng, kind, out)
		if not cave.is_empty():
			out.append(cave)
	if out.is_empty():
		push_error("KitDungeons: no room for a cave on %s (seed %d)" % [isl.node["name"], int(isl.node["seed"])])
	if force_temple or rng.randf() < TEMPLE_CHANCE:
		var tp := KitTemple.plan(isl, rng, out)
		if not tp.is_empty():
			out.append(tp)
	isl.build_ms["dungeon_plan"] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


## What a district planner, a quest or a creature placer needs of an interior (island
## space): its rooms as chambers [{role, c, y, r, h, slots {floor, roof}}], the end
## room's boss slot, who holds it now (`boss`), and the node its enemies go under
## (`enemies`, a path from the island: what's there sleeps with the dungeon).
static func poi(e: Dictionary) -> Dictionary:
	var chambers: Array = []
	for r in e["rooms"]:
		chambers.append({"role": r["role"], "c": r["c"], "y": r["y"], "r": r["r"], "h": r["h"], "slots": r["slots"]})
	return {"kind": e["kind"], "name": e["name"], "title": e["title"], "at": e["at"], "radius": e["radius"],
		"mouth": e["mouth"], "mouth_dir": e["mouth_dir"], "level": e["level"], "reward": e["reward"], "flag": e["flag"],
		"chambers": chambers, "boss_slot": e["boss_slot"], "boss": e["boss"], "enemies": "%s/Enemies" % e["name"]}


static func _plan_cave(isl: GenIsland, rng: RandomNumberGenerator, kind: String, taken: Array) -> Dictionary:
	var spec: Dictionary = SHAPES[kind]
	for relax in [1.0, 0.8, 0.62]:
		for attempt in range(45):
			var c := Vector2.from_angle(rng.randf() * TAU) * isl.radius * rng.randf_range(0.18, 0.7)
			if not site_clear(isl, c, 30.0, relax, taken):
				continue
			var lay := _layout(isl, rng, spec, c)
			if lay.is_empty() or not _fits(isl, lay, relax, taken):
				continue
			return _finish_cave(isl, rng, kind, lay, taken.size())
	return {}


## Far enough from every site and from the interiors planned so far.
static func site_clear(isl: GenIsland, c: Vector2, r: float, relax: float, taken: Array) -> bool:
	for s in KEEP.keys():
		if c.distance_to(isl.sites[s]) < float(KEEP[s]) * relax + r * 0.5:
			return false
	for e in taken:
		if c.distance_to(e["at"]) < float(e["radius"]) + r + 25.0:
			return false
	return true


## On dry land, off the paths and the sites' ground, all round a disk.
static func land_clear(isl: GenIsland, c: Vector2, r: float, path_pad: float) -> bool:
	for ring in [[0.0, 1], [0.5, 8], [1.0, 14]]:
		for i in range(int(ring[1])):
			var q := c + Vector2.from_angle(TAU * i / float(ring[1])) * r * float(ring[0])
			if isl.hv(q) < 1.4 or isl.path_dist(q) < path_pad or isl.excluded(q, 1.0):
				return false
	return true


## The highest ground under a disk (its middle, half way out and its edge).
static func top(isl: GenIsland, c: Vector2, r: float) -> float:
	var m := isl.hv(c)
	for i in range(8):
		m = maxf(m, isl.hv(c + Vector2.from_angle(TAU * i / 8.0) * r * 0.5))
	for i in range(12):
		m = maxf(m, isl.hv(c + Vector2.from_angle(TAU * i / 12.0) * r))
	return m


static func low(isl: GenIsland, c: Vector2, r: float) -> float:
	var m := isl.hv(c)
	for i in range(12):
		m = minf(m, isl.hv(c + Vector2.from_angle(TAU * i / 12.0) * r))
	return m


static func _layout(isl: GenIsland, rng: RandomNumberGenerator, spec: Dictionary, c: Vector2) -> Dictionary:
	var rs: Array = (spec["rooms"] as Array).duplicate()
	if rng.randf() < EXTRA_ROOM:
		rs.insert(rs.size() - 1, rs[mini(1, rs.size() - 2)] if rs.size() > 2 else rs[0])
	var w: float = spec["w"]
	var r0 := rng.randf_range(rs[0][0], rs[0][1])
	var y0 := top(isl, c, r0 + 1.5) + 0.35
	var rooms: Array = [{"c": c, "y": y0, "r": r0, "h": float(rs[0][2]), "role": "entry", "doors": []}]
	var tunnels: Array = []
	# the mouth: facing the village give or take, where the ground outside meets the first room's floor
	var base: float = (isl.sites["village"] - c).angle()
	var out := Vector2.ZERO
	var best := 0.7
	for k in range(9):
		var d := Vector2.from_angle(base + (k - 4) * 0.3)
		var m := c + d * (r0 + CaveMesher.T + 1.0)
		if isl.hv(m) < 1.6:
			continue
		# (a theme's own land can be steep: a mouth whose floor stands over the ground in it or below it can't be walked into)
		if not isl.land_plan.is_empty() and minf(isl.hv(m), isl.hv(m + d * 4.0)) < top(isl, m, w + 0.5) - 0.45:
			continue
		var score := absf(top(isl, m, w * 0.7) - y0) / (CaveMesher.T + 2.5) + absf(k - 4) * 0.08
		if score < best:
			best = score
			out = d
	if out == Vector2.ZERO:
		return {}
	var mouth := c + out * (r0 + CaveMesher.T + 1.0)
	var ent := _tunnel(isl, c + out * (r0 - 1.5), y0, mouth, top(isl, mouth, w * 0.7) + 0.05, w, spec["h"])
	if ent.is_empty():
		return {}
	ent["pts"].append(mouth + out * 3.5)
	ent["ys"].append(ent["ys"][ent["ys"].size() - 1])
	ent["mouth"] = true
	tunnels.append(ent)
	rooms[0]["doors"].append(c + out * (r0 - 1.5))
	# the rooms on in, each off the last
	var dir := -out
	var into_second := dir
	for i in range(1, rs.size()):
		var room := _next_room(isl, rng, rooms, tunnels, rooms[i - 1], dir, rs[i], spec, "end" if i == rs.size() - 1 else "mid")
		if room.is_empty():
			return {}
		dir = (room["c"] - rooms[i - 1]["c"]).normalized()
		if i == 1:
			into_second = dir
		rooms.append(room)
	if rng.randf() < float(spec["side_chance"]):
		var side_dir := into_second.rotated((1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.3, 1.8))
		var side := _next_room(isl, rng, rooms, tunnels, rooms[1], side_dir, spec["side"], spec, "side")
		if not side.is_empty():
			rooms.append(side)
	return {"rooms": rooms, "tunnels": tunnels, "mouth": mouth, "out": out, "mouth_y": float(ent["ys"][ent["ys"].size() - 1])}


static func _next_room(isl: GenIsland, rng: RandomNumberGenerator, rooms: Array, tunnels: Array, from: Dictionary, dir: Vector2, rs: Array, spec: Dictionary, role: String) -> Dictionary:
	var w: float = spec["w"]
	for k in range(10):
		var r := rng.randf_range(rs[0], rs[1])
		var d := dir.rotated(rng.randf_range(-0.75, 0.75))
		var c: Vector2 = from["c"] + d * (float(from["r"]) + r + rng.randf_range(spec["len"][0], spec["len"][1]))
		if isl.hv(c) < 2.0:
			continue
		var clear := true
		for o in rooms:
			if o != from and c.distance_to(o["c"]) < float(o["r"]) + r + 6.0:
				clear = false
		for t in tunnels:
			for q in t["pts"]:
				if (q as Vector2).distance_to(c) < r + w + 3.0:
					clear = false
		if not clear:
			continue
		var y := top(isl, c, r + 1.5) + 0.35
		var a: Vector2 = from["c"] + d * (float(from["r"]) - 1.0)
		var b := c - d * (r - 1.0)
		var tun := _tunnel(isl, a, from["y"], b, y, w, spec["h"])
		if tun.is_empty():
			continue
		from["doors"].append(a)
		tunnels.append(tun)
		return {"c": c, "y": y, "r": r, "h": float(rs[2]), "role": role, "doors": [b]}
	return {}


## A tunnel from a to b in 4 m steps, its floor over the ground all the way; none if it's too steep.
static func _tunnel(isl: GenIsland, a: Vector2, ya: float, b: Vector2, yb: float, w: float, h: float) -> Dictionary:
	var pts: Array = [a]
	var ys: Array = [ya]
	var n := maxi(2, int(a.distance_to(b) / 4.0))
	for i in range(1, n):
		var t := float(i) / n
		var q := a.lerp(b, t)
		pts.append(q)
		ys.append(maxf(lerpf(ya, yb, t), top(isl, q, w + 0.5) + 0.3))
	pts.append(b)
	ys.append(yb)
	for i in range(pts.size() - 1):
		if absf(float(ys[i + 1]) - float(ys[i])) > 0.6 * (pts[i] as Vector2).distance_to(pts[i + 1]):
			return {}
	return {"pts": pts, "ys": ys, "w": w, "h": h, "mouth": false}


static func _fits(isl: GenIsland, lay: Dictionary, relax: float, taken: Array) -> bool:
	for r in lay["rooms"]:
		var rr: float = float(r["r"]) + CaveMesher.T + 2.0
		if not land_clear(isl, r["c"], rr, 2.0) or not site_clear(isl, r["c"], rr, relax, taken):
			return false
	for t in lay["tunnels"]:
		if t["mouth"]:
			continue
		for q in t["pts"]:
			if isl.hv(q) < 1.4 or isl.path_dist(q) < float(t["w"]) + CaveMesher.T or isl.excluded(q, 1.0):
				return false
	return true


static func _finish_cave(isl: GenIsland, rng: RandomNumberGenerator, kind: String, lay: Dictionary, idx: int) -> Dictionary:
	var rooms: Array = lay["rooms"]
	var tunnels: Array = lay["tunnels"]
	var at := Vector2.ZERO
	for r in rooms:
		at += r["c"]
	at /= rooms.size()
	var radius := 0.0
	var lo := INF
	for r in rooms:
		radius = maxf(radius, at.distance_to(r["c"]) + float(r["r"]) + CaveMesher.T + 2.0)
		lo = minf(lo, low(isl, r["c"], float(r["r"]) + CaveMesher.T + 3.0))
	for t in tunnels:
		for q in t["pts"]:
			lo = minf(lo, isl.hv(q) - 1.0)
	# shapes in the cave's own space (its origin over `at` at sea level)
	var mr: Array = []
	for r in rooms:
		mr.append([r["c"].x - at.x, r["c"].y - at.y, r["y"], r["r"], r["h"]])
	var ms: Array = []
	for t in tunnels:
		var pts: Array = t["pts"]
		for i in range(pts.size() - 1):
			ms.append([pts[i].x - at.x, pts[i].y - at.y, t["ys"][i], pts[i + 1].x - at.x, pts[i + 1].y - at.y, t["ys"][i + 1],
				t["w"], t["h"], 0.0 if t["mouth"] else 1.0])
	var seed_value := rng.randi()
	var mesher := CaveMesher.make(mr, ms, seed_value)
	var mesh := mesher.mesh(CELL, lo - 2.0)
	# where the roof is over the floor, for things hanging from it
	for r in rooms:
		var hang: Array = []
		for k in range(12):
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * sqrt(rng.randf()) * 0.8
			var lx: float = q.x - at.x
			var lz: float = q.y - at.y
			hang.append(Vector3(lx, mesher.ceiling(lx, lz, r["y"]), lz))
		r["hang"] = hang
		# and where the walls are, off the doorways, for what's fixed to them
		var walls: Array = []
		var doors: Array = r["doors"].map(func(dp): return (dp - r["c"]).angle())
		for k in range(14):
			var a := rng.randf() * TAU
			if doors.any(func(da): return absf(angle_difference(a, da)) < 0.45):
				continue
			var hit := mesher.wall(r["c"].x - at.x, r["c"].y - at.y, float(r["y"]) + rng.randf_range(0.6, 2.8), a, float(r["r"]) * 1.6)
			if not hit.is_empty():
				walls.append(hit)
		r["walls"] = walls
		# free slots for creatures placed later (island space): floor points off the doors, roof points high enough to hang from
		var floor_slots: Array = []
		for k in range(24):
			if floor_slots.size() >= 4:
				break
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * rng.randf_range(0.3, 0.75)
			if r["doors"].any(func(dp): return q.distance_to(dp) < 3.2) or floor_slots.any(func(s): return Vector2(s.x, s.z).distance_to(q) < 2.5):
				continue
			floor_slots.append(Vector3(q.x, r["y"], q.y))
		var roof_slots: Array = []
		for hp in hang:
			if (hp as Vector3).y - float(r["y"]) >= 5.0:
				roof_slots.append(Vector3(hp.x + at.x, hp.y - 0.4, hp.z + at.y))
		r["slots"] = {"floor": floor_slots, "roof": roof_slots}
	# kept clear of trees and rocks, a path to the mouth
	for r in rooms:
		isl.reserve_area(r["c"], float(r["r"]) + CaveMesher.T + 1.5)
	for t in tunnels:
		for q in t["pts"]:
			isl.reserve(q, float(t["w"]) + CaveMesher.T)
	var mouth: Vector2 = lay["mouth"]
	var out: Vector2 = lay["out"]
	isl.reserve(mouth + out * 3.0, 4.0)
	path_to(isl, rng, mouth + out * 3.5)
	var pick: Array = TITLES[kind][rng.randi() % TITLES[kind].size()]
	var name := "Dungeon%d" % idx
	var end := {}
	for r in rooms:
		if r["role"] == "end":
			end = r
	var away: Vector2 = (end["c"] - end["doors"][0]).normalized()
	var bs: Vector2 = end["c"] + away * float(end["r"]) * 0.45
	return {"kind": kind, "name": name, "title": pick[0], "subtitle": pick[1], "at": at, "radius": radius,
		"boss": BOSS[kind], "boss_slot": Vector3(bs.x, end["y"], bs.y),
		"mouth": mouth, "mouth_dir": out, "mouth_y": lay["mouth_y"], "rooms": rooms, "tunnels": tunnels, "mesh": mesh,
		"seed": seed_value, "level": int(isl.node["level"]), "reward": isl.save_key(name.to_lower() + "_hoard"),
		"flag": isl.save_key(name.to_lower() + "_cleared")}


## A path from `p` to the nearest path, if it's more than a few steps off.
static func path_to(isl: GenIsland, rng: RandomNumberGenerator, p: Vector2) -> void:
	var best := Vector2.ZERO
	var best_d := INF
	for pts in isl.paths:
		var line: PackedVector2Array = pts
		for i in range(line.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
			if q.distance_to(p) < best_d:
				best_d = q.distance_to(p)
				best = q
	if best_d < 8.0:
		return
	var d := best - p
	var mid := p + d * 0.5 + Vector2(-d.y, d.x).normalized() * rng.randf_range(-0.15, 0.15) * best_d
	isl._add_path([p, mid, best], 1.1)


# ==========================================================================
# Putting them in the world (GenIsland.finish_steps, main thread)
# ==========================================================================
static func steps(isl: GenIsland) -> Array:
	var out: Array = []
	for e in isl.interiors:
		if e["kind"] == "temple":
			out.append(["temple", func(): KitTemple.build(isl, e)])
			out.append(["temple", func(): KitTemple.populate(isl, e)])
		else:
			# (a frame each; the dressing's passes share one rng and mesh, in the order one call made them)
			var w := {}
			out.append(["dungeons", func(): _shell(isl, e)])
			out.append(["dungeons", func(): _rock_collider(isl, e)])
			out.append(["dungeons", func(): _dress_start(isl, e, w)])
			out.append(["dungeons", func(): _dress_kind(e, w)])
			out.append(["dungeons", func(): _dress_walls(e, w)])
			out.append(["dungeons", func(): _dress_outside(isl, e, w)])
			out.append(["dungeons", func(): _populate(isl, e)])
	return out


## Island point p at height y in the dungeon's own space.
static func loc(e: Dictionary, p: Vector2, y: float) -> Vector3:
	return Vector3(p.x - e["at"].x, y, p.y - e["at"].y)


static func _shell(isl: GenIsland, e: Dictionary) -> void:
	var d := Dungeon.new()
	d.name = e["name"]
	d.isl = isl
	d.info = e
	d.position = Vector3(e["at"].x, 0.0, e["at"].y)
	var m: Dictionary = e["mesh"]
	var look: Dictionary = (LOOK[e["kind"]] as Dictionary).merged(KitStyle.of(isl.theme)["cave_look"], true)
	var body := StaticBody3D.new()
	body.name = "Rock"
	body.collision_layer = 1
	body.collision_mask = 0
	var outside := MeshInstance3D.new()
	outside.name = "Outside"
	outside.mesh = _surfaces(m["surfaces"], ["rock", "moss", "turf"], look)
	body.add_child(outside)
	var inside := MeshInstance3D.new()
	inside.name = "Inside"
	inside.mesh = _surfaces(m["surfaces"], ["wall", "floor"], look)
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside.visibility_range_end = float(e["radius"]) + 90.0
	body.add_child(inside)
	d.add_child(body)
	isl.add_child(d)


static func _rock_collider(isl: GenIsland, e: Dictionary) -> void:
	var m: Dictionary = e["mesh"]
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(m["faces"])
	cs.shape = shape
	isl.get_node(str(e["name"])).get_node("Rock").add_child(cs)
	# (the mesh is in the world now; the plan keeps only what's needed to find things)
	e["ledges"] = m["ledges"]
	e.erase("mesh")


static func _surfaces(surfs: Dictionary, keys: Array, look: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in keys:
		if not surfs.has(key):
			continue
		var s: Dictionary = surfs[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s["v"]
		arrays[Mesh.ARRAY_NORMAL] = s["n"]
		arrays[Mesh.ARRAY_TEX_UV] = s["uv"]
		arrays[Mesh.ARRAY_COLOR] = s["c"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, PSXMat.lit(look[key][0], look[key][1], {"affine": 0.6}))
	return mesh


# ==========================================================================
# Dressing
# ==========================================================================
## Floor spots in a room: a ring between rmin and rmax of its radius, `gap` from
## each other and from what's `used`, off its doors and the middle.
static func spots(e: Dictionary, room: Dictionary, rng: RandomNumberGenerator, n: int, rmin: float, rmax: float, gap: float, used: Array) -> Array:
	var out: Array = []
	var r: float = room["r"]
	for k in range(n * 12):
		if out.size() >= n:
			break
		var q: Vector2 = room["c"] + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(rmin, rmax)
		var ok := true
		for dp in room["doors"]:
			if q.distance_to(dp) < 3.2:
				ok = false
		var p := loc(e, q, room["y"])
		for u in used:
			if Vector2(p.x, p.z).distance_to(Vector2(u.x, u.z)) < gap:
				ok = false
		if ok:
			out.append(p)
			used.append(p)
	return out


static func room_of(e: Dictionary, role: String) -> Dictionary:
	for r in e["rooms"]:
		if r["role"] == role:
			return r
	return {}


## The local direction from p to the room's middle.
static func inward(e: Dictionary, room: Dictionary, p: Vector3) -> Vector3:
	var c := loc(e, room["c"], room["y"])
	return Vector3(c.x - p.x, 0.0, c.z - p.z).normalized()


## The dressing in four steps sharing `w` (d, rng, mb, clutter, used): dripstone, the kind's own, the walls, outside and lights.
static func _dress_start(isl: GenIsland, e: Dictionary, w: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e["seed"]) + 101
	var clutter := StaticBody3D.new()
	clutter.name = "Clutter"
	clutter.collision_layer = 1
	clutter.collision_mask = 0
	var used: Array = []
	for r in e["rooms"]:
		used.append(loc(e, r["c"], r["y"]))
	var d: Dungeon = isl.get_node(str(e["name"]))
	d.add_child(clutter)
	var frost: bool = KitStyle.of(isl.theme)["cave_frost"]
	w.merge({"d": d, "rng": rng, "mb": MeshBuilder.new(), "clutter": clutter, "used": used, "frost": frost})
	_dripstone_pass(e, w["mb"], clutter, rng, used, frost)


static func _dress_kind(e: Dictionary, w: Dictionary) -> void:
	var d: Dungeon = w["d"]
	var mb: MeshBuilder = w["mb"]
	var clutter: StaticBody3D = w["clutter"]
	var rng: RandomNumberGenerator = w["rng"]
	var used: Array = w["used"]
	match str(e["kind"]):
		"bug_tunnels":
			_dress_bugs(e, d, mb, rng, used, true)
		"root_cavern":
			_dress_bugs(e, d, mb, rng, used, false)
			_roots(e, mb, clutter, rng)
		"bat_roost":
			_dress_roost(e, mb, rng, used)
		"beast_den":
			_dress_den(e, mb, rng, used)
		"smugglers_grotto":
			_dress_grotto(e, d, mb, clutter, rng, used)
		"flooded_ruin", "sunken_shrine":
			_dress_ruin(e, d, mb, clutter, rng, used)
	if w["frost"]:
		_frost(e, mb, clutter, rng, used)


static func _dress_walls(e: Dictionary, w: Dictionary) -> void:
	var mb: MeshBuilder = w["mb"]
	_walls(e, mb, w["rng"])
	var inside := mb.to_instance("Dressing")
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside.visibility_range_end = float(e["radius"]) + 70.0
	(w["d"] as Dungeon).add_child(inside)


static func _dress_outside(isl: GenIsland, e: Dictionary, w: Dictionary) -> void:
	_outside(isl, e, w["d"], w["rng"])
	_lights(isl, e, w["d"])
	w.clear()


## The ice that grows in a frozen cave's dripstone and crystals (it glows a little of itself).
static func _ice_mat() -> Material:
	return PSXMat.lit("ice", Color(0.82, 0.93, 1.0), {"emission": Color(0.25, 0.62, 1.0), "emission_energy": 0.7, "affine": 0.3})


## Stalactites under the roof, stalagmites and rubble along the walls (`frost`: icicles and ice spires instead).
static func _dripstone_pass(e: Dictionary, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, used: Array, frost: bool) -> void:
	var stone := _ice_mat() if frost else PSXMat.lit("rock", Color(0.74, 0.7, 0.62))
	var rubble := PSXMat.lit("rock", Color(0.5, 0.48, 0.45), {"affine": 0.6})
	for r in e["rooms"]:
		var c := loc(e, r["c"], r["y"])
		for hp in r["hang"]:
			var root: Vector3 = hp
			var far := Vector2(root.x - c.x, root.z - c.z).length() / float(r["r"])
			var clear: float = root.y - float(r["y"]) - (3.4 if far < 0.55 else 2.4)
			var length := minf(rng.randf_range(0.8, 2.6), clear)
			if length < 0.5 or rng.randf() < 0.3:
				continue
			_spike(mb, stone, root + Vector3.UP * 0.6, length + 0.6, (length + 0.6) * rng.randf_range(0.13, 0.19), true, rng)
		for p in spots(e, r, rng, 5, 0.78, 0.92, 2.0, used):
			var h := rng.randf_range(0.6, 2.2)
			var r0 := h * rng.randf_range(0.18, 0.26)
			_spike(mb, stone, p - Vector3.UP * 0.3, h + 0.3, r0, false, rng)
			if r0 >= 0.25:
				KitLandmarks.cyl_col(body, r0 * 0.75, h, p + Vector3.UP * h * 0.5)
		for k in range(6):
			var a := rng.randf() * TAU
			var q: Vector2 = r["c"] + Vector2.from_angle(a) * float(r["r"]) * rng.randf_range(0.85, 0.97)
			mb.add_blob(rubble, Transform3D(Basis(Vector3.UP, a), loc(e, q, float(r["y"]) + 0.15)), Vector3.ONE * rng.randf_range(0.4, 1.1), rng, 0.25, 3, 6)


## A frozen cave's own (style "cave_frost"): clusters of ice crystals on the floors, and in the end room a waterfall
## frozen down the wall into an iced-over pool.
static func _frost(e: Dictionary, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, used: Array) -> void:
	var ice := _ice_mat()
	for r in e["rooms"]:
		for p in spots(e, r, rng, rng.randi_range(2, 4), 0.55, 0.88, 2.6, used):
			for k in range(rng.randi_range(3, 6)):
				var off := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
				var h := rng.randf_range(0.7, 2.1) * (1.4 if k == 0 else 1.0)
				_spike(mb, ice, p + off - Vector3.UP * 0.25, h, h * rng.randf_range(0.14, 0.2), false, rng)
			KitLandmarks.cyl_col(body, 0.6, 1.6, p + Vector3.UP * 0.8)
	var end := room_of(e, "end")
	for hit in end["walls"]:
		var p: Vector3 = hit[0]
		var nrm: Vector3 = hit[1]
		if absf(nrm.y) > 0.4 or p.y - float(end["y"]) < 2.2:
			continue
		var flat := Vector3(nrm.x, 0.0, nrm.z).normalized()
		var foot := Vector3(p.x, float(end["y"]), p.z) + flat * 0.3
		var top := p.y - float(end["y"]) + 1.2
		var rings: Array = []
		var n := maxi(4, int(top / 0.6))
		for k in range(n + 1):
			var t := float(k) / n
			var bulge := 1.0 + 0.25 * sin(t * 9.0 + rng.randf()) + (0.5 * (1.0 - t) * (1.0 - t))
			rings.append([top * t, 1.1 * bulge, 0.45 * bulge, 0.0, rng.randf_range(-0.08, 0.08)])
		mb.add_loft(ice, Transform3D(Basis.looking_at(-flat, Vector3.UP), foot), rings, MeshBuilder.profile_circle(8), 1.0, Color(0.95, 0.98, 1.0), false, true)
		mb.add_cylinder(ice, Transform3D(Basis(), foot + flat * 1.6 + Vector3.UP * 0.02), 2.2, 2.0, 0.08, 12, 0.6, Color(0.85, 0.92, 1.0))
		KitLandmarks.box_col_xf(body, Vector3(2.4, top, 1.0), Transform3D(Basis.looking_at(-flat, Vector3.UP), foot + Vector3.UP * top * 0.5))
		break


## On the walls: glowing lichen in the bug tunnels, the smugglers' torches, the ruin's glowing glyphs.
static func _walls(e: Dictionary, mb: MeshBuilder, rng: RandomNumberGenerator) -> void:
	var bright := PSXMat.glow(Color(0.35, 1.0, 0.75), 1.9)
	var dim := PSXMat.glow(Color(0.25, 0.62, 0.95), 1.3)
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var flame := PSXMat.glow(Color(1.0, 0.62, 0.25), 3.0)
	var glyph := PSXMat.lit("driftstone", Color(0.8, 0.86, 0.8), {"emission_tex": "driftstone_glow", "emission": Color(0.4, 0.95, 0.9), "emission_energy": 1.4})
	for r in e["rooms"]:
		var n := 0
		for hit in r["walls"]:
			var p: Vector3 = hit[0]
			var nrm: Vector3 = hit[1]
			var up := Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT
			match str(e["kind"]):
				"beast_den":
					if n >= 3:
						continue
					var b := Basis.looking_at(nrm, up) * Basis(Vector3.BACK, rng.randf_range(-0.4, 0.4))
					var t1 := b * Vector3.RIGHT
					for k in range(4):
						mb.add_box(iron, Transform3D(b, p + nrm * 0.03 + t1 * (k - 1.5) * 0.16), Vector3(0.05, rng.randf_range(0.7, 1.0), 0.02), 1.0, Color(0.4, 0.38, 0.36))
				"bug_tunnels", "root_cavern":
					var t1 := nrm.cross(up).normalized()
					var t2 := nrm.cross(t1)
					var b := Basis(t1, nrm, t1.cross(nrm))
					var mat := dim if n % 3 == 0 else bright
					for k in range(rng.randi_range(6, 12)):
						var s := rng.randf_range(0.08, 0.22)
						var off := t1 * rng.randf_range(-0.55, 0.55) + t2 * rng.randf_range(-0.55, 0.55) * 1.4
						mb.add_blob(mat, Transform3D(b, p + nrm * 0.05 + off), Vector3(s, 0.03, s * rng.randf_range(0.7, 1.5)), rng, 0.3, 2, 5, 1.0)
				"smugglers_grotto":
					if n >= 2 or p.y - float(r["y"]) < 1.4:
						continue
					var flat := Vector3(nrm.x, 0.0, nrm.z).normalized()
					var b := Basis.looking_at(flat, Vector3.UP)
					var at := p + Vector3.UP * (2.1 - (p.y - float(r["y"])))
					mb.add_box(iron, Transform3D(b, at + flat * 0.2), Vector3(0.08, 0.08, 0.45), 1.0)
					mb.add_cylinder(iron, Transform3D(Basis(), at + flat * 0.42), 0.09, 0.12, 0.16, 5, 1.0)
					mb.add_blob(flame, Transform3D(Basis(), at + flat * 0.42 + Vector3.UP * 0.26), Vector3(0.1, 0.18, 0.1), rng, 0.2, 2, 4, 1.0)
				"flooded_ruin", "sunken_shrine":
					if n >= 3:
						continue
					var b := Basis.looking_at(nrm, up)
					mb.add_box(glyph, Transform3D(b, p + nrm * 0.02), Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.6, 1.1), 0.04), 0.6)
			n += 1


## A dripstone hanging (`down`) or rising from `root`: flared at the rock, tapering to a point.
static func _spike(mb: MeshBuilder, mat: Material, root: Vector3, length: float, r0: float, down: bool, rng: RandomNumberGenerator) -> void:
	var s := -1.0 if down else 1.0
	var lean := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (0.02 if down else 0.08) * length
	var rings: Array = []
	var n := maxi(3, int(length * 2.0))
	for k in range(n + 1):
		var t := float(k) / n
		var rr := r0 * (1.0 + 0.35 * pow(1.0 - t, 6.0)) * pow(1.0 - t * 0.97, 1.3)
		rings.append([s * length * t, rr, rr, lean.y * t * t, lean.x * t * t])
	mb.add_loft(mat, Transform3D(Basis(), root), rings, MeshBuilder.profile_circle(6), 1.5, Color.WHITE * rng.randf_range(0.85, 1.05), down, not down)


static func _dress_bugs(e: Dictionary, d: Dungeon, mb: MeshBuilder, rng: RandomNumberGenerator, used: Array, nest_ring: bool) -> void:
	var silk := PSXMat.lit("canvas", Color(0.85, 0.88, 0.78))
	var egg := PSXMat.glow(Color(0.55, 0.9, 0.35), 0.9)
	var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
	var fungus := PSXMat.glow(Color(0.35, 0.95, 0.85), 2.2)
	var stalk := PSXMat.lit("", Color(0.75, 0.72, 0.6))
	for r in e["rooms"]:
		# egg sacs in clusters at the walls, glowing fungus round their feet, bones about
		for p in spots(e, r, rng, 2 if r["role"] != "end" else 3, 0.72, 0.88, 3.0, used):
			for k in range(5):
				var off := Vector3(rng.randf_range(-1.1, 1.1), 0.35, rng.randf_range(-1.1, 1.1))
				mb.add_blob(egg, Transform3D(Basis(), p + off), Vector3.ONE * rng.randf_range(0.3, 0.5), rng, 0.15, 3, 6)
			mb.add_blob(silk, Transform3D(Basis(), p + Vector3.UP * 0.12), Vector3(1.9, 0.3, 1.9), rng, 0.3, 3, 7)
		for p in spots(e, r, rng, 6, 0.8, 0.95, 1.4, used):
			for f in range(3):
				var q: Vector3 = p + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
				var h := rng.randf_range(0.2, 0.55)
				mb.add_cylinder(stalk, Transform3D(Basis(), q), 0.04, 0.03, h, 4, 1.0)
				mb.add_cylinder(fungus, Transform3D(Basis(), q + Vector3(0, h, 0)), 0.16, 0.02, 0.1, 6, 1.0, Color.WHITE, false, true)
		for k in range(5):
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * rng.randf_range(0.3, 0.8)
			mb.add_box(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), loc(e, q, float(r["y"]) + 0.09)),
				Vector3(0.08, rng.randf_range(0.5, 0.9), 0.08), 1.0)
	if not nest_ring:
		return
	# the brood mother's nest: silk-bound debris in a ring
	var end := room_of(e, "end")
	var nest := Dungeon.nest_point(e, end)
	for k in range(14):
		var a := TAU * k / 14.0
		mb.add_blob(silk, Transform3D(Basis(Vector3.UP, a), nest + Vector3(cos(a) * 4.0, 0.1, sin(a) * 4.0)), Vector3(1.0, 0.45, 0.6), rng, 0.25, 3, 6)


## The giant tree's roots: thick ones down through the roof into the floor, thin ones hanging.
static func _roots(e: Dictionary, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var bark := PSXMat.lit("bark", Color(0.75, 0.62, 0.5))
	for r in e["rooms"]:
		var c := loc(e, r["c"], r["y"])
		var thick := 0
		for hp in r["hang"]:
			var top: Vector3 = hp + Vector3.UP * 0.8
			var far := Vector2(top.x - c.x, top.z - c.z).length() / float(r["r"])
			if thick < 3 and far > 0.45:
				var out := Vector3(top.x - c.x, 0.0, top.z - c.z).normalized()
				var foot := Vector3(top.x, float(r["y"]) - 0.2, top.z) + out * rng.randf_range(0.5, 1.6)
				var rr := rng.randf_range(0.28, 0.45)
				var pts := MeshBuilder.curve_points(top, top.lerp(foot, 0.5) - out * rng.randf_range(0.6, 1.4), foot, 8)
				mb.add_tube(bark, pts, rr, rr * 1.5, 6, 1.5)
				KitLandmarks.cyl_col(body, rr * 1.2, 2.0, foot + Vector3.UP * 1.0)
				thick += 1
			else:
				var l := rng.randf_range(1.0, minf(3.0, top.y - float(r["y"]) - 2.6))
				if l < 0.6:
					continue
				var sway := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
				mb.add_tube(bark, MeshBuilder.curve_points(top, top + sway + Vector3.DOWN * l * 0.5, top + Vector3.DOWN * l + sway * 0.5, 6), 0.08, 0.03, 4, 1.5)


## Guano heaped under the roost, dark clusters hanging up there, the odd bone.
static func _dress_roost(e: Dictionary, mb: MeshBuilder, rng: RandomNumberGenerator, used: Array) -> void:
	var guano := PSXMat.lit("dirt", Color(0.92, 0.9, 0.82))
	var roost := PSXMat.lit("fur", Color(0.22, 0.18, 0.2))
	var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
	for r in e["rooms"]:
		for hp in r["hang"]:
			var top: Vector3 = hp
			if top.y - float(r["y"]) < 4.5:
				continue
			for k in range(rng.randi_range(3, 7)):
				var off := Vector3(rng.randf_range(-0.7, 0.7), -rng.randf_range(0.1, 0.4), rng.randf_range(-0.7, 0.7))
				mb.add_blob(roost, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), top + off), Vector3(0.14, 0.26, 0.12), rng, 0.2, 2, 4, 1.0)
			mb.add_blob(guano, Transform3D(Basis(), Vector3(top.x, float(r["y"]) + 0.05, top.z)), Vector3(rng.randf_range(0.8, 1.6), 0.12, rng.randf_range(0.8, 1.6)), rng, 0.3, 3, 6)
		for k in range(3):
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * rng.randf_range(0.3, 0.8)
			mb.add_box(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), loc(e, q, float(r["y"]) + 0.09)), Vector3(0.07, 0.6, 0.07), 1.0)


## Bones everywhere, a carcass picked clean, the nest of torn branches at the end.
static func _dress_den(e: Dictionary, mb: MeshBuilder, rng: RandomNumberGenerator, used: Array) -> void:
	var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
	var bark := PSXMat.lit("bark")
	for r in e["rooms"]:
		for k in range(10):
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * rng.randf_range(0.2, 0.9)
			var p := loc(e, q, float(r["y"]) + 0.08)
			mb.add_cylinder(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), p), 0.05, 0.05, rng.randf_range(0.5, 1.1), 5, 1.0, Color.WHITE, true, true)
			if k % 4 == 0:
				mb.add_blob(bone, Transform3D(Basis(), p + Vector3.UP * 0.08), Vector3(0.18, 0.15, 0.22), rng, 0.15, 3, 5)
		for p in spots(e, r, rng, 1, 0.5, 0.7, 3.0, used):
			# a ribcage: arcs off a spine
			var yaw := rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw)
			mb.add_cylinder(bone, Transform3D(b * Basis(Vector3.BACK, PI * 0.5), p + Vector3.UP * 0.15), 0.08, 0.06, 2.2, 5, 1.0, Color.WHITE, true, true)
			for k in range(6):
				var x := -0.9 + k * 0.36
				for s in [-1.0, 1.0]:
					var a: Vector3 = p + b * Vector3(x, 0.15, 0.0)
					var tip: Vector3 = p + b * Vector3(x + 0.1, 0.05, s * 0.75)
					mb.add_tube(bone, MeshBuilder.curve_points(a, a + b * Vector3(0, 0.9, s * 0.45), tip, 5), 0.04, 0.03, 4, 1.0)
	var end := room_of(e, "end")
	var nest := Dungeon.nest_point(e, end)
	for k in range(22):
		var a := TAU * k / 22.0
		var rr := rng.randf_range(2.6, 3.6)
		var b := Basis(Vector3.UP, a + PI * 0.5 + rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, PI * 0.5 + rng.randf_range(-0.3, 0.3))
		mb.add_cylinder(bark, Transform3D(b, nest + Vector3(cos(a) * rr, 0.25 + (k % 3) * 0.18, sin(a) * rr)), 0.1, 0.06, rng.randf_range(2.0, 3.0), 4, 1.0)


static func _dress_grotto(e: Dictionary, d: Dungeon, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, used: Array) -> void:
	var wood := PSXMat.lit("planks", Color(0.9, 0.85, 0.75))
	var dark := PSXMat.lit("planks_dark")
	var band := PSXMat.lit("metal", Color(0.55, 0.55, 0.6))
	var sack := PSXMat.lit("canvas", Color(0.78, 0.7, 0.52))
	var glass := PSXMat.lit("", Color(0.3, 0.55, 0.3))
	for r in e["rooms"]:
		# contraband stacked against the walls
		for p in spots(e, r, rng, 3 if r["role"] != "entry" else 2, 0.62, 0.8, 3.2, used):
			var face := inward(e, r, p)
			var side := face.cross(Vector3.UP)
			for k in range(rng.randi_range(2, 4)):
				var s := rng.randf_range(0.65, 0.95)
				var q: Vector3 = p + side * (k - 1.5) * 0.95 - face * rng.randf_range(0.0, 0.4)
				_crate(mb, wood, dark, q, s, rng.randf() * 0.3, body)
				if rng.randf() < 0.4:
					_crate(mb, wood, dark, q + Vector3.UP * s, s * 0.8, rng.randf() * 0.5, body)
			for k in range(rng.randi_range(1, 3)):
				_barrel(mb, dark, band, p + face * 1.2 + side * rng.randf_range(-1.5, 1.5), body)
			for k in range(3):
				mb.add_blob(sack, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p - side * 2.2 + Vector3(rng.randf_range(-0.4, 0.4), 0.25, rng.randf_range(-0.4, 0.4))),
					Vector3(0.45, 0.32, 0.35), rng, 0.2, 3, 6)
		for k in range(4):
			var q: Vector2 = r["c"] + Vector2.from_angle(rng.randf() * TAU) * float(r["r"]) * rng.randf_range(0.3, 0.7)
			mb.add_cylinder(glass, Transform3D(Basis(Vector3.BACK, PI * 0.5 * float(k % 2)), loc(e, q, float(r["y"]) + 0.06)), 0.05, 0.04, 0.26, 5, 1.0)
	# the crew's fire and table in the middle room, bunks in the side room
	var mid := room_of(e, "mid")
	var fire_at := Dungeon.fire_point(e, mid)
	var fire := Props.campfire()
	fire.name = "Campfire"
	fire.position = fire_at
	d.add_child(fire)
	for s in [-1.0, 1.0]:
		var lg := KitCamps.log_seat()
		lg.position = fire_at + Vector3(s * 2.2 - 0.9, 0.0, 0.0)
		d.add_child(lg)
	for tp in spots(e, mid, rng, 1, 0.55, 0.68, 3.0, used):
		var table := Props.table()
		table.position = tp
		table.rotation.y = rng.randf() * TAU
		d.add_child(table)
	var side := room_of(e, "side")
	if not side.is_empty():
		for p in spots(e, side, rng, 2, 0.55, 0.7, 3.0, used):
			var face := inward(e, side, p)
			var yaw := atan2(face.x, face.z)
			mb.add_box(dark, Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.25), Vector3(1.0, 0.5, 2.0), 1.0, Color.WHITE, true, false)
			mb.add_box(sack, Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.55), Vector3(0.9, 0.12, 1.9), 1.0, Color.WHITE, true, false)
			KitLandmarks.box_col(body, Vector3(1.0, 0.6, 2.0), p + Vector3.UP * 0.3)
	# the stash: gold heaped round the chest, a stolen boat, the crew's flag
	var end := room_of(e, "end")
	var stash := Dungeon.reward_point(e, end)
	var gold := PSXMat.lit("metal", Color(1.0, 0.8, 0.35), {"emission": Color(0.6, 0.4, 0.1), "emission_energy": 0.7})
	for k in range(7):
		var a := rng.randf() * TAU
		mb.add_blob(gold, Transform3D(Basis(), stash + Vector3(cos(a), 0.05, sin(a)) * rng.randf_range(0.8, 1.6)), Vector3(0.35, 0.16, 0.35), rng, 0.2, 3, 5)
	var boat_at: Array = spots(e, end, rng, 1, 0.55, 0.65, 3.5, used)
	if not boat_at.is_empty():
		var boat := Props.rowboat()
		boat.position = boat_at[0]
		boat.rotation.y = rng.randf() * TAU
		d.add_child(boat)
	var flag := KitCamps.flag("CrewFlag", {"h": 3.6})
	var fl: Array = spots(e, end, rng, 1, 0.75, 0.82, 2.0, used)
	if not fl.is_empty():
		flag.position = fl[0]
		d.add_child(flag)


static func _crate(mb: MeshBuilder, wood: Material, dark: Material, p: Vector3, s: float, yaw: float, body: StaticBody3D) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(wood, Transform3D(b, p + Vector3.UP * s * 0.5), Vector3.ONE * s, 1.0 / s, Color.WHITE, true, false)
	for x in [-1, 1]:
		for z in [-1, 1]:
			mb.add_box(dark, Transform3D(b, p + b * Vector3(x * s * 0.47, s * 0.5, z * s * 0.47)), Vector3(0.08, s + 0.02, 0.08), 1.0)
	KitLandmarks.box_col(body, Vector3.ONE * s, p + Vector3.UP * s * 0.5)


static func _barrel(mb: MeshBuilder, wood: Material, band: Material, p: Vector3, body: StaticBody3D) -> void:
	mb.add_cylinder(wood, Transform3D(Basis(), p), 0.34, 0.38, 0.5, 8, 1.2, Color.WHITE, false)
	mb.add_cylinder(wood, Transform3D(Basis(), p + Vector3.UP * 0.5), 0.38, 0.34, 0.5, 8, 1.2, Color.WHITE, true)
	mb.add_cylinder(band, Transform3D(Basis(), p + Vector3.UP * 0.15), 0.36, 0.37, 0.06, 8, 1.0, Color.WHITE, false)
	mb.add_cylinder(band, Transform3D(Basis(), p + Vector3.UP * 0.8), 0.37, 0.36, 0.06, 8, 1.0, Color.WHITE, false)
	KitLandmarks.cyl_col(body, 0.38, 1.0, p + Vector3.UP * 0.5)


static func _dress_ruin(e: Dictionary, d: Dungeon, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, used: Array) -> void:
	var water := PSXMat.lit("water", Color(0.3, 0.42, 0.46), {"emission": Color(0.08, 0.16, 0.2), "emission_energy": 0.6})
	var brick := PSXMat.lit("stone_brick", Color(0.66, 0.74, 0.68))
	var carved := PSXMat.lit("driftstone", Color(0.8, 0.86, 0.8), {"emission_tex": "driftstone_glow", "emission": Color(0.4, 0.95, 0.9), "emission_energy": 1.4})
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	for r in e["rooms"]:
		var c := loc(e, r["c"], r["y"])
		# standing water over the flagstones, deeper toward the middle
		var pool := PackedVector2Array()
		var pr: float = float(r["r"]) * rng.randf_range(0.55, 0.75)
		for k in range(14):
			var t := TAU * k / 14.0
			pool.append(Vector2(cos(t), sin(t)) * pr * rng.randf_range(0.8, 1.1))
		mb.add_extrude(water, Transform3D(flat, c + Vector3(rng.randf_range(-1.0, 1.0), 0.18, rng.randf_range(-1.0, 1.0))), pool, 0.02, 0.4)
		# pillars of the old halls along the walls, some fallen; carved stones glowing faintly
		for p in spots(e, r, rng, 3, 0.7, 0.85, 3.0, used):
			var broken := rng.randf() < 0.5
			var pil := Props.ruin_pillar(rng.randf_range(2.0, 3.6) if broken else minf(float(r["h"]) - 1.0, 5.0), broken, rng.randi() % 100)
			pil.position = p
			pil.rotation.y = rng.randf() * TAU
			d.add_child(pil)
		for p in spots(e, r, rng, 1, 0.4, 0.6, 3.0, used):
			var fp := Props.fallen_pillar(rng.randf_range(3.0, 4.2))
			fp.position = p
			fp.rotation.y = rng.randf() * TAU
			d.add_child(fp)
		for p in spots(e, r, rng, 2, 0.8, 0.9, 2.5, used):
			var face := inward(e, r, p)
			var yaw := atan2(face.x, face.z)
			mb.add_box(brick, Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.2), Vector3(1.3, 0.4, 0.7), 0.8, Color.WHITE, true, false)
			mb.add_box(carved, Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 1.3), Vector3(1.0, 1.8, 0.35), 0.6)
			KitLandmarks.box_col(body, Vector3(1.3, 2.2, 0.7), p + Vector3.UP * 1.1)
	# the altar at the end: a stepped dais the chest stands on, a statue either side
	var end := room_of(e, "end")
	var alt := Dungeon.reward_point(e, end)
	var face := inward(e, end, alt)
	var yaw := atan2(face.x, face.z)
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(brick, Transform3D(b, alt + Vector3.UP * 0.15), Vector3(4.2, 0.3, 3.4), 0.8, Color.WHITE, true, false)
	mb.add_box(brick, Transform3D(b, alt + Vector3.UP * 0.45), Vector3(3.0, 0.3, 2.4), 0.8, Color.WHITE, true, false)
	KitLandmarks.box_col(body, Vector3(4.2, 0.3, 3.4), alt + Vector3.UP * 0.15)
	KitLandmarks.box_col(body, Vector3(3.0, 0.6, 2.4), alt + Vector3.UP * 0.3)
	for s in [-1.0, 1.0]:
		var sp: Vector3 = alt + b * Vector3(s * 3.0, 0.0, -0.6)
		_statue(mb, brick, carved, sp, yaw)
		KitLandmarks.box_col(body, Vector3(1.0, 3.2, 1.0), sp + Vector3.UP * 1.6)


## A squat stone figure on a plinth, glowing eyes.
static func _statue(mb: MeshBuilder, stone: Material, glow: Material, p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(stone, Transform3D(b, p + Vector3.UP * 0.35), Vector3(1.1, 0.7, 1.1), 0.8, Color.WHITE, true, false)
	mb.add_box(stone, Transform3D(b, p + Vector3.UP * 1.25), Vector3(0.8, 1.1, 0.6), 0.8, Color.WHITE * 0.9, true, false)
	mb.add_box(stone, Transform3D(b, p + Vector3.UP * 2.1), Vector3(0.95, 0.6, 0.7), 0.8, Color.WHITE * 0.95, true, false)
	mb.add_box(stone, Transform3D(b, p + Vector3.UP * 2.7), Vector3(0.6, 0.6, 0.55), 0.8)
	for s in [-1.0, 1.0]:
		mb.add_box(glow, Transform3D(b, p + b * Vector3(s * 0.14, 2.78, 0.28)), Vector3(0.1, 0.07, 0.04), 1.0)


## Plants on the rock's ledges, a tree or two on top, vines over the mouth, scree at the foot,
## and something at the mouth that says what's inside.
static func _outside(isl: GenIsland, e: Dictionary, d: Dungeon, rng: RandomNumberGenerator) -> void:
	var meshes := IslandTheme.meshes(isl.theme)
	var ledges: Array = e["ledges"]
	var by_mesh := {}
	var taken: Array = []
	var trees := 0
	var mouth := loc(e, e["mouth"], e["mouth_y"])
	for k in range(ledges.size()):
		var l: Array = ledges[rng.randi() % ledges.size()]
		var p: Vector3 = l[0]
		if Vector2(p.x - mouth.x, p.z - mouth.z).length() < 4.5:
			continue
		var tree := p.y > float(e["rooms"][0]["y"]) + 7.0 and trees < 3
		var room := 6.0 if tree else 2.2
		if taken.any(func(q): return (q as Vector3).distance_to(p) < room):
			continue
		var list: Array = meshes["tree"] if tree else (meshes["fern"] if rng.randf() < 0.6 else meshes["bush"])
		var mesh: Mesh = list[rng.randi() % list.size()]
		if not by_mesh.has(mesh):
			by_mesh[mesh] = []
		by_mesh[mesh].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (rng.randf_range(0.6, 0.8) if tree else rng.randf_range(0.8, 1.2))), p - Vector3.UP * 0.1))
		taken.append(p)
		if tree:
			trees += 1
		if taken.size() >= 34:
			break
	for mesh in by_mesh.keys():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = (by_mesh[mesh] as Array).size()
		for i in range(mm.instance_count):
			mm.set_instance_transform(i, by_mesh[mesh][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Plants"
		mmi.multimesh = mm
		mmi.visibility_range_end = 160.0
		d.add_child(mmi)
	# vines down over the mouth
	var out: Vector2 = e["mouth_dir"]
	var o3 := Vector3(out.x, 0.0, out.y)
	var side := o3.cross(Vector3.UP)
	var vb := MeshBuilder.new()
	var vine := PSXMat.lit("leaves", Color(0.55, 0.8, 0.45))
	var leaf := PSXMat.lit("leaves", Color(0.7, 0.95, 0.6))
	var w: float = e["tunnels"][0]["w"]
	var h: float = e["tunnels"][0]["h"]
	for k in range(9):
		var top3 := mouth - o3 * rng.randf_range(0.5, 1.5) + side * rng.randf_range(-w - 1.0, w + 1.0) + Vector3.UP * (h + 0.6)
		var l := rng.randf_range(0.8, 2.6)
		var pts := MeshBuilder.curve_points(top3, top3 + o3 * 0.35 + Vector3.DOWN * l * 0.5, top3 + Vector3.DOWN * l + o3 * 0.15, 6)
		vb.add_tube(vine, pts, 0.035, 0.02, 4, 2.0)
		for q in range(2):
			vb.add_blob(leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pts[rng.randi_range(2, 6)]), Vector3(0.16, 0.1, 0.12), rng, 0.3, 2, 5, 1.0)
	# scree and rocks by the mouth
	var rock := PSXMat.lit("rock", Color(0.66, 0.63, 0.58), {"affine": 0.6})
	for k in range(10):
		var q := mouth + o3 * rng.randf_range(0.5, 4.0) + side * (1.0 if k % 2 == 0 else -1.0) * rng.randf_range(w + 0.5, w + 3.0)
		var s := rng.randf_range(0.25, 0.8)
		var g := Vector2(q.x + e["at"].x, q.z + e["at"].y)
		vb.add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, isl.hv(g) + s * 0.15, q.z)), Vector3(s, s * 0.6, s * 0.8), rng, 0.25, 3, 5, 0.6, Color.WHITE, -0.4)
	match str(e["kind"]):
		"bug_tunnels", "beast_den":
			# bones spilling out (and silk strung across the way in)
			var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
			var silk := PSXMat.lit("canvas", Color(0.85, 0.88, 0.78))
			for k in range(7 if e["kind"] == "bug_tunnels" else 14):
				var q := mouth + o3 * rng.randf_range(0.0, 3.5) + side * rng.randf_range(-2.5, 2.5)
				var g := Vector2(q.x + e["at"].x, q.z + e["at"].y)
				vb.add_box(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), Vector3(q.x, isl.hv(g) + 0.08, q.z)), Vector3(0.08, rng.randf_range(0.5, 0.9), 0.08), 1.0)
			if e["kind"] == "bug_tunnels":
				for s in [-1.0, 1.0]:
					vb.add_tube(silk, MeshBuilder.sag_points(mouth + side * s * (w - 0.2) + Vector3.UP * (h - 0.6), mouth - side * s * 0.3 + Vector3.UP * 1.0, 0.4, 6), 0.03, 0.03, 3, 1.0)
		"root_cavern":
			# the giant tree on top, its roots running down over the rock into the ground
			var crown := Vector3(0, -INF, 0)
			for l in ledges:
				var lp: Vector3 = l[0]
				if lp.y > crown.y and Vector2(lp.x, lp.z).length() < float(e["radius"]) * 0.6:
					crown = lp
			if crown.y > -INF:
				var tree := MeshInstance3D.new()
				tree.name = "GiantTree"
				tree.mesh = Props.jungle_tree_mesh(int(e["seed"]) % 1000)
				tree.position = crown - Vector3.UP * 0.4
				tree.scale = Vector3.ONE * 2.4
				d.add_child(tree)
				var tb := StaticBody3D.new()
				tb.name = "GiantTrunk"
				KitLandmarks.cyl_col(tb, 1.1, 8.0, crown + Vector3.UP * 4.0)
				d.add_child(tb)
				var bark := PSXMat.lit("bark", Color(0.75, 0.62, 0.5))
				for k in range(6):
					var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
					var dir := Vector3(cos(a), 0.0, sin(a))
					var reach := rng.randf_range(10.0, 16.0)
					var end3 := crown + dir * reach
					var g := Vector2(end3.x + e["at"].x, end3.z + e["at"].y)
					end3.y = isl.hv(g) - 0.3
					vb.add_tube(bark, MeshBuilder.curve_points(crown + dir * 0.6, crown + dir * reach * 0.5 + Vector3.UP * 0.8, end3, 9), 0.55, 0.2, 6, 1.0)
		"smugglers_grotto":
			# lanterns either side and a stack of crates: someone's minding the place
			for s in [-1.0, 1.0]:
				var lp := Props.lantern_post(2.4)
				var q := mouth + o3 * 1.6 + side * float(s) * (w + 1.2)
				var g := Vector2(q.x + e["at"].x, q.z + e["at"].y)
				lp.position = Vector3(q.x, isl.hv(g), q.z)
				lp.rotation.y = atan2(side.x * s, side.z * s) - PI * 0.5
				d.add_child(lp)
			var wood := PSXMat.lit("planks", Color(0.9, 0.85, 0.75))
			var dark := PSXMat.lit("planks_dark")
			var cb := StaticBody3D.new()
			cb.name = "MouthCrates"
			for k in range(3):
				var q := mouth + o3 * 2.6 + side * (w + 2.6 + k * 0.9)
				var g := Vector2(q.x + e["at"].x, q.z + e["at"].y)
				_crate(vb, wood, dark, Vector3(q.x, isl.hv(g), q.z), 0.85, k * 0.3, cb)
			d.add_child(cb)
		"flooded_ruin", "sunken_shrine":
			# a carved arch round the mouth: the ruin's old doorway
			var brick := PSXMat.lit("stone_brick", Color(0.66, 0.74, 0.68))
			var ab := StaticBody3D.new()
			ab.name = "Arch"
			var yaw := atan2(o3.x, o3.z)
			var floor_y: float = e["mouth_y"]
			for s in [-1.0, 1.0]:
				var q := mouth + o3 * 0.8 + side * float(s) * (w + 0.6)
				vb.add_box(brick, Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, floor_y + h * 0.5 - 0.5, q.z)), Vector3(1.0, h + 1.0, 1.0), 0.8)
				KitLandmarks.box_col(ab, Vector3(1.0, h + 1.0, 1.0), Vector3(q.x, floor_y + h * 0.5 - 0.5, q.z))
			var lt := mouth + o3 * 0.8
			vb.add_box(brick, Transform3D(Basis(Vector3.UP, yaw), Vector3(lt.x, floor_y + h + 0.3, lt.z)), Vector3(w * 2.0 + 2.4, 0.8, 1.2), 0.8)
			d.add_child(ab)
	var dress := vb.to_instance("Mouth")
	dress.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(dress)


## A few lights inside, asleep with the dungeon while nobody's near.
static func _lights(isl: GenIsland, e: Dictionary, d: Dungeon) -> void:
	var ctx := KitContext.make(isl, int(e["seed"]), isl.theme, LIGHTS, isl.build_ms)
	var col: Color = LOOK[e["kind"]]["light"]
	for role in ["end", "mid", "side", "entry"]:
		var r := room_of(e, role)
		if r.is_empty() or (role == "mid" and e["kind"] == "smugglers_grotto"):
			continue
		if not ctx.take_light():
			break
		var l := OmniLight3D.new()
		l.name = "CaveLight"
		l.position = loc(e, r["c"], float(r["y"]) + 3.5)
		l.light_color = col
		l.light_energy = (2.0 if role == "end" else 1.5) * float(LOOK[e["kind"]].get("energy", 1.0))
		l.omni_range = float(r["r"]) + 10.0
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 50.0
		l.distance_fade_length = 15.0
		d.add_child(l)
		d.lights.append(l)


# ==========================================================================
# Enemies and the reward
# ==========================================================================
static func _populate(isl: GenIsland, e: Dictionary) -> void:
	var d: Dungeon = isl.get_node(str(e["name"]))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e["seed"]) + 202
	var lv: int = e["level"]
	var t := Levels.tier(lv)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	d.add_child(enemies)
	d.enemies = enemies
	var used: Array = []
	for r in e["rooms"]:
		used.append(loc(e, r["c"], r["y"]))
	var end := room_of(e, "end")
	match str(e["kind"]):
		"bug_tunnels":
			var bugs := ScuttlebugNest.new()
			bugs.name = "Bugs"
			bugs.level = lv
			bugs.respawn_time = 90.0
			_bugs_in_rooms(e, bugs, rng, used, 2, 3)
			_spitters(bugs, room_of(e, "mid"), 2)
			enemies.add_child(bugs)
			var brood := ScuttlebugNest.new()
			brood.name = "Brood"
			brood.level = lv
			brood.start_empty = true
			brood.respawn_time = INF
			for p in spots(e, end, rng, 3, 0.55, 0.75, 3.0, used):
				brood.add_spot(p)
			enemies.add_child(brood)
			d.setup_queen(brood)
		"smugglers_grotto":
			var crew := _crew(e, rng, "Crew", lv)
			var mid := room_of(e, "mid")
			var fire := Dungeon.fire_point(e, mid)
			for s in [-1.0, 1.0]:
				var seat := fire + Vector3(s * 2.2, 0.0, 0.0)
				crew.add_grunt({"post": seat, "yaw": _yaw(seat, fire), "mode": "sit", "seat_y": 0.42, "seed": rng.randi() % 100000})
			var entry := room_of(e, "entry")
			var mouth := loc(e, e["mouth"], e["mouth_y"])
			for p in spots(e, entry, rng, 1, 0.2, 0.4, 2.0, used):
				crew.add_grunt({"post": p, "yaw": _yaw(p, mouth), "mode": "stand", "seed": rng.randi() % 100000, "role": "rifle"})
			var route: Array = [loc(e, entry["c"], entry["y"]), loc(e, mid["c"], mid["y"]) + Vector3(2.0, 0, -2.0)]
			var side := room_of(e, "side")
			if not side.is_empty():
				route.append(loc(e, side["c"], side["y"]))
				for p in spots(e, side, rng, 1, 0.3, 0.5, 2.0, used):
					crew.add_grunt({"post": p, "yaw": rng.randf() * TAU, "mode": "stand", "seed": rng.randi() % 100000})
			crew.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": rng.randi() % 100000})
			_end_guard(e, end, crew, rng, used, "Boss", lv)
			enemies.add_child(crew)
			d.setup_captain(crew)
			var face := inward(e, end, Dungeon.reward_point(e, end))
			_chest(isl, d, e, Dungeon.reward_point(e, end), atan2(face.x, face.z), [
				["gold", rng.randi_range(28, 42) + t * 10], ["treasure", rng.randi_range(3, 5)], ["rum", 3],
				[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], t), 1],
				[Gear.make("head", "tricorn", {"hat": "tricorn", "hat_color": CharacterLook.CLOTH[5], "trim_color": CharacterLook.TRIM[2]}, "Smuggler Boss's Tricorn", t), 1]])
		"flooded_ruin", "sunken_shrine":
			var shrine: bool = e["kind"] == "sunken_shrine"
			var bugs := ScuttlebugNest.new()
			bugs.name = "Bugs"
			bugs.level = lv
			bugs.respawn_time = 90.0
			_bugs_in_rooms(e, bugs, rng, used, 1, 2)
			enemies.add_child(bugs)
			var crew := _crew(e, rng, "Divers" if shrine else "Scavengers", lv)
			var mid := room_of(e, "mid")
			if mid.is_empty():
				mid = room_of(e, "entry")
			for p in spots(e, mid, rng, 2, 0.4, 0.6, 3.0, used):
				crew.add_grunt({"post": p, "yaw": _yaw(p, loc(e, mid["c"], mid["y"])), "mode": "stand", "seed": rng.randi() % 100000})
			_end_guard(e, end, crew, rng, used, "Diver" if shrine else "Digmaster", lv)
			enemies.add_child(crew)
			d.setup_captain(crew)
			var face := inward(e, end, Dungeon.reward_point(e, end))
			var gear: ItemData = Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[11]}, "Shrine Diver's Bandana", t) if shrine \
				else Gear.make("accessory", "pauldron", {"pauldron": true}, "Drowned King's Pauldron", t)
			_chest(isl, d, e, Dungeon.reward_point(e, end) + Vector3.UP * 0.6, atan2(face.x, face.z), [
				["gold", rng.randi_range(25, 40) + t * 10], ["treasure", rng.randi_range(4, 6)], ["rum", 1],
				[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], t), 1], [gear, 1]])
		"root_cavern", "bat_roost", "beast_den":
			var kind: String = e["kind"]
			var bugs := ScuttlebugNest.new()
			bugs.name = "Bugs"
			bugs.level = lv
			bugs.respawn_time = 90.0
			_bugs_in_rooms(e, bugs, rng, used, 1 if kind == "bat_roost" else 2, 1 if kind == "bat_roost" else 3)
			for r in e["rooms"]:
				if r["role"] != "end":
					_spitters(bugs, r, {"root_cavern": 1, "bat_roost": 3, "beast_den": 0}[kind])
			enemies.add_child(bugs)
			# the end room held by big ones
			var holders := ScuttlebugNest.new()
			holders.name = "EndNest"
			holders.level = lv
			holders.respawn_time = 300.0
			holders.respawn_clearance = float(end["r"]) + 30.0
			var bigs: int = {"root_cavern": 2, "bat_roost": 2, "beast_den": 3}[kind]
			var i := 0
			for p in spots(e, end, rng, bigs + 1, 0.3, 0.6, 3.0, used):
				holders.add_spot(p, i < bigs)
				i += 1
			if kind == "bat_roost":
				_spitters(holders, end, 2)
			enemies.add_child(holders)
			d.setup_nest(holders)
			var face := inward(e, end, Dungeon.reward_point(e, end))
			_chest(isl, d, e, Dungeon.reward_point(e, end), atan2(face.x, face.z), [
				["gold", rng.randi_range(25, 40) + t * 10], ["treasure", rng.randi_range(3, 5)], ["rum", 1],
				[ItemDB.tiered(IslandContent.LOOT_WEAPONS[rng.randi() % IslandContent.LOOT_WEAPONS.size()], t), 1]])
	var baker := isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(d, float(e["radius"]) + 6.0, false, isl.terrain_faces)


## Bugs in every room but the end: `entry` in the first, `rest` in the others (the first of those big).
static func _bugs_in_rooms(e: Dictionary, nest: ScuttlebugNest, rng: RandomNumberGenerator, used: Array, entry: int, rest: int) -> void:
	for r in e["rooms"]:
		if r["role"] == "end":
			continue
		var i := 0
		for p in spots(e, r, rng, entry if r["role"] == "entry" else rest, 0.35, 0.7, 2.5, used):
			nest.add_spot(p, r["role"] != "entry" and i == 0)
			i += 1


## Up to n spitters on threads from a room's roof (only where it's high enough to hang from).
static func _spitters(nest: ScuttlebugNest, r: Dictionary, n: int) -> void:
	var hung := 0
	for hp in r["hang"]:
		if hung >= n or (hp as Vector3).y - float(r["y"]) < 5.0:
			continue
		nest.add_spitter(hp - Vector3.UP * 0.4, Vector3(hp.x, r["y"], hp.z))
		hung += 1


static func _yaw(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


static func _crew(e: Dictionary, rng: RandomNumberGenerator, node_name: String, lv: int) -> GruntCamp:
	var crew := GruntCamp.new()
	crew.name = node_name
	crew.respawn_time = 300.0
	crew.respawn_clearance = float(e["radius"]) + 50.0
	crew.warm_start = true
	crew.level = lv
	return crew


## The end room's captain (a miniboss with a name) and a rifleman beside him.
static func _end_guard(e: Dictionary, end: Dictionary, crew: GruntCamp, rng: RandomNumberGenerator, used: Array, rank: String, _lv: int) -> void:
	var stash := Dungeon.reward_point(e, end)
	var face := inward(e, end, stash)
	var cap_post := stash + face * 2.5
	var lk := PirateGrunt.crew_look(rng)
	var C := CharacterLook.CLOTH
	var nm := "%s %s" % [IslandContent.EPITHET[rng.randi() % IslandContent.EPITHET.size()], IslandContent.FIRST[rng.randi() % IslandContent.FIRST.size()]]
	lk.merge({"name": nm, "build": "broad", "height": 1.1, "hat": ["tricorn", "bandana", "bicorne"][rng.randi() % 3],
		"hat_color": C[rng.randi() % C.size()], "coat": "longcoat", "coat_color": C[rng.randi() % C.size()],
		"trim_color": CharacterLook.TRIM[rng.randi() % CharacterLook.TRIM.size()], "marks": "scar"}, true)
	crew.add_grunt({"post": cap_post, "yaw": _yaw(cap_post, cap_post + face), "mode": "stand", "seed": rng.randi() % 100000,
		"look": lk, "captain": true, "title": "%s %s" % [rank, nm]})
	for p in spots(e, end, rng, 1, 0.35, 0.55, 2.5, used):
		crew.add_grunt({"post": p, "yaw": _yaw(p, loc(e, end["c"], end["y"])), "mode": "stand", "seed": rng.randi() % 100000, "role": "rifle"})


## The reward chest at local p (each captain opens their own; the save remembers).
static func _chest(isl: GenIsland, d: Dungeon, e: Dictionary, p: Vector3, yaw: float, items: Array) -> LootBag:
	var g := Vector2(p.x + e["at"].x, p.z + e["at"].y)
	var key: String = e["reward"]
	var bag := isl.strongbox(d, g, yaw, key.trim_prefix("isle%d_" % int(isl.node["id"])), items, 1.3, p.y + d.position.y - isl.hv(g))
	bag.name = "Hoard"
	return bag
