extends SceneTree
## Any procedural model in the game's light, auto-framed from a few angles, a
## contact sheet of the views, and its numbers (size, triangles, surfaces = draw
## calls, materials, colliders, lights).
## Args: <out_prefix> "<expr>[ | <expr> ...]" [views]
##   expr: GDScript returning a Node3D, Mesh or MeshBuilder (or an Array of them):
##     'Buildings.house({"floors": 2, "roof": "hip"})', 'Props.barrel()',
##     'WeaponDesigns.build("axe:war:4")', 'S.anchor()' (S = tools/dev/model_samples.gd).
##     Several (split on " | ") stand in a row along +X, left to right. Statements split by
##     ";" ending in a return also work: 'var n = Node3D.new(); HullBuilder.build(n); return n'.
##   views (comma separated; default front3,front,side,back3,top): front, front3, side,
##     back, back3, top, low (from knee height), far (front3, 4x out), eye (eye height,
##     6 m in front of the front face), wire (front3 as wireframe), or "yaw:pitch[:zoom]"
##     in degrees (yaw 0 = looking at the front, which faces +Z; zoom < 1 = closer).
## Env: MS_GROUND=<texture>|none (default grass), MS_HOUR=21, MS_PSX=<preset 0-4> (the game's
##   pixel grid; 0 = 640x360) instead of native, MS_ZOOM=0.5 (all views), MS_FOCUS="x,y,z"
##   (aim at that point of the first model, in its builder's coordinates, instead of the
##   row's centre; pair with MS_ZOOM for a close-up), MS_ROW=y|z (stack the row along that
##   axis instead of X: weapons lie along -Z, so MS_ROW=y with a side view shows a rack).
## Prints "MS " lines; the sheet is <out_prefix>_sheet.png (views left to right, top to bottom).
const VIEWS := {
	"front": [0.0, 8.0, 1.0], "front3": [35.0, 22.0, 1.0], "side": [90.0, 8.0, 1.0],
	"back": [180.0, 8.0, 1.0], "back3": [215.0, 22.0, 1.0], "top": [0.0, 84.0, 1.0],
	"low": [25.0, -6.0, 1.0], "far": [35.0, 18.0, 4.0], "wire": [35.0, 22.0, 1.0],
}
const AT := Vector3(0, 400, 0)
const FOV := 40.0

var t := 0.0
var out := ""
var exprs: Array = []
var views: Array = []
var shots: Array = []
var step := -1
var wait := 0
var cam: Camera3D
var row: Node3D
var box: AABB
var focus: Vector3


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	for e in a[1].split(" | "):
		exprs.append(e.strip_edges())
	views = Array((a[2] if a.size() > 2 else "front3,front,side,back3,top").split(","))
	if views.has("wire"):
		RenderingServer.set_debug_generate_wireframes(true)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t < 2.0:
		return false
	if step == -1:
		_setup()
		step = 0
		wait = 50 if OS.get_environment("MS_HOUR") != "" else 25
		return false
	if wait > 0:
		wait -= 1
		return false
	if step > 0:
		var img := root.get_texture().get_image()
		var n: String = views[step - 1]
		img.save_png("%s_%s.png" % [out, n.replace(":", "_")])
		shots.append(img)
		root.debug_draw = Viewport.DEBUG_DRAW_DISABLED
	if step >= views.size():
		_sheet()
		print("MS saved %s_*.png" % out)
		quit()
		return false
	_aim(views[step])
	step += 1
	wait = 4
	return false


