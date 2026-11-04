extends SceneTree
## 1.30 (round 9): a generated island's bounties need no taking. Each is marked on the held map from the start (an X
## with its title); the board has nothing to tear down; walking up to the place puts it in the crew's journal at its
## fight; once the target falls it's "report to <poster>", the poster pays, and the mark goes.
const TK := preload("res://tools/dev/test_kit.gd")
const ISLE := preload("res://tools/dev/t/quests/_isle.gd")
var stage
var p
var isl
var q: Dictionary
var j
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
	var MM = load("res://scripts/map/map_marks.gd")
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			isl = ISLE.build(stage, 9100)
			until = TK.wait_ticks(40)
		1:
			var notices: Array = isl.life.notices
			q = notices.filter(func(x): return x["kind"] == "bounty")[0]
			check("three notices, none in the journal before anyone goes", notices.size() == 3 and notices.all(func(x): return not j.has(x["id"])))
			check("each marked on the held map with an X", notices.all(func(x): return MM.has("notice:" + str(x["id"])) and MM.marks["notice:" + str(x["id"])]["kind"] == "x"))
			check("the board has nothing to take (no notice talk)", not root.get_node("Dialogue")._cache.has(isl.save_key("board")))
			var at: Vector3 = q["poi"]
			p.global_position = at + Vector3(20.0, 2.0, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(60)
		2:
			check("there: the bounty is the crew's, at its fight (%s)" % (j.goal(q["id"]) if j.has(q["id"]) else "-"), j.has(q["id"]) and j.step_of(q["id"]) == 0)
			check("...and followed", j.tracked == q["id"])
			root.get_node("Net").world_flag("cleared_" + str(q["id"]))
			until = TK.wait_ticks(60)
		3:
			check("its captain down: report to %s (%s)" % [q["giver"], j.goal(q["id"]) if j.has(q["id"]) else "-"], j.at_turnin(q["id"]) and j.goal(q["id"]).contains(str(q["giver"]).get_slice(" ", 0)))
			check("the poster has the report in their talk", _poster_has_pay())
			j.turn_in(q["id"], p.global_position)
			until = TK.wait_ticks(40)
		4:
			check("paid: done", j.is_done(q["id"]))
			check("...and its mark gone from the map", not MM.has("notice:" + str(q["id"])))
			return TK.done(fails)
	step += 1
	return false


func _poster_has_pay() -> bool:
	var dlg = root.get_node("Dialogue")
	for n in isl.find_children("*", "NPC", true, false):
		if n.npc_name == q["giver"] and n.dialogue_id != "":
			return dlg._load(n.dialogue_id)["nodes"].has("q_%s_pay" % q["id"])
	return false
