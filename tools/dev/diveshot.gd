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
				quit()
				return false
			var big: bool = spots[idx][0] in ["Wreck", "Ruin"]
			frame(spots[idx][1], 5.0 if big else 2.4, 2.4 if big else 1.6, true)
			if e < 1.6:
				return false
			shot("under_%s" % str(spots[idx][0]).to_lower())
			idx += 1
			t0 = t
	return false
