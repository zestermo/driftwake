extends SceneTree
## The hammer's guard carries the haft on top of the right shoulder for every design: the haft passes over the
## shoulder joint, and the head (the biggest: the anchor's flukes, the mallet's barrel) stays clear of the head and chest.
const TK := preload("res://tools/dev/test_kit.gd")
const DESIGNS := ["hammer", "hammer:kanabo", "hammer:mallet", "hammer:maul", "hammer:anchor"]
var stage
var p
var b
var di := 0
var got: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "warhammer"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## [lowest clearance of the weapon's far half from the head sphere, from the chest's line, the haft's height over
## the right shoulder joint where it passes it, how far it passes from it]
func measure() -> Array:
	var w: MeshInstance3D = b.weapon
	var hc: Vector3 = b.head.global_transform * Vector3(0, 0.11, 0)
	var low: Vector3 = b.hips.global_position + Vector3.UP * 0.12
	var high: Vector3 = (b.neck if b.neck else b.head).global_position
	var head_c := 99.0
	var chest_c := 99.0
	var arm_c := 99.0
	for s in w.mesh.get_surface_count():
		for v in (w.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.z > -0.7:
				continue
			var g: Vector3 = w.global_transform * v
			head_c = minf(head_c, g.distance_to(hc))
			chest_c = minf(chest_c, g.distance_to(Geometry3D.get_closest_point_to_segment(g, low, high)))
			arm_c = minf(arm_c, g.distance_to(Geometry3D.get_closest_point_to_segment(g, b.arm_r.global_position, b.fore_r.global_position)))
	var a: Vector3 = w.global_position
	var e: Vector3 = w.global_transform * Vector3(0, 0, -0.9)
	var sh: Vector3 = b.arm_r.global_position
	var on: Vector3 = Geometry3D.get_closest_point_to_segment(sh, a, e)
	var off: Vector3 = b.torso.global_basis.orthonormalized().inverse() * (on - sh)
	return [head_c, chest_c, arm_c, off.y, off.length(), absf(off.x)]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.2)
		1:
			if not b.weapon_in_hand:
				check("the hammer's in hand", false)
				return TK.done(fails)
			b.weapon.mesh = Props.weapon_mesh(DESIGNS[di])
			until = TK.wait_secs(0.8)
		2:
			var m := measure()
			if di == 0:
				var o: Vector3 = (b.arm_r.global_position + b.arm_l.global_position) * 0.5
				var tb: Basis = b.torso.global_basis.orthonormalized().inverse()
				print("GEOM arm_r %s head %s neck %s hips %s hand %s tip %s" % [tb * (b.arm_r.global_position - o), tb * (b.head.global_transform * Vector3(0, 0.11, 0) - o),
					tb * (b.neck.global_position - o), tb * (b.hips.global_position - o), tb * (b.weapon.global_position - o), tb * (b.weapon.global_transform * Vector3(0, 0, -0.95) - o)])
			m.push_front(DESIGNS[di])
			got.append(m)
			print("MEASURE %s %s" % [DESIGNS[di], str(m)])
			di += 1
			if di < DESIGNS.size():
				step = 1
				return false
			for g in got:
				check("%s on the shoulder: its head clear of the head by %.2f m, the chest by %.2f m, the upper arm by %.2f m; the haft lies %.2f m up from the shoulder joint, %.2f m from it, %.2f m to the side"
					% g, g[1] > 0.25 and g[2] > 0.2 and g[3] > 0.12 and g[4] > 0.06 and g[5] > 0.085 and g[5] < 0.16 and g[6] < 0.06)
			return TK.done(fails)
	step += 1
	return false
