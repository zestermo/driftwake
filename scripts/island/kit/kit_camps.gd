class_name KitCamps
extends RefCounted
## Camps in the wilds and the people in them: a campfire with its crackle, tents
## and log seats, a castaway's camp, a pirate crew's camp with its stash and
## strongbox (GruntCamp), a pirate den with its own pier and sloop, shacks and a
## lookout, a training yard. Crews take their grunts' seeds and looks from the
## caller, so the same island always has the same men in the same places.


## Where a 2.4 m Props.lantern_post's lamp is (the light the camps' lit posts take).
const LAMP_AT := Vector3(0.55, 1.85, 0.0)


## A campfire with its crackle (an Ambience loop).
static func campfire(ctx: KitContext, p: Vector2, footprint := 1.5) -> Node3D:
	var fire := Props.campfire()
	ctx.place(fire, p, 0.0, footprint)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)
	return fire


## Canvas A-frame tent (opening toward +Z) with a collider.
static func tent(tint: Color) -> StaticBody3D:
	var t := StaticBody3D.new()
	t.name = "Tent"
	var mb := MeshBuilder.new()
	var canvas := PSXMat.lit("canvas", tint)
	var wood := PSXMat.lit("bark")
	mb.add_gable_roof(canvas, Transform3D.IDENTITY, 2.2, 2.6, 1.6, 0.0, 0.6, Color.WHITE)
	# back wall + poles
	mb.add_tri(canvas, Vector3(-1.1, 0, -1.3), Vector3(1.1, 0, -1.3), Vector3(0, 1.6, -1.3),
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), Color(0.8, 0.8, 0.8), Vector3.FORWARD)
	for z in [-1.35, 1.35]:
		mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, 0, z)), 0.05, 0.05, 1.75, 5, 1.0)
	t.add_child(mb.to_instance())
	var tcs := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(2.2, 1.6, 2.6)
	tcs.shape = tbox
	tcs.position = Vector3(0, 0.8, 0)
	t.add_child(tcs)
	return t


## A log seat (along local X, top at 0.4).
static func log_seat() -> MeshInstance3D:
	var log_mb := MeshBuilder.new()
	log_mb.add_cylinder(PSXMat.lit("bark"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.9, 0.2, 0)), 0.2, 0.2, 1.8, 6, 1.0, Color.WHITE, true, true)
	var lg := log_mb.to_instance("Log")
	Props.seats().pair(lg, 0.4, 0.45)
	return lg


## A log seat at p, side-on to the fire at c.
static func log_by(ctx: KitContext, p: Vector2, c: Vector2) -> void:
	ctx.place(log_seat(), p, KitContext.face_yaw(c - p) + PI * 0.5)


## Where a grunt sits on a log at `log_p` round the fire at c.
static func seat_on(log_p: Vector2, c: Vector2) -> Vector2:
	return log_p + (c - log_p).normalized() * 0.15


## A grunt's yaw looking from `from` at `at` (grunts face -Z).
static func look_yaw(from: Vector2, at: Vector2) -> float:
	var d := at - from
	return atan2(-d.x, -d.y)


## A strongbox: a LootBag with the treasure-chest model, named in the save by
## ctx.save_key(key). `items`: [id or ItemData, count].
static func strongbox(ctx: KitContext, p: Vector2, yaw: float, key: String, items: Array, size := 1.15, y_offset := 0.0) -> LootBag:
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var stacks: Array[ItemStack] = []
	for e in items:
		var st := ItemStack.new()
		st.item = e[0] if e[0] is ItemData else ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		stacks.append(st)
	bag.setup(stacks)
	bag.save_id = ctx.save_key(key)
	ctx.place(bag, p, yaw, 0.0, y_offset)
	var chest_mesh := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	chest_mesh.mesh = Props.treasure_chest_mesh()
	chest_mesh.position = Vector3.ZERO
	chest_mesh.scale = Vector3.ONE * size
	return bag


