extends SceneTree
var f := 0
var step := 0
var dm
var isl
var player
var out := "res://tools/dev/out/dlg_"
func _initialize() -> void:
	change_scene_to_file("res://scenes/world/world.tscn")
func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
func shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT(skip) ", n); return
	root.get_texture().get_image().save_png(out + n + ".png")
	print("SAVED ", n)
func state() -> String:
	return str(player.state_machine.current_state.name)
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		dm = root.get_node("Dialogue")
		isl = root.get_node("World/Islands/Brinehollow")
		player = root.get_tree().get_first_node_in_group("player")
		var odile = isl.get_node("HarbormasterOdile")
		# stand the player in front of Odile
		player.global_position = odile.global_position + Vector3(0.8, 0.2, 2.6)
		for c in root.get_node("World").get_children():
			if c.has_method("shake"): c.rotation.y = 0.25
	if f == 40:
		var odile = isl.get_node("HarbormasterOdile")
		odile._on_interacted(player)
		print("active=", dm.active, " state=", state())
	if f > 40 and dm and dm.active:
		var box = dm._box
		if step == 0 and not box.is_typing():
			shot("odile_intro"); step = 1; press("interact")
		elif step == 1 and not box.is_typing() and box.has_choices():
			shot("odile_menu"); step = 2
			press("move_back"); press("interact")  # pick 2nd choice
		elif step == 1 and not box.is_typing():
			press("interact")
		elif step == 2 and not box.is_typing():
			print("line: ", box._text.text.substr(0, 60)); step = 3
			# skip to the end of this branch
		elif step == 3:
			if box.is_typing(): box.finish_typing()
			elif box.has_choices():
				# choose last option (goodbye)
				var n = box._choice_labels.size()
				for i in range(n): press("move_back")
				press("move_forward"); press("interact"); step = 4
			else: press("interact")
		elif step == 4:
			if box.is_typing(): box.finish_typing()
			else: press("interact")
	if step == 4 and dm and not dm.active and f < 400000:
		print("odile done. state=", state(), " flag met_odile=", dm.has_flag("met_odile"))
		step = 5
		var gus = isl.get_node("GusBrannock")
		var front := Vector3(sin(isl._tavern.rotation.y), 0, cos(isl._tavern.rotation.y))
		player.global_position = gus.global_position + front * 2.6 + Vector3(0, 0.3, 0.6)
		for c in root.get_node("World").get_children():
			if c.has_method("shake"): c.rotation.y = atan2(front.x, front.z) + 0.3
	if step == 5 and dm.is_blocking() == false:
		var gus = isl.get_node("GusBrannock")
		gus._on_interacted(player); step = 6
	if step >= 6 and dm.active:
		var box = dm._box
		if box.is_typing(): box.finish_typing()
		elif step == 6 and box.has_choices():
			press("interact"); step = 7  # first choice: rumors
		elif step == 6: press("interact")
		elif step == 7:
			shot("gus_rumor"); print("rumor: ", box._text.text); step = 8
	if step == 8 or f > 400000:
		quit()
	return false
