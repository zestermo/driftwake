extends SceneTree
## Trees show once their first point is earned: a new captain sees the Captain and the Cutlass; the first katana
## xp finds the Katana tree (tree_found once, a "new skill tree" banner on the HUD), never twice; a save keeps
## what's found.
const TK := preload("res://tools/dev/test_kit.gd")
const SAVE := "user://t_tree_found.dat"
var stage
var p
var pr
var heard: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			pr.tree_found.connect(func(t): heard.append(t))
			check("a new captain sees the Captain (%s)" % str(pr.visible_trees("captain")), pr.visible_trees("captain") == ["captain"])
			check("...and the Cutlass in Combat (%s)" % str(pr.visible_trees("combat")), pr.visible_trees("combat") == ["sword"])
			check("...no Adventure trees and no fruit yet", pr.visible_trees("adventure").is_empty() and pr.visible_trees("fruit").is_empty())
			pr.on_hit()
			check("the first katana hit finds the Katana tree (%s)" % str(heard), heard == ["katana"] and "katana" in pr.visible_trees("combat"))
			pr.on_hit()
			check("...once", heard == ["katana"])
			until = TK.wait_ticks(80)
		1:
			check("...with a banner (%s)" % stage.hud.banner_title.text, stage.hud.banner_title.text == "New skill tree!" and stage.hud.banner_sub.text.contains("Katana"))
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file(SAVE)
			SG.save(p)
			pr.from_dict({})
			check("a fresh block forgets it", not ("katana" in pr.visible_trees("combat")))
			check("load", SG.load_into(p))
			check("...a save keeps it", "katana" in pr.visible_trees("combat"))
			SG.use_test_file("")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
			return TK.done(fails)
	step += 1
	return false
