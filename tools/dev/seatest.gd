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
			# out at sea, east of Brinehollow, a pirate ship lying abeam (its brain off: just its guns)
			ship.place(Vector3(450, 0, 150), 0.0)
			es = get_nodes_in_group("enemy_ships")[0]
			es.set_physics_process(false)
			es._pos = Vector3(482, 0, 150)
			es._heading = 0.0
			es.global_transform = Transform3D(Basis(), Vector3(482, 0.85, 150))
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
				elif not (h._wet or h.global_position.y < 3.0):
					ok = false
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
			finish()
	return false
func get_root_halves() -> Array:
	var out: Array = []
	for n in current_scene.get_children():
		if n is RigidBody3D and n.get("_wet") != null:
			out.append(n)
	return out