func _setup() -> void:
	if OS.get_environment("MS_PSX") != "":
		root.get_node("Settings").set_value("video", "psx_preset", int(OS.get_environment("MS_PSX")), false)
	else:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	get_first_node_in_group("hud").visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	if OS.get_environment("MS_HOUR") != "":
		var wx = root.get_node("Weather")
		var k: Dictionary = (wx.get_script() as GDScript).get_script_constant_map()
		wx.set_world_time(fposmod(float(OS.get_environment("MS_HOUR")) - float(k["START_HOUR"]), 24.0) / 24.0 * float(k["DAY_LEN"]))
	cam = Camera3D.new()
	cam.fov = FOV
	cam.far = 3000
	root.add_child(cam)
	cam.current = true
	row = Node3D.new()
	row.name = "ModelShot"
	current_scene.add_child(row)
	row.global_position = AT
	var models: Array = []
	for e in exprs:
		var made = _eval(e)
		for m in (made if made is Array else [made]):
			models.append([e, _node(m)])
	# stand them in a row (along +X, or MS_ROW), each one's near edge after the last one's far edge
	var x := 0.0
	var gap := 0.0
	for m in models:
		var n: Node3D = m[1]
		row.add_child(n)
		var b := _bounds(n)
		gap = maxf(gap, maxf(b.size.x, b.size.z) * 0.15)
	var ax := maxi("xyz".find(OS.get_environment("MS_ROW")), 0) if OS.get_environment("MS_ROW") != "" else 0
	for m in models:
		var n: Node3D = m[1]
		var b := _bounds(n)
		n.position[ax] = x - b.position[ax]
		x += b.size[ax] + maxf(gap, 0.3)
	box = AABB()
	var first := true
	var sums := {"tris": 0, "surfaces": 0}
	for m in models:
		var b := _bounds(m[1])
		box = b if first else box.merge(b)
		first = false
		_report(m[0], m[1], sums)
	if models.size() > 1:
		print("MS total: %d models, %d surfaces, %d tris" % [models.size(), sums["surfaces"], sums["tris"]])
	var ground := OS.get_environment("MS_GROUND")
	if ground != "none":
		var mb := MeshBuilder.new()
		var span := maxf(60.0, maxf(box.size.x, box.size.z) * 6.0)
		mb.add_box(PSXMat.lit(ground if ground != "" else "grass"), Transform3D(Basis(), Vector3(box.get_center().x, -0.1, box.get_center().z)), Vector3(span, 0.2, span), 0.5)
		row.add_child(mb.to_instance("Ground"))
	focus = box.get_center()
	if OS.get_environment("MS_FOCUS") != "":
		var f := OS.get_environment("MS_FOCUS").split(",")
		focus = (models[0][1] as Node3D).position + Vector3(float(f[0]), float(f[1]), float(f[2]))


func _eval(e: String):
	var gd := GDScript.new()
	var lines := PackedStringArray()
	for s in e.split(";"):
		lines.append("\t" + s.strip_edges())
	var body := "\n".join(lines) if e.contains("return ") else "\treturn " + e
	gd.source_code = "extends RefCounted\nconst S := preload(\"res://tools/dev/model_samples.gd\")\nfunc make():\n%s\n" % body
	var err := gd.reload()
	if err != OK:
		push_error("modelshot: can't compile: " + e)
		quit(1)
		return []
	return gd.new().make()


func _node(m) -> Node3D:
	if m is Node3D:
		return m
	if m is MeshBuilder:
		return (m as MeshBuilder).to_instance()
	if m is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		return mi
	push_error("modelshot: not a Node3D, Mesh or MeshBuilder: " + str(m))
	quit(1)
	return Node3D.new()


