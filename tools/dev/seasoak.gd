extends SceneTree
## Repro for the sea going pale and opaque: F6 through every weather and
## back to clear (as in the capture), shooting the sea from Brinehollow's dock
## at each stop and printing what the sea and the haze are fed. Args: <out_prefix>
var t := 0.0
var out := ""
var p
var w
var oc
var cam: Camera3D
var t0 := 0.0
var n := 0
var i := 0
const SEQ := [1, 2, 3, -1, 0, 0]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func dump(tag: String) -> void:
	var m = oc.ocean_material
	print("[%s] t %.0f state %d fog %.2f storm %.2f in_cloud %.2f begin %.0f end %.0f haze_h %.2f  deep %s shallow %s amp %.2f" % [tag, t, w.state, w.fog, w.storm, w.in_cloud, w.fog_begin, w.fog_end, w.haze_height,
		m.get_shader_parameter("deep_color"), m.get_shader_parameter("shallow_color"), oc.amp_mult])
	root.get_texture().get_image().save_png("%s_%s.png" % [out, tag])
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for k in root.find_children("*", "CharacterCreator", true, false): k._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		w = root.get_node("Weather")
		oc = root.get_node("Ocean")
		var dh := fposmod(10.75 - float(w.hour()), 24.0)
		w.world_offset += dh / 24.0 * float(w.DAY_LEN)
		cam = Camera3D.new(); cam.fov = 85; cam.far = 3000; root.add_child(cam); cam.current = true
		p.global_position = Vector3(149.5, 1.8, 19.44)
		p.reset_physics_interpolation()
		cam.global_position = Vector3(147.36, 5.4, 23.2)
		cam.look_at(cam.global_position + Vector3(0.43, -0.5, -0.75), Vector3.UP)
		dump("start")
		t0 = t
		return false
	if t - t0 > 12.0:
		dump("%d_%d" % [i, SEQ[i]])
		w._apply_force(SEQ[i], w.world_time())
		i += 1
		t0 = t
		if i >= SEQ.size():
			quit()
	return false
