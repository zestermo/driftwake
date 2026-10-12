class_name KitContext
extends RefCounted
## What a kit piece (scripts/island/kit/) builds with instead of one island's
## constants: the island's ground, its reserves and paths, a seeded rng per piece,
## the style, a light budget and save keys. The same for Brinehollow
## (StarterIsland) and a generated island (GenIsland). Guide:
## .claude/skills/driftwake-islands/SKILL.md.
##
## Data calls (hv, ground_max/min, reserve, excluded, path_dist, rng, save_key,
## take_light, plan_place) touch no node or server: safe in a worker's prepare.
## Node calls (place, house, add, build_list, marker_*) run on the main thread.
## All points are island space (Vector2 x/z); nodes go under `parent`.

## The island: hv(p), reserve(p, r), excluded(p, pad), path_dist(p), save_key(k), paths.
var isl: Island
## Where this piece's nodes go: the island itself, or a site node under it.
var parent: Node3D
var seed: int
var style: Dictionary
## Shared by every context made from this one: {"lights": NightLights left}.
var budget: Dictionary
## piece -> build ms (the island's own dictionary).
var build_ms: Dictionary
## Ground a piece may not pave or plant over (Brinehollow's quay): p -> bool, or empty.
var paved: Callable
## [centre, radius] of what's built, checked by `excluded` instead of the island's
## reserves when `own_reserves` (a built generated island, whose reserves are its
## sites' clearings): shared by every context made from this one.
var taken: Array = []
var own_reserves := false


static func make(island: Island, island_seed: int, style_name: String, lights: int, ms: Dictionary) -> KitContext:
	var c := KitContext.new()
	c.isl = island
	c.parent = island
	c.seed = island_seed
	c.style = KitStyle.get_style(style_name)
	c.budget = {"lights": lights}
	c.build_ms = ms
	return c


## The same island, its nodes going under `node` (a site node) instead.
func under(node: Node3D) -> KitContext:
	var c := KitContext.new()
	c.isl = isl
	c.parent = node
	c.seed = seed
	c.style = style
	c.budget = budget
	c.build_ms = build_ms
	c.paved = paved
	c.taken = taken
	c.own_reserves = own_reserves
	return c


# --------------------------------------------------------------------------
# Data (worker-safe)
# --------------------------------------------------------------------------
func hv(p: Vector2) -> float:
	return isl.hv(p)


