class_name BeastDens
extends RefCounted
## An island's minibosses and its roaming beast (BeastPool's picks in the chain
## node), put on the island in IslandContent's "beasts" step. Each watches for
## captains itself (JungleBeast.wake_r / leash_r); dead, it stays dead until the
## island is built again.
##   boar     the alpha boar in its wallow at the ruins
##   roamer   the behemoth ("Roamer" under the island: BeastPool.roamer_of), grazing
##            its way round its range's middle, the ruins, the lair and the summit


## IslandContent's "beasts" steps: each miniboss, then the roamer (a body each: a frame each).
static func steps(isl: GenIsland) -> Array:
	var out: Array = []
	for m in isl.node["minis"]:
		out.append(["beasts", func(): _mini(isl, str(m))])
	out.append(["beasts", func(): _roamer(isl)])
	return out


static func _mini(isl: GenIsland, kind: String) -> void:
	match kind:
		"boar":
			var c: Vector2 = isl.sites["ruins"]
			var at: Vector2 = c + ((isl.sites["village"] as Vector2) - c).normalized().rotated(1.2) * 9.0
			var b: JungleBeast = load(BeastPool.info(isl.theme, "boar")["script"]).new()
			b.setup({"post": _ground(isl, at), "yaw": IslandContent._yaw_to(at, c), "level": IslandContent.level(isl), "name": BeastPool.mini_name(isl, "boar")})
			b.name = "Boar"
			isl.site_node("ruins").add_child(b)
			b.global_position = b.post
			b.reset_physics_interpolation()


static func _roamer(isl: GenIsland) -> void:
	var lv := IslandContent.level(isl)
	var home := BeastPool.roam_home(isl)
	var r: JungleBeast = load(BeastPool.info(isl.theme, str(isl.node["roamer"]))["script"]).new()
	r.setup({"post": _ground(isl, home), "yaw": 0.0, "level": lv, "name": BeastPool.roamer_name(isl)})
	r.set("waypoints", [_ground(isl, home), _ground(isl, isl.sites["ruins"] + Vector2(0, 14.0)), _ground(isl, isl.sites["lair"] + Vector2(16.0, 0)),
		_ground(isl, (isl.sites["summit"] as Vector2).lerp(home, 0.3))])
	r.name = "Roamer"
	isl.add_child(r)
	r.global_position = r.post
	r.reset_physics_interpolation()


static func _ground(isl: GenIsland, p: Vector2) -> Vector3:
	return isl.to_global(Vector3(p.x, isl.hv(p) + 0.4, p.y))
