extends SceneTree
## Co-op test, a second client: joins alongside netclient.gd and checks it
## sees the host AND the other client (snapshots relayed by the host).
## Args: <port> <start_delay> [crew size, 3: the host, the client and the watchers]
var t := 0.0
var step := 0
var port := 24690
var delay := 4.0
var net
var fails := 0
var accepted := false
var seen_move := false
var other_pos0 := Vector3.INF


## How many captains the crew will be once everyone's in ("five" mode: 5).
var crew := 3


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		port = int(a[0])
	if a.size() > 1:
		delay = float(a[1])
	if a.size() > 2:
		crew = int(a[2])
	var tn = load("res://tools/dev/nettest_node.gd").new()
	tn.name = "NetTest"
	root.add_child(tn)


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + "watcher: " + name)
	if not cond:
		fails += 1


var _said := 0
var join_failed := false
var most := 0
var stay_t := -1.0


func _process(d: float) -> bool:
	t += d
	# (a line every 20 s: five captains' worlds building on one machine take a while, and the runner stops a
	# silent process)
	if int(t / 20.0) > _said:
		_said = int(t / 20.0)
		print("  watcher at step %d, %d s" % [step, int(t)])
	if t > 200.0 + 100.0 * float(crew > 3):
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
			net.failed.connect(func(_r): join_failed = true)
			net.join_game("127.0.0.1", port)
			step = 1
		1:
			if accepted:
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2
			elif join_failed:
				# (the host is still building its world and can't answer before our timeout: knock again, like
				# netclient; with five captains loading on one machine it always is)
				join_failed = false
				net.join_game("127.0.0.1", port)
		2:
			if not net.world_ready:
				return false
			var others := 0
			for id in net.players.keys():
				var p = net.players[id]
				if id != net.my_id() and is_instance_valid(p) and p.visible:
					others += 1
			most = maxi(most, net.roster.size())
			# (a crew of five: the client may have finished and left by the time the late watchers are in, so what's
			# checked is that the whole crew got in and we see the host)
			if (crew <= 3 and others >= 2) or (crew > 3 and others >= 1 and most >= crew):
				check("sees the host and the other clients (%d puppets)" % others, true)
				check("roster of %d" % crew, most >= crew if crew > 3 else net.roster.size() == crew)
				for id in net.players.keys():
					if id != 1 and id != net.my_id():
						other_pos0 = net.players[id].global_position
				step = 3
			elif t > delay + (40.0 if crew <= 3 else 150.0):
				check("sees the host and the other clients (%d puppets)" % others, false)
				print("  ready ", net.world_ready, " roster ", net.roster.keys(), " players ", net.players.keys())
				for id in net.players.keys():
					var p = net.players[id]
					print("  ", id, " valid ", is_instance_valid(p), " vis ", p.visible if is_instance_valid(p) else false, " age ", net.snapshot_age(p) if is_instance_valid(p) else -1)
				_done()
		3:
			# (five: the client may be gone already; the relay is three's check. Stay a minute after passing, so a
			# watcher still loading sees us all too)
			if crew > 3:
				if stay_t < 0.0:
					stay_t = t
				if t < stay_t + 60.0:
					return false
				step = 4
				return false
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
