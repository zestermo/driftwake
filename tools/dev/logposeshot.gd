extends SceneTree
## The log pose held up (L): unset under level 5 (the needle wandering, on the
## icon and the compass strip), then set in Brinehollow's sea (icon, strip,
## the chart with the first island pinned at its edge); then out on the chain
## at a city whose log pose forks (a seed found for it): unset (the wait),
## then set at the helm (two needles, theme and danger) and the chart fitted
## round the city and the fork. The wrist itself: posebench with
## PB_KV="log_pose=1" (guard, log_pose:0.98).
## Args: <out_prefix>
var t := 0.0
var out := ""
var p
var gm
var world
var menu
var city := -1
var step := 0
var t0 := 0.0
var hold := 1.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func _process(d: float) -> bool:
	t += d
	if t < 2.5: return false
	if t - t0 < hold and step > 0: return false
	t0 = t
	hold = 1.0
	match step:
		0:
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p = get_first_node_in_group("player")
			gm = root.get_node("GameManager")
			world = root.get_node("World/Islands")
			menu = root.get_node("GameMenu")
			p.state_machine.force_state("Idle", {})
			p.give_log_pose()
			Input.action_press("log_pose")
		1:
			snap("unset")
			# a chain whose first city forks after it
			for s in range(1, 500):
				gm.chain_seed = s
				var c = world.chain()
				city = c.nodes.filter(func(n): return int(n["layer"]) == 3)[0]["id"]
				if c.next_of(city).size() == 2:
					break
			var PR = load("res://scripts/progression/progression.gd")
			while p.progression.level < int(world.chain().node(city)["level"]):
				p.progression.add_xp(PR.xp_to_next(p.progression.level) - p.progression.xp)
			print("seed ", gm.chain_seed, " city ", world.chain().node(city)["name"], " Lv ", p.progression.level)
			hold = 4.0
		2:
			snap("set_brinehollow")
			Input.action_release("log_pose")
			menu.open("chart")
		3:
			snap("chart_brinehollow")
			menu.close()
			var c = world.chain()
			var at: Vector2 = c.node(city)["pos"]
			var ahead: Vector2 = (c.node(c.next_of(city)[0])["pos"] + c.node(c.next_of(city)[1])["pos"]) * 0.5
			var dir: Vector2 = (ahead - at).normalized()
			var spot: Vector2 = at + dir * 650.0
			gm.chain_at = city
			gm.chain_set = false
			gm.chain_since = root.get_node("Weather").world_time()
			var ship = get_first_node_in_group("ship")
			ship.place(Vector3(spot.x, 0.0, spot.y), atan2(-dir.x, -dir.y))
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			Input.action_press("log_pose")
			hold = 2.0
		4:
			snap("chain_unset")
			gm.chain_set = true
			hold = 0.5
		5:
			if not world.chain_ready() and t < 60.0:
				step = 5
				return false
			hold = 2.0
		6:
			snap("fork_helm")
			Input.action_release("log_pose")
			menu.open("chart")
		7:
			snap("fork_chart")
			menu.close()
			quit()
	step += 1
	return false
