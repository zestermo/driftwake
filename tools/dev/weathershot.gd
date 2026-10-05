extends SceneTree
## Sky + weather renders. Args: <out_prefix>
var t := 0.0
var p
var w
var cam: Camera3D
var out := ""
var i := -1
var t0 := 0.0
var struck := false
# [name, hour, state, cam mode]
const SHOTS := [["morning_rays", 7.6, 1, "sun"], ["noon", 12.0, 0, "sea"], ["sunset", 18.1, 1, "sun"], ["night", 0.5, 0, "sky"],
	["rain", 13.0, 2, "deck"], ["storm", 15.0, 3, "sea"], ["storm_bolt", 15.0, 3, "bolt"], ["in_cloud", 12.0, 1, "cloud"], ["clouds_above", 10.0, 1, "high"]]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func set_hour(h: float) -> void:
	var cur: float = w.hour()
	var dh := fposmod(h - cur, 24.0)
	w.world_offset += dh / 24.0 * w.DAY_LEN
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		w = root.get_node("Weather")
		cam = Camera3D.new(); cam.fov = 60; cam.far = 3000; root.add_child(cam); cam.current = true
		t0 = t
		return false
	if i < 0 or t - t0 > 2.6:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, SHOTS[i][0]])
			print("shot ", SHOTS[i][0], " hour ", snappedf(w.hour(), 0.1), " state ", w.state, " cov ", snappedf(w.coverage, 0.01), " rain ", w.rain, " incloud ", snappedf(w.in_cloud, 0.01))
		i += 1
		if i >= SHOTS.size():
			quit()
			return false
		var s: Array = SHOTS[i]
		set_hour(float(s[1]))
		w.forced = int(s[2])
		w.forced_at = w.world_time() - 100.0
		t0 = t
		var mode: String = s[3]
		var base: Vector3 = p.global_position
		match mode:
			"sun":
				var sd: Vector3 = w.sun_dir
				cam.global_position = base + Vector3(0, 6, 0)
				cam.look_at(cam.global_position + Vector3(sd.x, 0.15, sd.z).normalized() * 10.0 + Vector3(0, 1.5, 0), Vector3.UP)
			"sea":
				cam.global_position = base + Vector3(0, 8, -20)
				cam.look_at(base + Vector3(0, 4, -120), Vector3.UP)
			"sky":
				cam.global_position = base + Vector3(0, 4, 0)
				cam.look_at(base + Vector3(10, 9, -30), Vector3.UP)
			"deck":
				cam.global_position = base + Vector3(3, 2.5, 6)
				cam.look_at(base + Vector3(0, 1.5, -6), Vector3.UP)
			"bolt":
				cam.global_position = base + Vector3(0, 8, -20)
				cam.look_at(base + Vector3(0, 30, -120), Vector3.UP)
			"cloud":
				var cl = current_scene.get_node("Clouds")
				var best = null
				for c in cl.clouds:
					if cl._vis(c) > 0.9:
						best = c
						break
				var cc: Vector3 = cl.center_of(best, base)
				cam.global_position = cc
				cam.look_at(cc + Vector3(1, 0, 0.2), Vector3.UP)
			"high":
				cam.global_position = base + Vector3(0, 230, 0)
				cam.look_at(base + Vector3(200, 120, -300), Vector3.UP)
	# the bolt shot: strike just before the picture
	if i >= 0 and SHOTS[i][3] == "bolt" and t - t0 > 2.3 and not struck:
		struck = true
		w._strike(p.global_position + Vector3(30, 0, -180), 180.0, 7)
	# the cloud shot: sit in a cloud that's visible at this coverage
	if i >= 0 and SHOTS[i][3] == "cloud" and t - t0 > 0.5:
		var cl = current_scene.get_node("Clouds")
		if cl.density_at(cam.global_position) < 0.5:
			for c in cl.clouds:
				if cl._vis(c) > 0.9:
					cam.global_position = cl.center_of(c, p.global_position)
					cam.look_at(cam.global_position + Vector3(1, 0, 0.2), Vector3.UP)
					break
	return false
