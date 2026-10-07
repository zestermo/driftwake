extends SceneTree
## Brinehollow QoL round: Nessa's stall, Sela's stall, the yard's live
## preview, the helm with the compass and chart marks, the chart with marks,
## the capstan and the anchor let go on its chain, a hull hit's number.
## Args: <out_prefix>
var t := 0.0
var out := ""
var p
var ship
var menu
var step := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func item(id: String):
	return load("res://resources/items/%s.tres" % id)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if t - t0 < (0.25 if step == 10 else 1.0) and step > 0: return false
	t0 = t
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			menu = root.get_node("GameMenu")
			p.inventory_component.add_item(item("treasure"), 7)
			p.inventory_component.add_item(item("gold"), 140)
			p.inventory_component.add_item(item("cutlass"), 1)
			menu.open_shop("nessa")
		1:
			snap("shop_nessa")
			menu.close()
			menu.open_shop("sela")
		2:
			snap("shop_sela")
			menu.close()
			menu.open("yard")
		3:
			snap("yard_preview")
			menu.close()
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			root.get_node("Net").set_waypoints([sc + Vector2(400, -300), sc + Vector2(-600, 200)])
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
		4:
			snap("helm_compass")
			menu.open("chart")
		5:
			snap("chart_marks")
			menu.close()
			p.state_machine.force_state("Idle", {})
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(-1.2, 0.8, -3.0)
			p.reset_physics_interpolation()
		6:
			pass
		7:
			pass
		8:
			# the capstan, the chain over the rail and down to the anchor
			var cam := Camera3D.new()
			cam.fov = 55
			root.add_child(cam)
			cam.current = true
			cam.global_position = ship.global_transform * Vector3(4.5, 2.6, -2.5)
			cam.look_at(ship.global_transform * Vector3(0.8, -0.5, -5.6), Vector3.UP)
			set_meta("cam", cam)
		9:
			snap("anchor_chain")
			ship.hull_hit(32.0, ship.global_transform * Vector3(2.6, 0.4, -4.5))
		10:
			snap("hull_number")
			quit()
	step += 1
	return false
