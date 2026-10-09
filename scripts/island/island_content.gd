class_name IslandContent
extends RefCounted
## What's on a generated island's sites (GenIsland.sites), from its seed: the
## same on every screen. Built in GenIsland.finish (main thread).
##   camp   - a pirate crew round a fire, tents, a lookout tower, their named
##            captain (a miniboss) and his strongbox (GruntCamp, its own nav zone)
##   lair   - scuttlebug burrows round a hive mound, canopy spitters in the
##            trees about, the hoard they sit on
##   ruins  - a ring of old pillars, slabs and a chest in the middle
##   summit - a lookout tower with a chest on its platform and the view
##   boss   - the beast's ground (BeastArena: the silverback)
##   village - IslandVillage

const FIRST := ["Ned", "Sal", "Mags", "Bram", "Corvin", "Ysolde", "Rook", "Tamsin", "Hask", "Vel", "Odo", "Fen"]
const EPITHET := ["Bloody", "One-Eye", "Iron", "Black", "Mad", "Saltjaw", "Red", "Grinning", "Lucky", "Bonesaw", "Quiet", "Hook"]
const LOOT_WEAPONS := ["cutlass", "boarding_axe", "katana", "pistol"]


## The sites as GenIsland.finish_steps, in order: one random stream through
## them all, so it's the same island however many frames they take.
static func steps(isl: GenIsland) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.node["seed"]) + 4049
	return [
		["camp", func(): _camp(isl, rng)],
		["lair", func(): _lair(isl, rng)],
		["ruins", func(): _ruins(isl, rng)],
		["summit", func(): _summit(isl)],
		["boss", func(): BeastArena.build(isl, rng)],
		# (after the camp, the lair and the beast: its jobs watch them)
		["village", func(): IslandVillage.build(isl, rng)],
	]


## The island's loot tier (ItemData.Rarity) by its level.
static func tier(isl: GenIsland) -> int:
	return clampi((int(isl.node["level"]) - 8) / 4, 1, 4)


static func _yaw_to(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


## Island point `q` on the ground, in `n`'s space.
static func _local(isl: GenIsland, n: Node3D, q: Vector2, y: float = INF) -> Vector3:
	return n.to_local(isl.to_global(Vector3(q.x, isl.hv(q) if y == INF else y, q.y)))


static func _fire(isl: GenIsland, parent: Node3D, p: Vector2) -> void:
	var fire := Props.campfire()
	isl.place(fire, parent, p, 0.0, 1.5)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)


