extends SceneTree
## Weapons put away on the captain's hip (sheathed): left side, back, front and
## a close front-left quarter per weapon ("front"/"back" are the model's +Z/-Z,
## so "back" shows the face). Args: <out_prefix>. Env SS_WORN=dagger+kris,kukri: only
## those ("a+b": a in the main hand, b in the off hand, on the left hip).
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var p
var cam: Camera3D
var WORN: Array = ["cutlass", "scimitar", "rapier", "katana", "tachi", "nodachi", "wakizashi", "boarding_axe", "war_axe", "hatchet", "pistol",
	"dagger", "kris", "kukri", "main_gauche", "dagger+sharktooth_knife"]
const VIEWS := ["side", "front", "back", "quarter"]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	if OS.get_environment("SS_WORN") != "":
		WORN = Array(OS.get_environment("SS_WORN").split(","))
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0 or (step > 0 and t - t0 < 0.6): return false
	t0 = t
	if step == 0:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		cam = Camera3D.new(); cam.fov = 32; root.add_child(cam); cam.current = true
	else:
		var i: int = (step - 1) / VIEWS.size()
		var v: String = VIEWS[(step - 1) % VIEWS.size()]
		root.get_texture().get_image().save_png("%s_%s_%s.png" % [out, WORN[i], v])
	if step >= WORN.size() * VIEWS.size():
		quit()
		return false
	var ids: PackedStringArray = str(WORN[step / VIEWS.size()]).split("+")
	if step % VIEWS.size() == 0:
		var it = ItemDB.get_item(ids[0])
		p.inventory_component.add_item(it, 1)
		p.set_offhand(null)
		p.equip_weapon(it, false)
		if ids.size() > 1:
			var off = ItemDB.get_item(ids[1])
			p.inventory_component.add_item(off, 1)
			p.set_offhand(off)
	var f: Vector3 = p.player_model.global_basis.z
	var r: Vector3 = p.player_model.global_basis.x
	match VIEWS[step % VIEWS.size()]:
		"side": cam.global_position = p.global_position + Vector3(0, 1.0, 0) - r * 2.6 + f * 0.3
		"front": cam.global_position = p.global_position + Vector3(0, 1.0, 0) + f * 2.6 - r * 0.6
		"back": cam.global_position = p.global_position + Vector3(0, 1.0, 0) - f * 2.6 - r * 0.6
		"quarter": cam.global_position = p.global_position + Vector3(0, 1.1, 0) - (f + r).normalized() * 1.5
	cam.look_at(p.global_position + Vector3(0, 0.85, 0), Vector3.UP)
	step += 1
	return false
