extends RefCounted
## The volcanic isle's forge town (VolcanicTheme.plan_places / place_steps; docs/volcanic_island_plan.md): the smiths'
## yard at the town's edge on the mountain's side (a theme place, so it gets its own trail, its ground kept clear and
## its plants kept off). Under an open slate-roofed shed the great forge, its hearth fed by a trough of the mountain's
## own lava (emissive, one light from the budget), a chimney smoking; two anvils with a smith at each (the ring of the
## hammer and a spit of embers near you), quench barrels, a weapon rack, an ore cart and a slag heap; in its corner the
## master tinkerer at his bench (a gadget Workbench, Workbench.place style "forge"), who teaches a blueprint you don't
## know for gold (Gadgets.teach). Each captain learns on their own machine (a captain's blueprints are their own).

const KIND := "volcanic_forge"
const R := 13.0
## How far out of the village's middle (the village's KEEP_OFF is 58 m) and how flat its ground must be.
const OUT := [70.0, 110.0]
const SLOPE := 0.16
## A blueprint's price: BASE + PER_TIER x the island's tier.
const BASE := 120
const PER_TIER := 60
const Tinkerer := preload("res://scripts/island/themes/volcanic_tinkerer.gd")
const Anvil := preload("res://scripts/island/themes/volcanic_anvil.gd")


## The forge yard's ground (GenIsland.prepare, worker): out of the village toward the mountain first, flat, clear of
## the sites and the flows; its people's bodies made ahead. [] when there's no room (nothing guaranteed).
static func plan_places(isl, avoid: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), KIND])
	var vil: Vector2 = isl.sites.get("village", Vector2.ZERO)
	var lp: Dictionary = isl.land_plan
	var up: Vector2 = ((lp["cone"]["c"] as Vector2) - vil).normalized()
	var L := preload("res://scripts/island/themes/volcanic_land.gd")
	for k in range(80):
		var a := up.angle() + rng.randf_range(-0.6, 0.6) * (1.0 + k / 20.0)
		var p := vil + Vector2.from_angle(a) * rng.randf_range(OUT[0], OUT[1])
		var h: float = isl.hv(p)
		if h < 2.0 or KitLandmarks.grad(isl, p, R * 0.6).length() > SLOPE or not KitLandmarks.clear_of(isl, p, R, avoid) or isl.path_dist(p) < 4.0:
			continue
		if L.flow_near(lp, p)[0] < float(lp["flows"][int(L.flow_near(lp, p)[1])]["w"]) + R:
			continue
		var face := (KitSetPieces._nearest_path(isl, p) - p).normalized()
		var st := KitStyle.of(isl.theme)
		var looks: Array = []
		for i in range(3):
			var lk := KitStyle.folk_look(st, rng)
			var hm := Humanoid.new()
			hm.setup(lk)
			Humanoid.stock(hm, lk)
			looks.append(lk)
		return [{"kind": KIND, "at": p, "y": h, "face": face, "r": R, "door": p + face * (R * 0.9), "keep": [[Vector2.ZERO, R]], "looks": looks}]
	return []


