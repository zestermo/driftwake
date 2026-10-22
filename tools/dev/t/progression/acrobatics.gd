extends SceneTree
## Acrobatics is learned by doing: a jump teaches it (and finds the tree: it shows under Adventure), a dodge
## teaches more; Acrobatics 2 lets Geppo be bought (a second jump in mid-air), 4 Swift Step.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var x0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func xp() -> int:
	return int(pr.mastery_of("acrobatics")["xp"])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			check("no Acrobatics yet, one jump", xp() == 0 and p.max_jumps == 1 and not ("acrobatics" in pr.visible_trees("adventure")))
			TK.act("jump")
			until = TK.wait_ticks(60)
		1:
			check("a jump teaches Acrobatics (%d) and finds its tree" % xp(), xp() == 3 and "acrobatics" in pr.visible_trees("adventure"))
			x0 = xp()
			TK.act("dodge")
			until = TK.wait_ticks(40)
		2:
			check("a dodge teaches more (%d)" % (xp() - x0), xp() - x0 == 5)
			pr.add_life("acrobatics", pr.mastery_to_next(1))
			check("Acrobatics 2: Geppo bought with its Adventure point, a second jump in mid-air", pr.buy("m_geppo") and p.max_jumps == 2)
			while pr.mastery_level("acrobatics") < 4:
				pr.add_life("acrobatics", pr.mastery_to_next(pr.mastery_level("acrobatics")))
			check("Acrobatics 4: Swift Step bought (a cheaper dodge)", pr.buy("m_swift") and p.dodge_cost() < p.DODGE_COST)
			return TK.done(fails)
	step += 1
	return false
