extends SceneTree
var fails := 0
var step := 0
var t := 0.0
var p
var got = null
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
## How far back (hips-space z) the left glute reaches: rest mesh, or skinned
## with the lower body's current bone poses.
func seat_back(lb: LowerBody, posed: bool) -> float:
	var mesh: ArrayMesh = (lb.get_node("Mesh") as MeshInstance3D).mesh
	var best := -1.0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			var p := v[i]
			if p.x > -0.03 or p.y > -0.05 or p.y < -0.17:
				continue
			var q := p
			if posed:
				q = Vector3.ZERO
				for k in range(4):
					var b := bones[i * 4 + k]
					q += (lb.get_bone_global_pose(b) * lb.get_bone_global_rest(b).affine_inverse() * p) * weights[i * 4 + k]
			best = maxf(best, q.z)
	return best


## Worst ratio, over the left thigh's sections between 6 and 20 cm below its
## joint, of mean distance from the thigh axis posed vs at rest.
func thigh_keep(lb: LowerBody) -> float:
	var mesh: ArrayMesh = (lb.get_node("Mesh") as MeshInstance3D).mesh
	var rest_t := lb.get_bone_global_rest(LowerBody.THIGH_L)
	var pose_t := lb.get_bone_global_pose(LowerBody.THIGH_L)
	var sums := {}
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			var p := v[i]
			var lp := rest_t.affine_inverse() * p   # leg space at rest
			if p.x > -0.02 or lp.y > -0.06 or lp.y < -0.2:
				continue
			var q := Vector3.ZERO
			for k in range(4):
				var b := bones[i * 4 + k]
				q += (lb.get_bone_global_pose(b) * lb.get_bone_global_rest(b).affine_inverse() * p) * weights[i * 4 + k]
			var lq := pose_t.affine_inverse() * q   # where it sits relative to the posed thigh
			var key := snappedf(lp.y, 0.02)
			if not sums.has(key):
				sums[key] = [0.0, 0.0]
			sums[key][0] += Vector2(lp.x, lp.z).length()
			sums[key][1] += Vector2(lq.x, lq.z).length()
	var worst := 1.0
	for key in sums:
		worst = minf(worst, sums[key][1] / maxf(sums[key][0], 1e-6))
	return worst


## Mean distance of the left knee's vertices (within 3.5 cm of the joint) from
## the joint, posed vs rest.
func knee_keep(lb: LowerBody) -> float:
	var mesh: ArrayMesh = (lb.get_node("Mesh") as MeshInstance3D).mesh
	var kr := lb.get_bone_global_rest(LowerBody.SHIN_L).origin
	var kp := lb.get_bone_global_pose(LowerBody.SHIN_L).origin
	var a := 0.0
	var b := 0.0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			var p := v[i]
			if p.x > -0.02 or absf(p.y - kr.y) > 0.035:
				continue
			var q := Vector3.ZERO
			for k in range(4):
				var bi := bones[i * 4 + k]
				q += (lb.get_bone_global_pose(bi) * lb.get_bone_global_rest(bi).affine_inverse() * p) * weights[i * 4 + k]
			a += p.distance_to(kr)
			b += q.distance_to(kp)
	return b / maxf(a, 1e-6)


## Sharpest turn (degrees) between neighbouring segments of a limb's front
## centre line within 12 cm of a joint, skinned with the current pose. `joint`
## is the bone whose origin is the joint, `upper` the bone above it (its rest x
## is the limb's centre line).
func front_kink(sk: Skeleton3D, joint: int, upper: int, back := false) -> float:
	var mesh: ArrayMesh = left_mesh(sk)
	var jr := sk.get_bone_global_rest(joint).origin
	var cx := sk.get_bone_global_rest(upper).origin.x
	var pts := {}
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			var p := v[i]
			var outer := p.z - jr.z if back else jr.z - p.z
			if absf(p.x - cx) > 0.012 or outer < 0.02 or absf(p.y - jr.y) > 0.12:
				continue
			var q := Vector3.ZERO
			for k in range(4):
				var bi := bones[i * 4 + k]
				q += (sk.get_bone_global_pose(bi) * sk.get_bone_global_rest(bi).affine_inverse() * p) * weights[i * 4 + k]
			pts[snappedf(p.y, 0.001)] = q
	var ys := pts.keys()
	ys.sort()
	var worst := 0.0
	for i in range(1, ys.size() - 1):
		var a: Vector3 = pts[ys[i]] - pts[ys[i - 1]]
		var b: Vector3 = pts[ys[i + 1]] - pts[ys[i]]
		if a.length() > 0.004 and b.length() > 0.004:
			worst = maxf(worst, rad_to_deg(a.angle_to(b)))
		if OS.get_environment("KINK_DBG") != "":
			print("   kink y %.3f  seg %.3f -> %.3f  turn %.0f" % [ys[i] - jr.y, a.length(), b.length(), rad_to_deg(a.angle_to(b))])
	return worst


