extends SceneTree
## Infuse and Reinforce (1.24.1, Iron Will; EdyAura): Infuse (was Coat) puts the Edy aura on the arms (rim shells and a
## flame off each hand) for its length; Reinforce (was the Hardening passive) is a skill: for 15 s +10% speed, a quarter
## less stamina, +8 defense and no flinch from light blows, the aura over the whole body with its ground disc; the disc
## stays on the ground and fades when the feet leave it; the start shoves a foe back; an old save's Hardening is Reinforce.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var step := 0
var until := 0
var fails := 0
var walk0 := 0.0
var def0 := 0.0
var g0 := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -7.0), "yaw": PI, "mode": "stand", "seed": 11}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cast(id: String) -> void:
	p.power.energy = 999.0
	p.power.set("_cd", {})
	p.state_machine.force_state("Skill", {"slot": 0, "id": id})


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			# (placed now: the shove's physics query needs the foe's hurtbox where it stands)
			g.global_position = p.global_position + Vector3(0, 0, -2.0)
			g.reset_physics_interpolation()
			pr.gift("will", 12)
			pr.attune("ember")
			# (1.26: the Edy tree) Infuse and Reinforce, the first two of Iron Will
			EdyTree.learn_path(pr, "e_iron_1")
			EdyTree.learn_path(pr, "e_iron_2")
			check("Reinforce (tier 1, 1 Edy) bought: its skill known", pr.knows("edy_reinforce") and pr.knows("armament_coat"))
			check("...no Hardening passive any more", not pr.is_passive("h_harden"))
			cast("armament_coat")
			until = TK.wait_ticks(20)
		1:
			var a = p.body_model.get_node_or_null("EdyAura")
			check("Infuse: the Edy aura on the arms", a != null and a.part == "arms")
			check("...shells on the arm meshes and a flame off each hand", a != null and a._shells.size() >= 2 and p.body_model.find_children("EdyHand", "", true, false).size() == 2)
			check("...no ground disc for Infuse", p.body_model.find_children("EdyGround", "", true, false).is_empty())
			p.power.buffs.erase("coat")
			if a:
				a.free()
			walk0 = p.move_speed
			def0 = p.defense()
			g0 = g.global_position
			cast("edy_reinforce")
			until = TK.wait_ticks(20)
		2:
			check("Reinforce: its buff", p.power.buff("reinforce"))
			check("...10%% quicker (%.2f -> %.2f)" % [walk0, p.move_speed], is_equal_approx(p.move_speed, walk0 * 1.1))
			check("...a quarter less stamina", is_equal_approx(p.stamina_k(), 0.75))
			check("...+8 defense (%.1f -> %.1f)" % [def0, p.defense()], is_equal_approx(p.defense(), def0 + 8.0))
			check("...the foe beside you shoved back (%.1f m)" % g.global_position.distance_to(g0), g.global_position.distance_to(p.global_position) > 2.3)
			var a = p.body_model.get_node_or_null("EdyAura")
			check("...the aura on the whole body with its flame card and ground disc", a != null and a.part == "reinforce" and a._disc != null and p.body_model.find_children("EdyFlame", "", true, false).size() == 1)
			var h := HitData.new()
			h.damage = 1.0
			h.stagger_duration = 0.3
			p.hurtbox.take_hit(h, g)
			until = TK.wait_ticks(2)
		3:
			check("a light blow doesn't rock you (%s)" % p.current_state_name(), p.current_state_name() != "Stagger")
			var a = p.body_model.get_node_or_null("EdyAura")
			check("...and the aura flares", a != null and a._flash > 0.5)
			until = TK.wait_ticks(40)
		4:
			if not p.is_free():
				return false
			g0 = p.body_model.get_node("EdyAura")._disc.global_position
			TK.act("jump")
			until = TK.wait_ticks(14)
		5:
			var a = p.body_model.get_node_or_null("EdyAura")
			check("off the ground: the disc stays where you stood (%.2f m off) and fades (%.2f)" % [a._disc.global_position.distance_to(g0), a._ground_k],
				a._disc.global_position.distance_to(g0) < 0.05 and a._ground_k < 0.9)
			var d: Dictionary = pr.to_dict()
			var earned: int = pr.will_earned
			d["bought"] = (d["bought"] as Array) + ["h_harden", "w_coat_heavy"]
			d["passives"] = ["h_harden", "", ""]
			pr.from_dict(d)
			check("(1.26) an old save's Will purchases are gone, their Edy back to spend on the tree, the passive slot empty", not pr.owns("h_harden") and not pr.owns("w_coat_heavy") and not pr.passives.has("h_harden") and pr.will_earned == earned)
			return TK.done(fails)
	step += 1
	return false