static func steps(isl, ctx, pl: Dictionary) -> Array:
	return [func(): _yard(isl, ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _people(isl, ctx, pl)]


## The yard (place-local: +z toward its way in).
static func _yard(isl, ctx, pl: Dictionary, node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"])
	var basalt := PSXMat.lit("volcanic_basalt", Color.WHITE, {"affine": 0.6})
	var brick := PSXMat.lit("stone_brick", Color(0.6, 0.56, 0.54), {"affine": 0.6})
	var beam := PSXMat.lit("planks_dark", Color(0.7, 0.66, 0.62))
	var slate := PSXMat.lit("volcanic_slate", Color.WHITE)
	var iron := PSXMat.flat(Color(0.13, 0.12, 0.12))
	var brass := PSXMat.lit("metal", Color(0.86, 0.66, 0.3))
	var wood := PSXMat.lit("planks", Color(0.62, 0.52, 0.42))
	var lava := KitLandmarks.flow_mat("volcanic_lava", Color(1.0, 0.62, 0.32), Vector2(0.03, 0.06), 2.6)
	var glow := PSXMat.glow(Color(1.0, 0.45, 0.12), 2.2)
	var cinder := PSXMat.lit("volcanic_cinder", Color(0.9, 0.86, 0.84))
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "Yard"
	var y0 := float(pl["y"])
	var gy := func(x: float, z: float) -> float: return float(isl.hv(KitLandmarks.lp(pl, x, z))) - y0
	var at := func(x: float, z: float, up := 0.0) -> Vector3: return Vector3(x, gy.call(x, z) + up, z)
	var box := func(m: Material, x: float, z: float, up: float, size: Vector3, col := true, b := Basis()) -> void:
		var xf := Transform3D(b, at.call(x, z, up))
		mb.add_box(m, xf, size, 0.5, Color.WHITE.darkened(rng.randf() * 0.12))
		if col:
			KitLandmarks.box_col_xf(body, size, xf)
	# the yard's trodden cinder floor
	var ground := MeshBuilder.new()
	for i in range(20):
		var a0 := TAU * i / 20.0
		var a1 := TAU * (i + 1) / 20.0
		var c := Vector3(0, gy.call(0, 0) + 0.06, 0)
		var p0 := Vector3(cos(a0) * (R - 1.5), 0, sin(a0) * (R - 1.5))
		var p1 := Vector3(cos(a1) * (R - 1.5), 0, sin(a1) * (R - 1.5))
		p0.y = gy.call(p0.x, p0.z) + 0.06
		p1.y = gy.call(p1.x, p1.z) + 0.06
		ground.add_tri(cinder, c, p0, p1, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(c.x, c.z) * 0.25, Vector2(p0.x, p0.z) * 0.25, Vector2(p1.x, p1.z) * 0.25, Color.WHITE, Vector3.UP)
	var gmi := ground.to_instance("Floor")
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gmi.visibility_range_end = 220.0
	node.add_child(gmi)
	# the great forge: a basalt hearth with the lava trough in its top, a brick chimney behind, bellows at its side
	box.call(basalt, 0.0, -4.2, 0.5, Vector3(3.4, 1.0, 2.2))
	box.call(basalt, 0.0, -4.2, 1.05, Vector3(3.0, 0.1, 1.8), false)
	var trough: Vector3 = at.call(0.0, -4.2, 1.12)
	KitLandmarks.water_disc(mb, lava, trough, 0.8, 10, 0.4)
	mb.add_box(lava, Transform3D(Basis(), trough + Vector3(0, -0.02, 0)), Vector3(2.6, 0.02, 1.4))
	mb.add_cylinder(brick, Transform3D(Basis(), at.call(0.0, -5.8, 0.0)), 0.9, 0.6, 8.0, 7, 0.5)
	KitLandmarks.cyl_col(body, 0.85, 8.0, at.call(0.0, -5.8, 4.0))
	box.call(PSXMat.lit("leather", Color(0.5, 0.36, 0.26)), 2.2, -4.2, 0.7, Vector3(0.6, 0.5, 1.0), false, Basis(Vector3.BACK, 0.2))
	box.call(beam, 2.5, -4.2, 0.8, Vector3(0.9, 0.08, 0.12), false)
	# the shed over it: four posts, a slate roof
	for sx in [-3.6, 3.6]:
		for sz in [-7.0, -1.2]:
			box.call(beam, sx, sz, 1.9, Vector3(0.24, 3.8, 0.24))
	var top := maxf(gy.call(-3.6, -4.1), gy.call(3.6, -4.1)) + 3.8
	mb.add_gable_roof(slate, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, top, -4.1)), 7.0, 8.4, 1.6)
	# two anvils before it, a quench barrel by each, embers in a brazier between them
	for s in [-1.0, 1.0]:
		var ax: float = 2.2 * s
		box.call(wood, ax, -1.3, 0.3, Vector3(0.5, 0.6, 0.5))
		box.call(iron, ax, -1.3, 0.72, Vector3(0.7, 0.22, 0.3))
		mb.add_cone(iron, Transform3D(Basis(Vector3.BACK, -PI * 0.5 * s), at.call(ax + 0.35 * s, -1.3, 0.74)), 0.1, 0.35, 5)
		mb.add_cylinder(wood, Transform3D(Basis(), at.call(ax + 1.5 * s, -0.4, 0.0)), 0.42, 0.4, 0.9, 8, 0.6)
		mb.add_cylinder(PSXMat.flat(Color(0.08, 0.1, 0.1)), Transform3D(Basis(), at.call(ax + 1.5 * s, -0.4, 0.86)), 0.38, 0.38, 0.02, 8)
		KitLandmarks.cyl_col(body, 0.42, 0.9, at.call(ax + 1.5 * s, -0.4, 0.45))
	mb.add_cylinder(iron, Transform3D(Basis(), at.call(0.0, -0.6, 0.0)), 0.35, 0.45, 0.7, 7)
	mb.add_blob(glow, Transform3D(Basis(), at.call(0.0, -0.6, 0.72)), Vector3(0.36, 0.12, 0.36), rng, 0.3, 2, 6)
	# a rack of new blades by the shed
	box.call(beam, -5.2, -5.6, 0.9, Vector3(0.12, 1.8, 2.4), true, Basis(Vector3.UP, 0.3))
	for k in range(5):
		var z := -6.6 + k * 0.5
		var bl: Vector3 = at.call(-5.0, z, 0.3)
		mb.add_box(PSXMat.lit("metal", Color(0.78, 0.8, 0.84)), Transform3D(Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, 0.12), bl + Vector3(0, 0.7, 0)), Vector3(0.04, 1.3, 0.09))
		mb.add_box(iron, Transform3D(Basis(Vector3.UP, 0.3), bl + Vector3(0, 0.05, 0)), Vector3(0.12, 0.08, 0.3))
	# the ore cart and the slag heap
	box.call(wood, -7.0, 2.6, 0.85, Vector3(1.4, 0.8, 2.0), true, Basis(Vector3.UP, 0.4))
	mb.add_blob(PSXMat.lit("volcanic_basalt", Color(0.8, 0.5, 0.35)), Transform3D(Basis(Vector3.UP, 0.4), at.call(-7.0, 2.6, 1.3)), Vector3(0.6, 0.35, 0.85), rng, 0.35, 2, 7)
	for s in [-1.0, 1.0]:
		for f in [-0.7, 0.7]:
			var wq := Vector3(-7.0, 0, 2.6) + Basis(Vector3.UP, 0.4) * Vector3(0.75 * s, 0, f)
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.BACK, PI * 0.5), at.call(wq.x, wq.z, 0.38)), 0.36, 0.36, 0.1, 8)
	for k in range(6):
		var q := Vector2(-7.5, -2.5) + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
		var s := rng.randf_range(0.5, 1.1)
		mb.add_blob(basalt, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at.call(q.x, q.y, s * 0.2)), Vector3(s, s * 0.6, s * 0.9), rng, 0.35, 2, 6, 0.5, Color(0.7, 0.62, 0.6))
		if rng.randf() < 0.4:
			mb.add_blob(glow, Transform3D(Basis(), at.call(q.x, q.y, s * 0.55)), Vector3(0.15, 0.06, 0.15), rng, 0.2, 2, 4)
	KitLandmarks.cyl_col(body, 1.8, 1.0, at.call(-7.5, -2.5, 0.4))
	# the master tinkerer's corner: a bench of gears and springs under a lean-to
	for sz in [-0.6, 3.6]:
		box.call(beam, 8.6, sz, 1.4, Vector3(0.2, 2.8, 0.2))
	var lt: Vector3 = at.call(7.6, 1.5, 2.9)
	mb.add_box(slate, Transform3D(Basis(Vector3.BACK, 0.25), lt), Vector3(2.8, 0.1, 5.0))
	box.call(wood, 8.2, 3.0, 0.45, Vector3(0.9, 0.9, 1.6))
	for k in range(5):
		var gq: Vector3 = at.call(8.2 + rng.randf_range(-0.3, 0.3), 3.0 + rng.randf_range(-0.6, 0.6), 0.92)
		mb.add_cylinder(brass, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * float(k % 2)), gq), rng.randf_range(0.08, 0.18), rng.randf_range(0.08, 0.18), 0.04, 8)
	box.call(wood, 8.8, 1.4, 1.2, Vector3(0.4, 2.4, 1.6))
	for k in range(4):
		mb.add_box(brass if k % 2 == 0 else iron, Transform3D(Basis(), at.call(8.6, 0.9 + k * 0.35, 0.6 + (k % 3) * 0.6)), Vector3(0.2, 0.18, 0.2))
	var mi := mb.to_instance("Forge")
	mi.visibility_range_end = 320.0
	node.add_child(mi)
	node.add_child(body)
	KitLights.light(ctx, node, at.call(0.0, -3.0, 1.8), 2.4, 16.0)
	var smoke := KitLandmarks.puffs(node, at.call(0.0, -5.8, 8.2), Color(0.42, 0.4, 0.38, 0.5), 10, 1.6, 1.6, 0.4)
	smoke.visibility_range_end = 260.0
	Workbench.place(node, at.call(6.6, 0.6, 0.0), PI * 0.5, {"style": "forge"})


