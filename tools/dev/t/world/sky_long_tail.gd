extends SceneTree
## The perf session's long tail kept their look: the sky's birds and the sea's foam write their MultiMeshes in one
## buffer a frame (each instance where it is, its wings or colour with it), a wind streak its row once when it's
## born (the GPU flies it); a foam patch its row once when it's born (the GPU drifts it on the swell, summing the ocean's own waves); DevCapture keeps its movement history with nothing running per tick.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var birds
var spray
var fi := -1


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
			var si: int = spray._streak(cam.global_position + Vector3(0, 0, -12), Vector3(1, 0, 0), 4.0, 0.5, 18.0, 0.06)
			var sr: PackedFloat32Array = spray.rows[spray._mm]
			var st := _xf(sr, si)
			var sc := _extra(sr, si)
			check("a wind streak born where it is, as long as it is, with its birth, life and speed for the GPU", sr.size() == spray.STREAKS * 16
				and st.origin.is_equal_approx(cam.global_position + Vector3(0, 0, -12)) and st.basis.x.is_equal_approx(Vector3(4, 0, 0))
				and is_equal_approx(st.basis.y.length(), 0.06) and is_equal_approx(sc.r, spray._clock) and is_equal_approx(sc.g, 0.5)
				and is_equal_approx(sc.b, 18.0) and spray._alive(si))
			var cx: float = cam.global_position.x + 4.0
			var cz: float = cam.global_position.z - 20.0
			fi = spray._foam_patch(cx, cz, 10.0, 1.2, 0.5, Vector2(0.6, -0.2))
			var fr: PackedFloat32Array = spray.rows[spray._foam_mm]
			var ft := _xf(fr, fi)
			var fc := _extra(fr, fi)
			check("a foam patch born where it is, turned and sized, with its birth, life and drift for the GPU", ft.origin.is_equal_approx(Vector3(cx, 0, cz))
				and is_equal_approx(ft.basis.x.length(), 1.2) and ft.basis.x.is_equal_approx(Basis(Vector3.UP, 0.5).x * 1.2) and is_equal_approx(fc.r, spray._clock)
				and is_equal_approx(fc.g, 10.0) and is_equal_approx(fc.b, 0.6) and is_equal_approx(fc.a, -0.2) and spray._foam_alive(fi))
			# (the light stage has no sea: the ocean's material, its waves sent, as a world has it)
			var oc0 = root.get_node("/root/Ocean")
			if oc0.ocean_material == null:
				oc0.ocean_material = ShaderMaterial.new()
				oc0.ocean_material.shader = load("res://scenes/ocean/ocean.gdshader")
				oc0._send_waves()
			until = TK.wait_secs(1.5)
		2:
			var oc = root.get_node("/root/Ocean")
			var om: ShaderMaterial = oc.ocean_material
			var fm: ShaderMaterial = spray._foam_mat
			check("its shader sums the ocean's own waves (the ocean material's wave uniforms and clock copied)", om != null
				and fm.get_shader_parameter("waves") == om.get_shader_parameter("waves") and fm.get_shader_parameter("amp_mult") == om.get_shader_parameter("amp_mult")
				and fm.get_shader_parameter("shore_rect") == om.get_shader_parameter("shore_rect") and absf(float(fm.get_shader_parameter("time_val")) - float(oc.clock())) < 0.1)
			var age: float = spray._clock - float(spray._foam[fi][0])
			check("...drifting on downwind as it ages (%.1f s)" % age, age > 1.0 and spray.foam_at(fi).is_equal_approx(Vector2(spray._foam[fi][2], spray._foam[fi][3]) + Vector2(0.6, -0.2) * age))
			check("DevCapture runs nothing per tick", not root.get_node("/root/DevCapture").is_physics_processing())
			check("...and keeps its history (%d samples)" % root.get_node("/root/DevCapture")._hist.size(), root.get_node("/root/DevCapture")._hist.size() >= 5)
			return TK.done(fails)
	step += 1
	return false
