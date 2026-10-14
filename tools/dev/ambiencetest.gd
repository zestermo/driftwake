extends SceneTree
## Ambience (the sound of where you are): surf at the end of Brinehollow's
## dock, quieter surf and wind in the middle of the island, and aboard the
## ship out at sea the open swell and the deep bed over the surf, the hull's wash
## rising (in volume and pitch) once she's under way, her timbers creaking; in a
## storm the wind's gusts and her spray's hiss; muffled under water; and ashore,
## waves crashing on a cliff and surf on a beach, each where it is.
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
	load("res://tools/dev/test_kit.gd").seed_of(self)
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
	if t > 160.0:
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
			check("...under it the deep swell", db("deep") > -25.0)
			var c: Array = amb.coast.nearest("", p.global_position)
			print("   coast %.0f m off: far breakers %.1f dB" % [c[0], db("far")])
			check("...and breakers on Brinehollow's far shore", float(c[0]) < 70.0 or float(c[0]) > 175.0 or db("far") > -30.0)
			# a storm: gusts, and the spray over her bow hissing
			root.get_node("Weather").forced = 3
			root.get_node("Weather").forced_at = root.get_node("Weather").world_time() - 100.0
			set_meta("gust", 0.0)
			set_meta("wind_calm", db("wind"))
			next()
		5:
			set_meta("gust", maxf(float(get_meta("gust")), amb.gust))
			if not wait(14.0): return false
			print("   storm under sail: gusts up to %.2f, wind %.1f dB, spray hiss %.1f dB" % [float(get_meta("gust")), db("wind"), db("spray")])
			check("in a storm the wind comes in gusts", float(get_meta("gust")) > 0.3)
			check("...louder than before", db("wind") > float(get_meta("wind_calm")))
			check("...and the ship's spray hisses", db("spray") > -40.0)
			# under water: everything muffled
			var cam := Camera3D.new()
			cam.name = "UnderCam"
			root.add_child(cam)
			cam.global_position = ship.global_position + Vector3(12.0, -4.0, 0.0)
			cam.current = true
			next()
		6:
			if not wait(2.5): return false
			var lp := low_pass()
			print("   under water: %.2f, low-pass %.0f Hz (on %s), rumble %.1f dB" % [amb.under, lp[0], lp[1], db("under")])
			check("with the camera under water the sound is muffled", amb.under > 0.9 and float(lp[0]) < 1000.0 and lp[1])
			check("...under a rumble of its own", db("under") > -25.0)
			root.get_node("UnderCam").queue_free()
			next()
		7:
			if not wait(1.5): return false
			var lp := low_pass()
			check("...and clear again above it", amb.under < 0.05 and not lp[1])
			root.get_node("Weather").forced = 0
			# a cliff on Brinehollow, then a beach: the shore by what it is
			var isl = root.get_node("World/Islands/Brinehollow")
			var spot := shore_spot(isl, true)
			check("found a cliff on Brinehollow", spot != Vector3.INF)
			put(spot)
			next()
		8:
			if not wait(4.0): return false
			print("   on a cliff top: rock %.1f shore %.1f dB (rock %.0f m, beach %.0f m)" % [db("rock"), db("shore"),
				amb.coast.nearest("rock", p.global_position)[0], amb.coast.nearest("beach", p.global_position)[0]])
			check("on a cliff top: waves crashing on rock", db("rock") > -25.0 and db("rock") > db("shore"))
			var isl = root.get_node("World/Islands/Brinehollow")
			put(shore_spot(isl, false))
			next()
		9:
			if not wait(4.0): return false
			print("   on a beach: rock %.1f shore %.1f dB (rock %.0f m, beach %.0f m)" % [db("rock"), db("shore"),
				amb.coast.nearest("rock", p.global_position)[0], amb.coast.nearest("beach", p.global_position)[0]])
			check("on a beach: the surf", db("shore") > -20.0 and db("shore") > db("rock"))
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false


## [cutoff Hz, on] of the underwater low-pass on the SFX bus.
func low_pass() -> Array:
	var b := AudioServer.get_bus_index("SFX")
	for i in range(AudioServer.get_bus_effect_count(b)):
		var e := AudioServer.get_bus_effect(b, i)
		if e.resource_name == "underwater":
			return [(e as AudioEffectLowPassFilter).cutoff_hz, AudioServer.is_bus_effect_enabled(b, i)]
	return [INF, false]


## A few metres in from Brinehollow's waterline, on a cliff (ground 6 m in over 3 m
## high) or a beach (under 1.2 m), along the first bearing that has one.
func shore_spot(isl, cliff: bool) -> Vector3:
	for k in range(64):
		var a := k * TAU / 64.0
		var d := Vector3(cos(a), 0.0, sin(a))
		for r in range(60, 420):
			if isl.height_at(d.x * r, d.z * r) < 0.0:
				var h: float = isl.height_at(d.x * (r - 6), d.z * (r - 6))
				if (cliff and h > 3.0) or (not cliff and h < 1.2 and h > 0.0):
					var lp: Vector3 = d * float(r - (6 if cliff else 4))
					return isl.to_global(Vector3(lp.x, isl.height_at(lp.x, lp.z) + 0.3, lp.z))
				break
	return Vector3.INF
