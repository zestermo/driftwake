extends SceneTree
## Pose bench: a standalone Humanoid on a flat floor, actions frozen at given
## progress values, shot from several angles.
## Args: <out_prefix> <stance> <weapon|none> <action:u,action:u,...> [views: side,front,three,top]
var f := 0
var h
var cam: Camera3D
var out := ""
var shots: Array = []
var views: Array = ["three"]
var si := 0
var vi := 0
var hold := 0
var tt := 0.0
const DUR := 30.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var stance := a[1]
	var weapon := a[2]
	for s in a[3].split(","):
		var p := s.split(":")
		shots.append([p[0], float(p[1]) if p.size() > 1 else -1.0])
	if a.size() > 4:
		views = Array(a[4].split(","))
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.72)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	w.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 8)
	floor_.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.4, 0.33)
	floor_.material_override = fm
	w.add_child(floor_)
	# a target marker 1.3 m in front (model forward = -Z)
	var tgt := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03; cm.bottom_radius = 0.03; cm.height = 1.8
	tgt.mesh = cm
	tgt.position = Vector3(0.9, 0.9, -1.3)
	w.add_child(tgt)
	h = Humanoid.new()
	h.swappable_hands = true
	var lk0 := CharacterLook.base_look() if OS.get_environment("PB_BASE") != "" else CharacterLook.default_look()
	if OS.get_environment("PB_FEM") != "":
		lk0["body"] = "fem"
		lk0["hair"] = "long"
	# look overrides, e.g. PB_KV="legs=shorts;build=broad;top=tube"
	for kv in OS.get_environment("PB_KV").split(";", false):
		var p := kv.split("=")
		lk0[p[0]] = p[1]
	h.setup(lk0)
	w.add_child(h)
	h.stance = stance
	if weapon != "none":
		h.set_weapon(Props.weapon_mesh(weapon))
		# PB_DUAL=1: the same weapon in the off hand too (dual pistols / swords)
		if OS.get_environment("PB_DUAL") != "":
			h.set_offhand(Props.weapon_mesh(weapon))
		h._attach_weapon(true)
		h.auto_point_guns = true
	h.armed = OS.get_environment("PB_REST") == ""
	if OS.get_environment("PB_BEAST") != "":
		var lk: Dictionary = h.look.duplicate(true)
		var fur := Color(0.55, 0.5, 0.44)
		lk["skin"] = fur
		lk["hair"] = "wild"
		lk["hair_color"] = fur.darkened(0.25)
		lk["facial_hair"] = "beard"
		lk["hat"] = "none"
		lk["height"] = float(lk.get("height", 1.0)) * 1.1
		lk["build"] = "broad"
		h.apply_look(lk)
		h.set_beast(true, fur)
	# airborne at this vertical speed (e.g. -6 = coming down, knees tucked)
	if OS.get_environment("PB_AIR") != "":
		h.grounded = false
		h.vertical_speed = float(OS.get_environment("PB_AIR"))
	if OS.get_environment("PB_SPEED") != "":
		h.ground_speed = float(OS.get_environment("PB_SPEED"))
		h.local_move = Vector2(0, 1)
		h.sprinting = OS.get_environment("PB_SPRINT") != ""
	cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.fov = 38


func place_cam(v: String) -> void:
	var c := Vector3(0, 1.0, -0.3)
	match v:
		"side":   # from the character's left
			cam.global_position = c + Vector3(-4.2, 0.3, 0)
		"right":
			cam.global_position = c + Vector3(4.2, 0.3, 0)
		"front":
			cam.global_position = c + Vector3(0, 0.4, -4.2)
		"back":
			cam.global_position = c + Vector3(0, 0.6, 4.2)
		"top":
			cam.global_position = c + Vector3(0.01, 4.5, 0.2)
		"chest":   # close on the shoulders, front three-quarter
			c = Vector3(0, 1.35, 0)
			cam.global_position = c + Vector3(-1.1, 0.15, -1.5)
		"chestf":
			c = Vector3(0, 1.35, 0)
			cam.global_position = c + Vector3(0, 0.1, -1.9)
		"chests":
			c = Vector3(0, 1.35, 0)
			cam.global_position = c + Vector3(-1.9, 0.1, 0)
		"hipsb":   # close on the waist and seat: from behind, the side, three-quarter back
			c = Vector3(0, 0.95, 0)
			cam.global_position = c + Vector3(0, 0.15, 1.9)
		"hipss":
			c = Vector3(0, 0.95, 0)
			cam.global_position = c + Vector3(-1.9, 0.1, 0)
		"hipsu":   # low behind, looking up under the seat
			c = Vector3(0, 0.75, 0)
			cam.global_position = c + Vector3(0.0, -0.45, 1.1)
		"hipsf":
			c = Vector3(0, 0.95, 0)
			cam.global_position = c + Vector3(0, 0.15, -1.9)
		"hips3":
			c = Vector3(0, 0.95, 0)
			cam.global_position = c + Vector3(-1.35, 0.2, 1.35)
		_:        # three-quarter front-left
			cam.global_position = c + Vector3(-3.0, 1.2, -2.8)
	cam.look_at(c, Vector3.UP if v != "top" else Vector3.FORWARD)


func _process(d: float) -> bool:
	f += 1
	tt += d
	if f < 4:
		return false
	if si >= shots.size():
		quit()
		return false
	var s: Array = shots[si]
	var name_: String = s[0]
	var u: float = s[1]
	if hold == 0:
		if name_ != "guard":
			h.play(name_, DUR)
	if name_ != "guard":
		h._action["t"] = u * DUR
		h._action_w = 1.0
	hold += 1
	place_cam(views[vi])
	if hold >= 5:
		root.get_texture().get_image().save_png("%s_%02d_%s_%s.png" % [out, si, name_, views[vi]])
		vi += 1
		hold = 1
		if vi >= views.size():
			vi = 0
			si += 1
			hold = 0
			h.stop_action()
	return false
