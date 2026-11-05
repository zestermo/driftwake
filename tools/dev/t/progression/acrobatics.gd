extends SceneTree
## Acrobatics is learned in the air (1.30.2): a plain jump a point (once each JUMP_GAP_S), a dodge through no blow
## nothing, an air jump more, time in the air and a tall drop too; Acrobatics 2 lets Geppo be bought (a second jump in
## mid-air). Its own curve: 40 x lv^1.15.
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
			check("a plain jump teaches a point (%d)" % xp(), xp() == pr.ACRO_XP["jump"])
			TK.act("jump")
			until = TK.wait_ticks(60)
		2:
			check("...but not another straight after (%d)" % xp(), xp() == pr.ACRO_XP["jump"])
			TK.act("dodge")
			until = TK.wait_ticks(40)
		3:
			check("a dodge through no blow teaches nothing (%d)" % xp(), xp() == pr.ACRO_XP["jump"])
			pr.add_life("acrobatics", pr.mastery_to_next(1, "acrobatics") + pr.mastery_to_next(2, "acrobatics"))
			check("Acrobatics 3 (467 xp by 5 on its own curve): Geppo bought with its 2 Adventure points, a second jump in mid-air",
				pr.mastery_to_next(4, "acrobatics") == 197 and pr.buy("m_geppo") and p.max_jumps == 2)
			x0 = xp()
			TK.act("jump")
			until = TK.wait_ticks(12)
		4:
			TK.act("jump")
			until = TK.wait_ticks(90)
		5:
			check("an air jump teaches more (%d)" % (xp() - x0), xp() - x0 >= pr.ACRO_XP["air_jump"])
			x0 = xp()
			p.global_position += Vector3(0, 9.0, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.5)
		6:
			check("a tall drop and its air time teach it (%d)" % (xp() - x0), xp() - x0 >= 4 + pr.ACRO_XP["air"])
			return TK.done(fails)
	step += 1
	return false
