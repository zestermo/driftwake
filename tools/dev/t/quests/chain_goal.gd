extends SceneTree
## 1.30 guidance: after Brinehollow's story the objective box is never blank. With no quest followed it shows the
## chain's next step: Morrow while there's no log pose, the level the needle waits for, "Sail to <island>" with its
## distance in km, "Explore" on an island whose needle hasn't set, and the next sail once it has. A quest taken is
## followed instead; when it ends, tracking falls back to the chain (not to the finished story).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var j
var gm
var hud
var chain
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			gm = root.get_node("GameManager")
			j.reset()
			check("the story is done on the stage", not root.get_node("Story").active())
			stage.get_node("NoIslands").remove_from_group("world_gen")
			var gs := GDScript.new()
			gs.source_code = "extends Node\nvar chain_islands := {}\nvar starter_island = null\nvar c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\n"
			gs.reload()
			var wg := Node.new()
			wg.set_script(gs)
			chain = load("res://scripts/world/chain.gd").make(4242, Vector2(p.global_position.x, p.global_position.z), Vector2(0, -1))
			wg.set("c", chain)
			stage.add_child(wg)
			gm.chain_at = -1
			root.get_node("Dialogue").flags.erase("log_pose")
			hud = stage.hud._objective
			until = TK.wait_ticks(20)
		1:
			check("no log pose: Morrow (%s)" % hud._goal.text, hud._box.visible and hud._goal.text.contains("Morrow"))
			check("...as the chain's step (%s)" % hud._head.text, hud._head.text.contains("THE CHAIN"))
			root.get_node("Dialogue").set_flag("log_pose")
			p.progression.level = 1
			until = TK.wait_ticks(20)
		2:
			check("the pose, too green: the level it waits for (%s)" % hud._goal.text, hud._goal.text.contains("Lv 5"))
			p.progression.level = 5
			until = TK.wait_ticks(20)
		3:
			var first: Dictionary = chain.node(chain.start_next[0])
			check("Lv 5: sail to the first island (%s)" % hud._goal.text, hud._goal.text.begins_with("Sail to") and hud._goal.text.contains(str(first["name"])))
			check("...follow the log pose, a bearing (%s)" % hud._sub.text, hud._sub.text.begins_with("Follow the log pose "))
			check("...its distance in km (%s)" % hud._dist.text, hud._dist.text.ends_with(" KM"))
			check("...its mark on the held map", root.get_node("Journal") != null and load("res://scripts/map/map_marks.gd").has("quest"))
			var q := {"id": "t_side", "title": "A side job", "giver": "Kai", "isle": "Test", "pos": Vector3.ZERO, "src": "npc",
				"steps": [{"do": "reach", "goal": "Go and look"}, {"do": "turnin", "goal": "Tell Kai"}], "reward": {"gold": 5}}
			j.register(q, null)
			j.take("t_side")
			until = TK.wait_ticks(20)
		4:
			check("a quest taken is followed instead (%s)" % hud._goal.text, j.tracked == "t_side" and hud._goal.text == "Go and look" and hud._head.text.contains("QUEST"))
			j.settle("t_side")
			until = TK.wait_ticks(20)
		5:
			check("the quest over: tracking isn't the finished story (%s)" % j.tracked, j.tracked == "")
			check("...the box is back on the chain (%s)" % hud._goal.text, hud._box.visible and hud._goal.text.begins_with("Sail to"))
			gm.chain_at = int(chain.start_next[0])
			gm.chain_set = false
			gm.chain_since = root.get_node("Weather").world_time()
			until = TK.wait_ticks(20)
		6:
			check("arrived, the needle unset, no island built: explore it (%s / %s)" % [hud._goal.text, hud._sub.text],
				hud._goal.text == "Explore %s" % chain.node(gm.chain_at)["name"] and hud._sub.text.contains("lodestone sets in"))
			gm.chain_set = true
			until = TK.wait_ticks(20)
		7:
			var nxt: Array = chain.next_of(gm.chain_at).map(func(id): return str(chain.node(id)["name"]))
			check("the needle set: sail on (%s, to %s)" % [hud._goal.text, nxt], hud._goal.text.begins_with("Sail to") and hud._goal.text.contains(nxt[0]))
			gm.chain_at = -1
			gm.chain_set = false
			return TK.done(fails)
	step += 1
	return false
