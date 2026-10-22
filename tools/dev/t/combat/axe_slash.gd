extends SceneTree
## The axe combo's drawn slashes run the way the bit does: hit 1 (axe_hack) from high on the right down
## to low on the left, hit 2 (axe_hook) rising from low on the left to high on the right, hit 3 (axe_split)
## straight down from over the head into the ground ahead; each is laid along the bit in the plain iron
## look while unawakened, and each hit lands on the dummy.
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
	stage = TK.stage(self, {"hud": false, "dummy": true, "weapon": "boarding_axe"})


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


## The ribbon's first and last tip in the captain's frame (x right, y up, -z ahead) and its lowest z.
func _path(r) -> Array:
	var front := INF
	for s in r.local_tips:
		front = minf(front, (s as Vector3).z)
	return [r.local_tips[0], r.local_tips[-1], front]


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
			p.progression.owned.erase("a_elem")
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.2)
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.6)
		1:
			check("the axe is out (%s)" % p.style(), p.style() == "axe" and p.armed)
			hp0 = hc.current_health
			click()
			until = TK.wait_secs(0.5)
		2:
			var r = _ribbon()
			check("hit 1 lays a drawn slash along the bit", p.body_model.current_action() == "axe_hack" and r != null and r.samples.size() >= 4)
			if r:
				var q := _path(r)
				var d: Vector3 = q[1] - q[0]
				print("   hit 1 bit %s -> %s (%s)" % [q[0], q[1], d])
				check("...from high on the right down to low on the left (down %.2f, left %.2f)" % [-d.y, -d.x], d.y < -0.6 and d.x < -0.3 and q[0].x > -0.1)
				check("...through the space in front (%.2f m ahead)" % -q[2], q[2] < -0.5)
				check("...in the axe's plain iron", r.kind == "axe" and not r.awake)
			check("hit 1 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			hp0 = hc.current_health
			click()
			until = TK.wait_secs(0.5)
		3:
			var r = _ribbon()
			check("hit 2 lays its own", p.body_model.current_action() == "axe_hook" and r != null and r.samples.size() >= 4)
			if r:
				var q := _path(r)
				var d: Vector3 = q[1] - q[0]
				print("   hit 2 bit %s -> %s (%s)" % [q[0], q[1], d])
				check("...rising from low on the left to high on the right (right %.2f, up %.2f)" % [d.x, d.y], d.x > 0.5 and d.y > 0.4)
				check("...through the space in front (%.2f m ahead)" % -q[2], q[2] < -0.5)
			check("hit 2 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			hp0 = hc.current_health
			click()
			# (the finisher's hit-stop holds the body, and the slash's window waits for it)
			until = TK.wait_secs(0.85)
		4:
			var r = _ribbon()
			check("hit 3 is the split, its own slash", p.body_model.current_action() == "axe_split" and r != null and r.samples.size() >= 4)
			if r:
				var q := _path(r)
				var d: Vector3 = q[1] - q[0]
				print("   hit 3 bit %s -> %s (%s)" % [q[0], q[1], d])
				check("...straight down from over the head (down %.2f, across %.2f, from %.2f m up)" % [-d.y, d.x, q[0].y], d.y < -1.0 and absf(d.x) < 0.7 and q[0].y > 1.6)
				check("...into the ground ahead (%.2f m ahead, %.2f m up)" % [-q[1].z, q[1].y], q[1].z < -0.6 and q[1].y < 0.6)
			check("hit 3 lands (%.0f -> %.0f)" % [hp0, hc.current_health], hc.current_health < hp0)
			return TK.done(fails)
	step += 1
	return false
