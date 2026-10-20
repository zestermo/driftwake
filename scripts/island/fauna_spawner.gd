class_name FaunaSpawner
extends Node3D
## An island's wildlife (scripts/enemies/fauna/). From the island's seed it
## rolls which creatures live there (a pool: nothing guaranteed, so two islands
## of a sea can be nothing alike), how many, their colours, and where: herds,
## colonies, troops and lone hunters spread over the island's zones (shore,
## floor under the canopy, canopy crowns, swamp, caves). Same seed, same
## island, on every screen. It keeps them coming back while nobody's watching
## and sets each one's distance LOD a few times a second (Creature.set_lod).
##
## Data for others: `groups` ({kind, zone, role, at (island space), spots}),
## roosts() / herds() / groups_of(kind), zones (zone -> island-space points),
## and fill_slots() for caves and dungeons that leave slots for wildlife.
## Which creatures there are is the island's theme's (ThemeDef.fauna, creatures, cave_fauna).

## A creature of the theme's kind `k` (its script in ThemeDef.creatures).
static func make(theme: String, k: String) -> Creature:
	return load(IslandThemes.of(theme).creatures[k]).new()


## The creatures are put on the island over this many build steps (each builds its own model: 3 steps of ~24 were
## a chain island's worst hitch, 262 ms).
const SPAWN_STEPS := 10
const MIN_KINDS := 3
const MAX_KINDS := 8
## Most creatures an island holds (the pool's density is scaled down to fit).
const CAP := 72
## Groups keep this far apart (m).
const SPACING := 16.0

var isl: Node3D
var theme := ""
## The theme's roster: kind -> {zones, p, dens}.
var roster := {}
var level: int = 0
var respawn_time: float = 150.0
var respawn_clearance: float = 40.0
## {kind: dens, "morph": {kind: 0..2}, "ambient": {...}} (roll())
var pool := {}
## zone -> PackedVector2Array (floor, shore, swamp) or Array of Vector3 (canopy crowns), island space.
var zones := {}
var groups: Array = []
## {kind, at (local), args, node, timer, gen, group}
var spots: Array = []

var _lod_t: float = 0.0
var _all_hidden := false


## Which of the theme's creatures live on an island of this seed, how many, which colours (data only).
static func roll(theme: String, seed_v: int) -> Dictionary:
	var roster: Dictionary = IslandThemes.of(theme).fauna
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 7717
	var kinds: Array = roster.keys()
	kinds.sort()
	var have: Array = []
	for k in kinds:
		if rng.randf() < float(roster[k]["p"]):
			have.append(k)
	while have.size() < MIN_KINDS:
		var k: String = kinds[rng.randi() % kinds.size()]
		if not have.has(k):
			have.append(k)
	while have.size() > MAX_KINDS:
		have.remove_at(rng.randi() % have.size())
	var out := {"morph": {}}
	# one kind runs riot (sometimes): twice the usual
	var plague: String = have[rng.randi() % have.size()] if rng.randf() < 0.35 else ""
	for k in have:
		var d: Array = roster[k]["dens"]
		var n := roundi(rng.randi_range(d[0], d[1]) * rng.randf_range(0.6, 1.5) * (2.0 if k == plague else 1.0))
		out[k] = maxi(n, 1)
		out["morph"][k] = rng.randi() % 3
	var amb := {"swarms": rng.randi_range(3, 10), "flocks": rng.randi_range(0, 4), "fireflies": rng.randf() < 0.8, "butterflies": rng.randf() < 0.8}
	# (one in 125 rolled no swarm and no flock: a bare island. Those get a flock; no other roll changes)
	if not KitStyle.of(theme)["ambient_bugs"]:
		amb["fireflies"] = false
		amb["butterflies"] = false
	if not (amb["fireflies"] or amb["butterflies"]):
		amb["flocks"] = maxi(int(amb["flocks"]), 1)
	out["ambient"] = amb
	return out


## Plans and fills a GenIsland's wildlife (IslandContent's "fauna" step).
## The island's fauna as build steps: the zones and spots, the creatures in SPAWN_STEPS parts, the ambient life (one rng through them, in order).
static func steps(island: Node3D) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(island.node["seed"]) + 9091
	var out: Array = [["fauna", func(): _plan_on(island, rng)]]
	out += GenIsland.sliced("fauna", 12, func() -> bool: return (island.get_node("Fauna") as FaunaSpawner)._zones_part(rng))
	out.append(["fauna", func(): (island.get_node("Fauna") as FaunaSpawner)._place(rng)])
	for part in range(SPAWN_STEPS):
		out.append(["fauna", func(): (island.get_node("Fauna") as FaunaSpawner)._spawn_part(part)])
	out.append(["fauna", func(): FaunaAmbient.build(island.get_node("Fauna"), rng)])
	return out


