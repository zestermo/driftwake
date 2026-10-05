extends SceneTree
## Round 10: the sky melts into a long-range fog at the horizon (no seam), an
## irregular sea (several crossing wave trains, peaked crests, wave groups),
## blended + sorted 3D clouds (no screen-door dither), cloud shadows on the
## sea/ground (no more multiply plane over the sky), and the rig is the same
## after a string of knockdowns as before them.
var t := 0.0
var step := 0
var wait := 0.0
var p
var w
var oc
var fails := 0
var data := {}
var rest := {}
var downs := 0
var t0 := 0.0

const RIG := ["hips", "torso", "neck", "head", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r", "leg_l", "shin_l", "leg_r", "shin_r"]


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func set_hour(h: float) -> void:
	var dh := fposmod(h - float(w.hour()), 24.0)
	w.world_offset += dh / 24.0 * float(w.DAY_LEN)


func rig_snapshot() -> Dictionary:
	var out := {}
	var bm = p.body_model
	for j in RIG:
		var n = bm.get(j)
		if n is Node3D:
			out[j] = [n.position, n.basis.get_scale()]
	return out


## A lone armed body moving along `mv` (relative to its facing) at combat
## speed: [planted-foot slide m/s, hips' yaw off the facing, chest's yaw off it]
func strafe_slide(mv: Vector2) -> Array:
	var h := Humanoid.new()
	h.setup(CharacterLook.default_look())
	root.add_child(h)
	h.global_position = Vector3(5000, 0, 5000)
	h.armed = true
	h.grounded = true
	h.ground_speed = 4.8
	h.local_move = mv
	h.set_process(false)
	var dt := 1.0 / 60.0
	var prev := {}
	var slip := 0.0
	var n := 0
	var hy := 0.0
	var cy := 0.0
	for f in range(240):
		h.global_position += Vector3(mv.x, 0, -mv.y) * 4.8 * dt
		h._process(dt)
		if f < 60:
			continue
		var fwd := -h.global_basis.z
		var hz := -h.hips.global_basis.orthonormalized().z
		var cz := -h.torso.global_basis.orthonormalized().z
		hy += Vector2(fwd.x, fwd.z).angle_to(Vector2(hz.x, hz.z))
		cy += Vector2(fwd.x, fwd.z).angle_to(Vector2(cz.x, cz.z))
		for side in ["l", "r"]:
			var sh: Node3D = h.get("shin_" + side)
			var other: Node3D = h.get("shin_" + ("r" if side == "l" else "l"))
			var a: Vector3 = sh.global_transform * Vector3(0, sh.position.y, 0)
			var b: Vector3 = other.global_transform * Vector3(0, other.position.y, 0)
			var y0: float = h.global_position.y
			if prev.has(side) and a.y - y0 < 0.04 and a.y < b.y - 0.01:
				slip += Vector2(a.x - prev[side].x, a.z - prev[side].z).length() / dt
				n += 1
			prev[side] = a
	h.queue_free()
	return [slip / maxf(n, 1), hy / 180.0, cy / 180.0]


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = get_first_node_in_group("player")
			w = root.get_node("Weather")
			oc = root.get_node("Ocean")
			set_hour(12.0)
			w.forced = 0
			w.forced_at = w.world_time() - 100.0
			wait = 1.0
			step = 1
		1:
			# --- the horizon: fog and sky agree, the sea is fogged out inside its edge
			var env: Environment = current_scene.get_node("WorldEnvironment").environment
			check("the sky isn't tinted by the scene fog (it hazes itself)", env.fog_sky_affect == 0.0)
			check("the sea is fully fogged before its edge (fog ends %d m < %d m)" % [int(env.fog_depth_end), int(oc.FAR_HALF)], env.fog_depth_end < oc.FAR_HALF - 100.0)
			var sky: ShaderMaterial = w._sky_mat
			var fc: Color = sky.get_shader_parameter("fog_color")
			check("the sky's horizon haze is the fog's colour", fc.is_equal_approx(env.fog_light_color))
			check("...and reaches a little way up", float(sky.get_shader_parameter("haze_height")) > 0.03)
			check("no cloud-shadow plane over the sky any more", current_scene.get_node_or_null("CloudShadows") == null)
			var cs: Vector4 = w.cloud_shadow
			check("cloud shadows fall on the sea and ground by day (%.2f)" % cs.y, cs.y > 0.05)
			# --- the sea
			var mat: ShaderMaterial = oc.ocean_material
			var gw = mat.get_shader_parameter("waves")
			check("the ocean shader has the game's wave table", gw != null and gw.size() == oc.WAVES.size() and (gw[0] as Vector4).is_equal_approx(oc._w4[0]))
			check("...and the same storm multiplier", absf(float(mat.get_shader_parameter("amp_mult")) - oc.amp_mult) < 0.01)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var s := 0.0
			var s2 := 0.0
			var n := 4000
			for i in range(n):
				var h: float = oc.get_wave_height(Vector3(rng.randf_range(-800, 800), 0, rng.randf_range(-800, 800)), rng.randf_range(0, 5000))
				s += h
				s2 += h * h
			var mean := s / n
			var sd := sqrt(s2 / n - mean * mean)
			check("sea level stays put (mean %.3f m)" % mean, absf(mean) < 0.06)
			check("waves about as big as before (sd %.2f m)" % sd, sd > 0.35 and sd < 0.8)
			# not one repeating stripe: one wavelength along the main swell isn't the same sea
			var a: Vector4 = oc._w4[0]
			var lam: float = TAU / a.z
			var dirv := Vector3(a.x, 0, a.y)
			var diff := 0.0
			for i in range(200):
				var q := Vector3(rng.randf_range(-500, 500), 0, rng.randf_range(-500, 500))
				diff += absf(oc.get_wave_height(q, 100.0) - oc.get_wave_height(q + dirv * lam, 100.0))
			check("no regular stripes: one swell length on, the sea differs (%.2f m)" % (diff / 200.0), diff / 200.0 > 0.25)
			var m3 := 0.0
			for i in range(6000):
				var h: float = oc.get_wave_height(Vector3(rng.randf_range(-600, 600), 0, rng.randf_range(-600, 600)), rng.randf_range(0, 3000))
				m3 += pow((h - mean) / sd, 3.0)
			check("peaked crests, broad troughs (skew %.2f)" % (m3 / 6000.0), m3 / 6000.0 > 0.1)
			var om = get_first_node_in_group("ocean_mesh")
			var v: PackedVector3Array = om.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check("fine 1 m sea cells out to %d m (%d verts)" % [int(oc.NEAR_HALF), v.size()], v.size() > 80000 and v.size() < 200000)
			# --- the 3D clouds: blended, no screen-door, sorted far to near
			var cl = current_scene.get_node("Clouds")
			var code: String = cl._mat.shader.code
			check("clouds blend instead of dithering", code.find("discard") < 0 and code.find("depth_draw_never") >= 0)
			check("clouds do their own haze (no double fog)", code.find("fog_disabled") >= 0)
			cl.coverage = 0.9
			wait = 0.2
			step = 2
		2:
			var cl = current_scene.get_node("Clouds")
			var mm: MultiMesh = cl._mm
			var cnt: int = mm.visible_instance_count
			check("clouds out at high cover (%d puffs)" % cnt, cnt > 50)
			var cam := root.get_viewport().get_camera_3d()
			var prev := INF
			var sorted := true
			for i in range(cnt):
				var dd := mm.get_instance_transform(i).origin.distance_to(cam.global_position)
				if dd > prev + 1.0:
					sorted = false
					break
				prev = dd
			check("...drawn farthest first", sorted)
			var far_ok := true
			for i in range(cnt):
				var o := mm.get_instance_transform(i).origin - cam.global_position
				if Vector2(o.x, o.z).length() > 1300.0:
					far_ok = false
			check("...and none past the fade-out (no popping at the wrap)", far_ok)
			# storm: the haze climbs, the fog closes in
			w.force(3)
			wait = 9.0
			step = 3
		3:
			var env: Environment = current_scene.get_node("WorldEnvironment").environment
			check("storm: the fog closes in", env.fog_depth_end < 300.0)
			check("...and the haze climbs the sky", float(w._sky_mat.get_shader_parameter("haze_height")) > 0.2)
			check("...the sky still meets the fog", (w._sky_mat.get_shader_parameter("fog_color") as Color).is_equal_approx(env.fog_light_color))
			w.force(0)
			# --- knockdowns: the rig mustn't drift
			p.global_position = p.global_position
			rest = rig_snapshot()
			downs = 0
			data["worst_pos"] = 0.0
			data["worst_scale"] = 0.0
			step = 4
		4:
			if p.current_state_name() != "Idle":
				return false
			if downs >= 6:
				step = 6
				return false
			downs += 1
			var dir := Vector3(sin(downs * 2.1), 0, cos(downs * 2.1))
			p.knock_down(dir * 7.0 + Vector3(0, 4.0, 0))
			t0 = t
			wait = 0.1
			step = 5
		5:
			if p.current_state_name() != "Idle" and t - t0 < 9.0:
				return false
			wait = 0.6
			step = 4
		6:
			var now := rig_snapshot()
			var wp := 0.0
			var ws := 0.0
			for j in rest:
				wp = maxf(wp, ((now[j][0] as Vector3) - (rest[j][0] as Vector3)).length())
				ws = maxf(ws, ((now[j][1] as Vector3) - (rest[j][1] as Vector3)).length())
			check("6 knockdowns later the limbs are the same length (worst joint moved %.4f m)" % wp, wp < 0.002)
			check("...and the same shape (worst scale change %.5f)" % ws, ws < 0.001)
			# --- combat-stance strafing: feet stay planted on diagonals and backpedals
			var base := strafe_slide(Vector2(0, 1))
			for mv in [Vector2(0.7071, 0.7071), Vector2(0.7071, -0.7071), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
				var r := strafe_slide(mv)
				var lim := 2.0 if absf(mv.y) < 0.1 else 1.6
				check("strafing %s: the planted foot barely slides (%.2f m/s at 4.8 m/s)" % [str(mv), r[0]], r[0] < lim)
				if mv.y > 0.5:
					var dh: float = r[1] - base[1]
					var dc: float = r[2] - base[2]
					check("...the hips turn into the move, the chest stays on the target (hips %.0f deg, chest %.0f deg)" % [rad_to_deg(dh), rad_to_deg(dc)], absf(dh) > 0.5 and absf(dc) < 0.15)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
