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
