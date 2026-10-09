extends SceneTree
## The island chain (docs/island_chain_plan.md) and the log pose: the chain is
## made from its seed (the same twice, another seed another chain), 9 layers
## with cities at 3 and 6 and the sea boss last, forks that split and rejoin,
## levels rising, the first island well past Redtide; the old placeholder
## islands are gone and the bottle treasures lie on Brinehollow's beaches.
## The log pose: none to start, given on the wrist, unset under level 5, then
## pointing at the first layer; hold L raises it and shows the HUD icon, the
## needle turns to the island; the seed, where we are, the set rule's state and
## the log pose survive a save and load; Gus's rumour talks of the chain. The
## compass strip shows its needles while L is held, danger reads by level, and
## the sea chart stays on Brinehollow there but fits the chain island and where
## it points out there.
## Streaming: an island is put in the world a step a frame and listed only
## once whole; one let go part way through (or still on its thread) leaves
## nothing behind; a new chain seed frees every island of the old one.
var SG
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var fails := 0
func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	Input.action_release("log_pose")
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
func _process(d: float) -> bool:
	t += d
	_watch()
	if t > 180.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://chaintest")
			SG.slot = 1
			SG.delete_slot(1)
			p = get_first_node_in_group("player")
			gm = root.get_node("GameManager")
			world = root.get_node("World/Islands")
			var CH = load("res://scripts/world/chain.gd")
			var c = world.chain()
			check("the chain is built from the game's seed", c != null and c.seed_value == gm.chain_seed)
			var by_layer := {}
			for n in c.nodes:
				if not by_layer.has(n["layer"]):
					by_layer[n["layer"]] = []
				by_layer[n["layer"]].append(n)
			print("   %d islands: %s" % [c.nodes.size(), ", ".join(c.nodes.map(func(n): return "%d:%s %s Lv%d" % [n["layer"], n["name"], n["role"], n["level"]]))])
			check("9 layers", by_layer.size() == 9)
			check("cities at layers 3 and 6, the sea boss's island last (one each)", by_layer[3].size() == 1 and by_layer[3][0]["role"] == "city"
				and by_layer[6].size() == 1 and by_layer[6][0]["role"] == "city" and by_layer[9].size() == 1 and by_layer[9][0]["role"] == "sea_boss")
			var links_ok := true
			var forks_differ := true
			var rising := true
			for n in c.nodes:
				if int(n["layer"]) < 9 and (n["next"] as Array).is_empty():
					links_ok = false
				for id in n["next"]:
					if int(c.node(id)["layer"]) != int(n["layer"]) + 1:
						links_ok = false
					if int(c.node(id)["level"]) <= int(n["level"]):
						rising = false
			# (different themes once there's more than one the islands can be built in)
			var themes_ready: int = CH.FIRST_SEA_THEMES.filter(func(th): return load("res://scripts/island/island_theme.gd").has(th)).size()
			for l in by_layer.keys():
				if by_layer[l].size() == 2:
					var a: Dictionary = by_layer[l][0]
					var b: Dictionary = by_layer[l][1]
					if a["seed"] == b["seed"] or a["pos"] == b["pos"] or (themes_ready > 1 and a["theme"] == b["theme"]):
						forks_differ = false
			check("every island leads on to the next layer (the last to none)", links_ok and (by_layer[9][0]["next"] as Array).is_empty())
			check("the two sides of a fork are different islands", forks_differ)
			check("levels rise island to island (from Lv 6, past Brinehollow's 5)", rising and int(by_layer[1][0]["level"]) >= 6)
			var seen := {}
			var todo: Array = c.start_next.duplicate()
			while not todo.is_empty():
				var id: int = todo.pop_back()
				if not seen.has(id):
					seen[id] = true
					todo.append_array(c.node(id)["next"])
			check("every island can be reached from Brinehollow", seen.size() == c.nodes.size())
			var first: Vector2 = c.node(c.start_next[0])["pos"]
			check("the first island lies well past Redtide (%.0f m out)" % first.distance_to(world.starter_center), first.distance_to(world.starter_center) > 1700.0)
			var far := 0.0
			var close := INF
			var twins := 0
			for s in range(300):
				var cs = c if s == 0 else CH.make(c.seed_value + s * 7919, world.starter_center, Vector2(0, -1))
				for a in cs.nodes:
					far = maxf(far, (a["pos"] as Vector2).distance_to(world.starter_center))
					for b in cs.nodes:
						if a["id"] != b["id"] and absi(int(a["layer"]) - int(b["layer"])) <= 1:
							close = minf(close, (a["pos"] as Vector2).distance_to(b["pos"]))
						if a["id"] != b["id"] and absi(int(a["layer"]) - int(b["layer"])) <= 2 and a["base"] == b["base"]:
							twins += 1
			check("...no name shared by islands within two layers (a fork's two included): %d" % twins, twins == 0)
			check("over 300 chains the line wanders round, never more than 8.5 km from Brinehollow (%.0f m)" % far, far < 8500.0)
			check("...islands a layer apart (and a fork's two) stay over 1 km apart (%.0f m)" % close, close > 1000.0)
			var again = CH.make(c.seed_value, world.starter_center, Vector2(0, -1))
			var c2 = world.chain()
			check("the same seed makes the same chain", c2.nodes.size() == c.nodes.size() and c2.nodes[4]["name"] == c.nodes[4]["name"] and c2.nodes[4]["pos"] == c.nodes[4]["pos"])
			var other = CH.make(c.seed_value + 1, world.starter_center, Vector2(0, -1))
			var same: bool = other.nodes.size() == again.nodes.size()
			if same:
				for i in range(other.nodes.size()):
					if other.nodes[i]["theme"] != again.nodes[i]["theme"] or other.nodes[i]["name"] != again.nodes[i]["name"]:
						same = false
			check("another seed makes another chain", not same)
			# the old placeholder islands are gone; the bottle treasures are on Brinehollow
			check("no placeholder islands in the world (only the chain's)", world.island_infos.all(func(i): return i.has("id")) and world.find_children("*Island*", "", false, false).is_empty())
			var sf = get_first_node_in_group("sea_features")
			var on_brine: bool = sf.treasures.size() == 4
			for tr in sf.treasures:
				var at: Vector3 = tr[0]
				if Vector2(at.x, at.z).distance_to(world.starter_center) > 320.0 or tr[1] != "Brinehollow":
					on_brine = false
			check("4 buried treasures on Brinehollow's beaches, a bottle for each", on_brine and sf.bottles.size() == 4)
			# --- the log pose
			check("a new captain has no log pose", not p.has_log_pose() and p.body_model.fore_l.get_node_or_null("LogPose") == null)
			p.give_log_pose()
			check("given, it's on the left wrist", p.has_log_pose() and p.body_model.fore_l.get_node_or_null("LogPose") != null)
			check("under level %d it hasn't set" % gm.LOG_POSE_LEVEL, gm.log_pose_targets().is_empty())
			var PR = load("res://scripts/progression/progression.gd")
			while p.progression.level < gm.LOG_POSE_LEVEL:
				p.progression.add_xp(PR.xp_to_next(p.progression.level) - p.progression.xp)
			var tg: Array = gm.log_pose_targets()
			check("at level %d it points at the first island(s) (%d)" % [gm.LOG_POSE_LEVEL, tg.size()], tg.size() == c.start_next.size() and tg[0]["id"] == c.start_next[0])
			p.state_machine.force_state("Idle", {})
			Input.action_press("log_pose")
			wait = 0.5
			step = 1
		1:
			var hud = get_first_node_in_group("hud")
			var icon = hud.get_node("LogPose")
			check("holding L raises it", p.log_pose_up and p.body_model.current_action() == "log_pose")
			check("...and the HUD shows the log pose", icon.visible and icon._k > 0.9)
			var lp = p.body_model.fore_l.get_node("LogPose")
			var tg: Array = gm.log_pose_targets()
			var to: Vector2 = tg[0]["pos"] - Vector2(lp._ball.global_position.x, lp._ball.global_position.z)
			var nd: Vector3 = -lp.needles[0].global_basis.z
			var off := absf(Vector2(nd.x, nd.z).angle_to(to))
			check("the needle points at the island (off by %.2f rad)" % off, off < 0.1)
			check("one needle per island", lp.needles[1].visible == (tg.size() > 1))
			check("...and the compass strip is up with its needles", hud._compass.visible)
			var MK = load("res://scripts/ui/chain_marks.gd")
			check("danger by level: easy / even / hard / deadly", MK.danger(5, 9)[0] == "easy" and MK.danger(7, 7)[0] == "even"
				and MK.danger(11, 7)[0] == "hard" and MK.danger(14, 5)[0] == "deadly")
			Input.action_release("log_pose")
			wait = 0.5
			step = 2
		2:
			var icon = get_first_node_in_group("hud").get_node("LogPose")
			check("let go of L, it's lowered and the icon goes", not p.log_pose_up and p.body_model.current_action() != "log_pose" and not icon.visible)
			# saved and loaded back
			var seed_was: int = gm.chain_seed
			gm.chain_at = 2
			gm.chain_set = true
			gm.chain_since = 1234.5
			SG.save(p)
			gm.chain_seed = seed_was + 99
			gm.chain_at = -1
			gm.chain_set = false
			gm.chain_since = 0.0
			root.get_node("Dialogue").flags.erase("log_pose")
			SG.load_into(p)
			check("the chain's seed and where we are are saved", gm.chain_seed == seed_was and gm.chain_at == 2)
			check("...whether the log pose has set there, and since when", gm.chain_set and is_equal_approx(gm.chain_since, 1234.5))
			check("...and so is the log pose (still on the wrist)", p.has_log_pose() and p.body_model.fore_l.get_node_or_null("LogPose") != null)
			gm.chain_at = -1
			# the sea chart: Brinehollow's sea as ever; on the chain, fitted round where we are and where it points
			var menu = root.get_node("GameMenu")
			menu.open("chart")
			var ch = menu._chart
			var c = world.chain()
			ch._view(world, gm)
			check("in Brinehollow's sea the chart is centred on Brinehollow", ch._centre == world.starter_center and ch._pin)
			var at: int = c.start_next[0]
			gm.chain_at = at
			gm.chain_set = true
			ch._view(world, gm)
			check("on the chain it shows the island we're at and where the log pose points",
				ch._inside(c.node(at)["pos"]) and c.next_of(at).all(func(id): return ch._inside(c.node(id)["pos"])) and not ch._pin)
			menu.close()
			gm.apply_chain(-1, false, 0.0)
			var rumor: String = root.get_node("Dialogue")._tokens["rumor"].call()
			print("   rumour: ", rumor)
			check("Gus's rumours tell of the chain", rumor != "" and not rumor.contains("{"))
			step = 3
		3:
			# --- streaming
			if not world.chain_ready():
				return false
			var c = world.chain()
			var first: int = c.start_next[0]
			var seen: Dictionary = steps_seen.get(first, {})
			print("   %s built in %d steps, seen at %s; %s" % [world.chain_islands[first].island_name, int(steps_of.get(first, 0)), seen.keys(), world.chain_islands[first].build_ms])
			check("a chain island is put in the world a step a frame (%d of %d steps seen)" % [seen.size(), int(steps_of.get(first, 0))], int(steps_of.get(first, 0)) >= 8 and seen.size() >= int(steps_of.get(first, 0)) - 1)
			check("...and only charted, kept clear and given its shallows once it's whole", not listed_early)
			# an island further on, wanted while the crew's at it, unwanted part way through
			var far: Array = c.nodes.filter(func(n): return int(n["layer"]) >= 4).map(func(n): return int(n["id"]))
			set_meta("x", far[0])
			set_meta("y", far[1])
			set_meta("z", far[2])
			gm.apply_chain(far[0], false, root.get_node("Weather").world_time())
			world.sync_chain_islands()
			check("moving on: the islands behind go, the one we're at is started", world.chain_islands.is_empty() and world._pending.has(far[0]))
			step = 4
		4:
			var x: int = get_meta("x")
			# (after its camp is made, before its beast and village)
			var past_camp := false
			if world._finishing.has(x):
				var names: Array = (world._finishing[x][1] as Array).map(func(s): return s[0])
				past_camp = int(world._finishing[x][2]) > names.find("camp") and int(world._finishing[x][2]) < names.find("boss")
			if not past_camp:
				if world.chain_islands.has(x):
					check("caught the island part way through its build", false)
					finish()
				return false
			var half = world._finishing[x][0]
			set_meta("half", half)
			set_meta("half_pos", Vector2(half.position.x, half.position.z))
			var H = load("res://scripts/npc/humanoid.gd")
			var keys: Array = load("res://scripts/island/island_village.gd").looks(half).map(func(lk): return H._look_key(lk))
			set_meta("look_keys", keys)
			print("   %s let go after %d of %d steps" % [half.island_name, int(world._finishing[x][2]), (world._finishing[x][1] as Array).size()])
			gm.apply_chain(get_meta("y"), false, root.get_node("Weather").world_time())
			world.sync_chain_islands()
			check("let go part way through its build: dropped at once", not world._finishing.has(x) and not world.chain_islands.has(x) and half.is_queued_for_deletion())
			wait = 1.2
			step = 5
		5:
			var x: int = get_meta("x")
			var at: Vector2 = get_meta("half_pos")
			check("...nothing of it left in the world", not is_instance_valid(get_meta("half")) and world.get_node_or_null("Isle%d" % x) == null)
			check("...nor on the chart, in the ships' no-go list or the sea's shallows", not world.island_infos.any(func(i): return int(i["id"]) == x)
				and not load("res://scripts/ship/enemy_ship.gd").no_go.any(func(z): return z[0] == at) and root.get_node("Ocean").isle_shoals.size() == mini(world.chain_islands.size(), 2))
			check("...nor among the navmesh zones", world.get_node("NavBaker")._zones.all(func(z): return is_instance_valid(z["node"])))
			var H = load("res://scripts/npc/humanoid.gd")
			var left := 0
			for k in get_meta("look_keys"):
				left += (H._ready_bodies.get(k, []) as Array).size()
			check("...nor its villagers' bodies, built ahead for it (%d left waiting)" % left, left == 0)
			# one let go while it's still being worked out on its thread: dropped when that's done
			var z: int = get_meta("z")
			gm.apply_chain(z, false, root.get_node("Weather").world_time())
			world.sync_chain_islands()
			set_meta("z_started", world._pending.has(z))
			gm.apply_chain(get_meta("y"), false, root.get_node("Weather").world_time())
			world.sync_chain_islands()
			step = 6
		6:
			var z: int = get_meta("z")
			if world._pending.has(z):
				return false
			check("let go while still worked out on its thread: never put in the world", get_meta("z_started") and not world.chain_islands.has(z) and not world._finishing.has(z) and world.get_node_or_null("Isle%d" % z) == null)
			step = 7
		7:
			# a load (or a host's world) brings another chain: every island of this one goes, built or not
			var y: int = get_meta("y")
			if not world._finishing.has(y):
				# (already whole: build it again to catch it part way)
				if world.chain_islands.has(y):
					world._free_chain_island(y)
					world.sync_chain_islands()
				return false
			set_meta("old_name", world._finishing[y][0].island_name)
			set_meta("old", world._finishing[y][0])
			set_meta("seed0", gm.chain_seed)
			gm.chain_seed += 1
			world.sync_chain_islands()
			check("a new chain (a load): the old chain's islands all go, half-built ones too", world.chain_islands.is_empty() and world._finishing.is_empty()
				and (get_meta("old") as Node).is_queued_for_deletion() and world._pending.has(y))
			step = 8
		8:
			var y: int = get_meta("y")
			if not world.chain_ready():
				return false
			var isl = world.chain_islands[y]
			check("...and the island we're at is built from the new chain (%s, was %s)" % [isl.island_name, get_meta("old_name")], isl.island_name == world.chain().node(y)["name"] and isl.node["seed"] == world.chain().node(y)["seed"])
			gm.chain_seed = get_meta("seed0")
			gm.apply_chain(-1, false, 0.0)
			finish()
	return false


## Every frame: the steps each chain island is seen at while it's put in the world.
var steps_seen := {}
var steps_of := {}
var listed_early := false
func _watch() -> void:
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return
	for id in w._finishing.keys():
		var e: Array = w._finishing[id]
		if not steps_seen.has(id):
			steps_seen[id] = {}
		steps_seen[id][int(e[2])] = true
		steps_of[id] = (e[1] as Array).size()
		if w.chain_islands.has(id) or w.island_infos.any(func(i): return int(i["id"]) == int(id)):
			listed_early = true
