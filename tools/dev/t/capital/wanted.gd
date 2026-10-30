extends SceneTree
## The Watch's bounty on Black Ned (1.27 C4): his gang of three holds the capital's second courtyard (a GruntCamp), the
## bounty is posted on the board, and once all three are down the taken bounty moves on to its turn-in with the Sergeant.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var q: Dictionary
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
			isl = w.build_capital(Vector3(900, 0, 900))
			until = TK.wait_secs(2.0)
		2:
			var camp = isl.life_node.wanted
			q = isl.life_node.wanted_q
			check("Black Ned's gang holds the second courtyard (%d)" % (camp.grunts.size() if camp else 0), camp != null and camp.grunts.size() == 3)
			check("the bounty is posted on the board", not q.is_empty() and str(q["src"]) == "board")
			if camp == null or q.is_empty():
				return TK.done(fails)
			root.get_node("Dialogue").dialogue_event.emit("isle_q:%s:take" % q["id"])
			for g in camp.grunts:
				if is_instance_valid(g):
					g.health.take_damage(99999.0)
			until = TK.wait_secs(1.5)
		3:
			check("all three down (%d left)" % isl.life_node.wanted.alive_count(), isl.life_node.wanted.alive_count() == 0)
			check("the bounty moves on to the Sergeant (turn-in)", J.at_turnin(q["id"]))
			return TK.done(fails)
	step += 1
	return false
