extends SceneTree
## Co-op test, a second client: joins alongside netclient.gd and checks it
## sees the host AND the other client (snapshots relayed by the host).
## Args: <port> <start_delay>
var t := 0.0
var step := 0
var port := 24690
var delay := 4.0
var net
var fails := 0
var accepted := false
var seen_move := false
var other_pos0 := Vector3.INF


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		port = int(a[0])
	if a.size() > 1:
		delay = float(a[1])
	var tn = load("res://tools/dev/nettest_node.gd").new()
	tn.name = "NetTest"
	root.add_child(tn)


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + "watcher: " + name)
	if not cond:
		fails += 1


func _process(d: float) -> bool:
	t += d
	if t > 200.0:
		check("timeout at step %d" % step, false)
		_done()
		return false
	match step:
		0:
			if t < delay:
				return false
			net = root.get_node("Net")
			net.my_info = {"name": "Watcher"}
			net.accepted.connect(func(): accepted = true)
			net.join_game("127.0.0.1", port)
			step = 1
		1:
			if accepted:
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2
		2:
			if not net.world_ready:
				return false
			var others := 0
			for id in net.players.keys():
				var p = net.players[id]
				if id != net.my_id() and is_instance_valid(p) and p.visible:
					others += 1
			if others >= 2:
				check("sees the host and the other client (%d puppets)" % others, true)
				check("roster of 3", net.roster.size() == 3)
				for id in net.players.keys():
					if id != 1 and id != net.my_id():
						other_pos0 = net.players[id].global_position
				step = 3
			elif t > delay + 40.0:
				check("sees the host and the other client (%d puppets)" % others, false)
				print("  ready ", net.world_ready, " roster ", net.roster.keys(), " players ", net.players.keys())
				for id in net.players.keys():
					var p = net.players[id]
					print("  ", id, " valid ", is_instance_valid(p), " vis ", p.visible if is_instance_valid(p) else false, " age ", net.snapshot_age(p) if is_instance_valid(p) else -1)
				_done()
		3:
			# the other client moves around during its test: we see it
			for id in net.players.keys():
				if id != 1 and id != net.my_id() and is_instance_valid(net.players[id]):
					if net.players[id].global_position.distance_to(other_pos0) > 1.5:
						seen_move = true
			if seen_move:
				check("the other client's moves reach us through the host", true)
				step = 4
			elif t > delay + 120.0:
				check("the other client's moves reach us through the host", false)
				step = 4
		4:
			_done()
	return false


func _done() -> void:
	print("WATCH RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	net.leave()
	quit()
