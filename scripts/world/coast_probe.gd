class_name CoastProbe
extends RefCounted
## Where the coast is round a point, and what kind. Rays go down (from 80 m) every
## STEP m out along DIRS bearings to REACH, one bearing a call, and wherever a
## bearing crosses between land and sea is a coast: "beach" (sand, low ground),
## "rock" (rock, cliffs, sea stacks, reefs) or "wall" (quays and stone walls:
## water slaps them, it doesn't surf). Wooden things (piers, ships, huts, palm
## trunks) don't count: the ray goes on through to what's under them.
## Ambience hears it, SeaSpray breaks the waves on it.

const Footsteps := preload("res://scripts/game/footsteps.gd")
const DIRS := 16
const STEP := 7.5
const REACH := 180.0
## Ground this high a few metres in from the waterline is a cliff, however it's painted.
const CLIFF := 2.5
const LAND_Y := -0.25

## Per bearing: [[kind, water point (sea level, a little out from the edge), land point], ...]
var coasts: Array = []
## Per bearing: land 30 m and 90 m out.
var land_30 := PackedByteArray()
var land_90 := PackedByteArray()
## The ground under the centre itself is under the sea (a pier, a ship, swimming).
var over_water := false
var _next := 0
static var _kinds := {}


func _init() -> void:
	coasts.resize(DIRS)
	for i in range(DIRS):
		coasts[i] = []
	land_30.resize(DIRS)
	land_90.resize(DIRS)


## Probe the next bearing out from `at`.
func tick(space: PhysicsDirectSpaceState3D, at: Vector3, skip: Array) -> void:
	var i := _next
	_next = (_next + 1) % DIRS
	var a := TAU * i / DIRS
	var d := Vector3(cos(a), 0.0, sin(a))
	var found: Array = []
	var prev := _sample(space, at, skip)
	if i == 0:
		over_water = not bool(prev[0])
	for k in range(1, int(REACH / STEP) + 1):
		var s := _sample(space, at + d * (k * STEP), skip)
		if k == 4:
			land_30[i] = 1 if s[0] else 0
		elif k == 12:
			land_90[i] = 1 if s[0] else 0
		if bool(s[0]) != bool(prev[0]):
			found.append(_edge(space, at, d, (k - 1) * STEP, k * STEP, bool(prev[0]), skip))
		prev = s
	coasts[i] = found


func land_near() -> float:
	return _frac(land_30)


func land_far() -> float:
	return _frac(land_90)


func _frac(a: PackedByteArray) -> float:
	var n := 0
	for v in a:
		n += v
	return n / float(DIRS)


## The nearest coast of `kind` ("" for any) to `from`: [distance, water point] ([INF, INF] if none in reach).
func nearest(kind: String, from: Vector3) -> Array:
	var best: Array = [INF, Vector3.INF]
	for list in coasts:
		for c in list:
			if kind != "" and c[0] != kind:
				continue
			var d := Vector2(from.x - (c[1] as Vector3).x, from.z - (c[1] as Vector3).z).length()
			if d < float(best[0]):
				best = [d, c[1]]
	return best


## Every coast found, [kind, water point, land point].
func all() -> Array:
	var out: Array = []
	for list in coasts:
		out.append_array(list)
	return out


## [land, hit] straight down at `p` (through anything wooden).
func _sample(space: PhysicsDirectSpaceState3D, p: Vector3, skip: Array) -> Array:
	var ex := skip.duplicate()
	for _i in range(4):
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 81.5, p.z), Vector3(p.x, -40.0, p.z), 1)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return [false, hit]
		var col := hit["collider"] as CollisionObject3D
		if col != null and _kind_of(col) == "wood":
			ex.append(col.get_rid())
			continue
		return [(hit["position"] as Vector3).y > LAND_Y, hit]
	return [false, {}]


## The crossing between r0 and r1 found to a metre, and what it's made of.
func _edge(space: PhysicsDirectSpaceState3D, at: Vector3, d: Vector3, r0: float, r1: float, land0: bool, skip: Array) -> Array:
	var lo := r0
	var hi := r1
	var land_hit: Dictionary = {}
	for _i in range(3):
		var mid := (lo + hi) * 0.5
		var s := _sample(space, at + d * mid, skip)
		if bool(s[0]) == land0:
			lo = mid
		else:
			hi = mid
		if s[0]:
			land_hit = s[1]
	var edge := at + d * ((lo + hi) * 0.5)
	# (seaward: from the land side out is +d when the ray started on land)
	var out := d if land0 else -d
	if land_hit.is_empty():
		land_hit = _sample(space, edge - out * 1.0, skip)[1]
	var water := Vector3(edge.x, 0.0, edge.z) + out * 2.0
	var inland: Array = _sample(space, edge - out * 4.0, skip)
	var kind := "beach"
	if not land_hit.is_empty():
		kind = _coast_kind(land_hit)
	if kind == "beach" and not (inland[1] as Dictionary).is_empty() and ((inland[1] as Dictionary)["position"] as Vector3).y > CLIFF:
		kind = "rock"
	return [kind, water, Vector3(edge.x, 0.0, edge.z) - out * 1.0]


func _coast_kind(hit: Dictionary) -> String:
	var col := hit["collider"] as Node
	var mi := Footsteps._terrain_mesh(col)
	if mi:
		return "rock" if Footsteps._terrain_surface(mi, hit["position"], hit["normal"]) == "stone" else "beach"
	match _kind_of(col):
		"rock":
			return "rock"
		"sand":
			return "beach"
	return "wall"


## What a collider is made of: "wood", "rock" (rock, driftstone), "sand", or "wall" (stone work, anything else).
static func _kind_of(col: Node) -> String:
	var id := col.get_instance_id()
	if _kinds.has(id):
		return _kinds[id]
	if _kinds.size() > 1024:
		_kinds.clear()
	var kind := "wall"
	if Footsteps._terrain_mesh(col):
		kind = "ground"
	else:
		var judged := Footsteps._judge(col)
		if judged == "wood":
			kind = "wood"
		elif judged == "sand":
			kind = "sand"
		else:
			var meshes := col.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty() and col.get_parent():
				meshes = col.get_parent().get_children().filter(func(c): return c is MeshInstance3D)
			for m in meshes.slice(0, 12):
				var mesh := (m as MeshInstance3D).mesh
				if mesh == null:
					continue
				for s in range(mesh.get_surface_count()):
					var tex := Footsteps._texture_name((m as MeshInstance3D).get_active_material(s))
					if "rock" in tex or "driftstone" in tex:
						kind = "rock"
	_kinds[id] = kind
	return kind
