extends SceneTree
## The bench's co-op guest (bench_brinehollow `coop`): a headless captain who joins the host on localhost and
## stands 2.5 m beside the host's captain wherever they go, kept alive, so the host's frame carries exactly what one
## more captain costs (their puppet, the snapshots both ways, events) and nothing else (the same actors awake, the
## same islands up). Not a test: no checks; quits when the host goes or after `life` s. Args: <port> [life]
var t := 0.0
var step := 0
var port := 24700
var life := 1800.0
var net
var accepted := false
var failed := false
var knock_t := 0.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		port = int(a[0])
	if a.size() > 1:
		life = float(a[1])


func _process(d: float) -> bool:
	t += d
	if t > life:
		quit()
		return false
	match step:
		0:
			if t < 1.0:
				return false
			net = root.get_node("Net")
			net.my_info = {"name": "Benchy"}
			net.accepted.connect(func(): accepted = true)
			net.failed.connect(func(_r): failed = true)
			net.join_game("127.0.0.1", port)
			print("GUEST joining :%d" % port)
			step = 1
		1:
			if accepted:
				change_scene_to_file("res://scenes/world/world.tscn")
				step = 2
			elif failed or t - knock_t > 10.0:
				# (the host may be mid-build in one long frame: knock again)
				failed = false
				knock_t = t
				net.join_game("127.0.0.1", port)
		2:
			if net.world_ready and net.local_player and net.players.has(1):
				print("GUEST in the world at %.0f s" % t)
				step = 3
		3:
			if not net.active:
				print("GUEST the host left")
				quit()
				return false
			_follow()
	return false


func _follow() -> void:
	var me = net.local_player
	var host = net.players.get(1)
	if me == null or host == null or not is_instance_valid(me) or not is_instance_valid(host):
		return
	var hc := me.health_component as Node
	if hc:
		hc.max_health = 100000.0
		hc.current_health = 100000.0
	var at: Vector3 = (host as Node3D).global_position + Vector3(2.5, 0.3, 0.0)
	if (me as Node3D).global_position.distance_to(at) > 1.5:
		(me as Node3D).global_position = at
		me.velocity = Vector3.ZERO
		(me as Node3D).reset_physics_interpolation()
