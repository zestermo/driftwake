extends SceneTree
## A Driftfruit power's forms (1.27, FruitForms): Active to begin with; Reflex at 150 uses of that power once the
## fruit's mastery is 12 (uses alone or mastery alone aren't enough); Nature at 400 uses and mastery 24; each power
## grows by its own use, not another's; what's left is said for the skill map.
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
	var pr = stage.player.progression
	var F = load("res://scripts/progression/fruit_forms.gd")
	check("a fresh power is Active", F.form(pr, "fire_fist", "ember") == 1)
	pr.uses["fire_fist"] = 150
	check("150 uses without the mastery: still Active (%s)" % F.next_step(pr, "fire_fist", "ember"), F.form(pr, "fire_fist", "ember") == 1 and F.next_step(pr, "fire_fist", "ember").contains("mastery 12"))
	pr.mastery["ember"] = {"lv": 12, "xp": 0}
	check("...and mastery 12: Reflex", F.form(pr, "fire_fist", "ember") == 2)
	check("another power of the same fruit doesn't grow with it", F.form(pr, "fire_ring", "ember") == 1)
	pr.uses["fire_fist"] = 400
	check("400 uses at mastery 12: still Reflex", F.form(pr, "fire_fist", "ember") == 2)
	pr.mastery["ember"] = {"lv": 24, "xp": 0}
	check("...and mastery 24: Nature, nothing left", F.form(pr, "fire_fist", "ember") == 3 and F.next_step(pr, "fire_fist", "ember") == "")
	return TK.done(fails)
