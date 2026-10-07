extends SceneTree
## The captain in the new armour and clothes, in the world: worn through the
## equipment slots (as a player would), front and back after standing a moment
## (the cape settles), then walking. Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var p
var cam: Camera3D
const OUTFITS := [
	[["accessory", "cape", {"cape": true, "cape_color": Color(0.66, 0.14, 0.12)}], ["vest", "mail", {"vest": "mail"}],
		["head", "morion", {"hat": "morion"}], ["hands", "gauntlets", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "gauntlets": true}],
		["feet", "greaves", {"feet": "greaves", "feet_color": Color(0.1, 0.08, 0.07)}]],
	[["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.28, 0.28, 0.3), "trim_color": Color(0.75, 0.76, 0.78)}],
		["head", "cavalier", {"hat": "cavalier", "hat_color": Color(0.36, 0.12, 0.1)}], ["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.55, 0.55, 0.58)}],
		["accessory", "bandolier", {"bandolier": true}]],
]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func view(front: bool) -> void:
	var f: Vector3 = -p.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized() * (1.0 if front else -1.0)
	cam.global_position = p.global_position + Vector3(0, 1.4, 0) + f * 3.0
	cam.look_at(p.global_position + Vector3(0, 1.0, 0), Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if step > 0 and t - t0 < 2.0:
		return false
	t0 = t
	if step == 0:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		cam = Camera3D.new(); cam.fov = 45; root.add_child(cam); cam.current = true
	var o := step / 2
	if step % 2 == 0:
		if o >= OUTFITS.size():
			quit()
			return false
		if o > 0:
			snap("outfit%d_back" % (o - 1))
		p.equipment.clear()
		for e in OUTFITS[o]:
			p.equipment.equip(Gear.make(str(e[0]), str(e[1]), e[2]))
		p.refresh_look()
		view(true)
	else:
		snap("outfit%d_front" % o)
		view(false)
	step += 1
	return false
