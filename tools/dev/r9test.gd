extends SceneTree
## Round 9: texture warp off by default, fine sea mesh + physics-ticked wave
## clock, swimmers on the waves, hair-coloured scalp, weather cycle + force,
## storm seas, rain, lightning, sun/moon by the hour, 3D cloud density and
## whiteout, world time saved and restored.
var t := 0.0
var step := 0
var wait := 0.0
var p
var w
var oc
var fails := 0
var data := {}


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func set_hour(h: float) -> void:
	var dh := fposmod(h - float(w.hour()), 24.0)
	w.world_offset += dh / 24.0 * float(w.DAY_LEN)


func _physics_process(_d: float) -> bool:
	if step == 3 and p and p.current_state_name() == "Swim" and t > float(data.get("swim_from", 1e9)):
		var s: Array = data.get("depths", [])
		s.append(oc.get_wave_height(p.global_position) - p.global_position.y)
		data["depths"] = s
	return false


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
			check("affine texture warp is off by default", float(root.get_node("Settings").DEFAULTS["video"]["warp"]) == 0.0)
			var om = get_first_node_in_group("ocean_mesh")
			var arr = om.mesh.surface_get_arrays(0)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			check("the sea mesh has 1 m cells near the camera (%d verts)" % v.size(), v.size() > 40000 and absf(v[1].x - v[0].x) > 0.0)
			var near_ok := false
			for i in range(v.size() - 1):
				if absf(v[i].x) < 2.0 and absf(v[i + 1].x - v[i].x - 1.0) < 0.001:
					near_ok = true
					break
			check("...1 m apart in the middle", near_ok)
			check("the weather is attached to the world", w._scene != null and w._sky_mat != null)
			# --- hair: the scalp under it is hair-coloured
			var hd = p.body_model.head
			var found := false
			var hc: Color = p.body_model.look.get("hair_color", Color.BLACK)
			for mi in hd.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = mi.mesh
				if m == null:
					continue
				for si in range(m.get_surface_count()):
					var mat = m.surface_get_material(si)
					if mat is ShaderMaterial and mat.get_shader_parameter("albedo_color") is Color:
						var c: Color = mat.get_shader_parameter("albedo_color")
						if c.is_equal_approx(hc.darkened(0.15)):
							found = true
			check("the scalp under the hair is hair-coloured", found or str(p.body_model.look.get("hair", "")) == "bald")
			# --- swim: feet stay at the same depth under the passing waves
			var ship = get_first_node_in_group("ship")
			w.forced = 0
			w.forced_at = w.world_time() - 100.0
			p.global_position = ship.global_transform * Vector3(14.0, 2.0, 4.0)
			p.reset_physics_interpolation()
			data["swim_from"] = t + 3.0
			wait = 2.0
			step = 3
		3:
			if t < float(data["swim_from"]) + 6.0:
				return false
			var s: Array = data.get("depths", [])
			s.sort()
			var spread: float = float(s[-1]) - float(s[0]) if s.size() > 10 else 99.0
			check("swimming: you ride the waves (depth varies %.2f m)" % spread, spread < 0.35)
			# --- the wave clock ticks with physics
			check("the wave clock is the physics clock", absf(oc.clock() - oc._session_time()) < 0.5)
			# --- time of day
			set_hour(12.0)
			wait = 0.3
			step = 4
		4:
			check("noon: the sun is high", w.sun_dir.y > 0.75 and w.night < 0.01)
			var sun = current_scene.get_node("DirectionalLight3D")
			data["noon_e"] = sun.light_energy
			set_hour(0.5)
			wait = 0.3
			step = 5
		5:
			var sun = current_scene.get_node("DirectionalLight3D")
			check("midnight: night, stars and moonlight", w.night > 0.95 and sun.light_energy < float(data["noon_e"]) * 0.4)
			check("...the light comes from above (the moon)", (-sun.global_basis.z).y < -0.1)
			set_hour(12.0)
			# --- weather: force a storm
			w.force(3)
			wait = 9.0
			step = 6
		6:
			check("forcing a storm: storm weather", w.state == 3 and w.storm > 0.95)
			check("...rough seas", oc.amp_mult > 1.7 and absf(oc.get_wave_height(Vector3(3, 0, 7), 10.0) / 1.8) > 0.0)
			check("...rain falls", w._rain.emitting and w._rain.amount_ratio > 0.5)
			check("...the fog closes in", current_scene.get_node("WorldEnvironment").environment.fog_depth_end < 300.0)
			check("...the clouds come down and darken", current_scene.get_node("Clouds").storm > 0.95)
			# lightning: deterministic, so find a strike tick and make sure it fires
			data["flashes"] = 0
			data["t_storm"] = t
			step = 7
		7:
			if w.flash > 0.3:
				data["flashes"] = int(data["flashes"]) + 1
			if t - float(data["t_storm"]) < 25.0 and int(data["flashes"]) == 0:
				return false
			check("lightning strikes in a storm", int(data["flashes"]) > 0)
			# under a roof: no rain on you
			w.force(0)
			wait = 9.0
			step = 8
		8:
			check("clear weather again: calm sea, no rain", oc.amp_mult < 1.05 and not w._rain.emitting)
			w.force(-1)
			var a: int = w._slot_state(100)
			var b: int = w._slot_state(100)
			check("the natural cycle is the same for everyone (deterministic)", a == b)
			var seen := {}
			for k in range(200):
				seen[w._slot_state(k)] = true
			check("...and has all four weathers", seen.size() == 4)
			# --- 3D clouds: density and the whiteout
			var cl = current_scene.get_node("Clouds")
			cl.coverage = 1.0
			var c0 = cl.clouds[0]
			var cc: Vector3 = cl.center_of(c0, p.global_position)
			check("inside a cloud: dense", cl.density_at(cc) > 0.9)
			check("...clear air above it", cl.density_at(cc + Vector3(0, 80, 0)) == 0.0)
			# --- world time is saved and restored
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://r9test")
			SG.slot = 1
			set_hour(20.0)
			data["wt"] = w.world_time()
			check("save writes", SG.save(p))
			w.world_offset = 0.0
			var sd: Dictionary = SG._read(SG.slot_path(1))
			check("the save remembers the time of day", absf(float(sd.get("world_time", -1.0)) - float(data["wt"])) < 1.0)
			w.set_world_time(float(sd["world_time"]))
			check("...and loading puts the clock back (%.1f h)" % w.hour(), absf(w.hour() - 20.0) < 0.2)
			SG.delete_slot(1)
			SG._test_dir = ""
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