static func _plan_on(island: Node3D, rng: RandomNumberGenerator) -> void:
	var f := FaunaSpawner.new()
	f.name = "Fauna"
	f.isl = island
	f.theme = str(island.theme)
	f.roster = IslandThemes.of(f.theme).fauna
	f.level = int(island.node["level"])
	f.pool = roll(f.theme, int(island.node["seed"]))
	island.add_child(f)


func _spawn_part(part: int) -> void:
	var n := ceili(spots.size() / float(SPAWN_STEPS))
	for i in range(part * n, mini((part + 1) * n, spots.size())):
		_spawn(spots[i])


# ==========================================================================
# Zones
# ==========================================================================
func _keep_clear(p: Vector2) -> bool:
	var s: Dictionary = isl.sites
	for k in s.keys():
		var r: float = {"village": 70.0, "dock": 55.0, "dock_end": 40.0, "camp": 35.0, "boss": 40.0, "lair": 26.0, "ruins": 16.0, "summit": 14.0}.get(k, 20.0)
		if p.distance_to(s[k]) < r:
			return true
	return false


## The zones a piece at a time (the forest's crowns 150 a call, then the rest): false once they're done.
var _zi := 0
var _floor_pts := PackedVector2Array()
var _canopy: Array = []
func _zones_part(rng: RandomNumberGenerator) -> bool:
	var crowns: Array = isl.forest_crowns
	if _zi < crowns.size():
		_crowns_zones(crowns.slice(_zi, _zi + 150), rng)
		_zi += 150
		return true
	_zones(rng)
	return false


func _crowns_zones(crowns: Array, rng: RandomNumberGenerator) -> void:
	for crown in crowns:
		var c := Vector2(crown.x, crown.z)
		if _keep_clear(c):
			continue
		var g: float = isl.hv(c)
		if crown.y - g > 5.0:
			_canopy.append(crown)
		var a := rng.randf() * TAU
		var q := c + Vector2.from_angle(a) * 2.6
		if isl.hv(q) > 2.0 and not isl.excluded(q, 0.3, 1.5):
			_floor_pts.append(q)


func _zones(rng: RandomNumberGenerator) -> void:
	var floor_pts := _floor_pts
	var canopy := _canopy
	# (an island with no forest to speak of - a desert - has its floor out in the open)
	if floor_pts.size() < 40:
		for i in range(240):
			var q := Vector2.from_angle(rng.randf() * TAU) * float(isl.radius) * sqrt(rng.randf()) * 0.85
			if isl.hv(q) > 2.0 and not _keep_clear(q) and not isl.excluded(q, 0.3, 1.5):
				floor_pts.append(q)
	var shore := PackedVector2Array()
	for i in range(96):
		var a := TAU * i / 96.0 + rng.randf_range(-0.02, 0.02)
		var dir := Vector2.from_angle(a)
		var r: float = isl.radius
		while r > 20.0:
			var h: float = isl.hv(dir * r)
			if h > 0.6:
				if h < 2.2 and not _keep_clear(dir * r):
					shore.append(dir * r)
				break
			r -= 3.0
	var swamp := PackedVector2Array()
	for sw in isl.get("swamps") if isl.get("swamps") != null else []:
		for k in range(6):
			swamp.append((sw[0] as Vector2) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * float(sw[1]))
	zones = {"floor": floor_pts, "canopy": canopy, "shore": shore, "swamp": swamp}


# ==========================================================================
# Groups
# ==========================================================================
func _place(rng: RandomNumberGenerator) -> void:
	var kinds: Array = roster.keys()
	kinds.sort()
	var total := 0
	for k in kinds:
		if pool.has(k):
			total += int(pool[k]) * _group_size(k)
	var k_scale := minf(1.0, float(CAP) / maxf(total, 1.0))
	var taken: Array = []
	for k in kinds:
		if not pool.has(k):
			continue
		var want := maxi(1, roundi(int(pool[k]) * k_scale))
		for i in range(want):
			var zone_list: Array = (roster[k]["zones"] as Array).filter(func(z): return z != "cave" and not (zones[z] as Array).is_empty())
			if zone_list.is_empty():
				break
			var zone: String = zone_list[rng.randi() % zone_list.size()]
			var at = _free_point(zones[zone], taken, rng)
			if at == null:
				break
			_add_group(k, zone, at, rng)
			taken.append(Vector2(at.x, at.z) if at is Vector3 else at)


func _group_size(k: String) -> int:
	return {"boar": 3, "mite": 6, "bat": 4, "monkey": 3, "crab": 3, "leaper": 1, "roller": 1}.get(k, roster[k].get("pack", [1, 1])[1])