## A flag on a pole. opts: h (pole), r ([foot, top]), cloth (a tint, or none),
## at (the cloth's [y, z] on the pole), size (Vector2), jolly (the skull too).
static func flag(node_name: String, opts: Dictionary) -> MeshInstance3D:
	var h := float(opts.get("h", 4.2))
	var r: Array = opts.get("r", [0.07, 0.05])
	var at: Array = opts.get("at", [h - 0.4, 0.45])
	var size: Vector2 = opts.get("size", Vector2(0.9, 0.55))
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, r[0], r[1], h, 5, 1.0)
	if opts.has("cloth"):
		var flag_mat := PSXMat.lit("cloth_red", opts["cloth"])
		pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, at[0], at[1])), size.x, size.y, Rect2(0, 0, 0.5, 0.5))
		pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, at[0], at[1])), size.x, size.y, Rect2(0, 0, 0.5, 0.5))
	if opts.get("jolly", false):
		var jolly := HullBuilder.jolly_material()
		pole.add_card(jolly, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, at[0], at[1])), 0.9, 0.55, Rect2(0, 0, 1, 1))
		pole.add_card(jolly, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, at[0], at[1])), 0.9, 0.55, Rect2(0, 0, 1, 1))
	return pole.to_instance(node_name)


# --------------------------------------------------------------------------
# A castaway's camp
# --------------------------------------------------------------------------
## A fire, a tent facing it at c + `tent_off`, a log seat at c + `log_off`.
static func castaway(ctx: KitContext, c: Vector2, tent_off: Vector2, log_off: Vector2, log_yaw := 0.2) -> void:
	campfire(ctx, c)
	var tent_p := c + tent_off
	ctx.place(tent(ctx.style["tent"]), tent_p, KitContext.face_yaw(c - tent_p), 2.0)
	ctx.place(log_seat(), c + log_off, log_yaw)


# --------------------------------------------------------------------------
# A pirate crew's camp
# --------------------------------------------------------------------------
## A crew's hideout round a fire at c, laid out along `to_sea` (the beach side):
## log seats, three tents, a contraband stash, a rowboat pulled up, a weapon
## rack, lanterns, the crew's flag and a strongbox (`chest`: [key, items]). The
## crew (GruntCamp `crew_name`): two at the fire, a rifleman on watch toward
## `watch`, one on patrol, a rifleman by the boat; `seeds` their five seeds.
static func pirate_camp(ctx: KitContext, c: Vector2, to_sea: Vector2, watch: Vector2, chest: Array, seeds: Array, crew_name := "Camp", clear := 16.0) -> GruntCamp:
	var side := Vector2(-to_sea.y, to_sea.x)
	var at := func(f: float, s_: float) -> Vector2: return c + to_sea * f + side * s_
	ctx.reserve(c, clear)
	campfire(ctx, c)
	var log_a: Vector2 = at.call(0.0, 2.3)
	var log_b: Vector2 = at.call(-2.3, -0.2)
	log_by(ctx, log_a, c)
	log_by(ctx, log_b, c)
	# tents (darker, patched canvas) facing the fire
	for tp in [at.call(-6.0, -3.5), at.call(-5.5, 4.0), at.call(-1.5, -6.5)]:
		ctx.place(tent(ctx.style["camp_tent"]), tp, KitContext.face_yaw(c - tp), 2.0)
	# contraband: crate stacks and barrels
	var stash: Vector2 = at.call(3.5, -4.5)
	ctx.place(Props.crate(0.9), stash, 0.2, 1.0)
	ctx.place(Props.crate(0.7), stash, 0.7, 0.0, 0.9)
	ctx.place(Props.crate(0.8), stash + side * -1.1, -0.3, 1.0)
	for k in range(3):
		ctx.place(Props.barrel(), at.call(2.0 + k * 0.9, 5.2 + (k % 2) * 0.5))
	# rowboat pulled up on the beach, weapon rack, lanterns, crew flag
	ctx.place(Props.rowboat(), at.call(10.0, 1.0), KitContext.face_yaw(to_sea) + 0.25, 1.5)
	ctx.place(Props.weapon_rack(), at.call(1.5, 4.2), KitContext.face_yaw(c - at.call(1.5, 4.2)))
	var lamps := [at.call(-3.0, 3.0), at.call(4.0, -1.5)]
	for k in range(lamps.size()):
		var post := ctx.place(Props.lantern_post(2.4), lamps[k])
		if k == 0:
			KitLights.light(ctx, post, LAMP_AT, 1.3, 9.0)
	ctx.place(flag("CrewFlag", {"cloth": ctx.style["crew_flag"]}), at.call(-3.0, -1.0), 0.4)
	var chest_p: Vector2 = at.call(-8.5, 0.5)
	strongbox(ctx, chest_p, KitContext.face_yaw(c - chest_p), chest[0], chest[1])
	# the crew
	var crew := GruntCamp.new()
	crew.name = crew_name
	ctx.parent.add_child(crew)
	var v3 := func(q: Vector2) -> Vector3: return Vector3(q.x, ctx.hv(q), q.y)
	var sit_a := seat_on(log_a, c)
	var sit_b := seat_on(log_b, c)
	crew.add_grunt({"post": v3.call(sit_a), "yaw": look_yaw(sit_a, c), "mode": "sit", "seat_y": 0.42, "seed": seeds[0]})
	crew.add_grunt({"post": v3.call(sit_b), "yaw": look_yaw(sit_b, c), "mode": "sit", "seat_y": 0.42, "seed": seeds[1]})
	var toward := (watch - c).normalized()
	var guard_p := c + toward * 9.0
	crew.add_grunt({"post": v3.call(guard_p), "yaw": look_yaw(guard_p, guard_p + toward), "mode": "stand", "seed": seeds[2], "role": "rifle"})
	var route := [v3.call(at.call(-4.0, -1.0)), v3.call(at.call(-0.5, -5.0)), v3.call(at.call(3.5, -2.5)), v3.call(at.call(1.0, 3.5))]
	crew.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": seeds[3]})
	var boat_guard: Vector2 = at.call(7.5, 2.5)
	crew.add_grunt({"post": v3.call(boat_guard), "yaw": look_yaw(boat_guard, boat_guard + to_sea), "mode": "stand", "seed": seeds[4], "role": "rifle"})
	return crew


