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
var seq := []
var label := ""
var sampling := false
var watch := {}
var samples := []

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
	var ly := 0.0
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
		# the thigh's swing plane: its knee hinge (local x) vs the body's right
		var bx := h.global_basis.x
		var kx := h.leg_l.global_basis.orthonormalized().x
		ly += Vector2(bx.x, bx.z).angle_to(Vector2(kx.x, kx.z))
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
	return [slip / maxf(n, 1), hy / 180.0, cy / 180.0, ly / 180.0]


## A lone armed body run through a list of [local_move, seconds] legs at
## combat speed; returns per-leg samples of [_gait_back, _travel_ang, torso rotation].
func gait_run(legs: Array) -> Array:
	var h := Humanoid.new()
	h.setup(CharacterLook.default_look())
	root.add_child(h)
	h.global_position = Vector3(5200, 0, 5000)
	h.armed = true
	h.grounded = true
	h.ground_speed = 4.8
	h.set_process(false)
	var dt := 1.0 / 60.0
	var out := []
	for leg in legs:
		var mv: Vector2 = leg[0]
		h.local_move = mv
		var frames := []
		for f in range(int(float(leg[1]) * 60.0)):
			h.global_position += Vector3(mv.x, 0, -mv.y) * 4.8 * dt
			h._process(dt)
			frames.append([h._gait_back, h._travel_ang, h.torso.rotation])
		out.append(frames)
	h.queue_free()
	return out


## A lone body jumping `n` times: per jump [lead side, knee gap rising, knee gap
## falling, arms' sideways vs forward reach rising (min over both arms)].
func jump_poses(n: int) -> Array:
	var h := Humanoid.new()
	h.setup(CharacterLook.default_look())
	root.add_child(h)
	h.global_position = Vector3(5400, 0, 5000)
	h.set_process(false)
	var dt := 1.0 / 60.0
	var out := []
	for i in range(n):
		h.grounded = true
		h.vertical_speed = 0.0
		for f in range(20):
			h._process(dt)
		h.grounded = false
		var rec := [0.0, 0.0, 0.0, 99.0]
		for f in range(70):
			h.vertical_speed = 7.0 - f * 0.3
			h._process(dt)
			if f == 0:
				rec[0] = h._jside
			var gap: float = h.leg_l.rotation.x - h.leg_r.rotation.x
			if f == 14:
				rec[1] = gap
				var inv := h.global_basis.orthonormalized().inverse()
				for arm in [h.arm_l, h.arm_r]:
					var dirv: Vector3 = inv * ((arm as Node3D).global_basis.orthonormalized() * Vector3.DOWN)
					rec[3] = minf(rec[3], absf(dirv.x) - absf(dirv.z))
			if f == 65:
				rec[2] = gap
		out.append(rec)
	h.queue_free()
	return out


## A lone body run through phases {spd, mv, t, armed, air}; per phase, per frame:
## {hips, torso, pivot_y, shin_l, shin_r, skid, stop, start}.
func body_run(phases: Array) -> Array:
	var h := Humanoid.new()
	h.setup(CharacterLook.default_look())
	root.add_child(h)
	h.global_position = Vector3(5600, 0, 5000)
	h.set_process(false)
	var dt := 1.0 / 60.0
	var out := []
	for ph in phases:
		h.ground_speed = float(ph.get("spd", 0.0))
		h.local_move = ph.get("mv", Vector2(0, 1))
		h.armed = bool(ph.get("armed", false))
		var air := bool(ph.get("air", false))
		h.grounded = not air
		var frames := []
		for f in range(int(float(ph["t"]) * 60.0)):
			h.vertical_speed = (4.0 - f * 0.4) if air else float(ph.get("vy", 0.0))
			h._process(dt)
			frames.append({"hips": h.hips.rotation, "torso": h.torso.rotation, "pivot_y": h.pivot.position.y,
				"shin_l": h.shin_l.rotation.x, "shin_r": h.shin_r.rotation.x,
				"skid": h._skid, "stop": h._stop, "start": h._start, "jside": h._jside})
		out.append(frames)
	h.queue_free()
	return out


