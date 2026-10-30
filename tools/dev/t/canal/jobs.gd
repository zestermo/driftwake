extends SceneTree
## The canal city's odd jobs (1.27 C4): three offered by its people (soup fish, the basket on the roofs, the candles);
## the basket sits up on a roof and fetching it moves the job on; the soup job waits at its turn-in once taken.
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
			var jobs: Array = isl.canal_life.job_qs
			check("three jobs offered by the city's people (%d)" % jobs.size(), jobs.size() == 3 and jobs.all(func(j): return str(j["src"]) == "npc"))
			for j in jobs:
				root.get_node("Dialogue").dialogue_event.emit("isle_q:%s:take" % j["id"])
			q = jobs[1]
			until = TK.wait_ticks(2)
		3:
			var n: Node3D = qn.mark(q, 0)
			check("the basket shows, up on a roof", n != null and n.visible and float(q["steps"][0]["y"]) > 4.0)
			n.get_node("Search").interacted.emit(stage.player)
			until = TK.wait_ticks(2)
		4:
			check("fetched: the job's at its turn-in", J.at_turnin(q["id"]))
			check("the soup job waits at its turn-in", J.at_turnin(isl.canal_life.job_qs[0]["id"]))
			return TK.done(fails)
	step += 1
	return false
