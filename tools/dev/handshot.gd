extends SceneTree
## Weapon designs in hand: the captain holding a few (drawn), side on.
## Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var p
var cam: Camera3D
const HELD := ["nodachi@4", "broadsword@2", "war_axe@3", "dragon_pistol@5", "rapier@6"]
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0 or (step > 0 and t - t0 < 1.2): return false
	t0 = t
	if step == 0:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		cam = Camera3D.new(); cam.fov = 40; root.add_child(cam); cam.current = true
	else:
		root.get_texture().get_image().save_png("%s_%s.png" % [out, HELD[step - 1].replace("@", "_")])
		print("shot ", HELD[step - 1])
	if step >= HELD.size():
		quit()
		return false
	var it = ItemDB.get_item(HELD[step])
	p.inventory_component.add_item(it, 1)
	p.equip_weapon(it)
	p.draw_weapon()
	var f: Vector3 = p.player_model.global_basis.z
	var r: Vector3 = p.player_model.global_basis.x
	cam.global_position = p.global_position + Vector3(0, 1.3, 0) + f * 2.2 + r * 1.2
	cam.look_at(p.global_position + Vector3(0, 1.1, 0), Vector3.UP)
	step += 1
	return false
