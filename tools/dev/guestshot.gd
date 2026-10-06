extends SceneTree
## A rendered co-op guest: joins a host (nethost.gd) on localhost and
## screenshots fixed views of the world as a guest sees it. Args: <port> <out_prefix>
var t := 0.0
var step := 0
var port := 24690
var out := ""
var net
var accepted := false
var cam: Camera3D
var t0 := 0.0
var i := 0
# [name, cam pos, look dir, seconds after the world is ready]
const SHOTS := [
	["dock", Vector3(147.36, 5.40, 23.20), Vector3(0.43, -0.50, -0.75), 4.0],
	["dock_later", Vector3(147.36, 5.40, 23.20), Vector3(0.43, -0.50, -0.75), 20.0],
	["sea", Vector3(150.0, 8.0, -20.0), Vector3(0.0, -0.3, -1.0), 24.0],
]


func _initialize():
	var a := OS.get_cmdline_user_args()
	port = int(a[0])
	out = a[1]


func _process(d: float) -> bool:
	t += d
	if t > 120.0:
		print("timeout at step ", step)
		quit()
		return false
	match step:
		0:
			if t < 2.0:
				return false
			net = root.get_node("Net")
			net.my_info = {"name": "Guest"}
			net.accepted.connect(func(): accepted = true)
			net.join_game("127.0.0.1", port)
			step = 1
		1:
			if accepted:
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2
		2:
			if not net.world_ready:
				return false
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			var hud = get_first_node_in_group("hud")
			if hud: hud.visible = false
			cam = Camera3D.new(); cam.fov = 85; cam.far = 3000; root.add_child(cam); cam.current = true
			for o in get_nodes_in_group("ocean_mesh"):
				print("ocean mesh ", o.get_path(), " at ", o.global_position, " mesh ", o.mesh, " override ", o.material_override)
			for l in root.find_children("*", "DirectionalLight3D", true, false):
				print("sun ", l.get_path(), " energy ", l.light_energy, " visible ", l.visible)
			print("hour ", root.get_node("Weather").hour(), " state ", root.get_node("Weather").state)
			print("cloud_shadow ", RenderingServer.global_shader_parameter_get("cloud_shadow"), " sky_haze ", RenderingServer.global_shader_parameter_get("sky_haze"), " fog_range ", RenderingServer.global_shader_parameter_get("fog_range"))
			var om = get_first_node_in_group("ocean_mesh")
			for k in ["deep_color", "shallow_color", "amp_mult", "wave_total", "time_val", "near_alpha"]:
				print("  ocean ", k, " ", om.material_override.get_shader_parameter(k))
			t0 = t
			step = 3
		3:
			var s: Array = SHOTS[i]
			cam.global_position = s[1]
			cam.look_at(cam.global_position + (s[2] as Vector3), Vector3.UP)
			if t - t0 < float(s[3]):
				return false
			root.get_texture().get_image().save_png("%s_%s.png" % [out, s[0]])
			print("shot ", s[0], " sea clock ", root.get_node("Ocean").clock(), " net time ", net.time())
			i += 1
			if i >= SHOTS.size():
				net.leave()
				quit()
	return false