## The smiths at their anvils and the master tinkerer at his bench.
static func _people(isl, _ctx, pl: Dictionary) -> void:
	var node: Node3D = isl.get_node("Place_" + KIND)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pl["seed"]) + 7
	var names: Array = (LifePools.of(isl.theme)["first"] as Array)
	var looks: Array = pl["looks"]
	var barks := ["Bellows! More air!", "Mind the sparks.", "Mountain-forged, every one.", "Quench! Stand back!", "Hammer, turn, hammer."]
	for i in range(2):
		var s := -1.0 if i == 0 else 1.0
		var anvil := Anvil.new()
		anvil.name = "Anvil%d" % i
		node.add_child(anvil)
		anvil.position = Vector3(2.2 * s, float(isl.hv(KitLandmarks.lp(pl, 2.2 * s, -1.3))) - float(pl["y"]) + 1.0, -1.3)
		anvil.beat = 1.25 + 0.2 * i
		_npc(isl, pl, node, "Smith %s" % names[rng.randi() % names.size()], looks[i], Vector2(2.2 * s, -0.4), Vector2(0, -1), {"barks": barks})
	var who := "Master Tinkerer %s" % names[rng.randi() % names.size()]
	var t := Tinkerer.new()
	t.name = "Tinkerer"
	t.key = isl.save_key("tinkerer")
	t.who = who
	t.price = BASE + PER_TIER * IslandContent.tier(isl)
	t.order = Gadgets.blueprint_ids()
	var orng := RandomNumberGenerator.new()
	orng.seed = int(pl["seed"]) + 11
	for k in range(t.order.size() - 1, 0, -1):
		var j := orng.randi() % (k + 1)
		var tmp = t.order[k]
		t.order[k] = t.order[j]
		t.order[j] = tmp
	node.add_child(t)
	_npc(isl, pl, node, who, looks[2], Vector2(7.0, 2.8), Vector2(0, 1), {"dialogue": t.define()})


static func _npc(isl, pl: Dictionary, node: Node3D, who: String, look: Dictionary, local: Vector2, face: Vector2, extra: Dictionary) -> NPC:
	var q := KitLandmarks.lp(pl, local.x, local.y)
	var fw := KitLandmarks.lp(pl, local.x + face.x, local.y + face.y) - q
	var cfg := {"name": who, "voice": 0.85 + float(absi(hash(who)) % 30) / 100.0, "look": look, "yaw": KitContext.face_yaw(fw)}
	cfg.merge(extra)
	var npc := NPC.new()
	npc.setup(cfg)
	npc.ground_func = isl.walk_height
	node.add_child(npc)
	npc.global_position = isl.to_global(Vector3(q.x, isl.hv(q), q.y))
	return npc
