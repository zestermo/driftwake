class_name SkyBirds
extends Node3D
## Birds in the sky round the local captain (each screen its own: cosmetic, nothing
## is sent, so a guest's birds needn't match). Over each island near you, seeded
## by the island: flocks wheeling high (a loose V going round, or a murmuring
## clump), gulls circling the harbour and perching on its roofs, posts and pier,
## parrots darting from crown to crown over the jungle. Near land the ship draws
## gulls too: circling her mast, trailing her wake, now and then landing on the
## masthead or a yardarm. Anything perched (or flying low) scatters when someone
## runs at it or comes right up to it. Gulls cry and parrots call, by distance.
## Fewer at dusk, none at night (the fauna has bats for that), gone in a storm.
##
## Cheap: one MultiMesh (one draw call) of at most MAX birds, the wings flapped in
## its shader (shaders/sky_bird.gdshader); an island's birds are made when you come
## within AWAKE of its coast and freed past SLEEP; those beyond DRAW aren't drawn or
## steered.

const Footsteps := preload("res://scripts/game/footsteps.gd")
const MAX := 72
const CAPS := {GULL: 24, DARK: 36, PARROT: 12, VULTURE: 18}
const AWAKE := 650.0
const SLEEP := 900.0
const DRAW := 480.0
## Gulls come out to the ship within this of an island's coast.
const SHIP_LAND := 260.0
const SHIP_GULLS := 3
const BRINEHOLLOW_SEED := 8181
## A bird on a perch goes up when a captain runs at it within SCATTER_R, or comes within CLOSE.
const SCATTER_R := 7.0
const CLOSE := 2.5
const RUN := 4.5
const SIZE := {GULL: 1.0, DARK: 1.7, PARROT: 0.65, VULTURE: 2.9}
const TOP_SPEED := {GULL: 11.0, DARK: 14.0, PARROT: 10.0, VULTURE: 8.0}
const UNSEEN_EVERY := 3
const UNSEEN_BEHIND := 4.0
## Seen past this (m) a bird moves under a pixel a frame: flown every SEEN_FAR_EVERY frames.
const SEEN_NEAR := 140.0
const SEEN_FAR_EVERY := 2

enum { GULL, DARK, PARROT, VULTURE }
enum { WHEEL, VEE, CIRCLE, TRAIL, PERCH, LAND, SCATTER, HOP, LEAVE }

var birds: Array = []
## How many of them are out (1 by day .. 0 at night or in a storm).
var day := 1.0
## Birds that scattered so far (tests).
var scattered := 0
var _isles := {}
var _mm: MultiMesh
var _scan_t := 0.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _runners := {}
var _frame := 0


func _ready() -> void:
	top_level = true
	_rng.randomize()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sky_bird.gdshader")
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = _bird_mesh()
	_mm.instance_count = MAX
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Birds"
	mmi.multimesh = _mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mmi)


