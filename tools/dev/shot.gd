extends SceneTree
# Usage: godot --path <proj> --script shot.gd -- out.png frames [cam_x cam_y cam_z look_x look_y look_z]
var frames := 0
var target := 120
var out := "/tmp/shot.png"
var cam_args: Array = []
var cam: Camera3D

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if a.size() > 1: target = int(a[1])
	if a.size() >= 8:
		for i in range(2, 8): cam_args.append(float(a[i]))
	change_scene_to_file("res://scenes/world/world.tscn")

func _process(_d: float) -> bool:
	frames += 1
	if cam_args.size() == 6 and frames > 5:
		if cam == null:
			cam = Camera3D.new()
			cam.far = 4000
			root.add_child(cam)
		cam.global_position = Vector3(cam_args[0], cam_args[1], cam_args[2])
		cam.look_at(Vector3(cam_args[3], cam_args[4], cam_args[5]))
		cam.make_current()
	if frames == 3 and OS.get_environment("PSX_OFF") == "1":
		RenderingServer.global_shader_parameter_set("psx_snap_res", Vector2(8192, 8192))
		RenderingServer.global_shader_parameter_set("psx_affine", 0.0)
	if frames == 5 and OS.get_environment("HIDE") != "":
		for pth in OS.get_environment("HIDE").split(","):
			var n = root.get_node_or_null(pth)
			if n: n.visible = false
			else: print("no node ", pth)
	if frames == target:
		var img := root.get_texture().get_image()
		img.save_png(out)
		print("SAVED ", out, " ", img.get_size())
		quit()
	return false