func _free_point(list, taken: Array, rng: RandomNumberGenerator):
	for t in range(12):
		var q = list[rng.randi() % list.size()]
		var q2: Vector2 = Vector2(q.x, q.z) if q is Vector3 else q
		if taken.all(func(o): return q2.distance_to(o) > SPACING):
			return q
	return null


## Island point (Vector2) on the ground, in local (island) space.
func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, isl.hv(p), p.y)


func _add_group(k: String, zone: String, at, rng: RandomNumberGenerator) -> void:
	var gi := groups.size()
	var g := {"kind": k, "zone": zone, "role": "lone", "at": at if at is Vector3 else _ground(at), "spots": []}
	groups.append(g)
	var morph: int = pool["morph"][k]
	var near := func(c: Vector2, r: float) -> Vector2: return c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, r)
	match k:
		"boar":
			g["role"] = "herd"
			var tusker := rng.randf() < 0.25
			for i in range(rng.randi_range(1, 2)):
				_add_spot(gi, k, _ground(near.call(at, 3.0)), {"herd": gi, "tusker": tusker and i == 0})
			for i in range(rng.randi_range(0, 3)):
				_add_spot(gi, k, _ground(near.call(at, 3.0)), {"herd": gi, "young": true})
		"mite":
			g["role"] = "nest"
			var mound := Props.burrow(int(absf(at.x * 13.0 + at.y * 7.0)))
			mound.scale = Vector3.ONE * 0.7
			add_child(mound)
			mound.position = _ground(at) + Vector3.DOWN * 0.15
			for i in range(rng.randi_range(5, 8)):
				_add_spot(gi, k, _ground(near.call(at, 2.5)), {"morph": morph})
		"bat", "toucan", "monkey":
			var crown: Vector3 = at
			var crowns: Array = (zones["canopy"] as Array).filter(func(c): return Vector2(c.x, c.z).distance_to(Vector2(crown.x, crown.z)) < 16.0)
			var n := 1
			match k:
				"bat":
					g["role"] = "roost"
					n = rng.randi_range(3, 6)
				"monkey":
					g["role"] = "troop"
					n = rng.randi_range(2, 4)
				"toucan":
					g["role"] = "perch"
			for i in range(n):
				var c: Vector3 = crowns[rng.randi() % crowns.size()] if k == "monkey" else crown
				var a := rng.randf() * TAU
				var drop := 1.4 if k == "bat" else (0.9 if k == "monkey" else 0.2)
				var anchor := c + Vector3(cos(a) * rng.randf_range(0.4, 1.3), -drop, sin(a) * rng.randf_range(0.4, 1.3))
				var foot := _ground(Vector2(anchor.x, anchor.z))
				_add_spot(gi, k, foot, {"morph": morph, "anchor": anchor, "colony": gi, "bold": rng.randf() < 0.5})
		"crab":
			g["role"] = "colony"
			for i in range(rng.randi_range(2, 4)):
				_add_spot(gi, k, _ground(near.call(at, 4.0)), {"morph": morph, "giant": rng.randf() < 0.08})
		"leaper", "roller":
			for i in range(rng.randi_range(1, 2)):
				_add_spot(gi, k, _ground(near.call(at, 2.0)), {"morph": morph})
		_:
			# (a theme's own kinds: a pack round its lead, `young` the chance each follower is one)
			var pack: Array = roster[k].get("pack", [1, 1])
			if pack[1] > 1:
				g["role"] = "pack"
			for i in range(rng.randi_range(pack[0], pack[1])):
				var young := i > 0 and rng.randf() < float(roster[k].get("young", 0.0))
				_add_spot(gi, k, _ground(near.call(at, 4.0) if i > 0 else at), {"morph": morph, "pack": gi, "lead": i == 0, "calf": young})


func _add_spot(gi: int, k: String, local_at: Vector3, args: Dictionary) -> void:
	groups[gi]["spots"].append(spots.size())
	spots.append({"kind": k, "at": local_at, "args": args, "node": null, "timer": 0.0, "gen": 0, "group": gi})


