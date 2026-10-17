extends SceneTree
## Hair lineup on a plain backdrop, the hair's spring chains settled first.
## Args: <out.png> [styles: comma list or all] [yaw_deg: 30 front 3/4, 150 back 3/4] [close|full] [settle frames, default 150]
## Colours per style below (root, tip); "close" frames heads and shoulders only. HS_HAT=<hat> puts a hat on.
const LOOKS := {
	"cascade": [Color(0.66, 0.74, 0.84), Color(0.5, 0.56, 0.72), "fem"],
	"high_tail": [Color(0.12, 0.05, 0.06), Color(0.72, 0.1, 0.12), "fem"],
	"waves": [Color(0.86, 0.66, 0.34), Color(0.8, 0.58, 0.3), "fem"],
	"mane": [Color(0.82, 0.78, 0.64), Color(0.72, 0.68, 0.56), "masc"],
	"princess": [Color(0.96, 0.8, 0.78), Color(0.86, 0.42, 0.38), "fem"],
	"court_bun": [Color(0.07, 0.06, 0.07), Color(0.1, 0.09, 0.11), "fem"],
	"twin_low": [Color(0.82, 0.74, 0.64), Color(0.78, 0.7, 0.6), "fem"],
	"half_bun": [Color(0.42, 0.26, 0.72), Color(0.56, 0.42, 0.86), "fem"],
}
var f := 0
var out := ""
var models: Array = []
var settle := 150


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var styles: Array = Array(a[1].split(",")) if a.size() > 1 and a[1] != "all" else HairFlow.STYLES.duplicate()
	var yaw := deg_to_rad(float(a[2]) if a.size() > 2 else 30.0)
	var close := a.size() > 3 and a[3] == "close"
	settle = int(a[4]) if a.size() > 4 else 150
	root.size = Vector2i(1600, 900)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.93, 0.93, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.74)
	e.ambient_light_energy = 0.75
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-35), 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var cols := mini(styles.size(), 4)
	var rows := ceili(styles.size() / float(cols))
	var dx := 0.62 if close else 0.74
	var dy := 0.75 if close else 1.25
	if rows > 1:
		dy += 0.7
	for i in range(styles.size()):
		var st: String = styles[i]
		var look: Array = LOOKS.get(st, [Color(0.3, 0.2, 0.1), Color(0.3, 0.2, 0.1), "fem"])
		var lk := CharacterLook.base_look()
		lk["hair"] = st
		lk["body"] = look[2]
		lk["hair_color"] = look[0]
		lk["hair_tip"] = look[1]
		lk["hat"] = OS.get_environment("HS_HAT") if OS.has_environment("HS_HAT") else "none"
		lk["sash_color"] = CharacterLook.CLOTH[16]
		lk["name"] = st
		var h := Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		h.position = Vector3((i % cols - (cols - 1) * 0.5) * dx, -(i / cols) * dy, 0)
		h.rotation.y = PI + yaw
		models.append(h)
		# what the hair costs: the head's chains (bones, triangles, surfaces)
		for sc in h.head.find_children("*", "SpringChains", true, false):
			var mi := sc.find_child("Mesh", true, false) as MeshInstance3D
			var tris := 0
			for si in range(mi.mesh.get_surface_count()):
				tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			print("HAIR %s chains %d bones %d tris %d surfaces %d" % [st, sc.chain_count(), sc.skel.get_bone_count(), tris, mi.mesh.get_surface_count()])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(rows * dy + (0.1 if close else 0.15), cols * dx * 9.0 / 16.0)
	var cy := (1.62 if close else 1.32) - (rows - 1) * dy * 0.5
	cam.look_at_from_position(Vector3(0, cy, 6.0), Vector3(0, cy, 0))


func _process(_d: float) -> bool:
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			h.set_process(false)
			for k in range(settle):
				h._process(1.0 / 60.0)
			h.head.rotation = Vector3.ZERO
			h.neck.rotation = Vector3.ZERO
	if f == 8:
		root.get_texture().get_image().save_png(out)
		print("SAVED")
		quit()
	return false
