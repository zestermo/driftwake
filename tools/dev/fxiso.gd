extends SceneTree
var f := 0
var holder: Node3D
func _initialize():
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.3, 0.45, 0.3)
	env.environment = e; root.add_child(env)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.look_at_from_position(Vector3(0, 2.5, 5), Vector3(0, 1, 0))
	holder = Node3D.new(); root.add_child(holder)
func _process(_d):
	f += 1
	var fx = root.get_node("FX")
	if f == 5:
		fx.slash(holder, "right", 2.0)
		fx.dust_ring(Vector3(-1.5, 0, 0), 14, 0.7)
		fx.dust(Vector3(1.5, 0.2, 0), 8, 0.6)
		fx.sparkle(Vector3(0, 2.2, 0), 12)
		print("kids: ", root.get_children().map(func(c): return c.get_class()))
	if f == 14:
		for c in holder.get_children(): print("trail progress ", c.get_instance_shader_parameter("progress"), " fade ", c.get_instance_shader_parameter("fade"))
		root.get_texture().get_image().save_png("res://tools/dev/out/fxiso.png"); print("SAVED"); quit()
	return false
