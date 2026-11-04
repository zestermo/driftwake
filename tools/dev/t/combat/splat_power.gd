extends SceneTree
## (1.30, round 5) A splat's power by overkill: a kill just past the line is a mellow throw of a metre or two; three
## times the line or more flies fast and far; a foe in the big one's path is knocked down, one grazed takes a knock.
## The same curve for captains (Splat.flat_power).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var SP
var mellow
var big
var behind
var graze
var start_m := Vector3.ZERO
var start_b := Vector3.ZERO
var graze_hp := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(-8.0, 0, 0.0), "role": "sword", "seed": 41},
		{"post": Vector3(6.0, 0, 2.0), "role": "sword", "seed": 42},
		{"post": Vector3(6.0, 0, -2.0), "role": "sword", "seed": 43},
		{"post": Vector3(7.1, 0, -0.6), "role": "sword", "seed": 44}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(dmg: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = 6.0
	h.knockback_force = 5.0
	h.impact = "punch"
	return h


func strike(g, h: HitData, from: Vector3) -> void:
	var to: Vector3 = g.global_position - from
	g.facing.rotation.y = atan2(-to.x, -to.z)
	var src := Node3D.new()
	stage.add_child(src)
	src.global_position = from
	g._on_hit(h, src)
	src.queue_free()


func splat_of(g):
	var r = g.humanoid.ragdoll
	return r.get_node_or_null("Splat") if r else null


func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 4:
				return false
			SP = load("res://scripts/combat/splat.gd")
			mellow = stage.camp.grunts[0]
			big = stage.camp.grunts[1]
			behind = stage.camp.grunts[2]
			graze = stage.camp.grunts[3]
			for g in stage.camp.grunts:
				TK.calm(g)
			check("the curve: 0 at the line, 0.5 at twice it, 1 at three times, -1 short", is_equal_approx(SP.power_of(10.0, 10.0), 0.0)
				and is_equal_approx(SP.power_of(20.0, 10.0), 0.5) and is_equal_approx(SP.power_of(40.0, 10.0), 1.0) and SP.power_of(9.0, 10.0) < 0.0)
			var cap := HitData.new()
			cap.damage = 31.0
			cap.knockdown = true
			check("a captain just over the 30%% line: mellow (%.2f); at 90%%: full (%.2f)" % [SP.flat_power(cap, 31.0, 100.0, mellow), SP.flat_power(cap, 90.0, 100.0, mellow)],
				SP.flat_power(cap, 31.0, 100.0, mellow) < 0.05 and is_equal_approx(SP.flat_power(cap, 90.0, 100.0, mellow), 1.0))
			until = TK.wait_ticks(5)
		1:
			start_m = mellow.humanoid.hips.global_position
			start_b = big.humanoid.hips.global_position
			graze_hp = graze.health.current_health
			mellow.health.current_health = 5.0
			strike(mellow, blow(5.0 + mellow.health.max_health * 0.52), mellow.global_position + Vector3(0, 0, 2))
			strike(big, blow(5000.0), big.global_position + Vector3(0, 0, 2))
			var sm = splat_of(mellow)
			var sb = splat_of(big)
			check("just past the line: thrown, mellow (power %.2f, %.1f m/s)" % [sm.power if sm else -1.0, sm._speed if sm else 0.0],
				sm != null and sm.power < 0.05 and sm._speed < 7.0)
			check("far past it: full power (%.2f, %.1f m/s)" % [sb.power if sb else -1.0, sb._speed if sb else 0.0],
				sb != null and is_equal_approx(sb.power, 1.0) and is_equal_approx(sb._speed, SP.SPEED_MAX))
			until = TK.wait_secs(0.9)
		2:
			check("the foe in its path is knocked down (%s; it at %s, the throw from %s)" % [behind.S.keys()[behind.state], behind.global_position, start_b],
				behind.state == behind.S.DOWN)
			check("...and took a little damage (%.0f of %.0f)" % [behind.health.current_health, behind.health.max_health],
				behind.health.current_health < behind.health.max_health and behind.health.current_health > behind.health.max_health * 0.5)
			check("one it grazed took a knock (%.1f -> %.1f), not floored (%s)" % [graze_hp, graze.health.current_health, graze.S.keys()[graze.state]],
				graze.health.current_health < graze_hp and graze.state != graze.S.DOWN)
			until = TK.wait_secs(1.2)
		3:
			var dm := flat(mellow.humanoid.hips.global_position, start_m)
			var db := flat(big.humanoid.hips.global_position, start_b)
			check("the mellow one went a metre or two (%.1f m)" % dm, dm > 0.5 and dm < 2.6)
			check("the big one went far (%.1f m)" % db, db > 4.5)
			return TK.done(fails)
	step += 1
	return false
