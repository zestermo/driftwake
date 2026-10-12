class_name KitLandmarks
extends RefCounted
## Things you see from far off and walk to: the lighthouse with its keeper's
## cottage, a ring of ruins round a standing stone, a lookout tower, the harbour
## tower, the dock crane, the chapel. Each wants its own levelled ground (the
## island's flat zones) and reserves what it stands on.


## The lighthouse at c (its door toward `face`, sunk `sink` m), the keeper's
## cottage at c + `hut_off` facing `hut_face`, and `stores` (barrel, then crates)
## at c + each offset. Returns the cottage.
static func lighthouse(ctx: KitContext, c: Vector2, face: Vector2, hut: Dictionary, hut_off: Vector2, hut_face: Vector2, stores: Array = [], sink := -0.3) -> Node3D:
	ctx.place(Props.lighthouse(), c, KitContext.face_yaw(face), 3.5, sink)
	var cottage := ctx.house(hut, c + hut_off, hut_face)
	for i in range(stores.size()):
		ctx.place(Props.barrel() if i == 0 else Props.crate(0.7), c + stores[i])
	return cottage


## A ring of old pillars (`n`, two of them fallen) round slabs and a standing
## stone you can examine (`dialogue`, "" for none). Returns the stone (or null).
static func ruins(ctx: KitContext, c: Vector2, rng: RandomNumberGenerator, dialogue := "driftstone", stone_face := Vector2(0.6, -0.8), n := 9, r := 7.5, clear := 9.5) -> Node3D:
	ctx.reserve(c, clear)
	for i in range(n):
		var a := TAU * i / n + 0.2
		var p := c + Vector2(cos(a), sin(a)) * r
		if i == 3 or i == 7:
			var fp := Props.fallen_pillar(rng.randf_range(3.5, 4.5))
			ctx.place(fp, p + Vector2(cos(a), sin(a)) * 1.5, a + PI * 0.5 + rng.randf_range(-0.3, 0.3))
			continue
		var broken := i % 2 == 0
		ctx.place(Props.ruin_pillar(rng.randf_range(2.0, 4.2) if broken else 4.4, broken, i), p, rng.randf() * TAU)
	# floor slabs
	var slab_m := PSXMat.lit("stone_brick", Color(0.75, 0.8, 0.75))
	var mb := MeshBuilder.new()
	for i in range(14):
		var p := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		var y := ctx.hv(c + p) + 0.02
		mb.add_box(slab_m, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), Vector3(p.x, y - ctx.hv(c) + 0.05, p.y)),
			Vector3(rng.randf_range(1.2, 2.0), 0.2, rng.randf_range(1.2, 2.0)), 0.6, Color.WHITE, true, false)
	ctx.put(mb.to_instance("Slabs"), Vector3(c.x, ctx.hv(c), c.y))
	if dialogue == "":
		return null
	var stone := ctx.place(Props.driftstone(), c, KitContext.face_yaw(stone_face), 1.5, -0.2)
	var inter := Interactable.new()
	inter.name = "Examine"
	inter.collision_layer = 512
	inter.collision_mask = 0
	inter.prompt_text = "Examine the Driftstone"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.8
	cs.shape = sph
	cs.position = Vector3(0, 1.5, 0)
	inter.add_child(cs)
	stone.add_child(inter)
	inter.interacted.connect(func(_p): Dialogue.start(dialogue, stone))
	return stone


static func harbour_tower(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	return ctx.place(Buildings.harbor_tower(), p, KitContext.face_yaw(face), 3.4)


static func crane(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	return ctx.place(Buildings.dock_crane(), p, KitContext.face_yaw(face), 1.2)


static func chapel(ctx: KitContext, p: Vector2, face: Vector2) -> Node3D:
	return ctx.place(Buildings.chapel(), p, KitContext.face_yaw(face), 6.2)


## A lookout tower: four posts, a railed platform at 6 m, a ladder up the +Z side.
static func lookout_tower() -> StaticBody3D:
	const H := 6.0
	const W := 1.4
	var body := StaticBody3D.new()
	body.name = "LookoutTower"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var planks := PSXMat.lit("planks_dark")
	for sx in [-W, W]:
		for sz in [-W, W]:
			mb.add_cylinder(wood, Transform3D(Basis(), Vector3(sx, -0.6, sz)), 0.14, 0.12, H + 1.8, 5, 1.0)
			cyl_col(body, 0.14, H + 1.8, Vector3(sx, H * 0.5 + 0.3, sz))
	# cross bracing on the sides
	for side in range(4):
		var b := Basis(Vector3.UP, side * PI * 0.5)
		mb.add_box(wood, Transform3D(b * Basis(Vector3.BACK, atan2(W * 2.0, 4.5)), b * Vector3(0, 2.8, W)), Vector3(0.1, Vector2(W * 2.0, 4.5).length(), 0.1), 1.0)
	mb.add_box(planks, Transform3D(Basis(), Vector3(0, H, 0)), Vector3(W * 2 + 0.6, 0.18, W * 2 + 0.6), 0.6)
	box_col(body, Vector3(W * 2 + 0.6, 0.2, W * 2 + 0.6), Vector3(0, H, 0))
	# rail on three sides, the ladder side open above the rungs
	var e := W + 0.3
	for k in range(4):
		var b := Basis(Vector3.UP, k * PI * 0.5)
		var top := b * Vector3(0, H + 1.0, e)
		if k == 0:
			for x in [-e, e]:
				mb.add_box(wood, Transform3D(Basis(), Vector3(x, H + 0.5, e)), Vector3(0.1, 1.0, 0.1), 1.0)
			mb.add_box(wood, Transform3D(Basis(), Vector3(0, H + 1.0, e)), Vector3(e * 2, 0.08, 0.08), 1.0)
			continue
		mb.add_box(planks, Transform3D(b, b * Vector3(0, H + 0.5, e)), Vector3(e * 2, 1.0, 0.08), 0.6)
		box_col(body, (b * Vector3(e * 2, 1.0, 0.1)).abs(), b * Vector3(0, H + 0.5, e))
		mb.add_box(wood, Transform3D(b, top), Vector3(e * 2 + 0.1, 0.1, 0.14), 1.0)
	# a little roof against the sun
	mb.add_pyramid_roof(PSXMat.lit("thatch"), Transform3D(Basis(), Vector3(0, H + 2.3, 0)), e * 2 + 0.5, e * 2 + 0.5, 1.1)
	for x in [-e, e]:
		for z in [-e, e]:
			mb.add_box(wood, Transform3D(Basis(), Vector3(x, H + 1.65, z)), Vector3(0.08, 1.3, 0.08), 1.0)
	body.add_child(mb.to_instance("TowerMesh"))
	var lad := Ladder.new()
	lad.length = H
	lad.rail = 1.0
	lad.deck_depth = 1.0
	lad.position = Vector3(0, H + 0.09, e)
	body.add_child(lad)
	return body


## A cylinder collider centred at `at`.
static func cyl_col(body: Node3D, r: float, h: float, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


static func box_col(body: Node3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	body.add_child(cs)
