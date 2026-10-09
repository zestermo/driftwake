extends SceneTree
## Co-op test, host side: hosts a world and runs the client's commands
## (see nettest_node.gd). Args: <port> [mode]
var t := 0.0
var st_t := 0.0
var step := 0
var port := 24690
var tn
## "late": start in single player, then host from the pause menu.
## "chain": in single player, land on the chain's first island and fell its
## camp's captain, then host in the running world (the guest joins late).
var mode := ""
var board_t := -1.0
var isl
var capt


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
	st_t += d
	match step:
		0:
			if t < 0.3:
				return false
			var net = root.get_node("Net")
			net.my_info = {"name": "Hosty"}
			if mode == "late" or mode == "chain":
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2 if mode == "late" else 3
				return false
			var err = net.host_game(port)
			print("HOST listening ", err)
			change_scene_to_file("res://scenes/world/world.tscn")
			step = 1
		2:
			if t < 2.0:
				return false
			_host_late()
		3:
			var w = root.get_node_or_null("World/Islands")
			if t < 2.0 or w == null or not w.chain_ready():
				return false
			var gm = root.get_node("GameManager")
			isl = w.chain_islands[w.chain().start_next[0]]
			var v: Vector2 = isl.sites["village"]
			var p = gm.player
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.to_global(Vector3(v.x, isl.height_at(v.x, v.y) + 1.5, v.y))
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.health_component.max_health = 5000.0
			p.health_component.current_health = 5000.0
			capt = isl.get_node("Site_camp/Camp").grunts.filter(func(g): return g.captain)[0]
			capt.health.take_damage(999999.0)
			print("HOST on %s (%d), its captain felled" % [isl.island_name, int(isl.node["id"])])
			step = 4
			st_t = 0.0
		4:
			# (hosted once the crew's there and the captain's body has gone)
			var w = root.get_node("World/Islands")
			var gm = root.get_node("GameManager")
			if (gm.chain_at != int(isl.node["id"]) or not w.chain_ready() or is_instance_valid(capt)) and st_t < 40.0:
				return false
			print("HOST chain at %d, set %s, captain gone %s" % [gm.chain_at, gm.chain_set, not is_instance_valid(capt)])
			# (in the running world, as the pause menu does, on the test's port)
			var net = root.get_node("Net")
			print("HOST listening late ", net.host_game(port), " ", net.world_ready)
			step = 1
		1:
			if mode == "board":
				_board_early()
			if t > 480.0:
				print("HOST timeout")
				quit()
	return false


## From the pause menu, like a player would.
func _host_late() -> void:
	var net = root.get_node("Net")
	var gm = root.get_node("GameMenu")
	gm.open("pause")
	gm._host_from_game()
	print("HOST listening late ", net.active, " ", net.world_ready, " ", net.local_player.name)
	step = 1


## "board": a pirate ship boards the crew's ship before the client joins
## (the client checks it gets the boarders already on deck).
func _board_early() -> void:
	if board_t == INF:
		return
	if board_t < 0.0:
		if root.get_node("Net").world_ready and t > 4.0:
			print("HOST board setup ", tn._run("board_setup", [], 0))
			board_t = t
	elif t > board_t + 0.6:
		print("HOST boarded ", tn._run("board_now", [], 0))
		board_t = INF
