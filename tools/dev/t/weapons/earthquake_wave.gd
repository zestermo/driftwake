extends SceneTree
## The hammer's Earthquake (HeavyAttack "quake"): its shockwave, 0.04 s after the blow, strikes a grunt behind you the
## blow never reached, through its Hurtbox (take_hit, where Net.route_hit sends a guest's hit to the host) with the
## captain as the attacker, knocking it down and breaking its wind-up, and doesn't strike the blow's own target again;
## the wave's HitData comes through the wire whole.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var front: Array = []
var back: Array = []
var by: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "warhammer",
		"grunts": [{"post": Vector3(0, 0, 1.2), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


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
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			stage.camera_rig.rotation.y = 0.0
			g = stage.camp.grunts[0]
			g.health.max_health = 9999.0
			g.health.current_health = 9999.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): front.append(h))
			g.hurtbox.hit_received.connect(func(h, a):
				back.append(h)
				by.append(a))
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			g._enter_idle()
			p.stamina = p.max_stamina
			p.state_machine.force_state("HeavyAttack", {})
			until = TK.wait_secs(1.2)
		2:
			check("the blow lands on the one in front, once (%d)" % front.size(), front.size() == 1)
			check("the shockwave strikes the grunt behind (%d)" % back.size(), back.size() == 1)
			if back.size() == 1:
				var w: HitData = back[0]
				check("knocked down, wind-up broken", w.knockdown and w.breaker)
				check("struck by the captain (the host knocks it back from the guest's puppet)", by[0] == p)
				var net = root.get_node("Net")
				var r: HitData = net.hit_unpack(net.hit_pack(w))
				check("the wave's hit comes through the wire whole", r.knockdown and r.breaker and is_equal_approx(r.damage, w.damage)
					and is_equal_approx(r.knockback_force, w.knockback_force))
			return TK.done(fails)
	step += 1
	return false
