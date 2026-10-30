extends SceneTree
## The canal city's investigation, the smuggling ring (1.27 C4): offered by Master Grane, three chalked crates in the campi:
## each shows only on its own step and searching it moves the trail on; the last brings it back to Grane.
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
			isl = w.build_canal(AT)
			until = TK.wait_ticks(6)
		2:
			qn = isl.canal_life.quest_node
			q = isl.canal_life.smug_q
			check("the smuggling ring is offered by Master Grane", not q.is_empty() and str(q["giver"]) == "Master Ottavio Grane")
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
			check("the trail ends back at Grane (turn-in)", J.at_turnin(q["id"]))
			return TK.done(fails)
	step += 1
	return false
