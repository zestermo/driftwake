extends SceneTree
## Vine's Vine Snare by its form (1.27, FruitForms, Player.vine_snare_reflex): Active, being hit snares nobody; Reflex
## (150 uses, mastery 12), whoever hits you is snared, at most once every 6 s; another fruit's captain never.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var pr = p.progression
	p.power.fruit = "vine"
	check("Active: being hit snares nobody", not p.vine_snare_reflex(stage.dummy))
	pr.uses["vine_snare"] = 150
	pr.mastery["vine"] = {"lv": 12, "xp": 0}
	check("Reflex: whoever hits you is snared", p.vine_snare_reflex(stage.dummy))
	check("...not twice in 6 s", not p.vine_snare_reflex(stage.dummy))
	p.power.fruit = "ember"
	p._snare_reflex_at = -1000000
	check("another fruit's captain: never", not p.vine_snare_reflex(stage.dummy))
	return TK.done(fails)
