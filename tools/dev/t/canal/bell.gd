extends SceneTree
## The drowned bell (1.27 C4): Father Anselm's: reaching the campanile's belfry moves it on, the clapper lies on the
## Grand Canal's bed (under the water, searchable while swimming), and hauling it up brings it to the turn-in.
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
			isl = w.build_canal(Vector3(900, 0, 900))
			until = TK.wait_ticks(6)
		2:
			q = isl.canal_life.bell_q
			check("the drowned bell is offered by Father Anselm", not q.is_empty() and str(q["giver"]) == "Father Anselm")
			if q.is_empty():
				return TK.done(fails)
			root.get_node("Dialogue").dialogue_event.emit("isle_q:%s:take" % q["id"])
			var p = stage.player
			p.global_position = q["steps"][0]["point"]
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.2)
		3:
			check("up in the belfry: the trail moves to the dive (step %d)" % J.step_of(q["id"]), J.step_of(q["id"]) == 1)
			var n: Node3D = isl.canal_life.quest_node.mark(q, 1)
			var water_y: float = isl.to_global(Vector3(0, 0.0, 0)).y
			check("the clapper lies under the water (%.1f m down)" % (water_y - n.global_position.y), n != null and n.visible and n.global_position.y < water_y - 2.0)
			check("...searchable while swimming", n.get_node("Search").usable_in_water)
			n.get_node("Search").interacted.emit(stage.player)
			until = TK.wait_ticks(2)
		4:
			check("hauled up: the bell's at its turn-in", J.at_turnin(q["id"]))
			return TK.done(fails)
	step += 1
	return false