## A gull, 1.3 m across, facing -Z: a body, a tail fan, wings hinged at the
## shoulder (grey, black tips). Vertex alpha marks the part for the shader.
static func _bird_mesh() -> ArrayMesh:
	var white := Color(0.95, 0.95, 0.93, 1.0)
	var grey := Color(0.62, 0.66, 0.7, 0.6)
	var tip := Color(0.1, 0.1, 0.11, 0.3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := func(col: Color, pts: Array) -> void:
		for p in pts:
			st.set_color(col)
			st.add_vertex(p)
	var nose := Vector3(0, 0.01, -0.25)
	var tail := Vector3(0, 0.02, 0.2)
	var l := Vector3(-0.055, 0.0, -0.03)
	var r := Vector3(0.055, 0.0, -0.03)
	var up := Vector3(0, 0.055, -0.03)
	var dn := Vector3(0, -0.045, -0.03)
	tris.call(white, [nose, l, up, nose, up, r, nose, dn, l, nose, r, dn, tail, up, l, tail, r, up, tail, l, dn, tail, dn, r])
	tris.call(white, [Vector3(0, 0.02, 0.15), Vector3(-0.07, 0.02, 0.31), Vector3(0.07, 0.02, 0.31)])
	tris.call(Color(0.98, 0.78, 0.2, 1.0), [nose, Vector3(-0.012, 0.0, -0.21), Vector3(0, 0.0, -0.32), nose, Vector3(0, 0.0, -0.32), Vector3(0.012, 0.0, -0.21)])
	for s in [-1.0, 1.0]:
		var a := Vector3(s * 0.04, 0.02, -0.09)
		var b := Vector3(s * 0.36, 0.02, -0.07)
		var c := Vector3(s * 0.38, 0.02, 0.07)
		var d := Vector3(s * 0.04, 0.02, 0.09)
		tris.call(grey, [a, b, c, a, c, d])
		tris.call(tip, [b, Vector3(s * 0.66, 0.02, 0.03), c])
	st.generate_normals()
	return st.commit()


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_mm.visible_instance_count = 0
		return
	var wx := get_node_or_null("/root/Weather")
	var night: float = float(wx.get("night")) if wx else 0.0
	var storm: float = float(wx.get("storm")) if wx else 0.0
	day = clampf(1.0 - night * 1.3, 0.0, 1.0) * (1.0 - smoothstep(0.35, 0.75, storm))
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_scan(cam.global_position)
	_watch_runners(delta)
	_advance(delta)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var ship_xf: Transform3D = ship.get_global_transform_interpolated() if ship else Transform3D.IDENTITY
	var at := cam.global_position
	var fwd := -cam.global_basis.z
	_frame += 1
	var n := 0
	var any_dead := false
	for i in range(birds.size()):
		var b: Dictionary = birds[i]
		b["acc"] = float(b["acc"]) + delta
		var to: Vector3 = (b["pos"] as Vector3) - at
		# behind the camera or past DRAW: flown every UNSEEN_EVERY frames, a turn each; seen past SEEN_NEAR every SEEN_FAR_EVERY
		var d2 := to.length_squared()
		var seen := to.dot(fwd) > -UNSEEN_BEHIND and d2 < DRAW * DRAW
		var every := (1 if d2 < SEEN_NEAR * SEEN_NEAR else SEEN_FAR_EVERY) if seen else UNSEEN_EVERY
		if every == 1 or (i + _frame) % every == 0 or not b.has("xf"):
			_fly(b, float(b["acc"]), at, ship, ship_xf)
			b["acc"] = 0.0
			b["xf"] = _xf(b)
		any_dead = any_dead or b["dead"]
		if b["gone"] or (b["pos"] as Vector3).distance_to(at) > DRAW:
			continue
		_mm.set_instance_transform(n, b["xf"])
		_mm.set_instance_custom_data(n, Color(b["wing"], b["fold"], b["paint"], 0.0))
		n += 1
	_mm.visible_instance_count = n
	if any_dead:
		birds = birds.filter(func(b): return not b["dead"])


## Birds drawn now (of `kind`, -1 any).
func shown(kind := -1) -> int:
	var n := 0
	var cam := get_viewport().get_camera_3d()
	for b in birds:
		if not b["gone"] and (kind < 0 or b["kind"] == kind) and cam and (b["pos"] as Vector3).distance_to(cam.global_position) <= DRAW:
			n += 1
	return n


func _xf(b: Dictionary) -> Transform3D:
	var basis := Basis.from_euler(Vector3(b["pitch"], b["yaw"], b["bank"]))
	return Transform3D(basis.scaled(Vector3.ONE * float(SIZE[b["kind"]])), b["pos"])


# --------------------------------------------------------------------------
# Who's near: islands, the ship
# --------------------------------------------------------------------------
func _scan(cam: Vector3) -> void:
	var wg := get_tree().get_first_node_in_group("world_gen")
	if wg == null:
		return
	var list := {}
	var bh = wg.get("starter_island")
	if bh != null and is_instance_valid(bh):
		list["brinehollow"] = [bh, BRINEHOLLOW_SEED, 200.0, "brinehollow"]
	for id in wg.chain_islands:
		var isl = wg.chain_islands[id]
		list["isle%d" % id] = [isl, int(isl.node["seed"]), float(isl.radius), str(isl.theme)]
	for key in _isles.keys():
		var e: Array = _isles[key]
		if not list.has(key) or not is_instance_valid(e[0]) or _off_coast(e, cam) > SLEEP:
			_free_isle(key)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var ship_land := INF
	for key in list:
		var e: Array = list[key]
		if not _isles.has(key) and _off_coast(e, cam) < AWAKE:
			_isles[key] = e
			_make_isle(key, e)
		if ship:
			ship_land = minf(ship_land, _off_coast(e, ship.global_position))
	_ship_gulls(ship, ship_land)


func _off_coast(e: Array, at: Vector3) -> float:
	var isl := e[0] as Node3D
	return Vector2(at.x - isl.global_position.x, at.z - isl.global_position.z).length() - float(e[2])


func _free_isle(key: String) -> void:
	_isles.erase(key)
	for b in birds:
		if b["owner"] == key:
			b["dead"] = true


func _count(kind: int) -> int:
	return birds.filter(func(b): return b["kind"] == kind and not b["dead"]).size()


func _bird(kind: int, owner: String, mode: int, at: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var b := {"kind": kind, "owner": owner, "mode": mode, "home": mode, "pos": at, "vel": Vector3.ZERO,
		"yaw": rng.randf() * TAU, "pitch": 0.0, "bank": 0.0, "wing": 0.0, "fold": 0.0, "flap": rng.randf() * TAU,
		"seed": rng.randf() * 100.0, "keep": rng.randf() * 0.98, "out": true, "gone": false, "dead": false,
		"paint": float(kind) if kind < PARROT else (6.0 if kind == VULTURE else float(rng.randi_range(2, 5))), "call": rng.randf_range(3.0, 15.0),
		"t": 0.0, "rest": rng.randf_range(5.0, 25.0), "perch": Vector3.INF, "perch_ship": false, "spot": -1, "acc": 0.0}
	birds.append(b)
	return b


## An island's own birds, the same every visit (its seed).
func _make_isle(key: String, e: Array) -> void:
	var isl := e[0] as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e[1]) + 4401
	var radius := float(e[2])
	var centre := isl.global_position
	# high flocks: a V going round the island, or a clump wheeling over it; over a theme's whose style says
	# "vulture" (KitStyle high_birds), a few vultures wheeling slow and wide on a thermal instead
	var kind := VULTURE if key != "brinehollow" and KitStyle.of(str(e[3]))["high_birds"] == "vulture" else DARK
	for f in range(rng.randi_range(1, 3)):
		var count := rng.randi_range(5, 10)
		if kind == VULTURE:
			count = 3 + count % 4
		if birds.size() + count > MAX or _count(kind) + count > CAPS[kind]:
			break
		var c := centre + Vector3(rng.randf_range(-0.4, 0.4) * radius, 0.0, rng.randf_range(-0.4, 0.4) * radius)
		var ground := _ground(isl, c)
		var flock := {"c": c, "a": rng.randf() * TAU, "w": rng.randf_range(0.06, 0.12) * (1.0 if rng.randf() < 0.5 else -1.0),
			"h": ground + rng.randf_range(38.0, 62.0), "r": rng.randf_range(22.0, 40.0), "R": radius * rng.randf_range(0.45, 0.75)}
		var vee := rng.randf() < 0.5 and kind == DARK
		if vee:
			flock["h"] = maxf(float(flock["h"]), _ground(isl, centre) + 45.0)
			flock["c"] = centre
			flock["w"] = signf(float(flock["w"])) * 11.0 / float(flock["R"])
		for i in range(count):
			var b := _bird(kind, key, VEE if vee else WHEEL, c + Vector3(0, float(flock["h"]), 0), rng)
			b["flock"] = flock
			b["rank"] = i
			b["off"] = rng.randf_range(-0.5, 0.5)
			b["ro"] = rng.randf_range(-6.0, 6.0)
			b["ho"] = rng.randf_range(-4.0, 4.0)
			b["pos"] = _target(b, null, Transform3D.IDENTITY)
	# the harbour's gulls: circling over it, and some on the roofs, posts and pier
	var dock := isl.find_child("DockingArea", true, false) as Node3D
	if dock:
		var at := dock.global_position
		var spots := _perches(at, 45.0, rng, 6)
		e.append(spots.map(func(p): return [p, -1]))
		var count := rng.randi_range(5, 8)
		for i in range(count):
			if birds.size() >= MAX or _count(GULL) >= CAPS[GULL]:
				break
			var b := _bird(GULL, key, CIRCLE, at, rng)
			b["c"] = at
			b["r"] = rng.randf_range(10.0, 30.0)
			b["h"] = rng.randf_range(7.0, 20.0)
			b["a"] = rng.randf() * TAU
			b["w"] = rng.randf_range(7.0, 10.0) / float(b["r"]) * (1.0 if rng.randf() < 0.6 else -1.0)
			b["pos"] = _target(b, null, Transform3D.IDENTITY)
			if i < 3 and i < spots.size():
				_take_spot(b, e, i)
				b["mode"] = PERCH
				b["pos"] = b["perch"]
				b["t"] = rng.randf_range(10.0, 40.0)
	else:
		e.append([])
	# parrots over the trees: a few small parties hopping crown to crown (the theme's ThemeDef.flocks; Brinehollow one)
	var crowns: Array = isl.get("forest_crowns") if isl.get("forest_crowns") != null else []
	if crowns.size() >= 6:
		var parties: int = 1 if key == "brinehollow" else IslandThemes.of(str(e[3])).flocks
		for g in range(parties):
			var count := rng.randi_range(3, 5)
			if birds.size() + count > MAX or _count(PARROT) + count > CAPS[PARROT]:
				break
			var mid: Vector3 = isl.to_global(crowns[rng.randi() % crowns.size()])
			var near: Array = crowns.map(func(c): return isl.to_global(c)).filter(func(c): return (c as Vector3).distance_to(mid) < 70.0)
			for i in range(count):
				var b := _bird(PARROT, key, HOP, mid, rng)
				b["crowns"] = near
				b["perch"] = (near[rng.randi() % near.size()] as Vector3) + Vector3.UP * 0.4
				b["pos"] = b["perch"]
				b["mode"] = PERCH
				b["home"] = HOP
				b["t"] = rng.randf_range(1.0, 8.0)


func _ground(isl: Node3D, at: Vector3) -> float:
	if not isl.has_method("height_at"):
		return 0.0
	var l := isl.to_local(at)
	return maxf(float(isl.call("height_at", l.x, l.z)), 0.0)


## Places to sit near `at`: roofs, posts, the pier, crates (not the open ground).
func _perches(at: Vector3, r: float, rng: RandomNumberGenerator, n: int) -> Array:
	var space := get_world_3d().direct_space_state
	var out: Array = []
	for i in range(60):
		if out.size() >= n:
			break
		var p := at + Vector3(rng.randf_range(-r, r), 0.0, rng.randf_range(-r, r))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 40.0, p + Vector3.DOWN * 5.0, 1))
		if hit.is_empty():
			continue
		var col := hit["collider"] as Node
		if col == null or Footsteps._terrain_mesh(col) != null or col is CharacterBody3D or col.is_in_group("ship"):
			continue
		if (hit["normal"] as Vector3).y < 0.55 or (hit["position"] as Vector3).y < 0.8:
			continue
		out.append(hit["position"])
	return out


