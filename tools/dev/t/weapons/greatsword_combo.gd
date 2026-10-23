extends SceneTree
## A greatsword in hand: its own stance, both hands on the hilt (no off hand) in the low guard, the point down near the
## ground on the left; the combo's rising cut, falling cut (chained straight on: it flows out of the first's
## follow-through with momentum) and flat backhand each land on the dummy; a tapped right click cleaves at once; held,
## it charges to the top and comes down when let go, flinging a crescent of air; put away it's slung on the back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var GA
var hits := 0
var taken := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.3), "weapon": "greatsword"})


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
			GA = load("res://scripts/player_states/greatsword_arts.gd")
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a greatsword fights as a greatsword (%s)" % p.style(), p.style() == "greatsword" and p.body_model.stance == "greatsword")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held at the guard by the grip", p.body_model.pole_w > 0.9 and not p.body_model.weapon.quaternion.is_equal_approx(Quaternion.IDENTITY))
			var b: Basis = p.player_model.global_basis
			var tip: Vector3 = GA.tip(p) - p.global_position
			var hand: Vector3 = p.body_model.hand_r.global_position - p.global_position
			check("low guard: the hands at the hip (%.2f m up), the point near the ground (%.2f m) out right (%.2f) and a little behind (%.2f ahead)"
				% [hand.y, tip.y, tip.dot(b.x), tip.dot(-b.z)], hand.y > 0.6 and hand.y < 1.15 and tip.y < 0.45 and tip.dot(b.x) > 0.5 and tip.dot(-b.z) < 0.1)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click: the rising cut (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_1")
			until = TK.wait_secs(0.5)
		3:
			check("the rising cut lands (%d)" % hits, hits >= 1)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		4:
			var st = p.state_machine.current_state
			check("chained straight on: the falling cut (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_2")
			check("it flows out of the follow-through with momentum (%s)" % str(st.get("_mom")), int(st.get("_mom")) == 1)
			until = TK.wait_secs(0.48)
		5:
			check("the falling cut lands (%d)" % hits, hits >= 1)
			hits = 0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		6:
			check("then the flat backhand, momentum building (%s, %s)" % [p.body_model.current_action(), str(p.state_machine.current_state.get("_mom"))],
				p.body_model.current_action() == "gs_3" and int(p.state_machine.current_state.get("_mom")) == 2)
			until = TK.wait_secs(0.5)
		7:
			check("the backhand lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(1.2)
		8:
			if not p.is_free():
				return false
			hits = 0
			TK.act("heavy_attack")
			until = TK.wait_ticks(8)
		9:
			check("a tapped right click cleaves at once (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_heavy")
			until = TK.wait_secs(0.5)
		10:
			check("the cleave lands (%d)" % hits, hits >= 1)
			until = TK.wait_secs(1.0)
		11:
			if not p.is_free():
				return false
			TK.press("heavy_attack")
			until = TK.wait_secs(1.15)
		12:
			var st = p.state_machine.current_state
			check("held, it's raised and charging to the top (%s, %s, level %s)" % [p.current_state_name(), p.body_model.current_action(), str(st.get("_level"))],
				p.current_state_name() == "HeavyAttack" and p.body_model.current_action() == "gs_charge" and int(st.get("_level")) == 2)
			hits = 0
			TK.release("heavy_attack")
			until = TK.wait_ticks(6)
		13:
			check("let go, it comes down (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gs_heavy")
			until = TK.wait_secs(0.3)
		14:
			check("the full cleave lands (%d)" % hits, hits >= 1)
			check("and flings a crescent of air down the line", get_nodes_in_group("projectiles").any(func(n): return n.get("kind") == "gale"))
			until = TK.wait_secs(1.2)
		15:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		16:
			var w = p.body_model.weapon
			check("put away, it's slung on the back (%s)" % w.get_parent().name, w.get_parent().name == "BackSocket")
			check("the grip let go with it", p.body_model.pole_w < 0.01)
			return TK.done(fails)
	step += 1
	return false