func press(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = true
	Input.parse_input_event(e)


func release(a: String) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = false
	Input.parse_input_event(e)


func tap(a: String) -> void:
	press(a)
	release(a)


func _process(d: float) -> bool:
	t += d
	if sampling:
		var bm = p.body_model
		samples.append([bm._gait_back, bm._travel_ang, bm.ground_speed])
	if not watch.is_empty():
		for k in watch.keys():
			watch[k] = maxf(watch[k], float(p.body_model.get("_" + k)))
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
					var dl: float = r[3] - base[3]
					check("...the legs turn into the move, the chest stays on the target (thighs %.0f deg, chest %.0f deg)" % [rad_to_deg(dl), rad_to_deg(dc)], absf(dl) > 0.5 and absf(dc) < 0.15)
					check("...without wringing the waist (pelvis vs chest %.0f deg)" % rad_to_deg(dh - dc), absf(dh - dc) < 0.45)
			# a swing through straight-back (back-left -> back-right), then forward-diagonal:
			# the travel angle used to wind past ±PI and latch the backpedal gait
			var g := gait_run([[Vector2(-0.7071, -0.7071), 1.0], [Vector2(0.7071, -0.7071), 1.0], [Vector2(0.7071, 0.7071), 1.5]])
			var last: Array = g[2][g[2].size() - 1]
			check("after turning through straight back, forward-diagonal strides forward again (back %s, travel %.0f deg)" % [str(last[0]), rad_to_deg(last[1])], not last[0] and absf(last[1] - PI / 4.0) < 0.1)
			var wound := false
			for leg in g:
				for fr in leg:
					if absf(fr[1]) > PI + 0.001:
						wound = true
			check("...the travel angle stays within ±180 deg", not wound)
			# chest tip: stepping off to the right rolls the chest right, then it settles
			var tp := gait_run([[Vector2(0, 1), 1.0], [Vector2(1, 0), 1.5]])
			var early: Vector3 = tp[1][8][2]
			var settled: Vector3 = tp[1][tp[1].size() - 1][2]
			check("a change of direction tips the chest into it (roll %.2f vs settled %.2f)" % [early.z, settled.z], early.z < settled.z - 0.1)
			# --- jumps: uneven legs, arms out to the sides, a different lead from jump to jump
			var jp := jump_poses(10)
			var sides := {}
			var min_gap := 99.0
			var min_side := 99.0
			var gaps := []
			for r in jp:
				sides[r[0]] = true
				min_gap = minf(min_gap, minf(absf(r[1]), absf(r[2])))
				min_side = minf(min_side, r[3])
				gaps.append(snappedf(r[2], 0.01))
			check("jumps lead with either leg (%d sides over 10 jumps)" % sides.size(), sides.size() == 2)
			check("...one knee higher than the other, rising and falling (smallest gap %.2f rad)" % min_gap, min_gap > 0.3)
			check("...the arms reach out more to the sides than in front (worst side-front %.2f)" % min_side, min_side > 0.1)
			var uniq := {}
			for g2 in gaps:
				uniq[g2] = true
			check("...and not the same pose every time (%d distinct falling poses)" % uniq.size(), uniq.size() >= 6)
			# --- landings: one foot first, either side
			var land_sides := {}
			var land_gap := 99.0
			for i in range(8):
				var lr := body_run([{"t": 0.5}, {"t": 0.55, "air": true}, {"t": 0.3, "vy": -10.0}])
				var fr: Dictionary = lr[2][6]
				land_sides[fr["jside"]] = true
				# the first (lower) foot is the right one when the left leads
				var first_bend: float = -float(fr["shin_r"] if float(fr["jside"]) > 0.0 else fr["shin_l"])
				var other_bend: float = -float(fr["shin_l"] if float(fr["jside"]) > 0.0 else fr["shin_r"])
				land_gap = minf(land_gap, first_bend - other_bend)
			check("landings take the weight on the foot that came down first (it bends %.2f rad more, worst case)" % land_gap, land_gap > 0.25)
			check("...either foot (%d sides over 8 landings)" % land_sides.size(), land_sides.size() == 2)
			# --- idle: the weight shifts from leg to leg
			var idl := body_run([{"t": 24.0}])
			var roll_lo := 99.0
			var roll_hi := -99.0
			var knee_gap := 0.0
			for fr in idl[0]:
				roll_lo = minf(roll_lo, (fr["hips"] as Vector3).z)
				roll_hi = maxf(roll_hi, (fr["hips"] as Vector3).z)
				knee_gap = maxf(knee_gap, absf(float(fr["shin_l"]) - float(fr["shin_r"])))
			check("idle weight shifts to both legs (hip roll %.2f..%.2f)" % [roll_lo, roll_hi], roll_lo < -0.04 and roll_hi > 0.04)
			check("...one knee relaxed, the other straight (gap %.2f rad)" % knee_gap, knee_gap > 0.25)
			# --- setting off leans into the first step
			var so := body_run([{"t": 1.0}, {"spd": 6.0, "t": 1.2}])
			var lean0: float = (so[1][6]["torso"] as Vector3).x
			var lean1: float = (so[1][so[1].size() - 1]["torso"] as Vector3).x
			check("setting off leans into the first step (torso %.2f vs %.2f running)" % [lean0, lean1], lean0 < lean1 - 0.12)
			# --- stopping from a run plants and dips
			var sp := body_run([{"spd": 6.0, "t": 1.0}, {"t": 1.2}])
			var dip0: float = sp[1][6]["pivot_y"]
			var dip1: float = sp[1][sp[1].size() - 1]["pivot_y"]
			check("stopping from a run plants with a dip (hips %.3f vs %.3f standing)" % [dip0, dip1], dip0 < dip1 - 0.03 and float(sp[1][1]["stop"]) > 0.0)
			# --- reversing at a run skids; not at a walk, not in the combat stance
			var sk := body_run([{"spd": 9.0, "t": 1.0}, {"spd": 9.0, "mv": Vector2(0, -1), "t": 0.6}])
			var back: float = (sk[1][6]["torso"] as Vector3).x
			check("reversing at a run skids (skid %.2f, leaning toward the new way: torso %.2f)" % [float(sk[1][1]["skid"]), back], float(sk[1][1]["skid"]) > 0.5 and back > 0.15)
			var sw := body_run([{"spd": 3.0, "t": 1.0}, {"spd": 3.0, "mv": Vector2(0, -1), "t": 0.3}])
			var sc := body_run([{"spd": 4.8, "t": 1.0, "armed": true}, {"spd": 4.8, "mv": Vector2(0, -1), "t": 0.3, "armed": true}])
			check("...but not at a walk, or in the combat stance", float(sw[1][1]["skid"]) == 0.0 and float(sc[1][1]["skid"]) == 0.0)
			# --- the real player: attack / dodge / backpedal, then forward-diagonal
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE + Vector2(0, 6)
			p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
			p.reset_physics_interpolation()
			if not p.armed:
				tap("ready_weapon")
			seq = [
				["say", "after a 3-hit combo"], ["tap", "light_attack", 0.35], ["tap", "light_attack", 0.35], ["tap", "light_attack", 0.9],
				["press", "move_forward", 0.0], ["press", "move_right", 0.5], ["sample", 0.8], ["release", "move_forward", 0.0], ["release", "move_right", 0.6],
				["say", "after a heavy attack"], ["tap", "heavy_attack", 1.3],
				["press", "move_forward", 0.0], ["press", "move_left", 0.5], ["sample", 0.8], ["release", "move_forward", 0.0], ["release", "move_left", 0.6],
				["say", "after a backstep dodge"], ["press", "move_back", 0.1], ["tap", "dodge", 0.15], ["release", "move_back", 0.6],
				["press", "move_forward", 0.0], ["press", "move_right", 0.5], ["sample", 0.8], ["release", "move_forward", 0.0], ["release", "move_right", 0.6],
				["say", "after attacking while backpedalling"], ["press", "move_back", 0.3], ["tap", "light_attack", 0.5], ["release", "move_back", 0.0],
				["press", "move_forward", 0.0], ["press", "move_left", 0.5], ["sample", 0.8], ["release", "move_forward", 0.0], ["release", "move_left", 0.6],
				["say", "after sweeping back-left -> back-right"], ["press", "move_back", 0.0], ["press", "move_left", 0.6], ["release", "move_left", 0.0], ["press", "move_right", 0.6],
				["release", "move_back", 0.0], ["press", "move_forward", 0.5], ["sample", 0.8], ["release", "move_forward", 0.0], ["release", "move_right", 0.6],
				# out of combat, with real input (braking takes a few ticks; a reversal
				# usually passes through a moment with both keys held)
				["tap", "ready_weapon", 0.8], ["say", "weapon away"], ["check_unarmed"],
				["press", "move_forward", 1.0], ["watch"], ["release", "move_forward", 0.4], ["expect", "stop", "letting go of a jog plants a stop"],
				["watch"], ["press", "move_forward", 0.3], ["expect", "start", "setting off leans into the first step"],
				["press", "sprint", 0.8], ["watch"], ["press", "move_back", 0.08], ["release", "move_forward", 0.4],
				["expect", "skid", "reversing at a sprint skids (both keys held for a moment)"],
				["release", "move_back", 0.0], ["release", "sprint", 0.5],
			]
			wait = 0.8
			step = 7
		7:
			if seq.is_empty():
				print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
				quit()
				return false
			var e: Array = seq.pop_front()
			match str(e[0]):
				"say":
					label = e[1]
				"tap":
					tap(e[1])
					wait = e[2]
				"press":
					press(e[1])
					wait = e[2]
				"release":
					release(e[1])
					wait = e[2]
				"sample":
					samples = []
					sampling = true
					wait = e[1]
					step = 8
				"check_unarmed":
					check("weapon put away for the casual moves", not p.armed)
				"watch":
					watch = {"stop": 0.0, "start": 0.0, "skid": 0.0}
				"expect":
					check("%s (peak %.2f)" % [e[2], watch[e[1]]], watch[e[1]] > 0.5)
					watch = {}
		8:
			sampling = false
			var back := 0
			var worst := 0.0
			var slow := 0
			for s in samples:
				if s[0]:
					back += 1
				worst = maxf(worst, absf(s[1]))
				if s[2] < 2.0:
					slow += 1
			check("%s, forward-diagonal strides forward (backpedal frames %d/%d, worst travel %.0f deg, state %s)" % [label, back, samples.size(), rad_to_deg(worst), p.current_state_name()],
				samples.size() > 10 and back == 0 and worst < deg_to_rad(80.0) and slow < samples.size() / 4)
			step = 7
	return false
