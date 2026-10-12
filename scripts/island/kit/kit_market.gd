class_name KitMarket
extends RefCounted
## A small market square: stalls (Buildings.stall kinds) in a horseshoe opening
## toward `toward` (the plaza), a planter in the middle, wares laid out on rugs
## between the stalls (one merged mesh), sacks heaped by them, crates and barrels
## round the outside. Rugs and goods from the style.


## Returns the stalls in `kinds` order (each has a "Vendor" marker). Radii: the
## stalls, the wares, the sacks, the crates and barrels [from, to]; `clear` is
## what's reserved round the middle.
static func build(ctx: KitContext, c: Vector2, toward: Vector2, kinds: Array, rng: RandomNumberGenerator,
		ring := 6.2, wares_r := 5.4, sacks_r := 8.2, cargo_r := [8.0, 9.5], clear := 9.0) -> Array:
	var to_plaza := (toward - c).normalized()
	var base := atan2(to_plaza.y, to_plaza.x)
	var n := kinds.size()
	var spread := 73.0 * 4.0 / n
	var stalls: Array = []
	for i in range(n):
		var a := base + deg_to_rad(70.0 + i * spread)
		var sp := c + Vector2(cos(a), sin(a)) * ring
		stalls.append(ctx.place(Buildings.stall(kinds[i]), sp, KitContext.face_yaw(c - sp), 2.2))
	ctx.place(Buildings.planter(0.7), c, 0.0, 0.8)
	var gmb := MeshBuilder.new()
	var rugs: Array = []
	for rg in ctx.style["rugs"]:
		rugs.append(PSXMat.lit(rg[0], rg[1], {"affine": 0.6}))
	var basket := PSXMat.lit("straw")
	var sack := PSXMat.lit("canvas", Color(0.82, 0.74, 0.56))
	var goods: Array = ctx.style["goods"]
	for i in range(n):
		var a := base + deg_to_rad(106.0 + i * spread)
		var gp := c + Vector2(cos(a), sin(a)) * wares_r
		if i < n - 1:
			var gy := ctx.hv(gp) + 0.06
			var r: Material = rugs[i % rugs.size()]
			var e1 := Vector2(cos(a), sin(a)) * 0.7
			var e2 := Vector2(-sin(a), cos(a)) * 1.0
			var v := func(q: Vector2) -> Vector3: return Vector3(q.x, gy, q.y)
			gmb.add_quad(r, v.call(gp - e1 - e2), v.call(gp + e1 - e2), v.call(gp + e1 + e2), v.call(gp - e1 + e2), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3.UP)
			for k in range(3):
				var bp := gp + e2 * (k - 1) * 0.6
				gmb.add_cylinder(basket, Transform3D(Basis(), Vector3(bp.x, gy, bp.y)), 0.2, 0.24, 0.2, 7, 1.0)
				var fm := PSXMat.flat(goods[(i + k) % goods.size()])
				for f in range(4):
					gmb.add_blob(fm, Transform3D(Basis(), Vector3(bp.x + rng.randf_range(-0.1, 0.1), gy + 0.24 + (f / 2) * 0.06, bp.y + rng.randf_range(-0.1, 0.1))), Vector3.ONE * 0.07, rng, 0.15, 2, 4, 1.0)
		var sp := c + Vector2(cos(a + 0.25), sin(a + 0.25)) * sacks_r
		for k in range(2):
			gmb.add_blob(sack, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sp.x + k * 0.5, ctx.hv(sp) + 0.28, sp.y + (k % 2) * 0.3)), Vector3(0.3, 0.32, 0.26), rng, 0.2, 3, 6)
	ctx.add(gmb.to_instance("Wares"))
	for i in range(6):
		var a := rng.randf() * TAU
		var q := c + Vector2(cos(a), sin(a)) * rng.randf_range(cargo_r[0], cargo_r[1])
		if ctx.path_dist(q) < 2.5:
			continue
		ctx.place(Props.crate(rng.randf_range(0.55, 0.8)) if i % 2 == 0 else Props.barrel(), q, rng.randf() * TAU, 0.6)
	ctx.reserve(c, clear)
	return stalls
