extends SceneTree
## Co-op test, host side: hosts a world and runs the client's commands
## (see nettest_node.gd). Args: <port>
var t := 0.0
var step := 0
var port := 24690
var tn
## "late": start in single player, then host from the pause menu
var mode := ""


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		port = int(a[0])
	if a.size() > 1:
		mode = a[1]
	tn = load("res://tools/dev/nettest_node.gd").new()
	tn.name = "NetTest"
	root.add_child(tn)


func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 0.3:
				return false
			var net = root.get_node("Net")
			net.my_info = {"name": "Hosty"}
			if mode == "late":
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2
				return false
			var err = net.host_game(port)
			print("HOST listening ", err)
			change_scene_to_file("res://scenes/world/world.tscn")
			step = 1
		2:
			if t < 2.0:
				return false
			# from the pause menu, like a player would
			var net = root.get_node("Net")
			var gm = root.get_node("GameMenu")
			gm.open("pause")
			gm._host_from_game()
			print("HOST listening late ", net.active, " ", net.world_ready, " ", net.local_player.name)
			step = 1
		1:
			if t > 300.0:
				print("HOST timeout")
				quit()
	return false
