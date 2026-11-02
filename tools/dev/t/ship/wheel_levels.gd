extends SceneTree
## The wheel (1.29): the new baseline wheel turns with the helm, and the Rudder & helm line's levels show on the wheel
## and its pedestal themselves: 2 brass on the wheel, 4 a carved pedestal, 5 gilt on both (each more of it).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func verts(mi: MeshInstance3D) -> int:
	var n := 0
	for s in range(mi.mesh.get_surface_count()):
		n += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			ship = stage.ship
			var wheel: MeshInstance3D = ship.wheel.get_node("WheelMesh")
			var post: MeshInstance3D = ship._helm_post
			var w := [verts(wheel)]
			var p := [verts(post)]
			for lv in range(1, 6):
				ship.apply_kit({"rudder": lv})
				w.append(verts(wheel))
				p.append(verts(post))
			print("   wheel verts by level %s, pedestal %s" % [str(w), str(p)])
			check("a wheel of eight spokes and a rim from the start (%d verts)" % w[0], w[0] > 300)
			check("2: brass on the wheel", w[2] > w[1])
			check("4: a carved pedestal", p[4] > p[3])
			check("5: gilt on the wheel and the pedestal", w[5] > w[4] and p[5] > p[4])
			ship.rudder = 1.0
			until = TK.wait_ticks(3)
		1:
			check("the wheel turns with the helm (%.2f)" % ship.wheel.rotation.z, absf(ship.wheel.rotation.z) > 1.0)
			return TK.done(fails)
	step += 1
	return false
