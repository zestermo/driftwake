extends SceneTree
## Strip of frames of an action with a weapon. Args: <out.png> <anim> <weapon> <dur> <yaw_deg> [stance]
var f := 0
var out := ""
var anim := ""
var dur := 0.75
var h: Humanoid
var frames: Array = []
const N := 8
func _initialize():
	var a := OS.get_cmdline_user_args(); out = a[0]; anim = a[1]; dur = float(a[3])
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.6, 0.75)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), 0); root.add_child(sun)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor.mesh = pm; root.add_child(floor)
	h = Humanoid.new(); h.setup(CharacterLook.default_look()); root.add_child(h)
	h.rotation.y = deg_to_rad(float(a[4]))
	h.set_weapon(Props.weapon_mesh(a[2])); h._attach_weapon(true); h.armed = true
	if a.size() > 5:
		h.stance = a[5]
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.3, 4.4), Vector3(0, 1.0, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		h.set_process(false)
		for k in range(40): h._process(1.0 / 60.0)
		h.play(anim, dur)
	if f >= 3 and f % 2 == 1 and frames.size() < N:
		# advance to the next sample time then capture on the following frame
		pass
	if f >= 3:
		var idx := (f - 3) / 2
		if (f - 3) % 2 == 0 and idx < N:
			var target := dur * float(idx) / float(N - 1) * 0.98
			while h._action.size() > 0 and float(h._action["t"]) < target:
				h._process(1.0 / 120.0)
		elif (f - 3) % 2 == 1 and idx < N:
			frames.append(root.get_texture().get_image())
		if frames.size() >= N:
			var f0: Image = frames[0]; var w: int = f0.get_width(); var hh: int = f0.get_height()
			var cw := int(w * 0.5); var ch := int(hh * 0.8)
			var sheet := Image.create(cw * 4, ch * 2, false, f0.get_format())
			for i in range(N):
				var im: Image = frames[i]
				sheet.blit_rect(im, Rect2i(int(w * 0.25), int(hh * 0.1), cw, ch), Vector2i((i % 4) * cw, (i / 4) * ch))
			sheet.save_png(out); print("SAVED"); quit()
	return false
