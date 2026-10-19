extends SceneTree
## A rival (a stand-in) challenges us: the prompt, Y accepts, 3-2-1 then Fight!; only the rival's blows land
## (lightened) and only the rival is on our enemies' layer, not a bystander; the rival's bar across the top;
## the rival goes down: Victory and a little XP; 3 s on, our health and energy are what they were before.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rival
var bystander
var duel
var step := 0
var until := 0
var fails := 0
var data := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Rival", "at": Vector3(0, 0, -2)}, {"name": "Bystander", "at": Vector3(3, 0, 0)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hit(dmg: float, by: Node) -> void:
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockback_force = 1.0
	hd.stagger_duration = 0.1
	p.hurtbox.take_hit(hd, by)


func armed(c: Node) -> bool:
	return c.hurtbox.collision_layer & Duel.ENEMY_LAYER != 0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			rival = stage.crew[0]
			bystander = stage.crew[1]
			duel = Duel.inst
			p.health_component.current_health = 80.0
			p.power.energy = 30.0
			p.fought()
			duel._challenge(rival.net_id, 1)
			until = TK.wait_ticks(3)
		1:
			check("the rival's challenge: our prompt (%s)" % duel.hud._ask_text.text, duel.hud.asking() and duel.hud._ask_text.text == "Rival challenges you to a duel")
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_Y
			ev.pressed = true
			duel.hud._input(ev)
			until = TK.wait_ticks(2)
		2:
			var d: Dictionary = duel.duel_of(1)
			check("Y accepts: a duel between us, counting down", not d.is_empty() and int(d["a"]) == rival.net_id and not duel.fighting(d) and not duel.hud.asking())
			check("...3 (%s)" % duel.hud.banner_text(), duel.hud.banner_text() == "3")
			check("...the rival's bar across the top already", stage.hud._boss_box.visible and stage.hud._boss_name.text == "Rival")
			check("...nobody's hittable yet", not armed(rival) and not armed(bystander))
			hit(10.0, rival)
			check("...nor can the rival hurt us yet", p.health_component.current_health == 80.0)
			until = TK.wait_secs(3.05)
		3:
			check("Fight! (%s)" % duel.hud.banner_text(), duel.fighting(duel.duel_of(1)) and duel.hud.banner_text() == "Fight!")
			check("...the rival is on our enemies' layer, the bystander isn't", armed(rival) and not armed(bystander))
			var near: Array = p.power.enemies_in(p.global_position, 6.0)
			check("...our skills find the rival, not the bystander", rival in near and not bystander in near)
			hit(10.0, bystander)
			check("...a bystander's blow does nothing", p.health_component.current_health == 80.0)
			hit(10.0, rival)
			var want: float = 80.0 - 10.0 * Duel.DAMAGE_K * (1.0 - p.damage_reduction())
			check("...the rival's blow lands, lightly (%.1f, want %.1f)" % [p.health_component.current_health, want], absf(p.health_component.current_health - want) < 0.01)
			data["xp"] = [p.progression.level, p.progression.xp]
			# down on their machine: their snapshot says 0
			rival.health_component.current_health = 0.0
			until = TK.wait_ticks(3)
		4:
			var d: Dictionary = duel.duel_of(1)
			check("the rival goes down: we win", not d.is_empty() and int(d["winner"]) == 1)
			check("...Victory (%s)" % duel.hud.banner_text(), duel.hud.banner_text() == "Victory")
			var xp: Array = data["xp"]
			check("...a little XP (+%d, %d of %d to the next level)" % [p.progression.xp - int(xp[1]), duel.xp_for(p), p.progression.get_script().xp_to_next(1)],
				p.progression.level == int(xp[0]) and p.progression.xp - int(xp[1]) == duel.xp_for(p) and duel.xp_for(p) >= Duel.MIN_XP)
			check("...nobody's hittable any more", not armed(rival))
			until = TK.wait_secs(Duel.REVIVE_AFTER + 0.1)
		5:
			check("3 s on: our health and energy as before the duel (%.0f, %.0f)" % [p.health_component.current_health, p.power.energy],
				absf(p.health_component.current_health - 80.0) < 0.5 and absf(p.power.energy - 30.0) < 2.0)
			check("...the bar's gone", not stage.hud._boss_box.visible)
			until = TK.wait_secs(0.6)
		6:
			check("...and the duel's over", duel.state["duels"].is_empty() and duel._mine.is_empty())
			return TK.done(fails)
	step += 1
	return false
