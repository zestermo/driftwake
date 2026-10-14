class_name KitLife
extends RefCounted
## The people: an island's cast as data (who, where, facing what, their looks,
## dialogue ids, shops, barks with story flags, walking routes), made into NPCs.
## A cast entry is {"cfg": NPC.setup's dictionary, "at": Vector2, "face": Vector2,
## "y": float (optional: a floor or a seat above the ground)}; `at_marker` fills
## at/face/y from a building's Marker3D (the tavern's Barkeep, a stall's Vendor).
## A walk-on's look comes from its name (`look_for`) so every screen sees the same
## face; GenIsland builds villagers' bodies ahead on its worker (Humanoid.stock).


## Makes the cast's NPCs, in order. Returns them.
static func spawn(ctx: KitContext, cast: Array) -> Array:
	var out: Array = []
	for e in cast:
		out.append(npc(ctx, e["cfg"], e["at"], e["face"], float(e.get("y", INF))))
	return out


## One NPC at p looking toward `face` when idle, on the ground (or at `y`).
static func npc(ctx: KitContext, cfg: Dictionary, p: Vector2, face: Vector2, y: float = INF) -> NPC:
	var n := NPC.new()
	cfg["yaw"] = atan2(-face.x, -face.y)
	n.setup(cfg)
	n.ground_func = ctx.isl.walk_height
	ctx.put(n, Vector3(p.x, ctx.hv(p) if y == INF else y, p.y), n.rotation.y)
	return n


## {"at", "face", "y"} of a named marker inside a placed building.
static func at_marker(ctx: KitContext, node: Node3D, marker: String) -> Dictionary:
	return {"at": ctx.marker_point(node, marker), "face": ctx.marker_face(node, marker), "y": ctx.marker_y(node, marker)}


## Waypoints on the ground through `pts` (or all at height `y`).
static func route(ctx: KitContext, pts: Array, y: float = INF) -> Array:
	var r: Array = []
	for q in pts:
		r.append(Vector3(q.x, ctx.hv(q) if y == INF else y, q.y))
	return r


## A walk round c: `n` waypoints at radius r.
static func ring(ctx: KitContext, c: Vector2, r: float, n := 5) -> Array:
	var pts: Array = []
	for i in range(n):
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return route(ctx, pts)


## A random look seeded by the name (the same on every screen), named.
static func look_for(who: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(who)
	var lk := CharacterLook.random_look(rng)
	lk["name"] = who
	return lk


# --------------------------------------------------------------------------
# Routines (Villager): a walk between spots is one's lane in to the hub ring, round it, the other's lane out
# --------------------------------------------------------------------------
const HUB_R := 6.0


## A lane straight in from `at` to the hub ring, turned aside from what's built (`blockers`: [centre, radius]).
static func lane_in(hub: Vector2, at: Vector2, blockers: Array) -> PackedVector2Array:
	return PackedVector2Array([at, to_ring(hub, at, blockers)])


## The point on the hub ring to head for from `from`: straight in, or the nearest
## turn either side whose line misses every blocker (but one `from` stands in).
static func to_ring(hub: Vector2, from: Vector2, blockers: Array) -> Vector2:
	var a := (from - hub).angle()
	var near := blockers.filter(func(b): return from.distance_to(b[0]) > float(b[1]))
	for k in range(11):
		var q := hub + Vector2.from_angle(a + 0.15 * float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)) * HUB_R
		if not near.any(func(b): return Geometry2D.get_closest_point_to_segment(b[0], from, q).distance_to(b[0]) < float(b[1]) + 0.4):
			return q
	return hub + Vector2.from_angle(a) * HUB_R


## A lane from `at` (off the path) along `path` back to the village: from the path
## point nearest `at` to the first one within `enter` m of the hub, then to the ring.
static func lane_along(hub: Vector2, at: Vector2, path: PackedVector2Array, enter: float, blockers: Array) -> PackedVector2Array:
	var near := 0
	for i in range(path.size()):
		if path[i].distance_squared_to(at) < path[near].distance_squared_to(at):
			near = i
	var step := -1 if path[0].distance_to(hub) < path[path.size() - 1].distance_to(hub) else 1
	var lane := PackedVector2Array([at])
	var i := near
	while i >= 0 and i < path.size() and path[i].distance_to(hub) > enter:
		lane.append(path[i])
		i += step
	lane.append(to_ring(hub, lane[lane.size() - 1], blockers))
	return lane


## The walk from spot a to spot b: a's lane in, round the hub ring the short way, b's lane out.
static func walk(hub: Vector2, a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	if a == b:
		return PackedVector2Array([a[0], b[0]])
	var out := a.duplicate()
	var a0 := (a[a.size() - 1] - hub).angle()
	var a1 := (b[b.size() - 1] - hub).angle()
	var span := angle_difference(a0, a1)
	var n := int(absf(span) / 0.4)
	for k in range(1, n + 1):
		out.append(hub + Vector2.from_angle(a0 + span * k / (n + 1)) * HUB_R)
	for k in range(b.size() - 1, -1, -1):
		out.append(b[k])
	return out


## Distance along `pts` to each point.
static func measure(pts: PackedVector2Array) -> PackedFloat32Array:
	var cum := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		cum.append(cum[k - 1] + pts[k - 1].distance_to(pts[k]))
	return cum


## [point, heading] `d` m along `pts`.
static func sample(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Array:
	var k := cum.bsearch(d, true)
	k = clampi(k, 1, pts.size() - 1)
	var seg := pts[k] - pts[k - 1]
	var u := clampf((d - cum[k - 1]) / maxf(cum[k] - cum[k - 1], 0.001), 0.0, 1.0)
	return [pts[k - 1] + seg * u, seg.normalized()]


## [stay, seconds into it] at `hour`: the last stay begun by then (stays sorted by "h", the day wrapping).
static func stay_at(stays: Array, hour: float) -> Array:
	var k := stays.size() - 1
	for i in range(stays.size()):
		if float(stays[i]["h"]) <= hour:
			k = i
	return [k, DayClock.secs_between(float(stays[k]["h"]), hour)]