# ==========================================================================
# The camp
# ==========================================================================
static func _camp(isl: GenIsland, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = isl.sites["camp"]
	var site := isl.site_node("camp")
	var f: Vector2 = (isl.sites["village"] - c).normalized()
	var s := Vector2(-f.y, f.x)
	var at := func(fw: float, sd: float) -> Vector2: return c + f * fw + s * sd
	_fire(isl, site, c)
	var log_a: Vector2 = at.call(0.0, 2.4)
	var log_b: Vector2 = at.call(-2.4, -0.4)
	isl.place(StarterIsland._log(), site, log_a, StarterIsland.face_yaw(c - log_a) + PI * 0.5)
	isl.place(StarterIsland._log(), site, log_b, StarterIsland.face_yaw(c - log_b) + PI * 0.5)
	for tp in [at.call(-6.0, -3.5), at.call(-5.5, 4.0), at.call(-1.5, -6.5)]:
		isl.place(StarterIsland._tent(Color(0.62, 0.55, 0.45)), site, tp, StarterIsland.face_yaw(c - tp), 2.0)
	var rough := {"flowers": false, "trim": Color(0.36, 0.34, 0.32)}
	var shack_p: Vector2 = at.call(-11.0, 0.0)
	isl.house({"w": 5.5, "d": 4.5, "h": 2.5, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.4}.merged(rough), site, shack_p, f)
	var stash: Vector2 = at.call(4.5, 5.0)
	isl.place(Props.crate(0.9), site, stash, 0.3, 1.0)
	isl.place(Props.crate(0.7), site, stash, 0.9, 0.0, 0.9)
	for k in range(3):
		isl.place(Props.barrel(), site, at.call(6.0 + (k % 2) * 0.9, 2.0 - k * 0.8))
	isl.place(Props.weapon_rack(), site, at.call(-3.0, 6.0), StarterIsland.face_yaw(c - at.call(-3.0, 6.0)))
	for lp in [at.call(3.0, -3.0), at.call(-7.0, 4.5)]:
		isl.place(Props.lantern_post(2.4), site, lp)
	var tower_p: Vector2 = at.call(8.0, -9.0)
	isl.place(StarterIsland._lookout_tower(), site, tower_p, StarterIsland.face_yaw(f), 2.6)
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.08, 0.06, 6.0, 5, 1.0)
	var jolly := HullBuilder.jolly_material()
	pole.add_card(jolly, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, 5.5, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
	pole.add_card(jolly, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, 5.5, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
	isl.place(pole.to_instance("CampFlag"), site, at.call(4.0, -6.0), 0.3)
	# the captain and his strongbox
	var cap_name := "%s %s" % [EPITHET[rng.randi() % EPITHET.size()], FIRST[rng.randi() % FIRST.size()]]
	var t := tier(isl)
	isl.strongbox(site, shack_p + f * 3.8 + s * 2.0, StarterIsland.face_yaw(f), "camp_box", [
		["gold", rng.randi_range(20, 35) + t * 8], ["treasure", rng.randi_range(2, 4)], ["rum", 2],
		[ItemDB.tiered(LOOT_WEAPONS[rng.randi() % LOOT_WEAPONS.size()], t), 1]])
	var crew := GruntCamp.new()
	crew.name = "Camp"
	crew.respawn_time = 300.0
	crew.respawn_clearance = 70.0
	crew.warm_start = true
	# (posts in the site's space: the crew sits at its origin, and joins the tree once it's manned)
	var v3 := func(q: Vector2) -> Vector3: return _local(isl, site, q)
	var seed0 := rng.randi() % 100000
	var sit_a: Vector2 = log_a + (c - log_a).normalized() * 0.15
	var sit_b: Vector2 = log_b + (c - log_b).normalized() * 0.15
	crew.add_grunt({"post": v3.call(sit_a), "yaw": _yaw_to(sit_a, c), "mode": "sit", "seat_y": 0.42, "seed": seed0 + 1})
	crew.add_grunt({"post": v3.call(sit_b), "yaw": _yaw_to(sit_b, c), "mode": "sit", "seat_y": 0.42, "seed": seed0 + 2})
	var route := [v3.call(at.call(-4.0, 8.0)), v3.call(at.call(5.0, 8.0)), v3.call(at.call(7.0, -7.0)), v3.call(at.call(-5.0, -9.0))]
	crew.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": seed0 + 3})
	var road: Vector2 = at.call(12.0, 1.5)
	crew.add_grunt({"post": v3.call(road), "yaw": _yaw_to(road, road + f), "mode": "stand", "seed": seed0 + 4, "role": "rifle"})
	var tower_foot: Vector2 = tower_p - f * 3.0
	crew.add_grunt({"post": v3.call(tower_foot), "yaw": _yaw_to(tower_foot, tower_foot + s), "mode": "stand", "seed": seed0 + 5, "role": "rifle"})
	var lk := PirateGrunt.crew_look(rng)
	var C := CharacterLook.CLOTH
	lk.merge({"name": cap_name, "build": "broad", "height": 1.1, "hat": ["tricorn", "bandana", "bicorne"][rng.randi() % 3],
		"hat_color": C[rng.randi() % C.size()], "coat": "longcoat", "coat_color": C[rng.randi() % C.size()],
		"trim_color": CharacterLook.TRIM[rng.randi() % CharacterLook.TRIM.size()], "marks": "scar"}, true)
	var cap_post: Vector2 = shack_p + f * 4.5 - s * 1.0
	crew.add_grunt({"post": v3.call(cap_post), "yaw": _yaw_to(cap_post, cap_post + f), "mode": "stand", "seed": seed0 + 6,
		"look": lk, "captain": true, "title": "Captain " + cap_name})
	site.add_child(crew)
	var baker := isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(site, 45.0, false, isl.terrain_faces)


# ==========================================================================
# The bug lair
# ==========================================================================
static func _lair(isl: GenIsland, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = isl.sites["lair"]
	var site := isl.site_node("lair")
	# the hive: a great burrow mound in the middle
	var hive := Props.burrow(int(absf(c.x * 13.0 + c.y * 7.0)))
	hive.scale = Vector3.ONE * 2.6
	isl.place(hive, site, c, rng.randf() * TAU, 0.0, -0.3)
	var t := tier(isl)
	isl.strongbox(site, c + Vector2.from_angle(rng.randf() * TAU) * 4.0, rng.randf() * TAU, "lair_hoard", [
		["gold", rng.randi_range(15, 30) + t * 6], ["treasure", rng.randi_range(2, 3)],
		[ItemDB.tiered(LOOT_WEAPONS[rng.randi() % LOOT_WEAPONS.size()], t), 1]], 1.0)
	var nest := ScuttlebugNest.new()
	nest.name = "Burrows"
	site.add_child(nest)
	for i in range(7):
		var a := TAU * i / 7.0 + rng.randf_range(-0.3, 0.3)
		var p := c + Vector2.from_angle(a) * rng.randf_range(7.0, 12.0)
		var b := Props.burrow(int(absf(p.x * 13.0 + p.y * 7.0)))
		isl.place(b, site, p, StarterIsland.face_yaw(c - p) + PI, 0.0, -0.08)
		var front := p + (c - p).normalized() * 1.8
		nest.add_spot(_local(isl, nest, front), i % 3 == 0)
	# spitters up in the big trees round about
	var roosts := ScuttlebugNest.new()
	roosts.name = "Roosts"
	roosts.respawn_time = 60.0
	site.add_child(roosts)
	var taken: Array = []
	for crown in isl.forest_crowns:
		if roosts.spots.size() >= 5:
			break
		var g := Vector2(crown.x, crown.z)
		var d := g.distance_to(c)
		if d < 18.0 or d > 60.0 or taken.any(func(q): return g.distance_to(q) < 14.0):
			continue
		var a := rng.randf() * TAU
		var anchor: Vector3 = crown + Vector3(cos(a) * 1.4, -1.3, sin(a) * 1.4)
		var ga := Vector2(anchor.x, anchor.z)
		if anchor.y - isl.hv(ga) < 6.0:
			continue
		taken.append(g)
		roosts.add_spitter(_local(isl, roosts, ga, anchor.y), _local(isl, roosts, ga))


# ==========================================================================
# The ruins
# ==========================================================================
static func _ruins(isl: GenIsland, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = isl.sites["ruins"]
	var site := isl.site_node("ruins")
	for i in range(9):
		var a := TAU * i / 9.0 + 0.2
		var p := c + Vector2.from_angle(a) * 7.5
		if i == 3 or i == 7:
			isl.place(Props.fallen_pillar(rng.randf_range(3.5, 4.5)), site, p + Vector2.from_angle(a) * 1.5, a + PI * 0.5 + rng.randf_range(-0.3, 0.3))
			continue
		var broken := i % 2 == 0
		isl.place(Props.ruin_pillar(rng.randf_range(2.0, 4.2) if broken else 4.4, broken, i), site, p, rng.randf() * TAU)
	var slab_m := PSXMat.lit("stone_brick", Color(0.75, 0.8, 0.75))
	var mb := MeshBuilder.new()
	var y0 := isl.hv(c)
	for i in range(14):
		var p := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		mb.add_box(slab_m, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), Vector3(p.x, isl.hv(c + p) - y0 + 0.07, p.y)),
			Vector3(rng.randf_range(1.2, 2.0), 0.2, rng.randf_range(1.2, 2.0)), 0.6, Color.WHITE, true, false)
	isl.place(mb.to_instance("Slabs"), site, c)
	var t := tier(isl)
	isl.strongbox(site, c, rng.randf() * TAU, "ruins_chest", [["gold", rng.randi_range(10, 20) + t * 5], ["treasure", rng.randi_range(1, 3)],
		["rum", 1]], 1.0, 0.18)


# ==========================================================================
# The summit's lookout
# ==========================================================================
static func _summit(isl: GenIsland) -> void:
	var c: Vector2 = isl.sites["summit"]
	var site := isl.site_node("summit")
	var face: Vector2 = isl.dock_dir
	var tower := isl.place(StarterIsland._lookout_tower(), site, c, StarterIsland.face_yaw(face), 2.6)
	# a small chest up on the platform, and the view
	var t := tier(isl)
	var bag := isl.strongbox(site, c, tower.global_rotation.y, "summit_chest", [["gold", 8 + t * 4], ["treasure", 1]], 0.8)
	bag.global_position = tower.to_global(Vector3(0, 6.1, -0.6))
	var view := Area3D.new()
	view.name = "View"
	view.collision_layer = 0
	view.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 2.0, 3.4)
	cs.shape = box
	view.add_child(cs)
	tower.add_child(view)
	view.position = Vector3(0, 7.0, 0)
	var shown := [false]
	view.body_entered.connect(func(b: Node3D):
		if not shown[0] and b.is_in_group("player") and b.get("is_local"):
			shown[0] = true
			b.get_tree().call_group("hud", "show_banner", "The view from the top", "All of %s lies below." % isl.island_name, true))