func _take_spot(b: Dictionary, e: Array, i: int) -> void:
	var spots: Array = e[4]
	spots[i][1] = birds.find(b)
	b["spot"] = i
	b["perch"] = spots[i][0]
	b["perch_ship"] = false


func _free_spot(b: Dictionary) -> void:
	if int(b["spot"]) >= 0 and _isles.has(b["owner"]):
		var spots: Array = (_isles[b["owner"]] as Array)[4]
		spots[int(b["spot"])][1] = -1
	b["spot"] = -1


## Near land the ship draws a few gulls out to her; away from it they go home.
func _ship_gulls(ship: Node3D, land: float) -> void:
	var mine := birds.filter(func(b): return b["owner"] == "ship" and not b["dead"])
	var want := SHIP_GULLS if ship != null and land < SHIP_LAND else 0
	if mine.size() > want:
		for b in mine.slice(want):
			b["owner"] = "gone"
			_leave(b)
	elif mine.size() < want and birds.size() < MAX and _count(GULL) < CAPS[GULL]:
		var b := _bird(GULL, "ship", TRAIL if mine.is_empty() else CIRCLE, ship.global_position, _rng)
		b["r"] = _rng.randf_range(8.0, 14.0)
		b["h"] = _rng.randf_range(10.0, 18.0)
		b["a"] = _rng.randf() * TAU
		b["w"] = 9.0 / float(b["r"]) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var away := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)).normalized()
		b["pos"] = ship.global_position + away * 90.0 + Vector3.UP * 30.0


