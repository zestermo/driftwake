extends SceneTree
## Distant objects against the horizon (ships, the boss arena) in fog/haze, from
## a fixed camera. Args: <out_prefix>
var t := 0.0
var p
var w
var cam: Camera3D
var out := ""
var i := -1
var t0 := 0.0
# [name, hour, weather state, cam pos, look dir, fov]
const SHOTS := [
	["cap_rain", 6.39, 2, Vector3(149.42, 3.61, 4.53), Vector3(-0.12, -0.35, -0.93), 85.0],
	["cap_rain_zoom", 6.39, 2, Vector3(149.42, 3.61, 4.53), Vector3(-0.12, -0.02, -0.99), 14.0],
	["clear_zoom", 12.0, 0, Vector3(149.42, 3.61, 4.53), Vector3(-0.12, -0.02, -0.99), 14.0],
	["storm_zoom", 15.0, 3, Vector3(149.42, 3.61, 4.53), Vector3(-0.12, -0.02, -0.99), 14.0],
	# capture 161506 (a guest's white sea), and the same with no ocean drawn
	["dock_sea", 10.76, 0, Vector3(147.36, 5.40, 23.20), Vector3(0.43, -0.50, -0.75), 85.0],
	["dock_no_sea", 10.76, 0, Vector3(147.36, 5.40, 23.20), Vector3(0.43, -0.50, -0.75), 85.0, true],
	["dock_sea_9", 9.24, 0, Vector3(147.36, 5.40, 23.20), Vector3(0.43, -0.50, -0.75), 85.0],
	["sea_9", 9.24, 0, Vector3(150.0, 8.0, -20.0), Vector3(0.0, -0.3, -1.0), 85.0],
]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func set_hour(h: float) -> void:
	var dh := fposmod(h - float(w.hour()), 24.0)
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
		cam = Camera3D.new(); cam.far = 3000; root.add_child(cam); cam.current = true
		t0 = t
		return false
	if i < 0 or t - t0 > 2.6:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, SHOTS[i][0]])
			print("shot ", SHOTS[i][0], " hour ", snappedf(w.hour(), 0.1), " state ", w.state, " fog ", w.fog_begin, "..", w.fog_end)
		i += 1
		if i >= SHOTS.size():
			quit()
			return false
		var s: Array = SHOTS[i]
		(get_first_node_in_group("ocean_mesh") as Node3D).visible = not (s.size() > 6 and s[6])
		set_hour(float(s[1]))
		w.forced = int(s[2])
		w.forced_at = w.world_time() - 100.0
		t0 = t
		cam.fov = float(s[5])
		cam.global_position = s[3]
		cam.look_at(cam.global_position + (s[4] as Vector3), Vector3.UP)
	return false