## Caves and dungeons: wildlife for the slots they leave ([Vector3 local to `parent`, "floor" | "ceiling"]).
## The theme's cave_fauna: its ceiling kind hangs in a roost, a floor kind picked per slot.
func fill_slots(parent: Node3D, slots: Array, salt: int = 0) -> void:
	var cave: Dictionary = IslandThemes.of(theme).cave_fauna
	var floors: Array = cave["floor"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.node["seed"]) + 3301 + salt
	for s in slots:
		var at: Vector3 = to_local(parent.to_global(s[0]))
		var ceiling := str(s[1]) == "ceiling"
		var gi := groups.size()
		var k: String = cave["ceiling"] if ceiling else floors[rng.randi() % floors.size()]
		var morph: int = pool["morph"].get(k, 2)
		groups.append({"kind": k, "zone": "cave", "role": "roost" if ceiling else "lone", "at": at, "spots": []})
		if ceiling:
			for i in range(rng.randi_range(2, 5)):
				var anchor := at + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
				_add_spot(gi, k, at + Vector3.DOWN * 3.0, {"morph": 2 if rng.randf() < 0.6 else morph, "anchor": anchor, "colony": gi})
		else:
			_add_spot(gi, k, at, {"morph": morph})
		for si in groups[gi]["spots"]:
			_spawn(spots[si])


func roosts() -> Array:
	return groups.filter(func(g): return g["role"] == "roost")


func herds() -> Array:
	return groups.filter(func(g): return g["role"] == "herd")


func groups_of(k: String) -> Array:
	return groups.filter(func(g): return g["kind"] == k)


static func of(island: Node) -> FaunaSpawner:
	return island.get_node_or_null("Fauna") as FaunaSpawner


# ==========================================================================
# Spawning, respawns
# ==========================================================================
func _ready() -> void:
	add_to_group("net_spawner")


func _spawn_all() -> void:
	for s in spots:
		_spawn(s)


func _spawn(s: Dictionary) -> void:
	var args: Dictionary = (s["args"] as Dictionary).duplicate()
	# spots keep anchors island-local like "at"; Flyer and Monkey want the world position
	if args.has("anchor"):
		args["anchor"] = to_global(args["anchor"] as Vector3)
	var home := to_global(s["at"] as Vector3)
	var c := make(theme, str(s["kind"]))
	c.setup(home, args)
	c.name = "F%d_%d" % [spots.find(s), int(s["gen"])]
	c.xp_k = 0.5 if int(s["gen"]) > 0 else 1.0
	c.level = level
	c.position = s["at"] as Vector3 + Vector3.UP * 0.2
	add_child(c)
	c.reset_physics_interpolation()
	s["node"] = c
	s["timer"] = 0.0
	if _all_hidden:
		c.set_lod(Creature.LOD_HIDDEN)


func _alive(s: Dictionary) -> bool:
	var c = s["node"]
	return c != null and is_instance_valid(c) and not (c as Creature).is_dead()


func alive_count() -> int:
	var n := 0
	for s in spots:
		if _alive(s):
			n += 1
	return n


func _process(delta: float) -> void:
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.25
		_update_lod()
	if Net.is_client():
		return
	var respawned := false
	for s in spots:
		if _alive(s):
			continue
		s["timer"] = float(s["timer"]) + delta
		if float(s["timer"]) < respawn_time or (s["node"] != null and is_instance_valid(s["node"])):
			continue
		var gp := to_global(s["at"] as Vector3)
		if Net.all_players().any(func(p): return (p as Node3D).global_position.distance_to(gp) < respawn_clearance):
			continue
		s["gen"] = int(s["gen"]) + 1
		_spawn(s)
		respawned = true
	if respawned:
		Net.spawned(self, net_gen())


## Each creature's LOD by the nearest captain; nobody near the island: all hidden and asleep.
func _update_lod() -> void:
	var pos: Array = []
	for p in Net.all_players():
		pos.append((p as Node3D).global_position)
	var c := isl.global_position
	var far := pos.all(func(q): return Vector2(q.x - c.x, q.z - c.z).length() > float(isl.radius) + 150.0)
	if far and _all_hidden:
		return
	_all_hidden = far
	var r: Array = Creature.LOD_RANGE
	for s in spots:
		var n = s["node"]
		if n == null or not is_instance_valid(n):
			continue
		var cr := n as Creature
		var d := INF
		if not far:
			for q in pos:
				d = minf(d, cr.global_position.distance_to(q))
		cr.set_lod(Creature.LOD_FULL if d < r[0] else (Creature.LOD_LOW if d < r[1] else (Creature.LOD_SLEEP if d < r[2] else Creature.LOD_HIDDEN)))


func net_gen():
	var g: Array = []
	for s in spots:
		g.append(int(s["gen"]))
	return g


## Co-op client: catch up with the host's respawns.
func net_set_gen(g) -> void:
	var arr: Array = g
	for i in range(mini(arr.size(), spots.size())):
		var s: Dictionary = spots[i]
		if int(arr[i]) == int(s["gen"]):
			continue
		s["gen"] = int(arr[i])
		var old = s["node"]
		if old != null and is_instance_valid(old):
			(old as Node).queue_free()
		_spawn(s)