func _leave(b: Dictionary) -> void:
	_free_spot(b)
	b["mode"] = LEAVE
	b["t"] = 0.0
	b["fold"] = 0.0


# --------------------------------------------------------------------------
# Scattering
# --------------------------------------------------------------------------
## How fast each captain is going (measured here, so a teleport between frames is a run too).
func _watch_runners(delta: float) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		var n := p as Node3D
		var id := n.get_instance_id()
		var was: Vector3 = _runners[id][0] if _runners.has(id) else n.global_position
		var v := (n.global_position - was) / maxf(delta, 0.0001)
		_runners[id] = [n.global_position, Vector2(v.x, v.z).length() if v.length() < 40.0 else 0.0]


func _scare(b: Dictionary) -> Vector3:
	var at: Vector3 = b["pos"]
	for p in get_tree().get_nodes_in_group("players"):
		var n := p as Node3D
		var d := Vector2(at.x - n.global_position.x, at.z - n.global_position.z).length()
		var dy := absf(at.y - n.global_position.y - 1.0)
		var fast: float = _runners[n.get_instance_id()][1] if _runners.has(n.get_instance_id()) else 0.0
		if dy < 4.0 and (d < CLOSE or (d < SCATTER_R and fast > RUN)):
			return n.global_position
	return Vector3.INF


