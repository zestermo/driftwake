extends SceneTree
## The tracked quest drives the objective HUD: nothing tracked and no story, no tracker; a quest taken is
## tracked and shown (QUEST, its step's goal, the distance, the marker on its target); a step done shows the
## next goal and flashes; J opens the journal (the tracker hides under it) listing it, T untracks it there and
## the tracker goes; J closes it.
const TK := preload("res://tools/dev/test_kit.gd")
var marks := load("res://scripts/map/map_marks.gd")
var stage
var p
var j
var hud
var src
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {"name": "Net-mender Kai", "at": Vector3(-3, 0, -3)}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	j._input(ev)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			hud = stage.hud._objective
			src = load("res://scripts/island/kit/kit_quests.gd").new()
			src.name = "Quests"
			stage.add_child(src)
			var q := {"id": "t_look", "kind": "scout", "title": "A look at the reef", "giver": "Net-mender Kai", "isle": "Test Isle", "pos": Vector3.ZERO, "src": "npc",
				"point": p.global_position + Vector3(0, 1, -60), "r": 6.0, "reward": {"gold": 20},
				"steps": [{"do": "reach", "goal": "Scout the reef"}, {"do": "turnin", "goal": "Tell Kai what you saw"}]}
			src.quests.append(q)
			j.register(q, src)
			until = TK.wait_ticks(3)
		1:
			check("no story, nothing tracked: no tracker", not hud._box.visible)
			check("...and no mark on the held map", not marks.has("quest"))
			j.take("t_look")
			until = TK.wait_ticks(25)
		2:
			check("a quest taken is tracked and shown", j.tracked == "t_look" and hud._box.visible)
			var m: Dictionary = marks.marks.get("quest", {})
			var pt: Vector3 = src.quests[0]["point"]
			check("...its mark on the held map, labelled (%s)" % m, not m.is_empty() and m["kind"] == "quest" and m["label"] == "A look at the reef"
				and (m["at"] as Vector2).distance_to(Vector2(pt.x, pt.z)) < 0.01)
			check("...as a quest, with its distance (%s)" % hud._head.text, hud._head.text.contains("QUEST") and hud._head.text.contains("60m"))
			check("...its step's goal (%s)" % hud._goal.text, hud._goal.text == "Scout the reef")
			check("...the marker on the place", hud._target().distance_to(src.quests[0]["point"]) < 0.01 and not hud._person())
			hud._flash = 0.0
			j.advance("t_look", 0)
			until = TK.wait_ticks(3)
		3:
			check("a step done: the next goal (%s), flashing" % hud._goal.text, hud._goal.text == "Tell Kai what you saw" and hud._flash > 0.0)
			check("...the marker on Kai now", hud._target().distance_to(stage.npc.global_position + Vector3.UP * 2.2) < 0.01 and hud._person())
			key(KEY_J)
			until = TK.wait_ticks(3)
		4:
			check("J opens the journal", j.is_open())
			check("...the tracker hides under it", not hud._box.visible)
			var scr = j.screen
			check("...Active lists the quest, picked", scr.tab == "active" and scr.rows.size() == 1 and scr.rows[scr.sel]["id"] == "t_look")
			key(KEY_T)
			check("T untracks it", j.tracked == "")
			key(KEY_D)
			check("D: the Done tab", scr.tab == "done" and scr.rows.is_empty())
			key(KEY_J)
			until = TK.wait_ticks(25)
		5:
			check("J closes it", not j.is_open())
			check("untracked: no tracker", not hud._box.visible)
			check("...and the map's mark gone", not marks.has("quest"))
			return TK.done(fails)
	step += 1
	return false
