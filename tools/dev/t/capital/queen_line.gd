extends SceneTree
## 1.30 guidance: the capital's lines and the stronghold run are journal quests. The Queen's line opens (the crew's,
## not taking your tracking) once her investigation is taken, and moves on as the world does: the forger found, her
## thanks (the marker on the Queen), the fortress found (and the stronghold run opens with it), her writ, the fortress
## fallen, her thanks: Done. The stronghold run counts its seals (1/2), then the Commodore, the vault, the escape.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var cap
var life
var J
var gm
var line_id := ""
var sh_id := ""
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _line_step() -> int:
	return J.step_of(line_id)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var F = load("res://scripts/island/city_favour.gd")
	match step:
		0:
			J = root.get_node("Journal")
			gm = root.get_node("GameManager")
			J.reset()
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			gm.chain_seed = 4242
			until = TK.wait_ticks(2)
		1:
			cap = w.build_capital(Vector3(900, 0, 900))
			until = TK.wait_ticks(6)
		2:
			life = cap.life_node
			line_id = str(life.seal_q["id"]) + "_line"
			check("the line isn't in the journal before it opens", not J.has(line_id))
			J.take(str(life.seal_q["id"]))
			until = TK.wait_secs(2.5)
		3:
			check("taking her investigation opens the Queen's line", J.has(line_id) and J.entries[line_id]["title"] == "The Queen's line")
			check("...the crew's (shared), not anyone's", int(J.entries.get(line_id, {}).get("by", -1)) == 0)
			check("...and your tracking stays on the investigation (%s)" % J.tracked, J.tracked == str(life.seal_q["id"]))
			check("...its first step is the investigation (%s)" % J.goal(line_id), J.goal(line_id).contains(str(life.seal_q["title"])))
			J.settle(str(life.seal_q["id"]))
			until = TK.wait_secs(2.5)
		4:
			check("the forger found: tell the Queen (%s)" % J.goal(line_id), _line_step() == 1 and J.goal(line_id).contains("Queen Ilsabet"))
			var queen := Vector3.INF
			for n in get_nodes_in_group("npcs"):
				if n.npc_name == "Queen Ilsabet":
					queen = n.global_position
			check("...the marker on the Queen, a person", J.target(line_id).distance_to(queen) < 3.0 and J.target_is_person(line_id))
			F.thank("capital", life)
			until = TK.wait_secs(2.5)
		5:
			check("her thanks: find the fortress (%s)" % J.goal(line_id), _line_step() == 2 and J.goal(line_id).contains("fortress"))
			root.get_node("Net").world_flag("stronghold_known")
			until = TK.wait_secs(2.5)
		6:
			check("the fortress known: back to the Queen for her writ", _line_step() == 3)
			sh_id = "stronghold_%d" % w.c.seed_value
			check("...and the stronghold run opens with it", J.has(sh_id) and str(J.entries[sh_id]["title"]).begins_with("Storm "))
			check("...the Landing's gate first (%s)" % J.goal(sh_id), J.step_of(sh_id) == 0 and J.goal(sh_id).contains("gate"))
			root.get_node("Net").world_flag("sh_gate_open")
			until = TK.wait_secs(2.5)
			step = 60
			return false
		60:
			check("...the gate up: its seals counted (%s)" % J.goal(sh_id), J.goal(sh_id).ends_with("(0/2)"))
			step = 6
			F.writ(life)
			root.get_node("Net").world_flag("sh_seal_arsenal")
			until = TK.wait_secs(2.5)
		7:
			var sp: Vector2 = w.c.node(w.c.stronghold_id())["pos"]
			check("the writ: take the fortress, marked on it", _line_step() == 4 and Vector2(J.target(line_id).x, J.target(line_id).z).distance_to(sp) < 1.0)
			check("one seal taken (%s)" % J.goal(sh_id), J.goal(sh_id).ends_with("(1/2)"))
			root.get_node("Net").world_flag("sh_seal_prison")
			until = TK.wait_secs(2.5)
		8:
			check("both seals: the Commodore next (%s)" % J.goal(sh_id), J.step_of(sh_id) == 2 and J.goal(sh_id).contains("Vane"))
			root.get_node("Net").world_flag("sh_seal_keep")
			until = TK.wait_secs(2.5)
		9:
			check("the keep's seal: the vault next, and the Queen's to be told", J.step_of(sh_id) == 3 and _line_step() == 5)
			gm.opened["sh_vault_%d" % int(gm.chain_seed)] = true
			F.thank_fortress(life)
			until = TK.wait_secs(2.5)
		10:
			check("the Queen thanked: her line is done", J.is_done(line_id))
			check("the vault open: escape the Scouring", J.step_of(sh_id) == 4)
			root.get_node("Net").world_flag("sh_escaped")
			until = TK.wait_secs(2.5)
		11:
			check("out of the ring: the stronghold run is done", J.is_done(sh_id))
			check("...both in the journal's Done", J.done().any(func(e): return e["id"] == sh_id) and J.done().any(func(e): return e["id"] == line_id))
			return TK.done(fails)
	step += 1
	return false
