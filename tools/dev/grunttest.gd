extends SceneTree
## Pirate grunts: camp, alert, attack turns, guard/guard break, hitstun, parry stagger, knockdown, death, return home.
const IDLE := 0; const ALERT := 1; const CHASE := 2; const CIRCLE := 3; const CLOSE := 4; const WIND := 5; const SWING := 6
const RECOVER := 7; const BLOCK := 8; const STAGGER := 9; const HITSTUN := 10; const DOWN := 11; const GETUP := 12; const RETURN := 13; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var fails := 0
var seen := {}
var max_att := 0
var hp0 := 0.0
var g
var t0 := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
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
func _process(d: float) -> bool:
	t += d
	if camp and step >= 2 and step <= 3:
		var att := 0
		for x in camp.grunts:
			if is_instance_valid(x):
				seen[x.state] = true
				if x.state in [WIND, SWING, CLOSE]: att += 1
		max_att = maxi(max_att, att)
	if wait > 0.0:
		wait -= d
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
			g.hurtbox.take_hit(light(), p)
			check("front light hit is blocked", g.state == BLOCK and is_equal_approx(g.health.current_health, hp))
			g._riposte = false
			g.hurtbox.take_hit(light(), p); g._riposte = false
			g.hurtbox.take_hit(light(), p); g._riposte = false
			g.hurtbox.take_hit(light(), p)
			print("   after 4 front hits: state ", g.state, " hp ", g.health.current_health)
			check("guard breaks: staggered + damaged", g.state == STAGGER and g.health.current_health < hp)
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
				check("drops gold", root.get_tree().current_scene.find_children("Coin*", "", false, false).size() > 0)
				step += 1
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
