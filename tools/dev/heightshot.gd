extends SceneTree
## The character creator at every height option (what the player sees), plus
## the body's measured top. Args: <out_prefix>
var t := 0.0
var step := 0
var out := ""
var cc
var i := 0


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(_d: float) -> bool:
	t += _d
	match step:
		0:
			if t < 3.0:
				return false
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			var p = root.get_tree().get_first_node_in_group("player")
			p.open_creator(false)
			step = 1
			t = 0.0
		1:
			if t < 1.0:
				return false
			cc = root.find_children("*", "CharacterCreator", true, false)[0]
			step = 2
		2:
			if i >= CharacterLook.HEIGHTS.size():
				quit()
				return false
			cc.look["height"] = CharacterLook.HEIGHTS[i]
			cc._rebuild()
			t = 0.0
			step = 3
		3:
			if t < 0.8:
				return false
			var pv = cc._preview
			print("height %.2f: scale %.2f  head top y %.3f" % [CharacterLook.HEIGHTS[i], pv.scale.y, pv.head.global_position.y - pv.global_position.y])
			root.get_texture().get_image().save_png("%s_%d.png" % [out, i])
			i += 1
			step = 2
	return false
