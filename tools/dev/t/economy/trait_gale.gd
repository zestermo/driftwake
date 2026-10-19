extends SceneTree
## A Gale cutlass changes the combo finisher: the first two cuts throw nothing, the finisher throws a wind blade
## (a Projectile) ahead along the captain's facing.
const TK := preload("res://tools/dev/test_kit.gd")
const ID := "cutlass@2+gale"
var stage
var p
var step := 0
var until := 0
var fails := 0
var clicks := 0
var thrown_before := false
var thrown := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": ID, "dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if stage.up and not get_nodes_in_group("projectiles").is_empty():
		if step == 1 and p.body_model.current_action() != "slash_spin":
			thrown_before = true
		else:
			thrown = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			check("a Gale cutlass in hand", p.equipped_weapon and p.equipped_weapon.weapon_trait == "gale" and p.armed)
			until = TK.wait_secs(0.3)
		1:
			if p.body_model.current_action() == "slash_spin":
				until = TK.wait_secs(0.6)
				step = 2
				return false
			clicks += 1
			if clicks > 12:
				check("the combo reached its finisher", false)
				return TK.done(fails)
			TK.act("light_attack")
			until = TK.wait_secs(0.2)
			return false
		2:
			check("the first cuts throw nothing", not thrown_before)
			check("the finisher throws a wind blade", thrown)
			return TK.done(fails)
	step += 1
	return false
