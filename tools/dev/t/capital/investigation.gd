extends SceneTree
## The capital's first investigation, the rooftop thief (1.27 C4; KitQuests' per-step pickups): posted on the board, it
## leads over three hatch roofs: each clue shows only on its own step, stands up on its roof, and searching it moves the
## trail on; the last one brings it to the turn-in with Sergeant Brannoch.
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
			q = isl.life_node.thief_q
			check("the rooftop thief is posted", not q.is_empty() and str(q["src"]) == "board")
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
			var roof_y: float = float(q["steps"][k]["y"])
			check("clue %d stands up on its roof (%.1f m)" % [k + 1, roof_y - isl.hv(Vector2(n.global_position.x, n.global_position.z))], roof_y > 4.0)
			n.get_node("Search").interacted.emit(stage.player)
			until = TK.wait_ticks(2)
		6:
			check("the trail ends at the Sergeant (turn-in)", J.at_turnin(q["id"]))
			return TK.done(fails)
	step += 1
	return false
