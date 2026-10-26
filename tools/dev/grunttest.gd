extends SceneTree
## Pirate grunts: camp, alert, attack turns, guard/guard break, hitstun, parry stagger, knockdown, death, return home.
const IDLE := 0; const ALERT := 1; const CHASE := 2; const CIRCLE := 3; const CLOSE := 4; const WIND := 5; const SWING := 6
const RECOVER := 7; const BLOCK := 8; const STAGGER := 9; const HITSTUN := 10; const DOWN := 11; const GETUP := 12; const RETURN := 13; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var until := 0
const TK = preload("res://tools/dev/test_kit.gd")
var p
var camp
var fails := 0
var seen := {}
var max_att := 0
var hp0 := 0.0
var g
var t0 := 0.0
func _initialize(): TK.seed_of(self); change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func light() -> HitData:
	var h := HitData.new(); h.damage = 12.0; h.knockback_force = 4.5; h.stagger_duration = 0.3; return h
var _circ_since := -1.0
## A circling grunt for the hit-reaction steps. Whether one is circling right
## now is down to AI timing and where the fight drifted (a knock into the sea,
## everyone mid-attack), so after 10 s without one: log why, and set one circling.
func circling() -> Node:
	for x in camp.grunts:
		if is_instance_valid(x) and x.state == CIRCLE:
			_circ_since = -1.0
			return x
	if _circ_since < 0.0:
		_circ_since = t
	if t - _circ_since < 10.0:
		return null
	var states := []
	for x in camp.grunts:
		states.append(x.state if is_instance_valid(x) else -1)
	print("   (no grunt circling for 10 s: states %s, player %s; setting one circling)" % [str(states), p.current_state_name()])
	_circ_since = -1.0
	for x in camp.grunts:
		if is_instance_valid(x) and x.state != DEAD and x.state != DOWN:
			x.global_position = p.global_position - p.player_model.global_basis.z * 2.5
			x.reset_physics_interpolation()
			x._set_state(CIRCLE)
			return x
	return null
var dashed := false
var feint := {}
var kinds := {}
func _up() -> void:
	if p.current_state_name() == "Downed":
		p.body_model.end_ragdoll()
		p.body_model.reset_pose()
	p.state_machine.force_state("Idle", {})
	p.hurtbox.monitorable = true
## The captain on dry land at the sentry's post, `x` circling `d` m in front (into the camp).
func _face_off(x, d: float) -> void:
	_up()
	var s = camp.grunts[2]
	var f := Vector3(-sin(s.post_yaw), 0.0, -cos(s.post_yaw))
	p.global_position = s.post + f * 0.6 + Vector3.UP * 0.3
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.player_model.rotation.y = s.post_yaw
	x.health.heal(999.0)
	x.global_position = s.post + f * (0.6 + d) + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
	x._set_state(CIRCLE)
## The captain starts a heavy with `x` circling 2.6 m in front, its dash ready.
func _heavy_at(x) -> void:
	_face_off(x, 2.6)
	p.state_machine.force_state("HeavyAttack", {})
	p.player_model.rotation.y = camp.grunts[2].post_yaw
	x._cooldown = 5.0
	x._dash_cd = 0.0
	x._dodge_chance = 1.0
	x._threat = ""
	dashed = false
