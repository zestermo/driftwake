extends SceneTree
## Ambience (the sound of where you are): surf at the end of Brinehollow's
## dock, quieter surf and wind in the middle of the island, and aboard the
## ship out at sea the open swell over the surf, the hull's wash rising (in
## volume and pitch) once she's under way, her timbers creaking.
var t := 0.0
var step := 0
var t0 := 0.0
var fails := 0
var p
var ship
var amb


func check(msg: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func wait(secs: float) -> bool:
	return t - t0 >= secs


func next() -> void:
	step += 1
	t0 = t


func db(k: String) -> float:
	return (amb._players[k] as AudioStreamPlayer).volume_db


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	q.exclude = [ship.get_rid()]
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	p.global_position = ((hit["position"] as Vector3) if not hit.is_empty() else at) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(d: float) -> bool:
	t += d
	if t > 90.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	match step:
		0:
			if not wait(2.0): return false
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			amb = root.get_node("Weather/Ambience")
			check("the ambience is running", amb != null)
			# (the loops are QOA-compressed: a loop end taken from the byte count played only the first fifth)
			var short := []
			for k in amb._players:
				var s := (amb._players[k] as AudioStreamPlayer).stream as AudioStreamWAV
				if s.loop_end / s.mix_rate < 15.0 or absf(s.loop_end / s.mix_rate - s.get_length()) > 0.01:
					short.append("%s %.1fs of %.1fs" % [k, s.loop_end / s.mix_rate, s.get_length()])
			check("every ambience loop plays its whole length (15 s or more) %s" % str(short), short.is_empty())
			var rain := root.get_node("Weather")._rain_snd.stream as AudioStreamWAV
			check("...the rain too", absf(rain.loop_end / rain.mix_rate - rain.get_length()) < 0.01)
			var isl = root.get_node("World/Islands/Brinehollow")
			var dp: Vector2 = isl._dock_point(isl.DOCK_LENGTH)
			put(isl.to_global(Vector3(dp.x, isl.DOCK_DECK_Y, dp.y)))
			next()
		1:
			if not wait(4.0): return false
			print("   dock end: land near %.2f far %.2f | shore %.1f sea %.1f wind %.1f dB" % [amb._land_near, amb._land_far, db("shore"), db("sea"), db("wind")])
			check("at the end of the dock: the surf", db("shore") > -20.0)
			check("...no hull sounds off the ship", db("wash") < -50.0 and db("creak") < -50.0)
			check("footsteps on the harbour pier (cobbles) are stone (%s)" % p.ground_surface(), p.ground_surface() == "stone")
			set_meta("shore_dock", db("shore"))
			var isl = root.get_node("World/Islands/Brinehollow")
			put(isl.to_global(Vector3(-20, 0, 10)))
			next()
		2:
			if not wait(4.0): return false
			print("   inland: land near %.2f far %.2f | shore %.1f wind %.1f dB" % [amb._land_near, amb._land_far, db("shore"), db("wind")])
			check("inland: the surf falls away", db("shore") < float(get_meta("shore_dock")) - 6.0)
			check("footsteps inland are the ground's (%s)" % p.ground_surface(), p.ground_surface() in ["grass", "dirt", "sand"])
			# out at sea (deep water, well clear of land), aboard, under full sail
			var wg = root.get_node("World/Islands")
			var sea := Vector3.INF
			for k in range(32):
				var a := k * TAU / 32.0
				var c: Vector2 = wg.starter_center + Vector2(cos(a), sin(a)) * 380.0
				if wg._deep_enough(c, 140.0):
					sea = Vector3(c.x, 0, c.y)
					break
			check("found open sea", sea != Vector3.INF)
			ship.place(sea, 0.0)
			ship.set_anchored(false)
			next()
		3:
			# (her collision follows place() on the next physics step: board her after)
			if not wait(0.3): return false
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0.0, HullBuilder.DECK_Y + 0.3, -2.0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			set_meta("wash_slow", db("wash"))
			ship.sail = 1.0
			next()
		4:
			if not wait(8.0): return false
			var wash := amb._players["wash"] as AudioStreamPlayer
			print("   aboard %s (%s), land near %.2f far %.2f" % [ship.aboard(p.global_position), p.current_state_name(), amb._land_near, amb._land_far])
			print("   at sea, %.1f m/s: sea %.1f shore %.1f wash %.1f (pitch %.2f) gurgle %.1f foam %.1f creak %.1f wind %.1f rig %.1f dB" % [ship.speed, db("sea"), db("shore"), db("wash"), wash.pitch_scale, db("gurgle"), db("foam"), db("creak"), db("wind"), db("rig")])
			check("out at sea: the open swell", db("sea") > -20.0)
			check("aboard under way: water rushing past the hull, louder and higher as she picks up speed", db("wash") > float(get_meta("wash_slow")) + 3.0 and wash.pitch_scale > 0.95)
			check("...gurgling along the planks", db("gurgle") > -35.0)
			check("...foam at the waterline once she's fast", ship.speed < 6.0 or db("foam") > -50.0)
			check("...her timbers creaking", db("creak") > -30.0)
			check("...and footsteps on her deck are wood (%s)" % p.ground_surface(), p.ground_surface() == "wood")
			check("...and the wind on deck", db("wind") > -30.0)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false
