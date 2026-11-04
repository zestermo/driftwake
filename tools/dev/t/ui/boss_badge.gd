extends SceneTree
## The top boss bar's level badge (PlayerHUD.show_boss with the boss as its foe): the boss's level in the gap's colour as the
## small enemy bars' (grey far below, white, red 3+ above); no badge without a foe. And a level-0 foe (Brinehollow's apes)
## is the level of the island it stands under (REF without one), not the level its numbers were tuned for.
const TK := preload("res://tools/dev/test_kit.gd")
const STUB := "extends Node3D\nvar level := 0\nvar node := {}\nfunc _lv_ref() -> int:\n\treturn 6\n"
var stage
var hud
var foe
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _badge_col() -> Color:
	return hud._boss_badge_label.get_theme_color("font_color")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			hud = stage.hud
			var sc := GDScript.new()
			sc.source_code = STUB
			sc.reload()
			foe = Node3D.new()
			foe.set_script(sc)
			foe.add_to_group("enemies")
			root.add_child(foe)
			p.progression.level = 3
			foe.level = 4
			hud.show_boss("Test Boss", 1.0, 1, foe)
			check("a level-4 boss on a level-3 captain: badge 4, white (%s)" % hud._boss_badge_label.text,
				hud._boss_badge.visible and hud._boss_badge_label.text == "4" and _badge_col() == Levels.BADGE_WHITE)
			foe.level = 6
			hud.show_boss("Test Boss", 1.0, 1, foe)
			check("+3 above: red", hud._boss_badge_label.text == "6" and _badge_col() == Levels.BADGE_RED)
			p.progression.level = 12
			hud.show_boss("Test Boss", 1.0, 1, foe)
			check("-6 below: grey", _badge_col() == Levels.BADGE_GREY)
			hud.show_boss("Test Boss", 1.0, 1)
			check("no foe, no badge", not hud._boss_badge.visible)
			p.progression.level = 3
			foe.level = 0
			check("a level-0 foe with no island is REF (%d), not its tuned level 6" % Levels.foe_level(foe), Levels.foe_level(foe) == Levels.REF)
			check("...so the level-3 captain sees no gap (%d)" % Levels.gap_to(foe, p), Levels.gap_to(foe, p) == 0)
			var isle := Node3D.new()
			var s2 := GDScript.new()
			s2.source_code = "extends Node3D\nvar node := {\"level\": 9}\n"
			s2.reload()
			isle.set_script(s2)
			root.add_child(isle)
			foe.reparent(isle)
			check("...under an island of level 9 it's 9 (%d)" % Levels.foe_level(foe), Levels.foe_level(foe) == 9)
			return TK.done(fails)
	step += 1
	return false
