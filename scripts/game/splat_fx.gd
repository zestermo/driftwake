class_name SplatFX
extends RefCounted
## (1.30) The effects of a wall splat (Splat): the impact mark a body leaves on a wall, a ceiling or the ground,
## and the launch. Marks are one pool of CAP meshes for the whole game (the oldest is taken over), three shapes
## built once and one shared lit material; each holds HOLD s and shrinks away. Called on every screen (FX.splat,
## FX.splat_launch through Net.fx); the camera's shake and the launch's hit-stop are each screen's own.

const CAP := 16
const BURST_RANGE := 160.0
const HOLD := 8.0
const SHRINK := 0.9
const VARIANTS := 3
## Cameras within this far feel a splat land.
const SHAKE_RANGE := 22.0
## The captain within this far of a launch gets its hit-stop and punch-in.
const LAUNCH_NEAR := 6.0

static var _pool: Array = []
static var _next := 0


## A body slammed into a surface at `pos` (normal `n`): the mark, dust and chips, blood, the crunch, a shake.
static func land(fx: Node, pos: Vector3, n: Vector3, size: float, blood: bool, seed_v: int) -> void:
	var cam := fx.get_viewport().get_camera_3d()
	var far := cam.global_position.distance_to(pos) if cam else 0.0
	if far > BURST_RANGE:
		return
	var up := n.normalized()
	mark(fx, pos, up, size, seed_v)
	fx.puff(pos + up * 0.2, "dust", 2 + int(size * 2.0), 0.9 * size + 0.3, 0.8, Color.WHITE, 0.4, up)
	fx.debris(pos + up * 0.1, up, int(4 + 6 * size), Color(0.42, 0.36, 0.3), 3.5 + 2.0 * size)
	fx.ring(pos + up * 0.05, up, 0.6 + 0.9 * size, Color(0.95, 0.9, 0.8, 0.7), 0.25, 0.08)
	if blood:
		fx._place_splat(pos - Vector3.UP * 0.25 * size if absf(up.y) < 0.6 else pos, up, 0.18 + 0.17 * size, Vector3.DOWN if absf(up.y) < 0.6 else Vector3.ZERO)
		fx.bleed(pos + up * 0.25, (up + Vector3.DOWN * 0.3).normalized(), int(6 + 6 * size))
	fx.sfx("rock_crash", pos, -9.0 + 5.0 * size, 0.08, 1.15)
	fx.sfx("punch_heavy", pos, -4.0, 0.08, 0.8)
	if far < SHAKE_RANGE:
		fx.get_node("/root/CombatManager").apply_camera_shake((0.12 + 0.3 * size) * (1.0 - far / SHAKE_RANGE), 0.25)


## A body thrown (from `pos` along `dir`): the rush of air and dust where it left, and the local captain's punch.
static func launch(fx: Node, pos: Vector3, dir: Vector3, k: float) -> void:
	fx.ring(pos, dir, 0.55 * k, Color(1.0, 0.97, 0.9, 0.8), 0.22, 0.07)
	fx.sfx("whoosh_big", pos, -3.0, 0.08, 0.85)
	fx.puff_ring(pos - Vector3.UP * 1.1 * k, "dust_low", 5, 0.3, 0.9, 0.6, Color.WHITE, 4.0)
	var me := fx.get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(pos) < LAUNCH_NEAR:
		fx.get_node("/root/CombatManager").apply_hitstop(0.08, [me])
		fx.get_node("/root/CombatManager").apply_camera_kick(0.18, 0.35)


## The mark itself: cracks round a dent, flat on the surface, popped in, held, shrunk away.
static func mark(fx: Node, pos: Vector3, up: Vector3, size: float, seed_v: int) -> MeshInstance3D:
	var kit := _kit(fx)
	var mi := _take(fx, kit[0])
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)).rotated(up, float(seed_v % 628) / 100.0)
	mi.mesh = (kit[1] as Array)[seed_v % VARIANTS]
	mi.global_transform = Transform3D(b, pos + up * 0.01)
	mi.scale = Vector3.ONE * size * 0.55
	mi.visible = true
	if mi.has_meta("tw") and (mi.get_meta("tw") as Tween).is_valid():
		(mi.get_meta("tw") as Tween).kill()
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.001, SHRINK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): mi.visible = false)
	mi.set_meta("tw", tw)
	return mi