# --------------------------------------------------------------------------
# A pirate den: a hostile crew's hold on a clifftop
# --------------------------------------------------------------------------
## Their camp at c on a plateau `top` m up, the sea off its cliff toward `to_sea`: a
## hoist out over the cliff (`hoist`: [its root on the clifftop, its tip over the water])
## with a rope ladder down to their pier at the cliff's foot, their sloop tied up
## alongside, the captain's shack, two crew shacks and a net shed, a lookout tower
## over the cliff, a fire with log seats, contraband, a fish rack, nets, a boat
## upturned for caulking, lanterns, their colours with the jolly roger, the captain's
## strongbox on his porch. The crew (GruntCamp `crew_name`, back after `respawn` s
## with nobody within `clearance`): two at the fire, a patrol, a guard at `guard`
## ([post, looking at]), a rifleman by the tower, another at the pier's end, the
## captain. opts: to_sea, hoist, top, guard, pier (length), deck_y, floor_y, hull
## (paint for HullBuilder), chest ([key, items]), seeds (7, the captain's last), captain (look), title.
static func den(ctx: KitContext, c: Vector2, opts: Dictionary, crew_name := "Den", respawn := 180.0, clearance := 60.0) -> GruntCamp:
	var pier_len := float(opts["pier"])
	var deck_y := float(opts["deck_y"])
	var f: Vector2 = opts["to_sea"]
	var s := Vector2(-f.y, f.x)
	var hoist_at: Array = opts["hoist"]
	var root: Vector2 = hoist_at[1]
	var rim := c + f * 17.0
	var at := func(fw: float, sd: float) -> Vector2: return c + f * fw + s * sd
	var pier_pt := func(d: float) -> Vector2: return root + f * d
	ctx.reserve(c, 20.0)

	hoist(ctx, hoist_at[0], root, float(opts["top"]), deck_y, "DenHoist")
	var pier := Props.dock(pier_len, 3.2, deck_y, float(opts["floor_y"]))
	ctx.put(pier, KitContext.v3(root), KitContext.face_yaw(f))
	var lad := Ladder.new()
	lad.length = deck_y + 1.0
	lad.deck_depth = 0.9
	lad.position = Vector3(0, deck_y, pier_len)
	pier.add_child(lad)
	for d in range(0, int(pier_len) + 6, 4):
		ctx.reserve(pier_pt.call(float(d)), 3.0)

	# their sloop, tied up alongside, bow out to sea
	var hull := MooredHull.new()
	hull.name = "DenSloop"
	hull.collision_layer = 1
	hull.collision_mask = 0
	var sloop_p: Vector2 = pier_pt.call(pier_len - 10.0) + s * (1.6 + HullBuilder.HALF_BEAM + 0.6)
	ctx.put(hull, Vector3(sloop_p.x, HullBuilder.FREEBOARD, sloop_p.y), KitContext.face_yaw(-f))
	var model := Node3D.new()
	hull.add_child(model)
	HullBuilder.build(model, opts["hull"])
	HullBuilder.collide(hull)
	for k in range(3):
		var bollard := Props.barrel() if k == 1 else Props.rope_coil()
		ctx.put(bollard, Vector3(0, deck_y, 0) + KitContext.v3(pier_pt.call(pier_len - 4.0 - k * 6.0) + s * 1.1))
	ctx.place(Props.crate(0.8), pier_pt.call(3.0) - s * 1.0, 0.4, 0.0, deck_y - ctx.hv(pier_pt.call(3.0) - s * 1.0))

	# shacks: the captain's (biggest, set back), two crew shacks, a net shed by the cliff
	var cap_p: Vector2 = at.call(-11.0, -5.0)
	var rough: Dictionary = ctx.style["rough"]
	ctx.house({"w": 7.5, "d": 5.5, "h": 2.8, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch",
		"porch": 1.8, "lean_to": "left", "name": "CaptainsShack"}.merged(rough), cap_p, f)
	var shack_a: Vector2 = at.call(-6.0, 10.0)
	ctx.house({"w": 5.0, "d": 4.0, "h": 2.3, "roof": "shed", "wall": "planks_weathered", "roof_tex": "thatch"}.merged(rough), shack_a, c - shack_a)
	var shack_b: Vector2 = at.call(2.0, -14.0)
	ctx.house({"w": 4.5, "d": 4.0, "h": 2.3, "roof": "gable", "wall": "planks", "roof_tex": "thatch", "chimney": true}.merged(rough), shack_b, c - shack_b)
	var shed: Vector2 = rim + s * 11.0 - f * 3.0
	ctx.house({"w": 4.5, "d": 3.5, "h": 2.2, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.2}.merged(rough), shed, f)

	# the lookout tower over the cliff, its ladder on the landward side
	var tower_p: Vector2 = rim - f * 2.0 - s * 11.0
	var tower := KitLandmarks.lookout_tower()
	tower.name = "DenTower"
	ctx.place(tower, tower_p, KitContext.face_yaw(-f), 2.6)

	# campfire with log seats, contraband, the crew's colours
	campfire(ctx, c)
	var log_a: Vector2 = at.call(0.0, 2.4)
	var log_b: Vector2 = at.call(-2.4, -0.4)
	log_by(ctx, log_a, c)
	log_by(ctx, log_b, c)
	var stash: Vector2 = at.call(5.0, 5.0)
	ctx.place(Props.crate(0.9), stash, 0.3, 1.0)
	ctx.place(Props.crate(0.7), stash, 0.9, 0.0, 0.9)
	ctx.place(Props.crate(0.8), stash + s * 1.2, -0.2, 1.0)
	for k in range(4):
		ctx.place(Props.barrel(), at.call(6.5 + (k % 2) * 0.9, 2.0 - k * 0.8))
	ctx.place(Props.weapon_rack(), at.call(-3.0, 6.0), KitContext.face_yaw(c - at.call(-3.0, 6.0)))
	ctx.place(Props.fish_rack(), rim + s * 5.0 - f * 3.0, KitContext.face_yaw(s), 1.5)
	ctx.place(Props.net_pile(), rim + s * 7.5 - f * 1.0)
	ctx.place(Props.upturned_boat(), rim - s * 5.0 - f * 1.0, KitContext.face_yaw(f) + 0.3, 1.5)
	var lamps := [at.call(3.0, -3.0), at.call(-7.0, 4.0), (hoist_at[0] as Vector2) - s * 2.2]
	for k in range(lamps.size()):
		var post := ctx.place(Props.lantern_post(2.4), lamps[k])
		if k > 0:
			KitLights.light(ctx, post, LAMP_AT, 1.3, 9.0)
	ctx.place(flag("DenFlag", {"h": 6.0, "r": [0.08, 0.06], "cloth": ctx.style["pirate_flag"], "at": [5.5, 0.6],
		"size": Vector2(1.2, 0.75), "jolly": true}), at.call(4.0, -6.0), 0.3)

	# the captain's strongbox on his porch
	var chest: Array = opts["chest"]
	strongbox(ctx, cap_p + f * 4.6 + s * 2.2, KitContext.face_yaw(f), chest[0], chest[1])

	# the crew
	var seeds: Array = opts["seeds"]
	var crew := GruntCamp.new()
	crew.name = crew_name
	crew.respawn_time = respawn
	crew.respawn_clearance = clearance
	ctx.put(crew, Vector3(c.x, 0.0, c.y))
	var v3 := func(q: Vector2, y: float = INF) -> Vector3: return Vector3(q.x - c.x, ctx.hv(q) if y == INF else y, q.y - c.y)
	var sit_a := seat_on(log_a, c)
	var sit_b := seat_on(log_b, c)
	crew.add_grunt({"post": v3.call(sit_a), "yaw": look_yaw(sit_a, c), "mode": "sit", "seat_y": 0.42, "seed": seeds[0]})
	crew.add_grunt({"post": v3.call(sit_b), "yaw": look_yaw(sit_b, c), "mode": "sit", "seat_y": 0.42, "seed": seeds[1]})
	var route := [v3.call(at.call(-4.0, 7.0)), v3.call(at.call(4.0, 8.0)), v3.call(at.call(6.0, -8.0)), v3.call(at.call(-5.0, -9.0))]
	crew.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": seeds[2]})
	var guard: Array = opts["guard"]
	crew.add_grunt({"post": v3.call(guard[0]), "yaw": look_yaw(guard[0], guard[1]), "mode": "stand", "seed": seeds[3]})
	var tower_guard: Vector2 = tower_p - f * 3.0
	crew.add_grunt({"post": v3.call(tower_guard), "yaw": look_yaw(tower_guard, tower_guard - f), "mode": "stand", "seed": seeds[4], "role": "rifle"})
	var pier_end: Vector2 = pier_pt.call(pier_len - 3.0)
	crew.add_grunt({"post": v3.call(pier_end, deck_y), "yaw": look_yaw(pier_end, pier_end - f), "mode": "stand", "seed": seeds[5], "role": "rifle"})
	var cap_post: Vector2 = cap_p + f * 5.0 - s * 1.0
	crew.add_grunt({"post": v3.call(cap_post), "yaw": look_yaw(cap_post, cap_post + f), "mode": "stand", "seed": seeds[6],
		"look": opts["captain"], "captain": true, "title": opts["title"]})
	return crew


