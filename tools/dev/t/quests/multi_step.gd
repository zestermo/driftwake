extends SceneTree
## A three-step quest in the crew journal (Journal): taken, it's Active on its first step and tracked;
## a step reached out of turn is ignored; reaching the place moves it on (its target then the next person), handing
## the parcel over moves it to the turn-in; the turn-in pays and it's Done, untracked, its steps all ticked.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var j
var src
var step := 0
var until := 0
var fails := 0
var gold0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {"name": "Net-mender Kai", "at": Vector3(-3, 0, -3)}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func quest() -> Dictionary:
	return {"id": "t_multi", "kind": "test", "title": "Three errands", "giver": "Net-mender Kai", "isle": "Test Isle", "pos": Vector3.ZERO, "src": "npc",
		"point": p.global_position + Vector3(0, 0, -30), "r": 6.0,
		"steps": [{"do": "reach", "goal": "Go and look at the reef", "said": "The reef's alive with fish."},
			{"do": "talk", "goal": "Take the net to Kai", "who": "Net-mender Kai"},
			{"do": "turnin", "goal": "Tell Kai it's done"}],
		"reward": {"gold": 40}}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			j = root.get_node("Journal")
			j.reset()
			src = load("res://scripts/island/kit/kit_quests.gd").new()
			src.name = "Quests"
			stage.add_child(src)
			var q := quest()
			src.quests.append(q)
			j.register(q, src)
			check("not taken: not in the journal", not j.has("t_multi") and j.active().is_empty())
			j.take("t_multi")
			check("taken: Active, on its first step", j.has("t_multi") and j.step_of("t_multi") == 0 and j.active().size() == 1 and j.done().is_empty())
			check("...and tracked (nothing else was)", j.tracked == "t_multi")
			check("...the goal is the first step's", j.goal("t_multi") == "Go and look at the reef")
			j.advance("t_multi", 1)
			check("a later step out of turn changes nothing", j.step_of("t_multi") == 0)
			until = TK.wait_ticks(4)
		1:
			check("not there yet: still on the first step", j.step_of("t_multi") == 0)
			p.global_position = src.quests[0]["point"]
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.8)
		2:
			check("there: on to the second step", j.step_of("t_multi") == 1)
			check("...whose goal is the parcel's", j.goal("t_multi") == "Take the net to Kai")
			check("...and the target is Kai, over his head", j.target("t_multi").distance_to(stage.npc.global_position + Vector3.UP * 2.2) < 0.01 and j.target_is_person("t_multi"))
			j.advance("t_multi", 1)
			check("handed over: on the turn-in", j.step_of("t_multi") == 2 and j.at_turnin("t_multi"))
			gold0 = p.inventory_component.count("gold")
			j.turn_in("t_multi", p.global_position)
			until = TK.wait_ticks(2)
		3:
			check("turned in: Done", j.is_done("t_multi") and j.active().is_empty() and j.done().size() == 1)
			check("...paid (40 gold)", p.inventory_component.count("gold") - gold0 == 40)
			check("...no longer tracked", j.tracked != "t_multi")
			check("...its goal reads Done", j.goal("t_multi") == "Done")
			j.turn_in("t_multi", p.global_position)
			check("a second turn-in pays nothing", p.inventory_component.count("gold") - gold0 == 40)
			return TK.done(fails)
	step += 1
	return false