func _scatter(b: Dictionary, from: Vector3) -> void:
	_free_spot(b)
	var away := Vector3(b["pos"].x - from.x, 0.0, b["pos"].z - from.z)
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	b["vel"] = away * 5.0 + Vector3.UP * 5.5
	b["mode"] = SCATTER
	b["t"] = _rng.randf_range(3.0, 5.0)
	b["rest"] = _rng.randf_range(20.0, 40.0)
	b["fold"] = 0.0
	scattered += 1
	FX.sfx("flap", b["pos"], -6.0, 0.15, 1.1)
	if b["kind"] == GULL and _rng.randf() < 0.7:
		FX.sfx("gull_cry", b["pos"], -4.0, 0.1)
	elif b["kind"] == PARROT:
		FX.sfx("jungle_bird", b["pos"], -5.0, 0.1)


# --------------------------------------------------------------------------
# Flying
# --------------------------------------------------------------------------
func _fly(b: Dictionary, delta: float, cam: Vector3, ship: Node3D, ship_xf: Transform3D) -> void:
	# out by day, home at night and in a storm
	var should: bool = float(b["keep"]) < day and b["owner"] != "gone"
	if b["out"] and not should:
		b["out"] = false
		_leave(b)
	elif not b["out"] and should:
		b["out"] = true
		b["gone"] = false
		b["mode"] = b["home"] if b["home"] != HOP else PERCH
		b["t"] = _rng.randf_range(1.0, 5.0)
		var tgt := _target(b, ship, ship_xf)
		var away := Vector3(tgt.x - cam.x, 0.0, tgt.z - cam.z).normalized()
		b["pos"] = tgt + away * 140.0 + Vector3.UP * 30.0 if b["home"] != HOP else tgt
	if b["gone"]:
		return
	b["t"] = float(b["t"]) - delta
	b["rest"] = float(b["rest"]) - delta
	var far := (b["pos"] as Vector3).distance_to(cam) > DRAW
	match int(b["mode"]):
		PERCH:
			_perched(b, delta, ship, ship_xf)
		LAND:
			_landing(b, delta, ship, ship_xf)
		HOP:
			_hopping(b, delta)
		SCATTER:
			_steer(b, delta, b["pos"] + b["vel"] * 2.0 + Vector3.UP * 4.0, 12.0)
			if float(b["t"]) <= 0.0:
				b["mode"] = b["home"] if b["home"] != HOP else HOP
				if b["mode"] == HOP:
					_hop_from(b, b["pos"])
		LEAVE:
			var away := Vector3(b["pos"].x - cam.x, 0.0, b["pos"].z - cam.z).normalized()
			_steer(b, delta, b["pos"] + away * 30.0 + Vector3.UP * 12.0, 14.0)
			if float(b["t"]) < -12.0 or (b["pos"] as Vector3).distance_to(cam) > 170.0:
				b["gone"] = true
				if b["owner"] == "gone":
					b["dead"] = true
		_:
			var tgt := _target(b, ship, ship_xf)
			if far:
				b["pos"] = tgt
			else:
				# (the ship's gulls keep up with her, and hurry back when she's got away)
				var top: float = TOP_SPEED[b["kind"]] + clampf(((b["pos"] as Vector3).distance_to(tgt) - 40.0) * 0.15, 0.0, 10.0)
				if b["owner"] == "ship" and ship:
					top += absf(float(ship.get("speed")))
				_steer(b, delta, tgt, top)
			_maybe_perch(b, ship, ship_xf)
			if b["mode"] in [CIRCLE, TRAIL] and float(b["pos"].y) < 9.0:
				var from := _scare(b)
				if from != Vector3.INF:
					_scatter(b, from)
	if not far:
		_wings(b, delta)
		_cry(b, delta, cam)