## A timber hoist out over a cliff: a plank deck from `root` on the clifftop out to
## `tip` over the drop (its top at `top_y`), rope rails, struts back into the rock, a
## gallows arm with a block and hook, and a rope ladder from the tip down to `bottom_y`.
static func hoist(ctx: KitContext, root: Vector2, tip: Vector2, top_y: float, bottom_y: float, node_name: String) -> Ladder:
	var dir := (tip - root).normalized()
	var length := root.distance_to(tip)
	var body := StaticBody3D.new()
	body.name = node_name
	ctx.put(body, Vector3(root.x, top_y, root.y), KitContext.face_yaw(dir))
	var mb := MeshBuilder.new()
	var deck := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var dark := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	var w := 2.2
	var z := -1.5
	while z < length - 0.01:
		var l := minf(2.0, length - z)
		mb.add_box(deck, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, -0.12, z + l * 0.5)), Vector3(l, 0.24, w), 0.5, Color.WHITE, false, false)
		z += l
	for x in [-w * 0.5 + 0.12, w * 0.5 - 0.12]:
		mb.add_box(dark, Transform3D(Basis.IDENTITY, Vector3(x, -0.38, (length - 1.5) * 0.5)), Vector3(0.18, 0.28, length + 1.5), 0.6)
		KitLandmarks.beam(mb, dark, Vector3(x, -0.45, length - 0.5), Vector3(x, -5.0, 0.3), 0.16)
		var rail_x: float = x * 1.06
		for zz in [0.0, length * 0.5, length - 0.6]:
			mb.add_box(dark, Transform3D(Basis.IDENTITY, Vector3(rail_x, 0.5, zz)), Vector3(0.1, 1.0, 0.1), 1.0)
		KitLandmarks.beam(mb, rope, Vector3(rail_x, 0.95, 0.0), Vector3(rail_x, 0.95, length - 0.6), 0.05)
		KitLandmarks.box_col(body, Vector3(0.12, 1.0, length - 0.6), Vector3(rail_x, 0.5, (length - 0.6) * 0.5))
	# the gallows: a post at one corner, its arm out past the ladder, a block, rope and hook
	var gx := -w * 0.5 + 0.15
	mb.add_cylinder(dark, Transform3D(Basis.IDENTITY, Vector3(gx, 0.0, length - 0.2)), 0.11, 0.09, 3.0, 5, 1.0)
	KitLandmarks.cyl_col(body, 0.11, 3.0, Vector3(gx, 1.5, length - 0.2))
	KitLandmarks.beam(mb, dark, Vector3(gx, 2.9, length - 0.2), Vector3(0.0, 2.9, length + 1.3), 0.12)
	KitLandmarks.beam(mb, dark, Vector3(gx, 2.0, length - 0.2), Vector3(gx * 0.5, 2.85, length + 0.5), 0.08)
	mb.add_box(dark, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.65, length + 1.2)), Vector3(0.22, 0.3, 0.16), 1.0)
	KitLandmarks.beam(mb, rope, Vector3(0.0, 2.55, length + 1.2), Vector3(0.0, -1.6, length + 1.2), 0.03)
	mb.add_box(PSXMat.lit("", Color(0.3, 0.3, 0.32)), Transform3D(Basis.IDENTITY, Vector3(0.0, -1.7, length + 1.2)), Vector3(0.08, 0.25, 0.08), 1.0)
	KitLandmarks.box_col(body, Vector3(w, 0.3, length + 1.5), Vector3(0, -0.15, (length - 1.5) * 0.5))
	body.add_child(mb.to_instance("HoistMesh"))
	var lad := Ladder.new()
	lad.length = top_y - bottom_y + 0.1
	lad.deck_depth = 1.0
	lad.position = Vector3(0.0, 0.0, length)
	body.add_child(lad)
	return lad