func _process(d: float) -> bool:
	t += d
	if g and is_instance_valid(g) and g.state == 21: dashed = true
	if camp and step >= 2 and step <= 3:
		for x in camp.grunts:
			if is_instance_valid(x) and x.state == WIND: kinds[x._attack] = true
	if camp and step >= 2 and step <= 3:
		var att := 0
		for x in camp.grunts:
			if is_instance_valid(x):
				seen[x.state] = true
				if x.state in [WIND, SWING, CLOSE]: att += 1
		max_att = maxi(max_att, att)
	# (waits are game time, in physics ticks: under load frames run fewer ticks than seconds pass)
	if wait > 0.0:
		until = TK.wait_secs(wait)
		wait = 0.0
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			check("camp with 5 grunts", camp.alive_count() == 5)
			var sitting := 0
			for x in camp.grunts:
				if x.humanoid.seated: sitting += 1
			check("two sitting by the fire", sitting == 2)
			check("all idle", camp.grunts.all(func(x): return x.state == IDLE))
			# walk up to the sentry, in front of it
			var guard = camp.grunts[2]
			var fwd: Vector3 = guard._fwd()
			p.global_position = guard.global_position + fwd * 8.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			wait = 1.5
		1:
			check("sentry spots you", camp.grunts[2].state != IDLE)
			var alerted := 0
			for x in camp.grunts:
				if x.state != IDLE: alerted += 1
			print("   alerted ", alerted)
			check("alarm spreads to the crew", alerted >= 4)
			wait = 12.0
		2:
			print("   states seen ", seen.keys(), " max attacking at once ", max_att)
			check("circle and strafe", seen.has(CIRCLE))
			check("wind-up tell before swinging", seen.has(WIND) and seen.has(SWING))
			check("recover (punish window)", seen.has(RECOVER))
			print("   attacks seen ", kinds.keys())
			check("the crew mixes its attacks", kinds.size() >= 2)
			check("at most 2 attack at once", max_att <= 2)
			print("   player state ", p.current_state_name())
			print("   player hp lost ", snappedf(hp0 - p.health_component.current_health, 1))
			check("they land hits", p.health_component.current_health < hp0)
			var reg = root.get_node_or_null("World/Islands/Brinehollow/NavRegion")
			var nm = reg.navigation_mesh if reg else null
			print("   Brinehollow navmesh polygons ", nm.get_polygon_count() if nm else -1)
			check("Brinehollow navmesh baked", nm != null and nm.get_polygon_count() > 100)
			var map: RID = p.get_world_3d().navigation_map
			var g1 = camp.grunts[0]
			var path := NavigationServer3D.map_get_path(map, g1.post, g1.post + Vector3(30, 0, 0), true)
			print("   path from a post 30 m east: %d points, ends %.1f m off" % [path.size(), path[path.size() - 1].distance_to(g1.post + Vector3(30, 0, 0)) if path.size() > 0 else -1.0])
			check("grunts get navmesh paths", path.size() >= 2)
			# a hit can knock the player off the beach into the sea, where the crew
			# won't follow (no one circles and step 4 waits forever): back on land
			if p.current_state_name() == "Swim":
				var g0 = camp.grunts[0]
				p.global_position = g0.global_position + g0._fwd() * 4.0 + Vector3.UP * 0.5
				p.reset_physics_interpolation()
				p.state_machine.force_state("Idle")
			step = 4
			return false
		4:
			g = circling()
			if g == null: return false
			# park the player 1.8 m in front of it and hit it from the front
			p.global_position = g.global_position + g._fwd() * 1.8
			p.reset_physics_interpolation()
			var hp: float = g.health.current_health
			# (1.23: a sword grunt blocks about a quarter of the front blows, never two running, so hit until one does)
			var blocked := false
			var tries := 0
			while tries < 40 and not blocked:
				tries += 1
				g._blocked_last = false
				g._set_state(CIRCLE)
				g.poise = Poise.make(g._poise_class())
				g.hurtbox.take_hit(light(), p)
				if g.state == BLOCK and is_equal_approx(g.health.current_health, hp):
					blocked = true
				else:
					g.health.current_health = hp
			check("a front light hit is sometimes blocked (%d tries)" % tries, blocked)
			# (and no guard breaks any more: a run of front blows wears its poise down)
			g._set_state(CIRCLE)
			g.poise = Poise.make(g._poise_class())
			var hits := 0
			while hits < 12 and g.state != STAGGER and g.state != DOWN:
				g._riposte = false
				g.hurtbox.take_hit(light(), p)
				hits += 1
			print("   after %d front hits: state %d hp %.0f" % [hits, g.state, g.health.current_health])
			check("a run of front hits breaks its poise: staggered or down, and damaged", (g.state == STAGGER or g.state == DOWN) and g.health.current_health < hp)
			wait = 2.0
		5:
			g = circling()
			if g == null: wait = 0.3; return false
			p.global_position = g.global_position - g._fwd() * 1.5
			var hp: float = g.health.current_health
			g.hurtbox.take_hit(light(), p)
			check("hit from behind lands (hitstun)", g.state == HITSTUN and g.health.current_health < hp)
			wait = 0.6
		6:
			g = circling()
			if g == null: wait = 0.3; return false
			g.parried(p)
			check("parried -> staggered", g.state == STAGGER)
			wait = 2.0
		7:
			g = circling()
			if g == null: wait = 0.3; return false
			var h := light(); h.damage = 30.0; h.knockdown = true; h.knockback_force = 10.0
			g.hurtbox.take_hit(h, p)
			check("heavy hit -> knocked down (ragdoll)", g.state == DOWN and g.humanoid.ragdoll != null)
			t0 = t
			step += 1
			return false
		8:
			if g.state != DOWN and g.state != GETUP or t - t0 > 8.0:
				print("   after knockdown: state ", g.state, " t ", snappedf(t - t0, 0.1))
				check("gets back up and fights on", g.state in [CIRCLE, CHASE, CLOSE, WIND, SWING, BLOCK, RECOVER, HITSTUN, 15, 16, 17, 19])
				var h := light(); h.damage = 999.0
				p.global_position = g.global_position - g._fwd() * 1.5
				g.hurtbox.take_hit(h, p)
				check("dies (ragdoll)", g.state == DEAD and g.humanoid.ragdoll != null)
				# (1.22: 60% of kills pay coins; the rates are t/economy/drop_rates')
				step = 20
			return false
		20:
			# --- elites dash out of a heavy; a plain grunt doesn't
			g = circling()
			if g == null: wait = 0.3; return false
			for x in camp.grunts:
				if is_instance_valid(x) and x != g: x.process_mode = Node.PROCESS_MODE_DISABLED
			check("a smuggler isn't an elite", not g.elite())
			_heavy_at(g)
			wait = 0.6
		21:
			check("a plain grunt doesn't dash from a heavy", not dashed)
			wait = 1.2
		22:
			g.elite_rank = true
			_heavy_at(g)
			hp0 = g.health.current_health
			wait = 0.6
		23:
			check("an elite dashes out of a heavy coming at it", dashed)
			check("...and the heavy whiffs", g.health.current_health >= hp0)
			check("...then its dash is on cooldown", g._dash_cd > 2.0)
			g.elite_rank = false
			wait = 1.0
		24:
			# --- the low sweep: a crouched wind-up and an arc on the ground, cut at the shins
			_face_off(g, 1.8)
			g._attack = "sweep"
			g._swing_i = 0
			g._start_wind()
			check("a low sweep: crouched wind-up and a ground arc first", g.humanoid.current_action() == "sweep_wind" and root.find_children("ArcWarn", "", true, false).size() > 0)
			t0 = t
		25:
			if not (g.state == SWING and g.hitbox.active) and t - t0 < 2.0: return false
			var cs = g.hitbox.get_child(0)
			check("...then it cuts low (jump it)", g.state == SWING and cs.position.y < 0.5)
			wait = 1.2
		26:
			# --- the feint: a wind-up that breaks off with no glint, then the real one (glint)
			_face_off(g, 1.8)
			g._attack = "feint"
			g._swing_i = 0
			g._start_wind()
			feint = {"early": false, "real": false}
			t0 = t
		27:
			if g.state == WIND and g._glinted:
				feint["early" if g._swing_i == 0 else "real"] = true
			if g.state != SWING and t - t0 < 2.5: return false
			check("a feint: the first wind-up breaks off without a glint", not feint["early"] and g._swing_i == 1)
			check("...the real one glints before it swings", feint["real"])
			for x in camp.grunts:
				if is_instance_valid(x): x.process_mode = Node.PROCESS_MODE_INHERIT
			wait = 1.0
			step = 9
			return false
		9:
			# run away: they give up and go home
			p.global_position = p.global_position + Vector3(0, 0, -60)
			p.reset_physics_interpolation()
			wait = 20.0
		10:
			var home := 0; var alive := 0
			for x in camp.grunts:
				if is_instance_valid(x) and x.state != DEAD:
					alive += 1
					if x.state == IDLE: home += 1
					else: print("   not home: state ", x.state, " mode ", x.idle_mode, " dist to post ", snappedf(x.global_position.distance_to(x.post), 0.01), " vel ", x.velocity)
			print("   back home ", home, "/", alive)
			check("survivors return to their posts", home == alive and alive == 4)
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false
