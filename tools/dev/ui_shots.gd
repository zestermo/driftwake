extends SceneTree
var t := 0.0
var step := 0
var wait := 0.0
var p
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("res://tools/dev/out/ui_%s.png" % n); print("SAVED ", n)
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE
			p.global_position = Vector3(150 + v.x + 6, isl.hv(v + Vector2(6, -8)) + 0.5, 150 + v.y - 8)
			p.reset_physics_interpolation()
			for c in root.get_node("World").get_children():
				if c.has_method("shake"): c.rotation.y = PI * 0.85
			# grab the axe too so the inventory has more in it
			p.inventory_component.add_item(load("res://resources/items/boarding_axe.tres"), 1)
			p.inventory_component.add_item(load("res://resources/items/gold.tres"), 7)
			p.inventory_component.add_item(load("res://resources/items/treasure.tres"), 1)
			act("ready_weapon"); wait = 1.2
		1:
			shot("combat"); act("inventory"); wait = 0.3
		2:
			shot("inventory"); act("inventory"); wait = 0.2
		3:
			act("pause"); wait = 0.3
		4:
			shot("pause"); root.get_node("GameMenu").open("options"); wait = 0.3
		5:
			shot("options"); quit()
	step += 1
	return false