## Where a bird on a path wants to be now.
func _target(b: Dictionary, ship: Node3D, ship_xf: Transform3D) -> Vector3:
	var s := float(b["seed"])
	match int(b["mode"]):
		WHEEL:
			var f: Dictionary = b["flock"]
			var a := float(f["a"]) + float(b["off"])
			var r := float(f["r"]) + float(b["ro"]) + sin(_t * 0.37 + s) * 5.0
			var c: Vector3 = f["c"] + Vector3(sin(_t * 0.05 + s * 0.01) * 18.0, 0.0, cos(_t * 0.043) * 18.0)
			return c + Vector3(cos(a) * r, float(f["h"]) + float(b["ho"]) + sin(_t * 0.6 + s) * 2.5, sin(a) * r)
		VEE:
			var f: Dictionary = b["flock"]
			var a := float(f["a"])
			var lead: Vector3 = f["c"] + Vector3(cos(a) * float(f["R"]), float(f["h"]), sin(a) * float(f["R"]))
			var dir := Vector3(-sin(a), 0.0, cos(a)) * signf(float(f["w"]))
			var side := dir.cross(Vector3.UP)
			var rank := int(b["rank"])
			var row := ceili(rank / 2.0)
			return lead - dir * row * 1.9 + side * row * 1.6 * (1.0 if rank % 2 == 0 else -1.0) + Vector3.UP * (sin(_t * 1.3 + s) * 0.3 + float(b["off"]))
		CIRCLE:
			var c: Vector3 = b["c"] if b["owner"] != "ship" else ship_xf * Vector3(0.0, HullBuilder.MAST_TOP, HullBuilder.MAST_Z)
			var a := float(b["a"])
			var r := float(b["r"]) + sin(_t * 0.31 + s) * 4.0
			return c + Vector3(cos(a) * r, float(b["h"]) * (0.4 if b["owner"] == "ship" else 1.0) + sin(_t * 0.45 + s) * 3.0, sin(a) * r)
		TRAIL:
			# astern, weaving over her wake
			return ship_xf * Vector3(sin(_t * 0.4 + s) * 6.0, 4.0 + sin(_t * 0.7 + s) * 1.5, HullBuilder.STERN_Z + 10.0 + sin(_t * 0.23 + s) * 5.0)
	return b["pos"]


func _steer(b: Dictionary, delta: float, tgt: Vector3, top: float) -> void:
	var want := (tgt - (b["pos"] as Vector3)) * 1.2
	if want.length() > top:
		want = want.normalized() * top
	var v: Vector3 = (b["vel"] as Vector3).move_toward(want, 9.0 * delta)
	b["vel"] = v
	b["pos"] = (b["pos"] as Vector3) + v * delta
	if Vector2(v.x, v.z).length() > 0.4:
		var yaw := atan2(-v.x, -v.z)
		var turn := wrapf(yaw - float(b["yaw"]), -PI, PI)
		b["yaw"] = float(b["yaw"]) + turn * minf(6.0 * delta, 1.0)
		b["bank"] = lerpf(float(b["bank"]), clampf(-turn * 6.0, -0.9, 0.9), minf(4.0 * delta, 1.0))
	b["pitch"] = lerpf(float(b["pitch"]), clampf(v.y * 0.08, -0.5, 0.5), minf(4.0 * delta, 1.0))


