extends SceneTree
## The Wolf's Rending Fang by its form (1.27, FruitForms, PowerComponent._wounds): claws in hybrid form: Active, a plain
## claw doesn't bleed; Reflex (150 uses, mastery 12), a crit bleeds and a plain one doesn't; Nature (400, 24), every claw
## bleeds; out of hybrid form, no bleed from the fruit.
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


func _claw(crit: bool) -> bool:
	var d = stage.dummy
	for c in d.get_children():
		if str(c.name).begins_with("Bleed"):
			c.free()
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 10.0
	if crit:
		hd.set_meta("crit", true)
	stage.player.power._wounds(d, hd, stage.player.style())
	return d.get_node_or_null("Bleed") != null


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var pr = p.progression
	p.power.fruit = "wolf"
	p.hybrid = true
	check("Active: a plain claw doesn't bleed", not _claw(false) and not _claw(true))
	pr.uses["rending_fang"] = 150
	pr.mastery["wolf"] = {"lv": 12, "xp": 0}
	check("Reflex: a crit bleeds, a plain claw doesn't", _claw(true) and not _claw(false))
	pr.uses["rending_fang"] = 400
	pr.mastery["wolf"] = {"lv": 24, "xp": 0}
	check("Nature: every claw bleeds", _claw(false))
	p.hybrid = false
	check("out of hybrid form: no bleed from the fruit", not _claw(false))
	return TK.done(fails)
