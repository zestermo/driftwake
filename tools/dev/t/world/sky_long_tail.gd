extends SceneTree
## The perf session's long tail kept their look: the sky's birds and the sea's streaks and foam write their
## MultiMeshes in one buffer a frame (each instance where it is, its wings or colour with it); the foam's height,
## sampled a third of the patches a frame and carried on between, stays on the swell; DevCapture keeps its
## movement history with nothing running per tick.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var birds
var spray
var worst := 0.0
var was_worst := 0.0
var frames := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Instance i of a MultiMesh buffer as the server reads it (TRANSFORM_3D: the basis's rows with the origin's
## component at the end of each, then the colour or custom data), which the headless renderer can't give back.
func _xf(r: PackedFloat32Array, i: int) -> Transform3D:
	var k := i * 16
	return Transform3D(Vector3(r[k], r[k + 4], r[k + 8]), Vector3(r[k + 1], r[k + 5], r[k + 9]), Vector3(r[k + 2], r[k + 6], r[k + 10]),
		Vector3(r[k + 3], r[k + 7], r[k + 11]))


func _extra(r: PackedFloat32Array, i: int) -> Color:
	var k := i * 16 + 12
	return Color(r[k], r[k + 1], r[k + 2], r[k + 3])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var cam := root.get_viewport().get_camera_3d()
	match step:
		0:
			birds = load("res://scripts/world/sky_birds.gd").new()
			root.add_child(birds)
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in range(6):
				var b: Dictionary = birds._bird(birds.GULL, "test", birds.PERCH, cam.global_position + Vector3(i * 3.0 - 8.0, 6.0, -20.0), rng)
				b["perch"] = b["pos"]
				b["t"] = 999.0
				b["rest"] = 999.0
			spray = load("res://scripts/world/sea_spray.gd").new()
			root.add_child(spray)
			until = TK.wait_ticks(3)
		1:
			var mm: MultiMesh = birds._mm
			check("every bird near is drawn (%d of 6)" % mm.visible_instance_count, mm.visible_instance_count == 6)
			var ok := true
			check("its buffer holds every bird", birds.rows.size() == birds.MAX * 16)
			for i in range(6):
				var b: Dictionary = birds.birds[i]
				var t := _xf(birds.rows, i)
				var c := _extra(birds.rows, i)
				var want := Basis.from_euler(Vector3(b["pitch"], b["yaw"], b["bank"])).scaled(Vector3.ONE * float(birds.SIZE[b["kind"]]))
				ok = ok and t.origin.is_equal_approx(b["pos"]) and t.basis.x.is_equal_approx(want.x) and t.basis.z.is_equal_approx(want.z) \
					and is_equal_approx(c.r, b["wing"]) and is_equal_approx(c.g, b["fold"]) and is_equal_approx(c.b, b["paint"])
			check("...each where it is, turned its way, its wings with it", ok)
			spray.set_process(false)
			spray._streaks = [[cam.global_position + Vector3(0, 0, -12), Vector3(1, 0, 0), 4.0, 0.25, 0.5, 18.0, 0.06]]
			spray._draw(cam)
			var sr: PackedFloat32Array = spray.rows[spray._mm]
			var st := _xf(sr, 0)
			check("a wind streak where it is, as long as it is, half through its life at its brightest", spray._mm.visible_instance_count == 1
				and sr.size() == spray.STREAKS * 16 and st.origin.is_equal_approx(cam.global_position + Vector3(0, 0, -12))
				and st.basis.x.is_equal_approx(Vector3(4, 0, 0)) and is_equal_approx(_extra(sr, 0).a, 0.4))
			spray._foam = []
			for i in range(12):
				spray._foam.append([cam.global_position.x + i * 4.0, cam.global_position.z - 20.0, 3.0, 99.0, 1.2, 0.0, Vector3.UP, INF, 0.0, 0.0])
			root.get_node("/root/Ocean").amp_mult = 1.6
		2:
			spray._draw_foam()
			var oc = root.get_node("/root/Ocean")
			for i in range(12):
				var f: Array = spray._foam[i]
				var y: float = _xf(spray.rows[spray._foam_mm], i).origin.y
				var h: float = oc.get_wave_height(Vector3(f[0], 0, f[1]))
				worst = maxf(worst, absf(y - (h + 0.05)))
				# (what it was: each patch's height every other frame, as it stood a frame ago between)
				was_worst = maxf(was_worst, absf(h - float(oc.get_wave_height(Vector3(f[0], 0, f[1]), oc.clock() - 1.0 / 60.0))))
			frames += 1
			if frames < 90:
				until = TK.wait_ticks(1)
				return false
			check("the foam stays on the swell sampled a third a frame, as near as it was every other frame (worst %.3f m off, was %.3f, over %d frames)" % [worst, was_worst, frames],
				worst <= was_worst and worst < 0.1)
			check("DevCapture runs nothing per tick", not root.get_node("/root/DevCapture").is_physics_processing())
			check("...and keeps its history (%d samples)" % root.get_node("/root/DevCapture")._hist.size(), root.get_node("/root/DevCapture")._hist.size() >= 5)
			return TK.done(fails)
	step += 1
	return false
