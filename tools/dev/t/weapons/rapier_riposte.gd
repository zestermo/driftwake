extends SceneTree
## A rapier's parry answers at once: a blow caught in the parry plays the riposte (rp_deflect), and a beat later the
## point goes into the attacker, a sure crit through their guard that leaves them reeling. Out of reach, nothing.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var got: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -1.8), "weapon": "rapier"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow() -> void:
	var hd := HitData.new()
	hd.damage = 10.0
	hd.knockback_force = 2.0
	p.hurtbox.take_hit(hd, stage.dummy)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): got.append(h))
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.6)
		1:
			p.state_machine.force_state("Parry", {})
			until = TK.wait_ticks(4)
		2:
			var hp: float = p.health_component.current_health
			blow()
			check("the blow is parried (%.0f -> %.0f)" % [hp, p.health_component.current_health], p.health_component.current_health >= hp)
			until = TK.wait_ticks(3)
		3:
			check("the parry turns into the riposte (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_deflect")
			until = TK.wait_secs(0.35)
		4:
			check("the riposte's thrust lands on the attacker (%d)" % got.size(), got.size() == 1)
			if got.size() > 0:
				var h = got[0]
				check("a sure crit through the guard, reeling them (crit %s, unblockable %s, stagger %.1f)" % [str(h.has_meta("crit")), str(h.unblockable), h.stagger_duration],
					h.has_meta("crit") and h.unblockable and h.stagger_duration >= 0.6)
			until = TK.wait_secs(1.0)
		5:
			if not p.is_free():
				return false
			got.clear()
			stage.dummy.global_position = p.global_position + Vector3(0, 0, -6.0)
			p.state_machine.force_state("Parry", {})
			until = TK.wait_ticks(4)
		6:
			blow()
			until = TK.wait_secs(0.4)
		7:
			check("a blow from out of reach is parried but not answered (%d)" % got.size(), got.is_empty())
			return TK.done(fails)
	step += 1
	return false