## The skinned mesh carrying the left limb (ArmBody has one per arm).
func left_mesh(sk: Skeleton3D) -> ArrayMesh:
	return ((sk.get_node("MeshL") if sk.has_node("MeshL") else sk.get_node("Mesh")) as MeshInstance3D).mesh


## Triangles whose winding disagrees with their vertex normals (drawn inside-out).
func inside_out(mesh: ArrayMesh) -> int:
	var bad := 0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for tt in range(0, v.size(), 3):
			var fnm := (v[tt + 2] - v[tt]).cross(v[tt + 1] - v[tt])
			if fnm.length() > 1e-9 and fnm.normalized().dot((n[tt] + n[tt + 1] + n[tt + 2]).normalized()) < 0.0:
				bad += 1
	return bad


## Mean distance of the skinned vertices within `band` of a joint height from
## that joint, posed vs rest. `bone` is the bone whose origin is the joint.
func joint_keep(sk: Skeleton3D, bone: int, side_x: float, band: float) -> float:
	var mesh: ArrayMesh = left_mesh(sk)
	var jr := sk.get_bone_global_rest(bone).origin
	var jp := sk.get_bone_global_pose(bone).origin
	var a := 0.0
	var b := 0.0
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for i in range(v.size()):
			var p := v[i]
			if p.x * side_x <= 0.0 or absf(p.y - jr.y) > band:
				continue
			var q := Vector3.ZERO
			for k in range(4):
				var bi := bones[i * 4 + k]
				q += (sk.get_bone_global_pose(bi) * sk.get_bone_global_rest(bi).affine_inverse() * p) * weights[i * 4 + k]
			a += p.distance_to(jr)
			b += q.distance_to(jp)
	return b / maxf(a, 1e-6)