## The highest ground within `r` of c (8 points round it and the middle).
func ground_max(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		var a := TAU * i / 8.0
		m = maxf(m, hv(c + Vector2(cos(a), sin(a)) * r))
	return m


func ground_min(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		var a := TAU * i / 8.0
		m = minf(m, hv(c + Vector2(cos(a), sin(a)) * r))
	return m


func reserve(p: Vector2, r: float) -> void:
	isl.reserve(p, r)
	if own_reserves:
		taken.append([p, r])


## Within `pad` of anything reserved (only reserves smaller than `under` count).
func excluded(p: Vector2, pad: float = 0.0, under := INF) -> bool:
	if not own_reserves:
		return isl.excluded(p, pad, under)
	for e in taken:
		if float(e[1]) < under and p.distance_to(e[0]) < float(e[1]) + pad:
			return true
	return false


func path_dist(p: Vector2) -> float:
	return isl.path_dist(p)


## A piece's own random stream: the island's seed plus the piece's salt, or a
## fixed seed (Brinehollow's, so it stays the same island).
func rng(salt: int, fixed := -1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = fixed if fixed >= 0 else hash([seed, salt])
	return r


func save_key(key: String) -> String:
	return isl.save_key(key)


## One NightLight from the island's budget: false once it's spent (the lamp stays dark).
func take_light() -> bool:
	if int(budget["lights"]) <= 0:
		return false
	budget["lights"] = int(budget["lights"]) - 1
	return true


## A placement worked out now and made later by build_list: its height (the
## highest ground under `footprint`), its reserve, `make` (a Callable returning
## the node) and `then` (called with the node once it's in, or empty).
func plan_place(plan: Array, make: Callable, p: Vector2, yaw: float = 0.0, footprint: float = 0.0, y_offset: float = 0.0, then := Callable()) -> void:
	var y := ground_max(p, footprint) if footprint > 0.0 else hv(p)
	plan.append([make, Vector3(p.x, y + y_offset, p.y), yaw, then])
	if footprint > 0.0:
		reserve(p, footprint + 1.5)


static func face_yaw(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


static func v3(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


# --------------------------------------------------------------------------
# Nodes (main thread)
# --------------------------------------------------------------------------
## Put `node` on the ground at p. `footprint` > 0 stands it on the highest ground
## under it and reserves the area (footprint + 1.5) from what's scattered later
## (unless a plan reserved it already: `reserve_it` false).
func place(node: Node3D, p: Vector2, yaw: float = 0.0, footprint: float = 0.0, y_offset: float = 0.0, reserve_it := true) -> Node3D:
	var y := ground_max(p, footprint) if footprint > 0.0 else hv(p)
	put(node, Vector3(p.x, y + y_offset, p.y), yaw)
	if footprint > 0.0 and reserve_it:
		reserve(p, footprint + 1.5)
	return node


## Makes a plan_place list's nodes, in order.
func build_list(plan: Array) -> Array:
	var out: Array = []
	for e in plan:
		var node: Node3D = (e[0] as Callable).call()
		put(node, e[1], e[2])
		if (e[3] as Callable).is_valid():
			(e[3] as Callable).call(node)
		out.append(node)
	return out


## A node built in island coordinates (a merged mesh), added under `parent`.
func add(node: Node3D) -> Node3D:
	if parent != isl:
		node.transform = _rel().affine_inverse() * node.transform
	parent.add_child(node)
	return node


## `node` at island-space `at`, turned `yaw`, under `parent` (no ground, no reserve).
func put(node: Node3D, at: Vector3, yaw := 0.0) -> void:
	if parent == isl:
		node.position = at
		node.rotation.y = yaw
		parent.add_child(node)
		return
	node.transform = _rel().affine_inverse() * Transform3D(Basis(Vector3.UP, yaw), at)
	parent.add_child(node)


## `parent`'s transform in island space.
func _rel() -> Transform3D:
	return isl.global_transform.affine_inverse() * parent.global_transform


## A Buildings.house on the ground at p, its door toward `face`: the stone footing
## reaches the lowest ground under it (or it stands on stilts), so nothing floats.
## A "lamp_light" takes one from the budget (dark without it).
func house(spec: Dictionary, p: Vector2, face: Vector2, on_stilts := false, reserve_it := true) -> Node3D:
	var r := maxf(float(spec.get("w", 6.0)), float(spec.get("d", 5.0))) * 0.6
	var top := ground_max(p, r)
	var low := ground_min(p, r)
	if spec.get("lamp_light", false) and not take_light():
		spec["lamp_light"] = false
	if on_stilts:
		spec["stilts"] = maxf(top - low + 0.6, 1.0)
		spec["foundation"] = 0.6
		return place(Buildings.house(spec), p, face_yaw(face), r, low - top, reserve_it)
	spec["foundation"] = top - low + 0.8
	return place(Buildings.house(spec), p, face_yaw(face), r, 0.0, reserve_it)


## Island-space point of `local` inside a placed node.
func local_point(node: Node3D, local: Vector3) -> Vector2:
	var w := node.transform * local if node.get_parent() == isl else isl.to_local(node.to_global(local))
	return Vector2(w.x, w.z)


## Island-space point of a named Marker3D inside a placed node (its origin without one).
func marker_point(node: Node3D, marker: String) -> Vector2:
	var m := node.get_node_or_null(marker) as Node3D
	return local_point(node, m.position if m else Vector3.ZERO)


func marker_y(node: Node3D, marker: String) -> float:
	var m := node.get_node_or_null(marker) as Node3D
	var local := m.position if m else Vector3.ZERO
	return (node.transform * local).y if node.get_parent() == isl else isl.to_local(node.to_global(local)).y


## The direction a named marker faces (island space).
func marker_face(node: Node3D, marker: String) -> Vector2:
	var m := node.get_node_or_null(marker) as Node3D
	var yaw := node.rotation.y + (m.rotation.y if m else 0.0)
	if node.get_parent() != isl:
		yaw += _rel().basis.get_euler().y
	return Vector2(sin(yaw), cos(yaw))


## Runs `fn` and adds its ms to build_ms[piece].
func timed(piece: String, fn: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	fn.call()
	build_ms[piece] = int(build_ms.get(piece, 0)) + int((Time.get_ticks_usec() - t0) / 1000)
