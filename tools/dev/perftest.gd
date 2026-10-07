extends SceneTree
## Performance round: nothing piles up over a session (swimmers drown, boarders
## left behind slip away, drops expire, the boss doesn't call a second crew),
## and the cheap paths work (stuck-sprint release, rig LOD, 3D render scale,
## prebuilt bodies, shared weapon meshes, far FX skipped, the perf log, orb
## slivers skipped).
const IDLE := 0; const DEAD := 14; const SWIM := 19
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var g
var g2
var bag_far
var bag_near
var fails := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func _process(d: float) -> bool:
	t += d
	if t > 90.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0: return false
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			# --- stuck sprint: an event saying Shift is up lets go of it
			Input.action_press("sprint")
			var mm := InputEventMouseMotion.new()
			mm.shift_pressed = false
			Input.parse_input_event(mm)
			wait = 0.1
			step += 1
		1:
			check("sprint lets go when an event says Shift is up", not Input.is_action_pressed("sprint"))
			Input.action_release("sprint")
			# --- a pirate in open sea with no beach in reach drowns
			g = camp.grunts[0]
			g.global_position = Vector3(260.0, 0.5, -320.0)
			g.velocity = Vector3.ZERO
			g.reset_physics_interpolation()
			# --- a boarder left behind, no captain near, slips away
			g2 = camp.grunts[1]
			g2.boarder = true
			g2.camp = null
			# (the captain far out at sea: nobody near the camp)
			p.global_position = Vector3(450.0, 1.0, -450.0)
			p.reset_physics_interpolation()
			wait = 2.0
			step += 1
		2:
			check("thrown into open sea, the pirate swims (%d)" % g.state, g.state == SWIM)
			check("the boarder stands idle at the camp (%d)" % g2.state, g2.state == IDLE)
			g._swim_t = 25.0
			g2._far_n = 7
			g2._far_t = 0.0
			wait = 0.3
			step += 1
		3:
			check("...and with no beach in reach, drowns (no loot, no XP)", not is_instance_valid(g) or g.state == DEAD)
			check("a boarder idle with no captain near slips away", not is_instance_valid(g2))
			wait = 2.0
			step += 1
		4:
			check("...the drowned body sinks away and is freed", not is_instance_valid(g))
			# --- drops expire, unless a captain is standing right there
			var LB = load("res://scenes/loot/loot_bag.tscn")
			var rum = load("res://resources/items/rum.tres")
			for k in range(2):
				var b = LB.instantiate()
				var st := ItemStack.new()
				st.item = rum
				st.quantity = 1
				var items: Array[ItemStack] = [st]
				b.setup(items, false)
				b.lifetime = 0.5
				current_scene.add_child(b)
				b.global_position = p.global_position + (Vector3(3, 0, 0) if k == 0 else Vector3(80, 0, 0))
				if k == 0: bag_near = b
				else: bag_far = b
			wait = 1.2
			step += 1
		5:
			check("an untouched drop goes after its lifetime", not is_instance_valid(bag_far))
			check("...but not from under a captain's feet", is_instance_valid(bag_near))
			# --- the boss's phase two only ever calls one crew at a time
			var fort = root.find_children("RedtideRock", "", true, false)[0]
			fort.call_crew()
			var n1: int = fort.crew.size()
			fort.call_crew()
			check("a reset fight's second phase two calls no extra crew (%d -> %d)" % [n1, fort.crew.size()], n1 > 0 and fort.crew.size() == n1)
			# --- rig LOD: a villager far off poses now and then; the player's every frame
			set_meta("frames", [])
			wait = 0.0
			step += 1
		6:
			var npcs := root.find_children("*", "NPC", true, false)
			var cam := root.get_viewport().get_camera_3d()
			var far_h = null
			for n in npcs:
				var h = n.get("humanoid")
				if h and h.lod and cam.global_position.distance_to(h.global_position) > 70.0:
					far_h = h
					break
			var frames: Array = get_meta("frames")
			frames.append([Engine.get_process_frames(), far_h.pose_frame if far_h else -1, p.body_model.pose_frame])
			if frames.size() < 30:
				return false
			# (this runs before the nodes each frame: "posed last frame" = frame - 1)
			var far_posed := 0
			var me_posed := 0
			for f in frames:
				if f[1] == f[0] - 1: far_posed += 1
				if f[2] == f[0] - 1: me_posed += 1
			check("a far villager poses only some frames (%d of 30)" % far_posed, far_h != null and far_posed < 20 and far_posed > 0)
			check("the player's own rig poses every frame (%d of 30)" % me_posed, me_posed >= 29)
			# --- the 3D renders at the PSX grid's size
			var psx = root.get_node("PSX")
			root.get_node("Settings").set_value("video", "psx_preset", 4, false)
			var want: float = psx.pixel_res().y / float(root.size.y)
			check("3D renders at the grid's size (scale %.2f, grid / window %.2f)" % [root.scaling_3d_scale, want], absf(root.scaling_3d_scale - minf(want, 1.0)) < 0.01)
			# --- bodies built ahead on a worker thread
			var H = load("res://scripts/npc/humanoid.gd")
			var lk: Dictionary = load("res://scripts/enemies/pirate_grunt.gd").look_for({"seed": 4242})
			H.prebuild([lk])
			set_meta("lk", lk)
			wait = 0.0
			step += 1
		7:
			var H = load("res://scripts/npc/humanoid.gd")
			H._reap()
			if not H._tasks.is_empty():
				return false
			var us := Time.get_ticks_usec()
			var h = H.make(get_meta("lk"))
			var ms := (Time.get_ticks_usec() - us) / 1000.0
			check("a prebuilt body is handed over at once (%.1f ms)" % ms, h != null and ms < 10.0 and h.pivot != null)
			root.add_child(h)
			check("...a whole, posable rig (skinned limbs, %d children)" % h.get_child_count(), h.hips.get_node_or_null("LowerBody") != null)
			h.queue_free()
			# --- weapon meshes are built once and shared
			check("weapon meshes are shared", Props.weapon_mesh("cutlass:sabre:2") == Props.weapon_mesh("cutlass:sabre:2"))
			# --- FX far from the camera aren't made
			var fx = root.get_node("FX")
			var cam := root.get_viewport().get_camera_3d()
			check("a burst 500 m off isn't made", fx._burst(cam.global_position + Vector3(500, 0, 0), 4, fx._spark_mat, 0.1, 0.3, {}) == null)
			check("...one in front of you is", fx._burst(cam.global_position - cam.global_basis.z * 4.0, 4, fx._spark_mat, 0.1, 0.3, {}) != null)
			# --- the perf log writes a line (exported builds too)
			var perf = root.get_node("Perf")
			perf._write_line()
			var txt := FileAccess.get_file_as_string("user://perf.log")
			check("user://perf.log gets a header and a line", txt.begins_with("Driftwake") and txt.contains(" min  fps "))
			# --- skill bar: an empty or full orb's sliver is skipped, not triangulated
			var SB = load("res://scripts/ui/skill_bar.gd")
			check("orb slivers are skipped", not SB._drawable(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0.01)])))
			check("...real pieces are drawn", SB._drawable(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])))
			# --- the terrain comes in chunks (culled by view and shadow range)
			var terrain = root.find_children("WorldTerrain", "", true, false)[0]
			check("the world terrain is chunked (%d pieces)" % terrain.get_child_count(), terrain.get_child_count() == 65)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false