static func live() -> int:
	var c := 0
	for mi in _pool:
		if is_instance_valid(mi) and (mi as MeshInstance3D).visible:
			c += 1
	return c


static func pool_size() -> int:
	return _pool.size()


static func _take(fx: Node, mat: Material) -> MeshInstance3D:
	for i in range(_pool.size() - 1, -1, -1):
		if not is_instance_valid(_pool[i]):
			_pool.remove_at(i)
	var mi: MeshInstance3D
	if _pool.size() < CAP:
		mi = MeshInstance3D.new()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 70.0
		fx._scene_root().add_child(mi)
		_pool.append(mi)
		return mi
	_next = (_next + 1) % CAP
	return _pool[_next]


## The shared material and the shapes, kept on FX (static vars would outlive the renderer at exit).
static func _kit(fx: Node) -> Array:
	if fx.has_meta("splat_kit"):
		return fx.get_meta("splat_kit")
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes: Array = []
	for v in VARIANTS:
		meshes.append(_shape(v * 7919 + 13))
	fx.set_meta("splat_kit", [mat, meshes])
	return fx.get_meta("splat_kit")


## One mark, radius ~1 on the XZ plane: a pale chipped rim, a dark dent, jagged cracks running out (some forked).
static func _shape(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var dark := Color(0.06, 0.05, 0.045)
	var rim := Color(0.2, 0.175, 0.155)
	var sides := 11
	var r0: Array = []
	for i in sides:
		r0.append(0.3 * rng.randf_range(0.8, 1.2))
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var j := (i + 1) % sides
		var i0 := Vector3(cos(a0), 0, sin(a0)) * float(r0[i])
		var i1 := Vector3(cos(a1), 0, sin(a1)) * float(r0[j])
		var o0 := i0 * rng.randf_range(1.3, 1.55)
		var o1 := i1 * rng.randf_range(1.3, 1.55)
		_tri(st, rim, i0 + Vector3.UP * 0.002, o0 + Vector3.UP * 0.002, o1 + Vector3.UP * 0.002)
		_tri(st, rim, i0 + Vector3.UP * 0.002, o1 + Vector3.UP * 0.002, i1 + Vector3.UP * 0.002)
		_tri(st, dark, Vector3.UP * 0.006, i0 + Vector3.UP * 0.006, i1 + Vector3.UP * 0.006)
	var cracks := rng.randi_range(7, 10)
	for c in cracks:
		var a := TAU * (c + rng.randf_range(-0.3, 0.3)) / cracks
		var reach := rng.randf_range(0.7, 1.25)
		var at := Vector3(cos(a), 0, sin(a)) * 0.25
		var w := 0.1
		var segs := rng.randi_range(3, 4)
		for s in segs:
			a += rng.randf_range(-0.6, 0.6)
			var nxt := at + Vector3(cos(a), 0, sin(a)) * (reach - 0.25) / segs
			_seg(st, dark, at, nxt, w, w * 0.62)
			if s == 1 and rng.randf() < 0.5:
				var b := a + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
				_seg(st, dark, nxt, nxt + Vector3(cos(b), 0, sin(b)) * rng.randf_range(0.15, 0.3), w * 0.5, 0.008)
			at = nxt
			w *= 0.7
	return st.commit()


static func _tri(st: SurfaceTool, c: Color, a: Vector3, b: Vector3, d: Vector3) -> void:
	for p in [a, b, d]:
		st.set_color(c)
		st.add_vertex(p)


static func _seg(st: SurfaceTool, c: Color, a: Vector3, b: Vector3, wa: float, wb: float) -> void:
	var along := (b - a).normalized()
	var side := along.cross(Vector3.UP)
	var y := Vector3.UP * 0.008
	_tri(st, c, a + side * wa * 0.5 + y, b + side * wb * 0.5 + y, b - side * wb * 0.5 + y)
	_tri(st, c, a + side * wa * 0.5 + y, b - side * wb * 0.5 + y, a - side * wa * 0.5 + y)
