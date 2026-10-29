extends SceneTree
## Infuse in the kicking stance (1.26, docs/v1_26_plan.md: "the Edy infuse adds the effect to the hands and arms, rather
## than feet and lower legs"): the aura's "legs" part puts its flames on the shins (none on the hands), Infuse picks it
## when the captain's style is black leg, and the black-steel Coat leaves the arms alone in that stance.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _cards(n: Node, name_prefix: String) -> int:
	return n.find_children(name_prefix + "*", "MeshInstance3D", true, false).size()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var body = p.body_model
	match step:
		0:
			p.progression.will_color = "storm"
			p.kicks = true
			p.equipped_weapon = null
			check("bare-footed with kicks learned: the black-leg style (%s)" % p.style(), p.style() == "black_leg")
			load("res://scripts/progression/edy_types.gd").aura(p, "legs" if p.style() == "black_leg" else "arms", 5.0)
			until = TK.wait_ticks(3)
		1:
			var feet: int = _cards(body.shin_r, "EdyFoot") + _cards(body.shin_l, "EdyFoot")
			var hands: int = _cards(body.hand_r, "EdyHand") + _cards(body.hand_l, "EdyHand")
			check("Infuse's flames on both legs (%d)" % feet, feet == 2)
			check("...none on the hands (%d)" % hands, hands == 0)
			p.power.add_buff("coat", 5.0)
			p.update_coat_visual()
			var ab = body.torso.get_node_or_null("ArmBody")
			check("the Coat leaves the kicker's arms their own colour", ab == null or (ab.arm_mesh(true).material_override == null and ab.arm_mesh(false).material_override == null))
			return TK.done(fails)
	step += 1
	return false
