extends SceneTree
## The points prompts say only what's true: a weapon's mastery level-up names what it opens and never mentions
## points; an Adventure level-up adds one short "N Adventure points (K)" while that pool has points to spend; a
## Captain level-up adds "N Combat points (K)" the same way; with the pools spent nothing is said and the HUD's
## pulse (can_spend) is off.
const TK := preload("res://tools/dev/test_kit.gd")
const HUD := "extends Node\nvar toasts: Array = []\nvar banners: Array = []\nfunc show_toast(t):\n\ttoasts.append(str(t))\nfunc show_banner(a, b = \"\", _c = false):\n\tbanners.append(str(a) + \" | \" + str(b))\nfunc show_new_tree(_a, _b):\n\tpass\n"
var stage
var p
var pr
var hud: Node
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func level(tree: String) -> void:
	var m: Dictionary = pr.mastery_of(tree)
	pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))


func last() -> String:
	return str(hud.toasts[-1]) if not hud.toasts.is_empty() else ""


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var s := GDScript.new()
			s.source_code = HUD
			s.reload()
			hud = Node.new()
			hud.set_script(s)
			hud.add_to_group("hud")
			root.add_child(hud)
			level("katana")
			print("   " + last())
			check("katana mastery 2: names what it opens, no points line", last().begins_with("Katana mastery 2") and last().contains("Quick Draw") and not last().contains("point"))
			check("...2 Combat points spendable: the pulse is on", pr.can_spend("combat"))
			pr.buy("k_draw")
			check("spent: the pulse is off", pr.pool("combat") == 0 and not pr.can_spend("combat"))
			level("katana")
			check("katana mastery 3 with the pool spent: no points line", last().begins_with("Katana mastery 3") and not last().contains("point"))
			level("acrobatics")
			print("   " + last())
			check("Acrobatics 2: one short Adventure line", last().begins_with("Acrobatics 2") and last().contains("1 Adventure point (K)"))
			pr.buy("m_geppo")
			check("...spent: the Adventure pulse is off", not pr.can_spend("adventure"))
			pr.add_xp(pr.xp_to_next(pr.level) - pr.xp)
			var b: String = str(hud.banners[-1]) if not hud.banners.is_empty() else ""
			print("   " + b)
			check("Captain 2: the banner says 2 Combat points (K)", b.begins_with("Level 2") and b.contains("2 Combat points (K)"))
			pr.buy("k_deflect")
			level("swim")
			check("Swimming 2 with only an Adventure point: the line is Adventure's", last().contains("1 Adventure point (K)") and not last().contains("Combat"))
			pr.buy("sw_long")
			level("swim")
			check("Swimming 3, one point again: said once more", last().begins_with("Swimming 3") and last().contains("1 Adventure point (K)"))
			pr.buy("sw_long")
			check("everything spent: neither pulse", not pr.can_spend("combat") and not pr.can_spend("adventure"))
			hud.queue_free()
			return TK.done(fails)
	step += 1
	return false
