extends SceneTree
## The capital's missing apprentice (1.27 C4): offered by Mirela, a bench and a note in two walk-in workshops, a cellar door
## by the courtyard den: each shows only on its own step and searching it moves the trail on; it ends back at Mirela.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(900, 0, 900)
var stage
var w
var isl
var q: Dictionary
var qn
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var J = root.get_node("Journal")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(AT)
			until = TK.wait_ticks(6)
		2:
			qn = isl.life_node.quest_node
			q = isl.life_node.appr_q
			check("the missing apprentice is offered by Mirela", not q.is_empty() and str(q["giver"]) == "Mirela")
			if q.is_empty():
				return TK.done(fails)
			root.get_node("Dialogue").dialogue_event.emit("isle_q:%s:take" % q["id"])
			until = TK.wait_ticks(2)
		3, 4, 5:
			var k: int = step - 3
			check("clue %d: the trail is at it (step %d)" % [k + 1, J.step_of(q["id"])], J.step_of(q["id"]) == k)
			var n: Node3D = qn.mark(q, k)
			var others := true
			for j in range(3):
				if j != k and qn.mark(q, j).visible:
					others = false
			check("clue %d shows, the others don't" % (k + 1), n != null and n.visible and others)
			n.get_node("Search").interacted.emit(stage.player)
			until = TK.wait_ticks(2)
		6:
			check("the trail ends back at Mirela (turn-in)", J.at_turnin(q["id"]))
			return TK.done(fails)
	step += 1
	return false
