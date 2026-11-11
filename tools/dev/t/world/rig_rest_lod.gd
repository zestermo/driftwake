extends SceneTree
## Two rig rules from the 2026-11-10 perf pass (docs/review_2026_11_10.md):
## - a lod rig standing about (no action, not walking, not talking) poses one step less often past REST_R of the
##   camera; walking, talking or close by it keeps its rate;
## - grunts in a fight (fight_lod) swing hair and cloth only for the SIMS_N nearest the camera, as calm ones do
##   (they had dropped out of that rule when fights took them off `lod`: a third of a fighting grunt's pose).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var body
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	var gs: Array = []
	for i in range(10):
		var a := TAU * float(i) / 10.0
		gs.append({"post": Vector3(cos(a) * 5.0, 0, sin(a) * 5.0), "role": "sword", "seed": 500 + i})
	stage = TK.stage(self, {"hud": false, "grunts": gs})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or stage.camp.grunts.size() < 10 or TK.ticking(until):
		return false
	match step:
		0:
			# (by path: Humanoid and CharacterLook reach the autoloads)
			var H = load("res://scripts/npc/humanoid.gd")
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			body = H.make(load("res://scripts/npc/character_look.gd").random_look(rng))
			body.lod = true
			stage.add_child(body)
			until = TK.wait_ticks(4)
		1:
			var cam: Camera3D = root.get_viewport().get_camera_3d()
			check("the stage has a camera", cam != null)
			# (2026-11-11) the joints are out of the engine's physics interpolation, the body over them in it
			check("a body's joints don't interpolate, the body does", body.pivot.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF
					and not body.pivot.is_physics_interpolated() and not body.head.is_physics_interpolated() and body.is_physics_interpolated())
			var cap = stage.player.find_children("*", "", true, false).filter(func(n): return n is Node3D and n.name == "Pivot")
			check("the captain's too", cap.size() == 1 and not cap[0].is_physics_interpolated() and stage.player.is_physics_interpolated())
			var gr = stage.camp.grunts[0]
			check("and a grunt's", not gr.humanoid.pivot.is_physics_interpolated() and gr.is_physics_interpolated())
			var fwd: Vector3 = -cam.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var at := func(m: float) -> void:
				body.global_position = Vector3(cam.global_position.x, stage.player.global_position.y, cam.global_position.z) + fwd * m
			at.call(9.0)
			check("standing about 9 m off: every 2nd frame (%d)" % body._lod_every(), body._lod_every() == 2)
			body.ground_speed = 2.0
			check("walking there: every frame (%d)" % body._lod_every(), body._lod_every() == 1)
			body.ground_speed = 0.0
			body.talking = true
			check("talking there: every frame (%d)" % body._lod_every(), body._lod_every() == 1)
			body.talking = false
			at.call(4.0)
			check("standing 4 m off: every frame (%d)" % body._lod_every(), body._lod_every() == 1)
			at.call(30.0)
			check("standing 30 m off: every 3rd frame (%d)" % body._lod_every(), body._lod_every() == 3)
			body.lod = false
			at.call(9.0)
			check("a rig that isn't lod (a captain): every frame (%d)" % body._lod_every(), body._lod_every() == 1)
			body.queue_free()
			# --- the fight
			stage.player.hurtbox.monitorable = false
			for g in stage.camp.grunts:
				g.alert()
			until = TK.wait_secs(2.0)
		2:
			var fighting := 0
			var cloth := 0
			var swinging := 0
			for g in stage.camp.grunts:
				var h = g.humanoid
				if h.fight_lod:
					fighting += 1
				if not h._sims.is_empty():
					cloth += 1
					if h._sims_near:
						swinging += 1
			print("   %d in the fight, %d with hair or cloth, %d swinging it" % [fighting, cloth, swinging])
			check("the grunts are in the fight (%d of 10)" % fighting, fighting >= 8)
			check("most have hair or cloth to swing (%d)" % cloth, cloth >= 6)
			# (SIMS_N 4, and one more for the slack that keeps two at the edge from trading places)
			check("only the nearest few swing it (%d of %d)" % [swinging, cloth], swinging >= 1 and swinging <= 5)
			return TK.done(fails)
	step += 1
	return false