## Round its path: the flocks' and circles' angles move on.
func _advance(delta: float) -> void:
	var seen := {}
	for b in birds:
		if b.has("flock"):
			var f: Dictionary = b["flock"]
			if not seen.has(f):
				seen[f] = true
				f["a"] = float(f["a"]) + float(f["w"]) * delta
		elif b.has("w"):
			b["a"] = float(b["a"]) + float(b["w"]) * delta


func _wings(b: Dictionary, delta: float) -> void:
	if b["mode"] == PERCH:
		b["fold"] = move_toward(float(b["fold"]), 1.0, delta * 4.0)
		b["wing"] = -0.15
		return
	b["fold"] = move_toward(float(b["fold"]), 0.0, delta * 6.0)
	var v: Vector3 = b["vel"]
	var kind: int = b["kind"]
	var rate: float = {GULL: 17.0, DARK: 30.0, PARROT: 44.0, VULTURE: 9.0}[kind]
	var effort := clampf(0.2 + v.y * 0.3 + (1.0 if b["mode"] in [SCATTER, LAND, HOP] else 0.0), 0.0, 1.0)
	# (a vulture soars: a few slow beats now and then)
	var glides: bool = kind != PARROT and effort < 0.6 and sin(_t * (0.5 if kind == GULL else 0.9) + float(b["seed"])) > ({GULL: 0.1, DARK: 0.4, VULTURE: -0.8}[kind])
	b["flap"] = float(b["flap"]) + delta * rate
	if glides:
		b["wing"] = lerpf(float(b["wing"]), 0.14 + 0.04 * sin(float(b["flap"]) * 0.2), minf(5.0 * delta, 1.0))
	else:
		b["wing"] = sin(float(b["flap"])) * (0.55 + 0.25 * effort) + 0.1


func _cry(b: Dictionary, delta: float, cam: Vector3) -> void:
	if b["kind"] == DARK or b["kind"] == VULTURE:
		return
	b["call"] = float(b["call"]) - delta
	if float(b["call"]) > 0.0:
		return
	b["call"] = _rng.randf_range(5.0, 16.0) * (2.0 if b["mode"] == PERCH else 1.0)
	if (b["pos"] as Vector3).distance_to(cam) < 60.0:
		FX.sfx("gull_cry" if b["kind"] == GULL else "jungle_bird", b["pos"], -5.0 if b["kind"] == GULL else -7.0, 0.1)


# --------------------------------------------------------------------------
# Perching
# --------------------------------------------------------------------------
## A circling gull with nobody about now and then comes down to a free perch:
## the harbour's, or on the ship the masthead or a yardarm (while she's slow).
func _maybe_perch(b: Dictionary, ship: Node3D, ship_xf: Transform3D) -> void:
	if b["kind"] != GULL or b["mode"] != CIRCLE or float(b["rest"]) > 0.0:
		return
	b["rest"] = _rng.randf_range(15.0, 35.0)
	if b["owner"] == "ship":
		if ship == null or absf(float(ship.get("speed"))) > 6.0:
			return
		for o in birds:
			if o != b and o["perch_ship"] and o["mode"] in [PERCH, LAND]:
				return
		var spots := [Vector3(0.0, HullBuilder.MAST_TOP + 0.05, HullBuilder.MAST_Z), Vector3(4.1, HullBuilder.YARD_Y + 0.12, HullBuilder.MAST_Z),
			Vector3(-4.1, HullBuilder.YARD_Y + 0.12, HullBuilder.MAST_Z)]
		b["perch"] = spots[_rng.randi() % spots.size()]
		b["perch_ship"] = true
	elif _isles.has(b["owner"]):
		var e: Array = _isles[b["owner"]]
		var free: Array = []
		for i in range((e[4] as Array).size()):
			if int(e[4][i][1]) < 0:
				free.append(i)
		if free.is_empty():
			return
		_take_spot(b, e, free[_rng.randi() % free.size()])
		if _scare({"pos": b["perch"]}) != Vector3.INF:
			_free_spot(b)
			return
	else:
		return
	b["mode"] = LAND
	b["from"] = b["pos"]
	b["t"] = 0.0


