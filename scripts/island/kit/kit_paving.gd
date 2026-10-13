class_name KitPaving
extends RefCounted
## Cobbles laid over the ground, following it 5 cm up: ragged disks (a plaza, a
## market) and strips along paths. `plan_*` work out the quads (data: a worker may
## do it), `build` makes the one mesh. Ground the context marks as paved already
## (KitContext.paved: Brinehollow's quay) is skipped. Path wear (dirt along the
## paths) is the island's terrain splat, not this.


## Cobbles over a ragged disk of ground (cells of 1.5 m, the edge jittered by rng).
static func plan_disk(ctx: KitContext, quads: Array, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var s := 1.5
	var n := int(ceil(r / s))
	for ix in range(-n, n):
		for iz in range(-n, n):
			var a := c + Vector2(ix, iz) * s
			var mid := a + Vector2(s, s) * 0.5
			if mid.distance_to(c) > r - 0.8 + rng.randf() * 1.6:
				continue
			_quad(ctx, quads, a, a + Vector2(s, 0), a + Vector2(s, s), a + Vector2(0, s))


## Cobbles along a path (its half-width `hw`).
static func plan_path(ctx: KitContext, quads: Array, pts: PackedVector2Array, hw: float) -> void:
	var line := PackedVector2Array()
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var steps := maxi(int(ceil(a.distance_to(b) / 1.5)), 1)
		for k in range(steps):
			line.append(a.lerp(b, float(k) / steps))
	line.append(pts[pts.size() - 1])
	var sides: Array = []
	for i in range(line.size()):
		var t := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		sides.append(Vector2(-t.y, t.x) * hw)
	for i in range(line.size() - 1):
		var s0: Vector2 = sides[i]
		var s1: Vector2 = sides[i + 1]
		_quad(ctx, quads, line[i] - s0, line[i] + s0, line[i + 1] + s1, line[i + 1] - s1)


static func _quad(ctx: KitContext, quads: Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	if ctx.paved.is_valid() and ctx.paved.call(a) and ctx.paved.call(c):
		return
	var v := func(q: Vector2) -> Vector3: return Vector3(q.x, ctx.hv(q) + 0.05, q.y)
	quads.append([v.call(a), v.call(b), v.call(c), v.call(d), a * 0.4, b * 0.4, c * 0.4, d * 0.4])


## The cobbles' mesh (no shadow: it lies on the ground), added under the context's parent.
## `tex` (the style's paving by default) and `tint` make other ground: trodden earth.
static func build(ctx: KitContext, quads: Array, node_name := "Cobbles", tex := "", tint := Color.WHITE) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit(ctx.style["paving"] if tex == "" else tex, tint, {"affine": 0.6})
	for q in quads:
		mb.add_tri(mat, q[0], q[1], q[2], Vector3.UP, Vector3.UP, Vector3.UP, q[4], q[5], q[6], Color.WHITE, Vector3.UP)
		mb.add_tri(mat, q[0], q[2], q[3], Vector3.UP, Vector3.UP, Vector3.UP, q[4], q[6], q[7], Color.WHITE, Vector3.UP)
	var paving := mb.to_instance(node_name)
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.add(paving)
	return paving