## Bounds of everything visible under `n`, in the row's space.
func _bounds(n: Node3D) -> AABB:
	var inv := row.global_transform.affine_inverse()
	var b := AABB()
	var first := true
	for v in [n] + n.find_children("*", "", true, false):
		if not (v is MeshInstance3D or v is MultiMeshInstance3D):
			continue
		var vb: AABB = inv * (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		b = vb if first else b.merge(vb)
		first = false
	return b


func _report(label: String, n: Node3D, sums: Dictionary) -> void:
	var b := _bounds(n)
	var by := {}
	var meshes := 0
	var surfaces := 0
	var tris := 0
	var colliders := 0
	var lights := 0
	for v in [n] + n.find_children("*", "", true, false):
		if v is CollisionShape3D:
			colliders += 1
		elif v is Light3D:
			lights += 1
		elif v is MeshInstance3D and (v as MeshInstance3D).mesh:
			meshes += 1
			var mi := v as MeshInstance3D
			for i in range(mi.mesh.get_surface_count()):
				var k := _tris(mi.mesh, i)
				var key := _mat_name(mi.get_active_material(i))
				by[key] = int(by.get(key, 0)) + k
				tris += k
				surfaces += 1
		elif v is MultiMeshInstance3D and (v as MultiMeshInstance3D).multimesh:
			var mm := (v as MultiMeshInstance3D).multimesh
			meshes += 1
			for i in range(mm.mesh.get_surface_count()):
				var k := _tris(mm.mesh, i) * mm.instance_count
				by["(multimesh) " + _mat_name(mm.mesh.surface_get_material(i))] = k
				tris += k
				surfaces += 1
	print("MS %s" % label)
	print("MS   size %.2f x %.2f x %.2f m (x y z), from (%.2f, %.2f, %.2f)" % [b.size.x, b.size.y, b.size.z, b.position.x - n.position.x, b.position.y, b.position.z])
	print("MS   meshes %d  surfaces %d  tris %d  materials %d  colliders %d  lights %d" % [meshes, surfaces, tris, by.size(), colliders, lights])
	var keys := by.keys()
	keys.sort_custom(func(p, q): return int(by[p]) > int(by[q]))
	for key in keys:
		print("MS     %6d  %s" % [by[key], key])
	sums["tris"] += tris
	sums["surfaces"] += surfaces


func _tris(mesh: Mesh, i: int) -> int:
	var arr := mesh.surface_get_arrays(i)
	var idx = arr[Mesh.ARRAY_INDEX]
	if idx != null and (idx as PackedInt32Array).size() > 0:
		return (idx as PackedInt32Array).size() / 3
	return (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


func _mat_name(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var tex = sm.get_shader_parameter("albedo_tex")
		var s: String = (tex as Texture2D).resource_path.get_file().get_basename() if tex is Texture2D and (tex as Texture2D).resource_path != "" else ("painted" if tex else "flat")
		var tint = sm.get_shader_parameter("albedo_color")
		if tint is Color and tint != Color.WHITE:
			s += " #" + (tint as Color).to_html(false)
		var glow = sm.get_shader_parameter("emission_color")
		if glow is Color and (glow as Color).get_luminance() > 0.0:
			s += " +glow"
		return s
	if m == null:
		return "(none)"
	return m.get_class()


func _aim(v: String) -> void:
	if v == "wire":
		root.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	var zoom := float(OS.get_environment("MS_ZOOM")) if OS.get_environment("MS_ZOOM") != "" else 1.0
	var c := row.to_global(focus)
	if v == "eye":
		cam.fov = 60.0
		cam.global_position = row.to_global(Vector3(focus.x, 1.7, box.end.z + 6.0 * zoom))
		cam.look_at(row.to_global(Vector3(focus.x, maxf(focus.y, 1.2), focus.z)), Vector3.UP)
		return
	cam.fov = FOV
	var spec: Array
	if v.contains(":"):
		var p := v.split(":")
		spec = [float(p[0]), float(p[1]), float(p[2]) if p.size() > 2 else 1.0]
	else:
		spec = VIEWS[v]
	var yaw := deg_to_rad(float(spec[0]))
	var pitch := deg_to_rad(float(spec[1]))
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	# back off until every corner of the bounds is inside the frame
	var basis := Basis.looking_at(-back, Vector3.UP)
	var tv := tan(deg_to_rad(FOV) * 0.5)
	var vp := root.get_visible_rect().size
	var th := tv * vp.x / vp.y
	var dist := 0.0
	for i in range(8):
		var q := box.get_endpoint(i) - focus
		var z := -q.dot(basis.z)
		dist = maxf(dist, maxf(absf(q.dot(basis.x)) / th, absf(q.dot(basis.y)) / tv) - z)
	cam.global_position = c + back * dist * 1.08 * float(spec[2]) * zoom
	cam.look_at(c, Vector3.UP)


func _sheet() -> void:
	if shots.size() < 2:
		return
	var cols := mini(shots.size(), 3)
	var rows := ceili(shots.size() / float(cols))
	var cw := 640
	var ch := int(cw * (shots[0] as Image).get_height() / float((shots[0] as Image).get_width()))
	var sheet := Image.create(cols * cw, rows * ch, false, Image.FORMAT_RGBA8)
	for i in range(shots.size()):
		var img: Image = shots[i]
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, cw, ch), Vector2i((i % cols) * cw, (i / cols) * ch))
	sheet.save_png(out + "_sheet.png")
