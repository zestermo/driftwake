extends SceneTree
## A fighting staff in hand (1.28): its own stance, two-handed, held near its middle (both hands on the shaft, the
## shaft slid StaffMoves.SHIFT through the right); the combo's overhead blow lands and shoves them back, the second
## (the rear end up through them) is a launcher, the sweep lands; the right click is the Cyclone: two turns that strike
## all round, so it lands from behind too.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var last_hit: HitData
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "staff"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				last_hit = h)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a staff fights as a staff (%s / %s)" % [p.style(), p.body_model.stance], p.style() == "staff" and p.body_model.stance == "staff")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two-handed: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held near its middle (shift %.2f)" % p.body_model.pole_shift_cur, p.body_model.pole_shift_cur > 0.4)
			check("both hands on it", p.body_model.pole_lw > 0.9)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click: the overhead blow (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_1")
			until = TK.wait_secs(0.35)
		3:
			check("it lands (%d) and shoves them back (%.1f)" % [hits, last_hit.knockback_force if last_hit else 0.0], hits >= 1 and last_hit != null and last_hit.knockback_force >= 4.0)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		4:
			check("chained: the rising butt-end (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_2")
			until = TK.wait_secs(0.4)
		5:
			check("it lands as a launcher (%d, launch %.1f)" % [hits, last_hit.launch if last_hit else 0.0], hits >= 1 and last_hit != null and last_hit.launch > 0.0)
			hits = 0
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.0)
			p.reset_physics_interpolation()
			TK.act("light_attack")
			until = TK.wait_secs(0.2)
		6:
			# (buffered until the rising blow's chain point)
			check("then the flat sweep (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_3")
			until = TK.wait_secs(0.4)
		7:
			check("the sweep lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(1.0)
		8:
			if not p.is_free():
				return false
			# the dummy behind: the Cyclone turns all the way round
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, -2.2)
			p.player_model.rotation.y = 0.0
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hits = 0
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		9:
			check("right click: the Cyclone (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sf_heavy")
			until = TK.wait_secs(1.2)
		10:
			check("it strikes all round: the one behind is hit (%d)" % hits, hits >= 1)
			return TK.done(fails)
	step += 1
	return false
