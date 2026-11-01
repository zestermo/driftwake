extends SceneTree
## A rapier in hand: its own stance (no off hand: the free hand fences), the guard holds the point out at the foe; the
## combo's straight thrust and disengage land on the dummy; the third, the phantom double, lands twice (the mirror's
## thrust, then the real one); the right click lunges, a long line that lands from further off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var RA
var hits := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "rapier"})


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
			RA = load("res://scripts/player_states/rapier_arts.gd")
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(_h, _a): hits += 1)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a rapier fights as a rapier (%s)" % p.style(), p.style() == "rapier" and p.body_model.stance == "rapier")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			var b: Basis = p.player_model.global_basis
			var tip: Vector3 = RA.tip(p) - p.global_position
			check("the guard: the point out ahead (%.2f m) at chest height (%.2f m up)" % [tip.dot(-b.z), tip.y], tip.dot(-b.z) > 0.7 and tip.y > 0.9 and tip.y < 1.8)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click: the straight thrust (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_1")
			until = TK.wait_secs(0.3)
		3:
			var b: Basis = p.player_model.global_basis
			var blade: Vector3 = -(p.body_model.weapon.global_basis.z as Vector3).normalized()
			check("at full extension the blade points at them, level (%.2f ahead, %.2f up)" % [blade.dot(-b.z), blade.y], blade.dot(-b.z) > 0.85 and absf(blade.y) < 0.35)
			check("the thrust lands (%d)" % hits, hits >= 1)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		4:
			check("chained: the disengage (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_2")
			until = TK.wait_secs(0.4)
		5:
			check("the disengage lands (%d)" % hits, hits >= 1)
			hits = 0
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.0)
			p.reset_physics_interpolation()
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		6:
			check("then the phantom double (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_3")
			until = TK.wait_secs(0.7)
		7:
			check("the phantom double lands twice: the mirror's thrust and the real one (%d)" % hits, hits >= 2)
			until = TK.wait_secs(1.0)
		8:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 3.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hits = 0
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		9:
			check("right click: the lunge (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rp_heavy")
			until = TK.wait_secs(0.7)
		10:
			check("the lunge lands from 3.6 m off (%d)" % hits, hits >= 1)
			return TK.done(fails)
	step += 1
	return false
