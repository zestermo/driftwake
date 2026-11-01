extends SceneTree
## The marking spyglass (1.28): raised to the eye, it marks the foes and unopened chests in view within its reach on
## the compass (not a foe past the reach), costs no charge, only its cooldown; a crewmate's marks arriving by their
## keys mark the same foes here; the marks run out with time.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"chest": [["gold", 10]], "grunts": [{"post": Vector3(1, 0, -18), "role": "sword", "seed": 61},
		{"post": Vector3(-2, 0, -52), "role": "sword", "seed": 62}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var M = load("res://scripts/gadgets/gadget_marks.gd")
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts
			for x in g:
				TK.calm(x, Vector3.BACK)
			p.gadgets.give("spyglass", 0)
			TK.act("gadget_fire")
			until = TK.wait_ticks(3)
		1:
			check("the glass goes up to the eye (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gd_spy")
			check("...on its cooldown, no charge to spend", p.gadgets.cooldown_left("spyglass") > 20.0 and p.gadgets.max_charges("spyglass") == 0)
			until = TK.wait_secs(1.0)
		2:
			check("the foe in view within its reach is marked", M.is_marked(g[0]))
			check("...not the one past its reach (%.0f m)" % g[1].global_position.distance_to(p.global_position), not M.is_marked(g[1]))
			check("...and the unopened chest in view, as a cache", M.is_marked(stage.chest) and M.kind_of(stage.chest) == "cache")
			M.mark_keys([root.get_node("Net").key_of(g[1])], 0.5)
			check("a crewmate's mark arriving by its key marks it here", M.is_marked(g[1]))
			until = TK.wait_secs(1.0)
		3:
			check("...and runs out with its time", not M.is_marked(g[1]) and M.is_marked(g[0]))
			return TK.done(fails)
	step += 1
	return false
