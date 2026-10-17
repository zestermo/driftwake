extends SceneTree
## Chain._name never runs out: every theme name already given on nearby layers (chain seeds 74, 200, 220, 259
## used to divide by zero) still gives every island a name.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	for s in [74, 200, 220, 259]:
		var c = load("res://scripts/world/chain.gd").make(s, Vector2.ZERO, Vector2(1, 0))
		var named := true
		for n in c.nodes:
			if str(n["name"]).is_empty() or str(n["base"]).is_empty():
				named = false
		check("chain seed %d: %d islands, every one named" % [s, c.nodes.size()], c.nodes.size() > 0 and named)
	return TK.done(fails)