func _initialize():
	# 1. every option value builds
	var opts := {"body": CharacterLook.BODIES, "build": CharacterLook.BUILDS, "height": CharacterLook.HEIGHTS,
		"head": CharacterLook.HEADS, "nose": CharacterLook.NOSES, "eyes": range(6), "brows": range(5), "mouth": range(6),
		"marks": CharacterLook.MARKS, "hair": CharacterLook.HAIR, "facial_hair": CharacterLook.FACIAL_HAIR,
		"hat": CharacterLook.HATS, "top": CharacterLook.TOPS, "sleeves": CharacterLook.SLEEVES, "vest": CharacterLook.VESTS,
		"coat": CharacterLook.COATS, "legs": CharacterLook.LEGS, "feet": CharacterLook.FEET, "belt": CharacterLook.BELTS,
		"gloves": [true, false], "apron": [true, false], "earring": [true, false], "eyepatch": [true, false],
		"scarf": [true, false], "pauldron": [true, false], "pouch": [true, false]}
	var built := 0
	var ok := true
	for k in opts.keys():
		for v in opts[k]:
			var lk := CharacterLook.default_look(); lk[k] = v
			var h := Humanoid.new(); h.setup(lk); root.add_child(h)
			for i in range(5): h._process(1.0 / 60.0)
			var meshes := h.find_children("*", "MeshInstance3D", true, false).size()
			if meshes < 8 or h.hand_r == null or h.hip_socket == null or h.head == null:
				ok = false; print("   bad build ", k, "=", v, " meshes=", meshes)
			h.free(); built += 1
	check("all %d single-option variants build (>=8 meshes, sockets present)" % built, ok)
	var rng := RandomNumberGenerator.new()
	ok = true
	var max_meshes := 0
	for i in range(60):
		rng.seed = 1000 + i
		var h := Humanoid.new(); h.setup(CharacterLook.random_look(rng)); root.add_child(h)
		for j in range(5): h._process(1.0 / 60.0)
		var n := h.find_children("*", "MeshInstance3D", true, false).size()
		max_meshes = maxi(max_meshes, n)
		if n < 8: ok = false
		h.free()
	check("60 random looks build (max %d mesh instances each)" % max_meshes, ok and max_meshes <= 16)
	# 1b. the skinned lower body: one surface, thighs without meshes of their own,
	# nothing inside-out, and the thigh bones follow the leg joints
	var lb_ok := true
	var lb_msg := ""
	for body in ["fem", "masc"]:
		for build in CharacterLook.BUILDS:
			for legs in CharacterLook.LEGS:
				var lk := CharacterLook.base_look(); lk["body"] = body; lk["build"] = build; lk["legs"] = legs
				var h := Humanoid.new(); h.setup(lk); root.add_child(h)
				var lb = h.hips.get_node_or_null("LowerBody")
				if lb == null or not (lb is LowerBody):
					lb_ok = false; lb_msg = "%s/%s/%s: no LowerBody" % [body, build, legs]; h.free(); continue
				var mi: MeshInstance3D = lb.get_node("Mesh")
				if mi.skin == null or h.leg_l.find_children("*", "MeshInstance3D", false, false).size() > 0:
					lb_ok = false; lb_msg = "%s/%s/%s: not skinned, or the thigh still has a mesh" % [body, build, legs]
				var mesh: ArrayMesh = mi.mesh
				for s in range(mesh.get_surface_count()):
					var arr := mesh.surface_get_arrays(s)
					var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					for tt in range(0, v.size(), 3):
						var fnm := (v[tt + 2] - v[tt]).cross(v[tt + 1] - v[tt])
						if fnm.length() > 1e-9 and fnm.normalized().dot((n[tt] + n[tt + 1] + n[tt + 2]).normalized()) < 0.0:
							lb_ok = false; lb_msg = "%s/%s/%s: inside-out triangle at %s" % [body, build, legs, str(v[tt])]
				h.free()
	if lb_msg != "":
		print("   ", lb_msg)
	check("skinned lower body for every body/build/legs: one surface, thighs without own meshes, nothing inside-out", lb_ok)
	# the skinned arms: every top/sleeves/coat, both bodies
	var ab_ok := true
	var ab_msg := ""
	for body in ["fem", "masc"]:
		for top in CharacterLook.TOPS:
			for sl in CharacterLook.SLEEVES:
				for coat in ["none", "longcoat"]:
					var lk := CharacterLook.base_look(); lk["body"] = body; lk["top"] = top; lk["sleeves"] = sl; lk["coat"] = coat
					var h := Humanoid.new(); h.setup(lk); root.add_child(h)
					var ab = h.torso.get_node_or_null("ArmBody")
					if ab == null or not (ab is ArmBody):
						ab_ok = false; ab_msg = "%s/%s/%s/%s: no ArmBody" % [body, top, sl, coat]
					else:
						var bad := inside_out(ab.arm_mesh(false).mesh) + inside_out(ab.arm_mesh(true).mesh)
						if bad > 0:
							ab_ok = false; ab_msg = "%s/%s/%s/%s: %d inside-out triangles" % [body, top, sl, coat, bad]
					h.free()
	if ab_msg != "":
		print("   ", ab_msg)
	check("skinned arms for every body/top/sleeves/coat: present, nothing inside-out", ab_ok)
	# 2. apply_look keeps the weapon
	var h2 := Humanoid.new(); h2.setup(CharacterLook.default_look()); root.add_child(h2)
	h2.set_weapon(Props.weapon_mesh("cutlass"))
	h2._attach_weapon(true)
	rng.seed = 5
	h2.apply_look(CharacterLook.random_look(rng))
	check("apply_look keeps weapon in hand", h2.weapon != null and is_instance_valid(h2.weapon) and h2.weapon.get_parent() == h2.hand_r)
	h2._attach_weapon(false)
	h2.apply_look(CharacterLook.default_look())
	check("apply_look keeps weapon sheathed", h2.weapon.get_parent() == h2.hip_socket)
	h2.free()
	# 3. legacy conversion + neutral defaults
	var legacy := CharacterLook.normalize({"shirt": Color.RED, "coat": true, "hat": "bald", "face": 2, "width": 1.3})
	check("legacy look converts (coat/hair/beard/build/top color)", legacy["coat"] == "longcoat" and legacy["hair"] == "bald" and legacy["facial_hair"] == "beard" and legacy["build"] == "stout" and legacy["top_color"] == Color.RED and not legacy.has("shirt"))
	var partial := CharacterLook.normalize({"top": "tunic"})
	check("partial look fills from neutral base (no captain coat/hat)", partial["coat"] == "none" and partial["hat"] == "none" and partial["top"] == "tunic")
	# 4. save/load
	rng.seed = 77
	var lk := CharacterLook.random_look(rng); lk["name"] = "Mara Vance"
	CharacterLook.save_look(lk)
	var re := CharacterLook.load_look()
	var same := true
	for k in lk.keys():
		if typeof(lk[k]) == TYPE_COLOR:
			if not (lk[k] as Color).is_equal_approx(re[k]): same = false; print("   diff ", k)
		elif lk[k] != re[k]: same = false; print("   diff ", k)
	check("save/load round-trips every key", same)
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			check("player loads the saved look", p.body_model.look["name"] == "Mara Vance")
			# the lower body's thigh bones follow the leg joints (swing one, pose, compare)
			var bm = p.body_model
			var lb: LowerBody = bm.hips.get_node("LowerBody")
			bm.leg_l.rotation = Vector3(0.9, 0.1, -0.2)
			lb._pose()
			var want: Transform3D = bm.hips.global_transform.affine_inverse() * bm.leg_l.global_transform
			check("lower body thigh bone follows the swung leg", lb.get_bone_global_pose(LowerBody.THIGH_L).is_equal_approx(want))
			# lifting a leg (a jump tuck) mustn't flatten that side of the seat:
			# skin the seat on the CPU and compare how far back it reaches
			var depth_rest := seat_back(lb, false)
			bm.leg_l.rotation = Vector3(1.4, 0.0, -0.1)
			lb._pose()
			var depth_up := seat_back(lb, true)
			check("lifting a leg keeps the seat's volume (back of the left glute %.3f m -> %.3f m)" % [depth_rest, depth_up], depth_up > depth_rest * 0.9)
			# ...and doesn't squash the upper thigh: each thigh-section vertex keeps its
			# distance from the thigh's axis (rest vs lifted, worst ring)
			var keep := thigh_keep(lb)
			check("lifting a leg doesn't pinch the upper thigh (worst section keeps %d%% of its girth)" % roundi(keep * 100.0), keep > 0.9)
			# a deeply bent knee stays round: the knee vertices keep their distance from the joint
			bm.shin_l.rotation = Vector3(-2.0, 0.0, 0.0)
			lb._pose()
			var kk := knee_keep(lb)
			check("a bent knee keeps its volume (knee section keeps %d%% of its size)" % roundi(kk * 100.0), kk > 0.88)
			var kink := front_kink(lb, LowerBody.SHIN_L, LowerBody.THIGH_L)
			check("a bent knee is round, not pointed (sharpest turn along its front %d deg)" % roundi(kink), kink < 30.0)
			# arms: a deeply bent elbow and an arm raised overhead stay round
			var ab: ArmBody = bm.torso.get_node("ArmBody")
			bm.arm_l.rotation = Vector3(2.6, 0.0, -0.4)
			bm.fore_l.rotation = Vector3(2.2, 0.0, 0.0)
			ab._pose()
			var ek := joint_keep(ab, ArmBody.FORE_L, -1.0, 0.035)
			var sk := joint_keep(ab, ArmBody.ARM_L, -1.0, 0.035)
			check("a bent elbow keeps its volume (%d%%)" % roundi(ek * 100.0), ek > 0.88)
			var ekink := front_kink(ab, ArmBody.FORE_L, ArmBody.ARM_L, true)
			check("a bent elbow is round, not pointed (sharpest turn along its back %d deg)" % roundi(ekink), ekink < 30.0)
			check("a raised arm keeps the shoulder's volume (%d%%)" % roundi(sk * 100.0), sk > 0.85)
			check("headless: creator not auto-opened", not CharacterCreator.active)
			check("{captain} token fills the name", root.get_node("Dialogue")._fill_tokens("Hi {captain}") == "Hi Mara Vance")
			# open from the pause menu
			root.get_node("GameMenu").open("pause")
			root.get_node("GameMenu")._open_appearance()
			step = 1; t = 0
		1:
			if t < 0.2: return false
			var cc: CharacterCreator = null
			for n in root.get_children():
				if n is CharacterCreator: cc = n
			check("Appearance opens the creator and pauses", cc != null and paused and CharacterCreator.active)
			for tab in CharacterCreator.TABS: cc._show_tab(tab)
			check("all tabs build rows", cc._list.get_child_count() > 0)
			var before: String = p.body_model.look["hair"]
			cc._randomize()
			cc._finish(false)
			check("Cancel keeps the old look and unpauses", p.body_model.look["hair"] == before and not paused and not CharacterCreator.active)
			p.open_creator(false)
			step = 2; t = 0
		2:
			if t < 0.2: return false
			var cc2: CharacterCreator = null
			for n in root.get_children():
				if n is CharacterCreator: cc2 = n
			var coat_before = p.body_model.look["coat"]
			check("Appearance no longer edits clothes (no Outfit/Extras tabs)", not cc2._tab_buttons.has("Outfit") and not cc2._tab_buttons.has("Extras"))
			cc2.look["hair"] = "ponytail"; cc2.look["coat"] = "captain" if coat_before != "captain" else "jacket"; cc2.look["name"] = "Ada Black"
			cc2._finish(true)
			check("Done applies + saves body/hair, keeps worn gear", p.body_model.look["hair"] == "ponytail" and p.body_model.look["coat"] == coat_before and CharacterLook.load_look()["name"] == "Ada Black")
			check("weapon survives the rebuild", p.body_model.weapon != null and p.body_model.weapon.get_parent() != null)
			print("RESULT fails=", fails)
			quit()
	return false
