extends SceneTree
## The story's start, rendered: the loading screen (files, then the island's
## build), waking on the beach (eyelids, the gull landing and cawing, getting
## up), the first objective and its marker, walking up to Old Pell, his story
## line, the next objective flashing. Args: <out_prefix>
var out := ""
var t := 0.0
var wt := -1.0
var p
var shots: Array = []
var stage := 0
var dm


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	LoadingScreen.go(self, "res://scenes/world/world.tscn")


func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)


func _process(d: float) -> bool:
	t += d
	match stage:
		0:
			if t > 0.25:
				snap("loading")
				stage = 1
		1:
			p = root.get_tree().get_first_node_in_group("player")
			if p == null:
				return false
			stage = 2
			t = 0.0
		2:
			if t < 2.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			root.get_node("Settings").set_value("video", "perf_overlay", false, false)
			root.get_node("Story").begin()
			p.wake_on_beach()
			dm = root.get_node("Dialogue")
			wt = 0.0
			shots = [[0.3, "wake0_closed"], [1.0, "wake1_squint"], [2.2, "wake2_open"], [2.95, "wake3_caw"], [3.4, "wake4_jolt"],
				[4.6, "wake5_sit"], [5.7, "wake6_crouch"], [7.6, "wake7_standing"], [10.0, "wake8_objective"]]
			stage = 3
		3:
			wt += d
			if not shots.is_empty() and wt >= float(shots[0][0]):
				snap(str(shots[0][1]))
				shots.pop_front()
			if shots.is_empty():
				# toward Pell along the quay: his marker
				var pell: Node3D
				for n in root.get_tree().get_nodes_in_group("npcs"):
					if n.npc_name == "Old Pell":
						pell = n
				var from: Vector3 = pell.global_position + Vector3(-14, 0.5, 6)
				p.global_position = from
				p.reset_physics_interpolation()
				var dir: Vector3 = pell.global_position - from
				p.player_model.rotation.y = atan2(-dir.x, -dir.z)
				var cam: Camera3D = p.get_viewport().get_camera_3d()
				var rig: Node3D = cam.get_parent().get_parent()
				rig.rotation.y = atan2(-dir.x, -dir.z)
				t = 0.0
				stage = 4
		4:
			if t > 1.5:
				snap("pell_marker")
				dm.start("pell", _pell())
				t = 0.0
				stage = 5
		5:
			if t > 2.0:
				dm._box.finish_typing()
				snap("pell_talk")
				for i in range(10):
					if dm.active:
						dm._advance()
				t = 0.0
				stage = 6
		6:
			if dm.active:
				dm._close()
			if t > 1.2:
				snap("next_objective")
				quit()
	return false


func _pell() -> Node3D:
	for n in root.get_tree().get_nodes_in_group("npcs"):
		if n.npc_name == "Old Pell":
			return n
	return null
