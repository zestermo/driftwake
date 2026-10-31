extends SceneTree
## The fruits' fourth powers, part 1 (1.27): Clockwork's Haste makes the crew near you quicker for 8 s; Bubble Bounce
## throws you high and forward; Iron Drop leaps ahead and floors whoever is near where you land.
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
var stage
var step := 0
var until := 0
var fails := 0
var speed0 := 0.0
var top := 0.0
var pos0 := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -6), "role": "sword", "seed": 61}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func ready(p, fruit: String, id: String) -> void:
	p.power.fruit = fruit
	p.power.loadout[0] = id
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()
	p.global_position = Vector3(0, Y, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.player_model.global_basis = Basis.IDENTITY
	p.state_machine.force_state("Idle", {})


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var g = stage.camp.grunts[0]
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			ready(p, "clockwork", "haste")
			speed0 = p.move_speed
			check("Haste casts", p.power.try_cast(0))
			until = TK.wait_ticks(2)
		2:
			check("...you're quicker (%.2f -> %.2f)" % [speed0, p.move_speed], p.power.buff("haste") and p.move_speed > speed0 * 1.2)
			until = TK.wait_secs(8.5)
		3:
			check("...and back to your pace after 8 s (%.2f)" % p.move_speed, is_equal_approx(p.move_speed, speed0))
			ready(p, "bubble", "bubble_bounce")
			top = p.global_position.y
			pos0 = p.global_position
			check("Bubble Bounce casts", p.power.try_cast(0))
			until = TK.wait_ticks(1)
		4:
			top = maxf(top, p.global_position.y)
			if not p.is_on_floor() or top < Y + 1.0:
				if TK.ticking(until + 240):
					return false
			check("...high into the air (%.1f m up)" % (top - Y), top - Y > 4.0)
			check("...and forward (%.1f m)" % (pos0.z - p.global_position.z), pos0.z - p.global_position.z > 3.0)
			until = TK.wait_secs(1.0)
		5:
			ready(p, "iron", "iron_drop")
			g.global_position = Vector3(0, Y, -6)
			g.velocity = Vector3.ZERO
			until = TK.wait_ticks(3)
		6:
			p.state_machine.force_state("Idle", {})
			check("Iron Drop casts", p.power.try_cast(0))
			until = TK.wait_secs(2.5)
		7:
			check("...landed ahead (%.1f m)" % -p.global_position.z, -p.global_position.z > 3.0 and p.is_on_floor())
			check("...and the foe near where you land floored (state %d)" % int(g.state), int(g.state) == int(g.S.DOWN))
			return TK.done(fails)
	step += 1
	return false
