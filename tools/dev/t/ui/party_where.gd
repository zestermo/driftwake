extends SceneTree
## The party panel's where-or-what (1.22): a crewmate 50 m north reads "50m N", down "DOWN 50m N", close by nothing,
## in deep water "swim".
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Mate", "at": Vector3(0, 0, -50)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var hud = get_first_node_in_group("hud")
	var mate: Node3D = null
	for c in get_nodes_in_group("players"):
		if c != stage.player:
			mate = c
	if mate == null:
		check("a crewmate on the stage", false)
		return TK.done(fails)
	mate.global_position = stage.player.global_position + Vector3(0, 0, -50)
	var w: String = hud.party_where(mate, false)
	check("50 m north: \"%s\"" % w, w == "50m N")
	w = hud.party_where(mate, true)
	check("down: \"%s\"" % w, w == "DOWN 50m N")
	mate.global_position = stage.player.global_position + Vector3(6, 0, 0)
	w = hud.party_where(mate, false)
	check("close by: nothing (\"%s\")" % w, w == "")
	return TK.done(fails)
