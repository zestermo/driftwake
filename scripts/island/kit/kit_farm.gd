class_name KitFarm
extends RefCounted
## Farmland (Brinehollow's windmill hamlet, 2026-10-17): fields of a crop in rows on tilled ground (one
## MultiMesh a field, unshadowed, ranged), fenced round but for a gap, a scarecrow in the grain; an
## orchard of fruit trees in rows (a MultiMesh a tree shape, a collider a trunk). A field is [centre,
## half size, yaw, crop] in island space, local +X along its rows. Reserves cover each.

const CROP_RANGE := 140.0


## Island point of field-local (x, z).
static func at(f: Array, x: float, z: float) -> Vector2:
	return (f[0] as Vector2) + Vector2(x, z).rotated(-float(f[2]))


## Is p inside field f (grown by `pad`)?
static func inside(f: Array, p: Vector2, pad := 0.0) -> bool:
	var l := (p - (f[0] as Vector2)).rotated(float(f[2]))
	var h: Vector2 = f[1]
	return absf(l.x) <= h.x + pad and absf(l.y) <= h.y + pad


## 0..1 tilled ground at p (the terrain's splat): full inside, gone 1.5 m out.
static func tilled(fields: Array, p: Vector2) -> float:
	var best := 0.0
	for f in fields:
		var l := (p - (f[0] as Vector2)).rotated(float(f[2]))
		var h: Vector2 = f[1]
		var d := maxf(absf(l.x) - h.x, absf(l.y) - h.y)
		best = maxf(best, 1.0 - clampf((d + 0.5) / 2.0, 0.0, 1.0))
	return best


## Reserve a field's ground (circles over it) so nothing grows or stands in it.
static func reserve(ctx: KitContext, f: Array, pad := 0.5) -> void:
	var h: Vector2 = f[1]
	var nx := maxi(int(ceil(h.x * 2.0 / 4.0)), 1)
	var nz := maxi(int(ceil(h.y * 2.0 / 4.0)), 1)
	for i in range(nx + 1):
		for j in range(nz + 1):
			ctx.reserve(at(f, -h.x + h.x * 2.0 * i / nx, -h.y + h.y * 2.0 * j / nz), 2.9 + pad)


## A field: crop clumps in rows, fence round it (a gap in its -Z side's middle), a scarecrow in grain.
static func field(ctx: KitContext, f: Array, rng: RandomNumberGenerator, n: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Field%d" % n
	ctx.add(node)
	var crop: String = f[3]
	var h: Vector2 = f[1]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BrinehollowModels.crop_mesh(crop)
	var xfs: Array = []
	var row := 0.9 if crop != "vines" else 1.4
	var step := 0.55 if crop == "wheat" else (0.7 if crop == "greens" else 0.9)
	var z := -h.y + row * 0.5
	while z < h.y:
		var x := -h.x + step * 0.5
		while x < h.x:
			var q := at(f, x + rng.randf_range(-0.08, 0.08), z + rng.randf_range(-0.06, 0.06))
			var s := rng.randf_range(0.85, 1.15)
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, ctx.hv(q) - 0.02, q.y)))
			x += step
		z += row
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crop"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = CROP_RANGE
	node.add_child(mmi)
	# the fence: each side in runs of about 3 m, a gap for the gate on -Z
	var yaw := float(f[2])
	for side in range(4):
		var along := h.x if side % 2 == 0 else h.y
		var runs := maxi(int(round(along * 2.0 / 3.0)), 1)
		for k in range(runs):
			var t0 := -along + along * 2.0 * k / runs
			var t1 := -along + along * 2.0 * (k + 1) / runs
			if side == 0 and absf((t0 + t1) * 0.5) < along * 2.0 / runs * 0.6:
				continue
			var a: Vector2
			var b: Vector2
			match side:
				0:
					a = at(f, t0, -h.y - 0.4)
					b = at(f, t1, -h.y - 0.4)
				1:
					a = at(f, h.x + 0.4, t0)
					b = at(f, h.x + 0.4, t1)
				2:
					a = at(f, t1, h.y + 0.4)
					b = at(f, t0, h.y + 0.4)
				_:
					a = at(f, -h.x - 0.4, t1)
					b = at(f, -h.x - 0.4, t0)
			var seg := Props.fence_segment(a.distance_to(b), 0.85)
			ctx.under(node).put(seg, Vector3(a.x, minf(ctx.hv(a), ctx.hv(b)), a.y), KitContext.face_yaw(b - a))
	if crop == "wheat":
		var sc := at(f, rng.randf_range(-h.x, h.x) * 0.4, rng.randf_range(-h.y, h.y) * 0.4)
		ctx.under(node).place(BrinehollowModels.scarecrow(rng.randi()), sc, rng.randf() * TAU)
	reserve(ctx, f)
	return node


## An orchard: fruit trees every `gap` m across f, a shape of three, each with a trunk collider.
static func orchard(ctx: KitContext, f: Array, rng: RandomNumberGenerator, gap := 5.0) -> Node3D:
	var node := StaticBody3D.new()
	node.name = "Orchard"
	node.collision_layer = 1
	node.collision_mask = 0
	var meshes := [BrinehollowModels.fruit_tree_mesh(1), BrinehollowModels.fruit_tree_mesh(2), BrinehollowModels.fruit_tree_mesh(3)]
	var by: Array = [[], [], []]
	var h: Vector2 = f[1]
	var x := -h.x + gap * 0.5
	while x < h.x:
		var z := -h.y + gap * 0.5
		while z < h.y:
			var q := at(f, x + rng.randf_range(-0.4, 0.4), z + rng.randf_range(-0.4, 0.4))
			var s := rng.randf_range(0.85, 1.15)
			var y := ctx.hv(q) - 0.05
			by[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(q.x, y, q.y)))
			KitLandmarks.cyl_col(node, 0.2 * s, 1.8, Vector3(q.x, y, q.y))
			z += gap
		x += gap
	for i in range(3):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = by[i].size()
		for k in range(by[i].size()):
			mm.set_instance_transform(k, by[i][k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 400.0
		node.add_child(mmi)
	ctx.add(node)
	reserve(ctx, f, 0.0)
	return node
