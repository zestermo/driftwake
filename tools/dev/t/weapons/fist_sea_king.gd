extends SceneTree
## Sea King Fist arms the fist (the charge, then the galaxy glow and the timer); left too long it fades and half the
## ult comes back; armed and in the air, attack dives it onto the dummy below; armed, a parried grunt is hit
## point-blank by the counter version.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var grunt
var taken := 0.0
var hp_g := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -8.0),
		"grunts": [{"post": Vector3(6, 0, 4), "yaw": 0.0, "mode": "stand", "seed": 31}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func arm() -> bool:
	p.power.cooldowns.clear()
	p.power.ult = p.power.ULT_MAX
	return p.power.try_cast(4)


func place(at: Vector3) -> void:
	p.global_position = at
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = 0.0


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.progression.owned["u_seaking"] = true
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			grunt = stage.camp.grunts[0] if stage.camp else null
			check("a grunt", grunt != null)
			if grunt == null:
				return TK.done(fails)
			check("Sea King Fist on R", p.power.equip("sea_king_fist", 4))
			until = TK.wait_secs(0.6)
		1:
			check("cast: the charge (%s)" % p.body_model.current_action(), arm())
			until = TK.wait_secs(0.8)
		2:
			check("armed: the timer runs (%.1f s) and the fist glows" % p.fist_armed, p.fist_armed > 6.5 and p.body_model.has_meta("galaxy_fist"))
			check("free to move again (%s)" % p.current_state_name(), p.is_free())
			p.fist_armed = 0.3
			p.power.ult = 0.0
			until = TK.wait_secs(0.5)
		3:
			check("run out: unarmed, half the ult back (%.0f)" % p.power.ult, p.fist_armed <= 0.0 and absf(p.power.ult - p.power.ULT_MAX * 0.5) < 1.0)
			check("...the glow gone", not p.body_model.has_meta("galaxy_fist"))
			arm()
			until = TK.wait_secs(0.8)
		4:
			place(stage.dummy.global_position + Vector3(0, 8.0, 1.2))
			taken = 0.0
			until = TK.wait_ticks(3)
		5:
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		6:
			var tech = p.state_machine.get_node("Technique")
			# the air unleash hands off to the dive (Plunge) within a few ticks
			var st: String = p.current_state_name()
			check("armed in the air, attack lets it go (%s %s)" % [st, tech.id], (st == "Technique" and tech.id == "sea_king_unleash") or st == "Plunge")
			until = TK.wait_secs(1.6)
		7:
			check("the dive's blast lands on the dummy (%.0f)" % taken, taken > 0.0)
			check("...unarmed after", p.fist_armed <= 0.0)
			until = TK.wait_secs(1.0)
		8:
			if not p.is_free():
				return false
			arm()
			until = TK.wait_secs(0.8)
		9:
			var fwd := Vector3(0, 0, -1)
			place(grunt.global_position - fwd * 1.6 + Vector3(0, 0.05, 0))
			hp_g = grunt.health.current_health
			p.state_machine.force_state("Parry", {})
			until = TK.wait_ticks(2)
		10:
			var blow := HitData.new()
			blow.damage = 12.0
			p.hurtbox.take_hit(blow, grunt)
			check("the blow parried (%s)" % p.parried_by, p.parried_by == grunt)
			check("...and the ult key lets it go", p.power.try_cast(4))
			until = TK.wait_ticks(2)
		11:
			var tech = p.state_machine.get_node("Technique")
			check("the counter version (%s)" % str(tech._done.get("counter")), tech.id == "sea_king_unleash" and bool(tech._done.get("counter", false)))
			until = TK.wait_secs(0.8)
		12:
			check("it hits the parried grunt point-blank (%.0f -> %.0f)" % [hp_g, grunt.health.current_health], grunt.health.current_health < hp_g)
			return TK.done(fails)
	step += 1
	return false
