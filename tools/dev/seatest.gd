extends SceneTree
## Sea round: cannonballs cut in two by a katana or cutlass (the halves fly on, split
## 45 degrees, and land in the sea or on deck), not by other weapons; set off in
## mid-air by a shot; left alone they land.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var es
var gun
var ball
var fails := 0
var hull0 := 0.0
var hp0 := 0.0
var t0 := 0.0
var cut_vel := Vector3.ZERO
var halves: Array = []
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
## The pirate ship's gun fires at `at` (default: our captain's chest).
func shoot(at: Vector3 = Vector3.INF) -> void:
	gun.cool = 0.0
	gun.aim_at(p.global_position + Vector3(0, 1.1, 0) if at == Vector3.INF else at)
	gun.fire(es)
	ball = null
	for b in get_nodes_in_group("cannonballs"):
		if b.team == "enemy" and not b._done:
			ball = b
	hull0 = ship.hull
	hp0 = p.health_component.current_health
	t0 = t
## The ball, once it's within `d` of our captain's chest.
func near(d: float) -> bool:
	return is_instance_valid(ball) and not ball._done and ball.global_position.distance_to(p.global_position + Vector3(0, 1.1, 0)) < d
func hit(sever: bool, ranged: bool) -> void:
	var hd := HitData.new()
	hd.damage = 20.0
	hd.sever = sever
	hd.ranged = ranged
	ball.hurtbox.take_hit(hd, p)
func gone() -> bool:
	return not is_instance_valid(ball) or ball.is_queued_for_deletion()
