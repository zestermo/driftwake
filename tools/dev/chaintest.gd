extends SceneTree
## The island chain (docs/island_chain_plan.md) and the log pose: the chain is
## made from its seed (the same twice, another seed another chain), 9 layers
## with cities at 3 and 6 and the sea boss last, forks that split and rejoin,
## levels rising, the first island well past Redtide; the old placeholder
## islands are gone and the bottle treasures lie on Brinehollow's beaches.
## The log pose: none to start, given on the wrist, unset under level 10, then
## pointing at the first layer; hold L raises it and shows the HUD icon, the
## needle turns to the island; the seed, where we are and the log pose survive
## a save and load; Gus's rumour talks of the chain.
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
	if t > 60.0:
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
			for l in by_layer.keys():
				if by_layer[l].size() == 2 and by_layer[l][0]["theme"] == by_layer[l][1]["theme"]:
					forks_differ = false
			check("every island leads on to the next layer (the last to none)", links_ok and (by_layer[9][0]["next"] as Array).is_empty())
			check("the two sides of a fork are different islands", forks_differ)
			check("levels rise island to island (from Lv 12)", rising and int(by_layer[1][0]["level"]) >= 12)
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
			check("no placeholder islands in the world", world.island_infos.is_empty() and world.find_children("*Island*", "", false, false).is_empty())
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
			check("under level 10 it hasn't set", gm.log_pose_targets().is_empty())
			var PR = load("res://scripts/progression/progression.gd")
			while p.progression.level < 10:
				p.progression.add_xp(PR.xp_to_next(p.progression.level) - p.progression.xp)
			var tg: Array = gm.log_pose_targets()
			check("at level 10 it points at the first island(s) (%d)" % tg.size(), tg.size() == c.start_next.size() and tg[0]["id"] == c.start_next[0])
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
			Input.action_release("log_pose")
			wait = 0.5
			step = 2
		2:
			var icon = get_first_node_in_group("hud").get_node("LogPose")
			check("let go of L, it's lowered and the icon goes", not p.log_pose_up and p.body_model.current_action() != "log_pose" and not icon.visible)
			# saved and loaded back
			var seed_was: int = gm.chain_seed
			gm.chain_at = 2
			SG.save(p)
			gm.chain_seed = seed_was + 99
			gm.chain_at = -1
			root.get_node("Dialogue").flags.erase("log_pose")
			SG.load_into(p)
			check("the chain's seed and where we are are saved", gm.chain_seed == seed_was and gm.chain_at == 2)
			check("...and so is the log pose (still on the wrist)", p.has_log_pose() and p.body_model.fore_l.get_node_or_null("LogPose") != null)
			gm.chain_at = -1
			var rumor: String = root.get_node("Dialogue")._tokens["rumor"].call()
			print("   rumour: ", rumor)
			check("Gus's rumours tell of the chain", rumor != "" and not rumor.contains("{"))
			finish()
	return false
