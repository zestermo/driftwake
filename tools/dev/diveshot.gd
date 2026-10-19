extends SceneTree
## Dive shots in Brinehollow's waters: the surface over a sunken chest, then each kind of dive spot (chest,
## oysters, reef, wreck, ruin) seen from just behind a diver, with the game camera under the waves.
## Args: <out_prefix> [hour]
var t := 0.0
var p
var sw
var rig
var out := ""
var phase := 0
var t0 := 0.0
var spots: Array = []
var idx := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " at ", p.global_position, " cam under ", sw.camera_under())


## Put the diver `back` m from the spot's middle, facing it, `up` m over it, the camera behind looking on.
func frame(spot: Node3D, back: float, up: float, diving: bool) -> void:
	var c := spot.global_position
	var d := Vector3(1, 0, 0.3).normalized()
	p.global_position = c - d * back + Vector3(0, up, 0)
	p.reset_physics_interpolation()
	p.player_model.rotation.y = atan2(d.x, d.z) + PI
	rig.rotation.y = p.player_model.rotation.y + 0.7
	rig.get_node("SpringArm3D").rotation.x = (-0.3 if back > 4.0 else -0.55) if diving else -0.6
	rig.current_zoom = 4.0
	sw._diving = diving
	sw._cam_under = diving
	p.body_model.diving = diving


func _process(d: float) -> bool:
	t += d
	if t < 1.5:
		return false
	if p == null:
		for n in root.find_children("*", "CharacterCreator", true, false):
			n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud:
			hud.visible = false
		var w := root.get_node_or_null("/root/Weather")
		if OS.get_cmdline_user_args().size() > 1 and w:
			w.call("force", 0)
		p = root.get_tree().get_first_node_in_group("player")
		sw = p.get_node("StateMachine/Swim")
		rig = root.get_tree().current_scene.find_child("CameraRig", true, false)
		var holder = root.get_tree().get_first_node_in_group("dive_sites").get_node("Dive_brinehollow")
		for kind in [["Chest", "Chest_dive_chest"], ["Oysters", "Oysters_"], ["Reef", "Reef_"], ["Wreck", "Wreck_"], ["Ruin", "Ruin_"]]:
			for c in holder.get_children():
				if str(c.name).begins_with(kind[1]):
					spots.append([kind[0], c])
					break
		print("spots: ", spots.map(func(s): return s[0]))
		return false
	var e := t - t0
	match phase:
		0:
			if t < 6.0:
				return false
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			frame(spots[0][1], 3.0, 9.0, false)
			p.global_position.y = float(p.water_surface()) - 1.3
			phase = 1
			t0 = t
		1:
			if e < 2.5:
				return false
			shot("surface")
			phase = 2
			t0 = t
		2:
			if idx >= spots.size():
				# a rip off a beach, from a swimmer caught in it
				var sc = root.get_tree().get_first_node_in_group("sea_currents")
				var rip: Array = sc.rips["brinehollow"][0]
				var a: Vector2 = rip[0]
				var b: Vector2 = rip[1]
				sw._diving = false
				sw._cam_under = false
				p.body_model.diving = false
				p.global_position = Vector3(a.x, 0.0, a.y).lerp(Vector3(b.x, 0.0, b.y), 0.25)
				p.global_position.y = float(p.water_surface()) - 1.3
				p.reset_physics_interpolation()
				p.player_model.rotation.y = atan2(a.x - b.x, a.y - b.y) + PI
				rig.rotation.y = p.player_model.rotation.y + 0.9
				rig.get_node("SpringArm3D").rotation.x = -0.75
				rig.current_zoom = 9.0
				phase = 3
				t0 = t
				return false
			var big: bool = spots[idx][0] in ["Wreck", "Ruin"]
			frame(spots[idx][1], 5.0 if big else 2.4, 2.4 if big else 1.6, true)
			if e < 1.6:
				return false
			shot("under_%s" % str(spots[idx][0]).to_lower())
			idx += 1
			t0 = t
		3:
			if e < 2.0:
				return false
			shot("rip")
			# the shark at Brinehollow's wreck: let it notice a swimmer and come round with its fin out
			var shark = root.get_tree().get_first_node_in_group("sea_threats").find_child("Shark0", true, false)
			var to: Vector3 = shark.home + Vector3(9.0, 0.0, 0.0)
			p.global_position = Vector3(to.x, float(p.water_surface(to)) - 1.3, to.z)
			p.reset_physics_interpolation()
			shark.global_position = shark.home + Vector3(-8.0, 0.0, 0.0)
			shark.reset_physics_interpolation()
			phase = 4
			t0 = t
		4:
			var shark = root.get_tree().get_first_node_in_group("sea_threats").find_child("Shark0", true, false)
			var to_s: Vector3 = shark.global_position - p.global_position
			rig.rotation.y = atan2(-to_s.x, -to_s.z) + 0.3
			rig.get_node("SpringArm3D").rotation.x = -0.45
			rig.current_zoom = 6.0
			if e < 3.2:
				return false
			shot("shark_fin")
			phase = 5
			t0 = t
		5:
			var shark = root.get_tree().get_first_node_in_group("sea_threats").find_child("Shark0", true, false)
			if int(shark.state) != int(shark.S.TELL) and e < 8.0:
				return false
			shot("shark_tell")
			quit()
	return false
