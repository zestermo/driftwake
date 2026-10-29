extends SceneTree
## A hand cannon in hand: its own stance, on the right shoulder with both hands on it (no off hand); a left click braces
## and fires a ball that flies down range and bursts on the dummy, its splash throwing a grunt beside it down too; the
## recoil shoves you back; empty, a long reload; put away it's slung on the back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var hits := 0
var last
var ghit
var from := Vector3.ZERO
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -12.0), "weapon": "hand_cannon",
		"grunts": [{"post": Vector3(1.4, 0, -12.0), "yaw": 0.0, "mode": "stand", "seed": 5}]})


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
			g = stage.camp.grunts[0]
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				last = h)
			g.hurtbox.hit_received.connect(func(h, _a): ghit = h)
			stage.camera_rig.rotation.y = 0.03
			stage.camera_rig.get_node("SpringArm3D").rotation.x = -0.05
			until = TK.wait_secs(0.7)
		1:
			check("a hand cannon fights as a cannon (%s, %s)" % [p.style(), p.body_model.stance], p.style() == "cannon" and p.body_model.stance == "cannon")
			var dirk = ItemDB.get_item("dagger")
			p.inventory_component.add_item(dirk, 1)
			check("two hands on it: nothing goes in the off hand", not p.set_offhand(dirk) and p.offhand_weapon == null)
			check("held on the shoulder by both grips", p.body_model.pole_w > 0.9 and p.body_model.pole_lw > 0.9)
			var c: Vector3 = load("res://scripts/weapons/cannon_arts.gd").muzzle(p)
			check("the barrel over the shoulder, its muzzle out ahead (%.2f up, %.2f ahead)" % [c.y - p.global_position.y, -(c.z - p.global_position.z)],
				c.y - p.global_position.y > 1.3 and -(c.z - p.global_position.z) > 0.5)
			from = p.global_position
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		2:
			check("left click braces it (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Shoot" and p.body_model.current_action() == "cn_fire")
			until = TK.wait_secs(0.4)
		3:
			var shells: Array = get_nodes_in_group("projectiles").filter(func(n): return n.get("kind") == "ball")
			check("a ball in flight (%d)" % shells.size(), shells.size() == 1)
			check("the kick shoved you back (%.2f m)" % (p.global_position.z - from.z), p.global_position.z - from.z > 0.4)
			until = TK.wait_secs(1.0)
		4:
			check("it burst on the dummy 12 m off: staggered, not floored (1.26: plain shots floor only point-blank) (%d)" % hits, hits >= 1 and not last.knockdown and last.breaker and last.ranged)
			check("the splash staggers the grunt beside it", ghit != null and not ghit.knockdown and ghit.breaker)
			check("empty: a long reload (%s, %.1f s)" % [p.body_model.current_action(), p.reload_time()], p.reloading() and p.reload_time() >= 2.0)
			until = TK.wait_secs(2.6)
		5:
			check("loaded again (%d)" % p.ammo[0], p.ammo[0] == 1 and not p.reloading())
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		6:
			var w = p.body_model.weapon
			check("put away, it's slung on the back (%s)" % w.get_parent().name, w.get_parent().name == "BackSocket")
			return TK.done(fails)
	step += 1
	return false
