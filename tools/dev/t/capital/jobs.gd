extends SceneTree
## The Watch's odd jobs on the capital's board (1.27 C4): three posted (a packet, the cat on the roofs, fish for the cook);
## the cat sits up on a roof and coaxing it down moves the job on; the fish job waits at its turn-in once taken.
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
			var jobs: Array = isl.life_node.job_qs
			check("three jobs posted on the board (%d)" % jobs.size(), jobs.size() == 3 and jobs.all(func(j): return str(j["src"]) == "board"))
			for j in jobs:
				root.get_node("Dialogue").dialogue_event.emit("isle_q:%s:take" % j["id"])
			q = jobs[1]
			until = TK.wait_ticks(2)
		3:
			var n: Node3D = qn.mark(q, 0)
			check("the cat shows, up on a roof", n != null and n.visible and float(q["steps"][0]["y"]) > 4.0)
			n.get_node("Search").interacted.emit(stage.player)
			until = TK.wait_ticks(2)
		4:
			check("coaxed down: the job's at its turn-in", J.at_turnin(q["id"]))
			check("the fish job waits at its turn-in", J.at_turnin(isl.life_node.job_qs[2]["id"]))
			return TK.done(fails)
	step += 1
	return false
