extends SceneTree
## A warhammer in hand: its own stance, both hands on the haft (no off hand) and the head resting on the shoulder;
## the light combo's smash, upswing and flat swing and the heavy (Earthquake) each land on the dummy; put away
## it's slung on the back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var HA
var hp := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.2), "weapon": "warhammer"})


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
			hc = stage.dummy.get_node("HealthComponent")
			HA = load("res://scripts/player_states/hammer_arts.gd")
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			check("a warhammer fights as a hammer (%s)" % p.style(), p.style() == "hammer" and p.body_model.stance == "hammer")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held at the guard by the grip", p.body_model.pole_w > 0.9 and not p.body_model.weapon.quaternion.is_equal_approx(Quaternion.IDENTITY))
			var head: Vector3 = HA.head(p) - p.global_position
			var back: float = head.dot(p.player_model.global_basis.z)
			check("the head rests up on the shoulder (%.2f m up, %.2f m back)" % [head.y, back], head.y > 1.35 and back > -0.1)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		2:
			check("left click smashes (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_smash")
			until = TK.wait_secs(0.5)
		3:
			check("the smash lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		4:
			check("it chains into the upswing (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_upper")
			until = TK.wait_secs(0.45)
		5:
			check("the upswing lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			hp = hc.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		6:
			check("then the flat swing (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_sweep")
			until = TK.wait_secs(0.55)
		7:
			check("the flat swing lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			until = TK.wait_secs(1.2)
		8:
			if not p.is_free():
				return false
			hp = hc.current_health
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		9:
			check("right click: the Earthquake (%s)" % p.body_model.current_action(), p.body_model.current_action() == "ham_heavy")
			until = TK.wait_secs(0.75)
		10:
			check("the heavy lands (%.0f -> %.0f)" % [hp, hc.current_health], hc.current_health < hp)
			until = TK.wait_secs(0.9)
		11:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		12:
			var w = p.body_model.weapon
			check("put away, it's slung on the back (%s)" % w.get_parent().name, w.get_parent().name == "BackSocket")
			var head: Vector3 = HA.head(p) - p.global_position
			check("its head up behind the shoulder (%.2f m up)" % head.y, head.y > 1.3)
			check("the grip let go with it", p.body_model.pole_w < 0.01)
			return TK.done(fails)
	step += 1
	return false