## The climb up to a clifftop den (`plan`): rock slabs to jump between and a knife edge
## (`climb`: {"k": "slab", "at", "y", "r"} / {"k": "edge", "line" (Vector3s), "w"}), a
## hoist with a rope ladder from the last slab up to the top (`hoist` [root, tip], `top`,
## `ladder_y`), and at its foot (`start`, `face` toward the climb) the crew's warning:
## their colours, a skull on a pike, two torches (one lit after dark from the budget).
static func den_climb(ctx: KitContext, plan: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var node := Node3D.new()
	node.name = "DenClimb"
	ctx.put(node, Vector3.ZERO)
	var a: Array = [[], [], [], [], []]
	var rags := MeshBuilder.new()
	var stake := PSXMat.lit("bark")
	var rag := PSXMat.lit("cloth_red")
	for e in plan["climb"]:
		var shade := rng.randf_range(0.86, 1.02)
		if e["k"] == "slab":
			var p: Vector2 = e["at"]
			var r: float = e["r"]
			Coast.slab(a, rng, p, ctx.ground_min(p, r * 1.5) - 1.0, e["y"], r, shade)
			ctx.reserve(p, r + 1.0)
			# a stake with a rag on its outer lip: the crew's way up
			var out: Vector2 = e["out"]
			var sp := p + out * (r - 0.3) + out.orthogonal() * 0.4
			var foot := Vector3(sp.x, float(e["y"]) - 0.05, sp.y)
			rags.add_cylinder(stake, Transform3D(Basis.IDENTITY, foot), 0.05, 0.035, 1.15, 5, 1.0)
			var rag_at := foot + Vector3(0, 0.62, 0) + KitContext.v3(out.orthogonal()) * 0.18
			for turn in [0.0, PI]:
				rags.add_card(rag, Transform3D(Basis(Vector3.UP, KitContext.face_yaw(out) + turn), rag_at), 0.36, 0.45, Rect2(0, 0, 0.5, 0.5))
		else:
			var line: Array = e["line"]
			var low := INF
			for q in line:
				low = minf(low, ctx.ground_min(Vector2(q.x, q.z), 2.0))
				ctx.reserve(Vector2(q.x, q.z), 2.0)
			Coast.fin(a, rng, line, e["w"], low - 1.0, shade)
	Coast.build(node, {Vector2i.ZERO: Coast.pack(a)})
	node.add_child(rags.to_instance("Rags"))
	var hp: Array = plan["hoist"]
	hoist(ctx, hp[0], hp[1], plan["top"], plan["ladder_y"], "ClimbHoist")
	var foot: Vector2 = plan["start"]
	var face: Vector2 = plan["face"]
	var side := Vector2(-face.y, face.x)
	ctx.place(flag("ClimbFlag", {"h": 5.0, "r": [0.08, 0.06], "cloth": ctx.style["pirate_flag"], "at": [4.5, 0.6],
		"size": Vector2(1.2, 0.75), "jolly": true}), foot - side * 2.2, KitContext.face_yaw(side))
	var pike := MeshBuilder.new()
	var bone := PSXMat.lit("", Color(0.86, 0.82, 0.7))
	var dark := PSXMat.lit("", Color(0.08, 0.07, 0.06))
	pike.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.06, 0.04, 2.3, 5, 1.0)
	pike.add_box(bone, Transform3D(Basis.IDENTITY, Vector3(0, 2.38, 0)), Vector3(0.28, 0.26, 0.3), 1.0, Color.WHITE, false)
	pike.add_box(bone, Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0.05)), Vector3(0.2, 0.1, 0.2), 1.0)
	for x in [-0.07, 0.07]:
		pike.add_box(dark, Transform3D(Basis.IDENTITY, Vector3(x, 2.4, 0.15)), Vector3(0.08, 0.08, 0.02), 1.0)
	ctx.place(pike.to_instance("SkullPike"), foot + side * 2.2, KitContext.face_yaw(-face))
	for k in [-1.0, 1.0]:
		var t := KitHouses.torch(2.3)
		ctx.place(t, foot + side * k * 1.2 - face * 0.4, 0.0, 0.0, 0.0, false)
		if k > 0.0:
			KitLights.light(ctx, t, Vector3(0, 2.6, 0), 1.2, 9.0)
	ctx.reserve(foot, 3.5)
	return node


