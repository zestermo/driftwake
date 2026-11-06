extends SceneTree
## Beasts' and creatures' blows sound like what struck (2026-11-06): a move's name picks bite, claw or
## slam (CombatManager.beast_impact), each has its takes in FX, and impact_sound passes them through.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
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
	var cm = root.get_node("CombatManager")
	check("a bite bites", cm.beast_impact("bite") == "bite" and cm.beast_impact("jaw_snap") == "bite")
	check("a swipe rakes", cm.beast_impact("swipe") == "claw" and cm.beast_impact("pincer") == "claw")
	check("a tail or a stomp slams", cm.beast_impact("tail_sweep") == "slam" and cm.beast_impact("stomp") == "slam")
	check("a spit is a plain hit", cm.beast_impact("spit") == "")
	for s in ["claw", "bite", "slam"]:
		check("%s has its takes" % s, FileAccess.file_exists("res://assets/audio/%s_1.wav" % s) or ResourceLoader.exists("res://assets/audio/%s_1.wav" % s))
		var hd := HitData.new()
		hd.impact = s
		check("%s plays as itself" % s, cm.impact_sound(hd) == s)
	return TK.done(fails)
