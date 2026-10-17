extends SceneTree
## The katana combo's drawn slashes run the way the blade does: hit 1 (katana_r) from high on the
## right down to low on the left, hit 2 (katana_l) level from left to right across the front, hit 3
## (katana_stab) a thrust along the blade pointing at the target; each hit lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hp0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": true, "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## The newest drawn slash on the captain, or null.
func _ribbon():
	var last = null
	for c in p.body_model.get_children():
		var sc = c.get_script()
		if sc and str(sc.resource_path).ends_with("petal_ribbon.gd") and not c.is_queued_for_deletion():
			last = c
	return last


## The ribbon's samples in the captain's frame (x right, y up, -z ahead): [first tip, last tip,
## last blade direction, lowest z].
func _path(r) -> Array:
	var inv: Basis = p.body_model.global_basis.orthonormalized().inverse()
	var dir: Vector3 = (inv * ((r.samples[-1][1] as Vector3) - (r.samples[-1][0] as Vector3))).normalized()
	var front := INF
	for s in r.local_tips:
		front = minf(front, (s as Vector3).z)
	return [r.local_tips[0], r.local_tips[-1], dir, front]


func click() -> void:
	p.stamina = p.max_stamina
	TK.act("light_attack")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hc = stage.dummy.get_node("HealthComponent")
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.4)
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.6)
		1:
			check("the katana is out (%s)" % p.style(), p.style() == "katana" and p.armed)
			hp0 = hc.current_health
			click()
			until = TK.wait_secs(0.6)
		2:
			var r = _ribbon()
			check("hit 1 lays a drawn slash along the blade", p.body_model.current_action() == "katana_r" and r != null and r.samples.size() >= 4)
			if r:
				var q := _path(r)
				var d: Vector3 = q[1] - q[0]
				print("   hit 1 tip %s -> %s (%s)" % [q[0], q[1], d])
				check("...from high on the right down to low on the left (down %.2f, left %.2f)" % [-d.y, -d.x], d.y < -0.6 and d.x < -0.3 and q[0].x > -0.1)
				check("...through the space in front (%.2f m ahead)" % -q[3], q[3] < -0.5)
				check("...not the old fixed arc (plain steel while unawakened)", not r.awake and not r.thrust)
			check("hit 1 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			hp0 = hc.current_health
			click()
			until = TK.wait_secs(0.56)
		3:
			var r = _ribbon()
			check("hit 2 lays its own", p.body_model.current_action() == "katana_l" and r != null and r.samples.size() >= 4)
			if r:
				var q := _path(r)
				var d: Vector3 = q[1] - q[0]
				print("   hit 2 tip %s -> %s (%s)" % [q[0], q[1], d])
				check("...level across from left to right (right %.2f, height change %.2f)" % [d.x, d.y], d.x > 0.8 and absf(d.y) < 0.4)
				check("...through the space in front (%.2f m ahead)" % -q[3], q[3] < -0.6)
			check("hit 2 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			hp0 = hc.current_health
			# (back off for the stab: its lunge runs ~2.5 m and slides past a dummy that doesn't give)
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 3.0)
			p.reset_physics_interpolation()
			click()
			until = TK.wait_secs(0.55)
		4:
			var r = _ribbon()
			print("   now %s / %s, %.2f m from the dummy, ribbon %s" % [p.current_state_name(), p.body_model.current_action(),
				p.global_position.distance_to(stage.dummy.global_position), str(r.thrust) if r else "none"])
			check("hit 3 is the stab, a thrust along the blade", p.body_model.current_action() == "katana_stab" and r != null and r.thrust)
			if r:
				var q := _path(r)
				print("   hit 3 blade %s" % q[2])
				check("...pointing at the target (%.2f ahead)" % -q[2].z, q[2].z < -0.85)
			check("hit 3 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