func _perch_at(b: Dictionary, ship_xf: Transform3D) -> Vector3:
	return ship_xf * (b["perch"] as Vector3) if b["perch_ship"] else b["perch"]


func _landing(b: Dictionary, delta: float, ship: Node3D, ship_xf: Transform3D) -> void:
	var dur := 2.4
	var k := clampf(-float(b["t"]) / dur, 0.0, 1.0)
	var to := _perch_at(b, ship_xf)
	var from: Vector3 = b["from"]
	var p := from.lerp(to, 1.0 - pow(1.0 - k, 2.0))
	p.y += sin(k * PI) * 2.0 * (1.0 - k)
	var v := (p - (b["pos"] as Vector3)) / maxf(delta, 0.0001)
	b["vel"] = v
	b["pos"] = p
	if Vector2(v.x, v.z).length() > 0.3:
		b["yaw"] = atan2(-v.x, -v.z)
	b["bank"] = 0.0
	b["pitch"] = -0.3 * k
	if k >= 1.0:
		b["mode"] = PERCH
		b["t"] = _rng.randf_range(15.0, 50.0)
		b["vel"] = Vector3.ZERO


func _perched(b: Dictionary, delta: float, ship: Node3D, ship_xf: Transform3D) -> void:
	b["pos"] = _perch_at(b, ship_xf)
	b["pitch"] = 0.0
	b["bank"] = 0.0
	b["vel"] = Vector3.ZERO
	# now and then it shuffles round
	if fmod(_t + float(b["seed"]), 4.0) < delta:
		b["yaw"] = float(b["yaw"]) + _rng.randf_range(-1.2, 1.2)
	var from := _scare(b)
	if from != Vector3.INF:
		_scatter(b, from)
		return
	var shaken: bool = b["perch_ship"] and ship != null and absf(float(ship.get("speed"))) > 7.0
	if float(b["t"]) <= 0.0 or shaken:
		_free_spot(b)
		b["perch_ship"] = b["perch_ship"] and not shaken
		if b["home"] == HOP:
			_hop_from(b, b["pos"])
		else:
			b["mode"] = b["home"]
			b["vel"] = Vector3.UP * 3.0 + Basis(Vector3.UP, float(b["yaw"])) * Vector3.FORWARD * 3.0
			FX.sfx("flap", b["pos"], -10.0, 0.15, 1.1)


# --------------------------------------------------------------------------
# Parrots: crown to crown
# --------------------------------------------------------------------------
func _hop_from(b: Dictionary, at: Vector3) -> void:
	var crowns: Array = b["crowns"]
	var to: Vector3 = (crowns[_rng.randi() % crowns.size()] as Vector3) + Vector3.UP * 0.4
	b["from"] = at
	b["perch"] = to
	b["mode"] = HOP
	b["t"] = 0.0
	b["dur"] = at.distance_to(to) / 9.0 + 0.6
	if _rng.randf() < 0.5:
		FX.sfx("jungle_bird", at, -6.0, 0.12)


func _hopping(b: Dictionary, delta: float) -> void:
	var k := clampf(-float(b["t"]) / float(b["dur"]), 0.0, 1.0)
	var from: Vector3 = b["from"]
	var to: Vector3 = b["perch"]
	var p := from.lerp(to, smoothstep(0.0, 1.0, k))
	p.y += sin(k * PI) * (3.0 + from.distance_to(to) * 0.08)
	var v := (p - (b["pos"] as Vector3)) / maxf(delta, 0.0001)
	b["vel"] = v
	b["pos"] = p
	if Vector2(v.x, v.z).length() > 0.3:
		b["yaw"] = atan2(-v.x, -v.z)
	b["bank"] = 0.0
	b["pitch"] = clampf(v.y * 0.06, -0.4, 0.4)
	if k >= 1.0:
		b["mode"] = PERCH
		b["t"] = _rng.randf_range(2.0, 9.0)