func _process(d: float) -> bool:
	t += d
	if t > 120.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			es = get_nodes_in_group("enemy_ships")[0]
			# out at sea where pirates hunt (clear of land), a pirate ship lying
			# abeam (its brain off: just its guns)
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			var sea := Vector3.INF
			for k in range(32):
				var a := k * TAU / 32.0
				var c := Vector3(sc.x + cos(a) * 420.0, 0, sc.y + sin(a) * 420.0)
				if es.huntable_at(c) and es.huntable_at(c + Vector3(40, 0, 0)):
					sea = c
					break
			check("found open sea to fight in", sea != Vector3.INF)
			set_meta("sea", sea)
			ship.place(sea, 0.0)
			es.set_physics_process(false)
			es._pos = sea + Vector3(32, 0, 0)
			es._heading = 0.0
			es.global_transform = Transform3D(Basis(), es._pos + Vector3(0, 0.85, 0))
			for c in es.cannons:
				if c.position.x < 0.0 and absf(c.position.z + 1.6) < 0.1:
					gun = c
			wait = 0.5
			step = 1
		1:
			p.global_position = ship.global_transform * Vector3(1.0, 0.6, -2.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			p.equip_weapon(load("res://resources/items/boarding_axe.tres"))
			wait = 1.0
			step = 2
		2:
			check("on the deck", p.is_on_floor() and ship.aboard(p.global_position))
			shoot()
			check("the pirate gun fires a ball with a name (%s)" % (ball.id if ball else "none"), ball != null and ball.id != "" and ball.hurtbox != null)
			step = 3
		3:
			if not near(3.0):
				if t - t0 > 4.0 or gone():
					check("the ball reached the deck", false)
					finish()
				return false
			hit(true, false)
			check("an axe can't cut it", not gone() and not ball._done)
			wait = 1.5
			step = 4
		4:
			p.equip_weapon(load("res://resources/items/katana.tres"))
			shoot()
			step = 5
		5:
			if not near(3.0):
				return false
			cut_vel = ball.velocity
			hit(true, false)
			check("a katana cuts it in two", gone())
			halves = get_root_halves()
			check("...two halves", halves.size() == 2)
			if halves.size() == 2:
				var a: Vector3 = halves[0].linear_velocity
				var b: Vector3 = halves[1].linear_velocity
				var fa := Vector2(a.x, a.z).angle_to(Vector2(cut_vel.x, cut_vel.z))
				var fb := Vector2(b.x, b.z).angle_to(Vector2(cut_vel.x, cut_vel.z))
				print("   halves part %.0f / %.0f deg from the ball's line at %.1f / %.1f m/s (ball %.1f)" % [rad_to_deg(fa), rad_to_deg(fb), a.length(), b.length(), cut_vel.length()])
				check("...flying on with its momentum, 45 degrees either side", absf(absf(fa) - PI * 0.25) < 0.05 and absf(absf(fb) - PI * 0.25) < 0.05 and signf(fa) != signf(fb) and absf(a.length() - cut_vel.length()) < 0.5)
			wait = 1.5
			step = 6
		6:
			check("...nothing bursts: hull and captain untouched", ship.hull == hull0 and p.health_component.current_health == hp0)
			var ok := halves.size() == 2
			for h in halves:
				if not is_instance_valid(h):
					ok = false
				elif not (h._wet or (ship.aboard(h.global_position) and ship.to_local(h.global_position).y < 2.5)):
					ok = false
			for h in halves:
				print("   half at ", h.global_position if is_instance_valid(h) else "gone", " wet ", h._wet if is_instance_valid(h) else "-")
			check("...the halves come down (in the sea or on deck)", ok)
			p.equip_weapon(load("res://resources/items/cutlass.tres"))
			shoot()
			step = 7
		7:
			if not near(3.0):
				return false
			hit(true, false)
			check("a cutlass cuts it too", gone())
			wait = 1.0
			step = 8
		8:
			shoot()
			step = 9
		9:
			if not near(4.0):
				return false
			hit(false, true)
			check("a shot sets it off in mid-air", gone())
			wait = 1.0
			step = 10
		10:
			check("...harmlessly", ship.hull == hull0 and p.health_component.current_health == hp0)
			# and left alone it lands: at the hull this time
			shoot(ship.global_transform * Vector3(2.9, 0.2, -1.0))
			wait = 3.0
			step = 11
		11:
			print("   hull ", hull0, " -> ", ship.hull)
			check("left alone, it lands (hull hit)", ship.hull < hull0)
			# --- who the pirates go after
			check("a captain aboard at sea: the pirates have a target", es._crew_ship() == ship and es._huntable(ship))
			p.global_position = ship.global_transform * Vector3(0, 0, 30)
			p.reset_physics_interpolation()
			wait = 0.2
			step = 12
		12:
			check("nobody aboard: no target (an empty ship isn't worth a shot)", es._crew_ship() == null)
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			check("in Brinehollow's harbour, by its dock: not huntable", not es.huntable_at(Vector3(sc.x, 0, sc.y - 200.0)))
			check("...nor just off another island's shore", not es.huntable_at(Vector3(es.no_go[2][0].x + float(es.no_go[2][1]) + 20.0, 0, es.no_go[2][0].y)))
			# --- steering round land: a patrol whose waypoints lie on an island
			var z: Array = es.no_go[2]
			var c := Vector3(z[0].x, 0, z[0].y)
			var r := float(z[1])
			var from := c + Vector3(r + 120.0, 0, 0)
			es._pos = from
			es._heading = atan2(-(c - from).x, -(c - from).z)
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), from + Vector3(0, 0.85, 0))
			es.patrol_center = c
			es.patrol_radius = 5.0
			es._set_state(0)
			es.speed = 8.0
			es.set_physics_process(true)
			set_meta("zone", [c, r])
			set_meta("closest", INF)
			t0 = t
			step = 13
		13:
			var zz: Array = get_meta("zone")
			var dd: float = Vector2(es._pos.x - zz[0].x, es._pos.z - zz[0].z).length()
			set_meta("closest", minf(float(get_meta("closest")), dd))
			if t - t0 < 30.0:
				return false
			print("   steering round an island (keep-out %.0f m): closest %.1f m" % [zz[1], get_meta("closest")])
			check("pirate ships keep clear of islands", float(get_meta("closest")) > float(zz[1]) - 8.0)
			# --- boarding them: out at sea, our captain lands on its deck
			var sea: Vector3 = get_meta("sea") + Vector3(0, 0, -80)
			es._pos = sea
			es.speed = 0.0
			es.global_transform = Transform3D(Basis(), sea + Vector3(0, 0.85, 0))
			es._set_state(0)
			wait = 0.3
			step = 14
		14:
			p.global_position = es.global_transform * Vector3(0.0, 0.8, -2.5)
			p.reset_physics_interpolation()
			wait = 1.0
			step = 15
		15:
			check("our captain stands on the pirate deck (aboard, on floor)", es.aboard(p.global_position) and p.is_on_floor())
			check("all hands turn to fight (%d grunts)" % es.deck_crew.size(), es.state == 6 and es.deck_crew.size() == 6)
			check("...the men on deck became them (none left standing as crew)", es._crew.all(func(c): return not c["node"].visible))
			check("...and they come at us", es.deck_crew.filter(func(g): return g.state != 0).size() >= 3)
			for g in es.deck_crew:
				g.health.take_damage(9999.0)
			wait = 0.5
			step = 16
		16:
			check("deck cleared: she strikes her colours (a prize)", es.state == 7 and not es._jolly.visible)
			var bag = es.get_node("Model").get_node_or_null("Prize_" + es.name)
			check("...the captain's chest waits on her deck", bag != null and es.aboard(bag.global_position))
			# left empty, she's scuttled
			p.global_position = ship.global_transform * Vector3(0, 1.0, 0)
			p.reset_physics_interpolation()
			es._empty_t = es.SCUTTLE_AFTER - 0.2
			wait = 1.0
			step = 17
		17:
			check("a prize left empty is scuttled", es.state == 5)
			finish()
	return false
func get_root_halves() -> Array:
	var out: Array = []
	for n in current_scene.get_children():
		if n is RigidBody3D and n.get("_wet") != null:
			out.append(n)
	return out