# --------------------------------------------------------------------------
# A training yard
# --------------------------------------------------------------------------
## A w x d fenced yard at c (4 m fence lengths, a gate gap in the middle of the
## +x side), straw dummies at `dummies` (offsets, facing +x), a weapon rack, a
## bench and a barrel.
static func training_yard(ctx: KitContext, c: Vector2, w := 22.0, d := 16.0, dummies := [Vector2(-5, -4), Vector2(-6, 2), Vector2(-3, 5)]) -> void:
	var segs := []
	for i in range(int(d / 4.0)):
		segs.append([c + Vector2(-w * 0.5, -d * 0.5 + i * 4.0), 0.0])
	for i in range(int(w / 4.0)):
		segs.append([c + Vector2(-w * 0.5 + i * 4.0, -d * 0.5), PI * 0.5])
		segs.append([c + Vector2(-w * 0.5 + i * 4.0, d * 0.5), PI * 0.5])
	for i in range(int(d / 4.0)):
		var z0 := -d * 0.5 + i * 4.0
		if z0 >= -3.0 and z0 < 3.0:
			continue
		segs.append([c + Vector2(w * 0.5, z0), 0.0])
	for sg in segs:
		ctx.place(Props.fence_segment(4.0), sg[0], sg[1])
	ctx.reserve(c, w * 0.5)
	var dummy_scene: PackedScene = load("res://scenes/enemies/dummy_target.tscn")
	for off in dummies:
		ctx.place(dummy_scene.instantiate() as Node3D, c + off, KitContext.face_yaw(Vector2(1, 0)))
	ctx.place(Props.weapon_rack(), c + Vector2(2, -7), 0.0)
	ctx.place(Props.bench(), c + Vector2(6, 6.5), PI)
	ctx.place(Props.barrel(), c + Vector2(-9.5, -6.5))
