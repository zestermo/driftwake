extends SceneTree
## Weapon designs: every design of each kind laid out in a rack (one shot per
## kind), the cutlass, katana, axe and pistol across all seven tiers, and a
## sheet of every icon. Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var cam: Camera3D
var rack: Node3D
const KINDS := ["cutlass", "katana", "axe", "pistol"]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
## Lay `models` out in a row, blades up, against a dark board, high over the sea.
func lay(models: Array) -> void:
	if rack:
		rack.queue_free()
	rack = Node3D.new()
	current_scene.add_child(rack)
	rack.global_position = Vector3(0, 300, 0)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(models.size() * 0.42 + 0.4, 1.8, 0.05)
	board.mesh = bm
	board.material_override = PSXMat.lit("planks_dark", Color(0.45, 0.4, 0.38))
	rack.add_child(board)
	board.position = Vector3(0, 0, -0.15)
	for i in range(models.size()):
		var mi := MeshInstance3D.new()
		mi.mesh = Props.weapon_mesh(models[i])
		rack.add_child(mi)
		# grip low, the business end up; seen from the side (+X toward the camera)
		mi.position = Vector3((i - (models.size() - 1) * 0.5) * 0.42, -0.45, 0)
		mi.rotation = Vector3(PI * 0.5, PI * 0.5, 0)
	cam.global_position = rack.global_position + Vector3(0, 0.0, maxf(models.size() * 0.42, 1.6) * 1.05 + 0.6)
	cam.look_at(rack.global_position, Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0 or (step > 0 and t - t0 < 0.8): return false
	t0 = t
	if step == 0:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		cam = Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.current = true
	var shots := []
	for k in KINDS:
		var ms := ["%s::0" % k]
		for dz in WeaponDesigns.designs_of(k):
			ms.append("%s:%s:0" % [k, dz])
		shots.append(["designs_" + k, ms])
	var tiers := []
	for k in KINDS:
		for tr in range(7):
			tiers.append("%s::%d" % [k, tr])
	shots.append(["tiers_blades", tiers.slice(0, 14)])
	shots.append(["tiers_axes_guns", tiers.slice(14, 28)])
	if step > 0:
		snap(shots[step - 1][0])
	if step < shots.size():
		lay(shots[step][1])
	else:
		# every weapon item's icon on one sheet, 2x
		var ids: Array = []
		for k in KINDS:
			ids.append_array(WeaponDesigns.item_ids(k))
		var sheet := Image.create(10 * 52, 6 * 52, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.06, 0.06, 0.09))
		var n := 0
		for id in ids:
			for tr in [0, 4]:
				var it = ItemDB.tiered(str(id), tr) if tr > 0 else ItemDB.get_item(str(id))
				var img: Image = it.icon.get_image()
				img.resize(48, 48, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(img, Rect2i(0, 0, 48, 48), Vector2i((n % 10) * 52 + 2, (n / 10) * 52 + 2))
				n += 1
		sheet.save_png("%s_icons.png" % out)
		print("shot icons")
		quit()
	step += 1
	return false
