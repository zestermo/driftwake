extends SceneTree
## Sea round: cannonballs cut in two by a katana or cutlass (the halves fly on, split
## 45 degrees, and land in the sea or on deck), not by other weapons; set off in
## mid-air by a shot; left alone they land. Then chases, boarding, hull damage,
## hazards, loot, the chart and the Sea King (rise, bite, tail slam, cannon, kill).
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
var fired_n := 0
var ys: Array = []
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
	# (a clean ship each shot: a fire from the last one would burn the hull meanwhile)
	ship.fires.clear()
	ship.breaches.clear()
	ship.flood = 0.0
	ship.hull = ship.max_hull
	ship._send_damage()
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
	if t > 200.0:
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
			# (the rest of the fleet keeps its distance until the ramming test wants the brig)
			for other in get_nodes_in_group("enemy_ships"):
				if other != es:
					other.set_physics_process(false)
			es._pos = sea + Vector3(32, 0, 0)
			es._heading = 0.0
			es.global_transform = Transform3D(Basis(), es._pos + Vector3(0, HullBuilder.FREEBOARD, 0))
			# (its middle gun on the side facing us)
			for c in es.cannons:
				if c.position.x < 0.0 and absf(c.position.z + 3.2) < 0.1:
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
			# (a half that glances off the cabin or the rigging takes a while to come down)
			wait = 3.5
			step = 6
		6:
			var sk = get_first_node_in_group("sea_kings")
			print("   hull %.1f -> %.1f  fires %d holes %d flood %.2f  sea king state %s at %.0f m  hp %.0f -> %.0f" % [hull0, ship.hull, ship.fires.size(), ship.breaches.size(), ship.flood,
				str(sk.state) if sk else "-", sk._head.global_position.distance_to(ship.global_position) if sk else -1.0, hp0, p.health_component.current_health])
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
			# (shot down before it reaches the rail, 5.4 m out on the wider hull)
			if not near(6.0):
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
			# (no_go: Brinehollow's circles, Redtide, then the other islands)
			var starter_circles: int = ((root.get_node("World/Islands/Brinehollow").get_script() as GDScript).get_script_constant_map()["NO_GO"] as Array).size()
			var z: Array = es.no_go[starter_circles + 1]
			check("...nor just off another island's shore", not es.huntable_at(Vector3(z[0].x + float(z[1]) + 20.0, 0, z[0].y)))
			# --- steering round land: a patrol whose waypoints lie on an island
			var c := Vector3(z[0].x, 0, z[0].y)
			var r := float(z[1])
			var from := c + Vector3(r + 120.0, 0, 0)
			es._pos = from
			es._heading = atan2(-(c - from).x, -(c - from).z)
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), from + Vector3(0, HullBuilder.FREEBOARD, 0))
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
			es.global_transform = Transform3D(Basis(), sea + Vector3(0, HullBuilder.FREEBOARD, 0))
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
			check("...the men on deck became them (none left standing as crew)", es._crew.all(func(c): return c["gone"]))
			check("...in their own bodies", es.deck_crew.all(func(g): return es._crew.any(func(c): return c["node"] == g.humanoid)))
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
			# --- the fleet: different ships
			var by := {}
			for s in get_nodes_in_group("enemy_ships"):
				by[s.kind] = s
			print("   fleet: ", by.keys())
			check("a fleet of kinds: sloop, gunboat, brig, Marines", by.has("sloop") and by.has("gunboat") and by.has("brig") and by.has("marine"))
			if by.has("brig") and by.has("gunboat") and by.has("marine"):
				var bg = by["brig"]
				check("the brig: 4 guns a side, 8 crew, a heavy hull", bg.cannons.size() == 8 and bg._crew.size() == 8 and bg.max_hull > 400.0)
				check("the gunboat: 2 guns a side, 4 crew, fast", by["gunboat"].cannons.size() == 4 and by["gunboat"]._crew.size() == 4 and by["gunboat"]._max_speed() > 12.0)
				var mr = by["marine"]
				check("the Marines: in whites, the gull on the sail, never board", mr._crew.all(func(c): return c["look"]["name"] == "Marine" and c["look"]["top_color"].r > 0.9) and not mr.spec["boards"])
				set_meta("by", by)
				# --- ramming: the brig runs at our ship with our captain on deck
				var sea: Vector3 = get_meta("sea")
				ship.place(sea, 0.0)
				ship.sail = 0.0
				bg.set_physics_process(true)
				bg._pos = sea + Vector3(0, 0, 45)
				bg._heading = 0.0
				bg.speed = 6.0
				bg.global_transform = Transform3D(Basis(), bg._pos + Vector3(0, HullBuilder.FREEBOARD, 0))
				wait = 0.3
				step = 18
			else:
				finish()
		18:
			var bg = get_meta("by")["brig"]
			p.global_position = ship.global_transform * Vector3(0.0, 0.8, 1.5)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			hull0 = ship.hull
			bg._ram_cd = 0.0
			bg._volleys = 1
			bg._set_state(8)
			t0 = t
			step = 19
		19:
			var bg = get_meta("by")["brig"]
			if p.current_state_name() == "Downed":
				set_meta("thrown", true)
			set_meta("ram_min", minf(float(get_meta("ram_min", INF)), bg._pos.distance_to(ship.global_position * Vector3(1, 0, 1))))
			if bg.state == 8 and t - t0 < 12.0:
				return false
			print("   ram: closest %.1f m, state %d" % [get_meta("ram_min"), bg.state])
			print("   rammed: hull ", hull0, " -> ", ship.hull, ", captain thrown ", get_meta("thrown", false), " after %.1f s" % (t - t0))
			check("the brig rams us: our hull takes it", ship.hull < hull0 - 20.0)
			check("...and throws our captain off their feet", bool(get_meta("thrown", false)))
			check("...then backs off to come round", bg.state != 8 and bg._ram_cd > 0.0)
			# --- a double broadside: two volleys back to back
			bg.set_physics_process(false)
			var n0 := get_nodes_in_group("cannonballs").size()
			set_meta("balls0", n0)
			bg._volley_cd = 0.0
			bg._heading = PI * 0.5
			bg._pos = ship.global_position + Vector3(0, 0, 35)
			bg.global_transform = Transform3D(Basis(Vector3.UP, bg._heading), bg._pos + Vector3(0, HullBuilder.FREEBOARD, 0))
			fired_n = 0
			bg._warn_t = -1.0
			bg._second = false
			for c in bg.cannons:
				c.cool = 0.0
				c.fired.connect(func(): fired_n += 1)
			bg._try_volley(ship, ship.global_position - bg._pos, 35.0)
			bg.set_physics_process(true)
			t0 = t
			step = 20
		20:
			if t - t0 < 4.5:
				return false
			print("   brig volley: %d shots" % fired_n)
			check("the brig fires a double broadside (8 shots)", fired_n >= 8)
			step = 200
		200:
			# --- beaten: it runs; caught, it strikes
			var sl = get_meta("by")["gunboat"]
			sl.set_physics_process(true)
			sl._pos = ship.global_position + Vector3(30, 0, 0)
			sl.global_transform = Transform3D(Basis(), sl._pos + Vector3(0, HullBuilder.FREEBOARD, 0))
			sl.hull = sl.max_hull * 0.2
			sl._fled = false
			sl._set_state(2)
			wait = 0.5
			step = 21
		21:
			var sl = get_meta("by")["gunboat"]
			check("badly holed, a pirate runs for it", sl.state == 9)
			sl.hull = sl.max_hull * 0.1
			wait = 0.5
			step = 22
		22:
			var sl = get_meta("by")["gunboat"]
			check("caught at a tenth of her hull, she strikes her colours", sl.state == 7 and not sl._jolly.visible)
			check("...her crew don't fight (still aboard, cutlasses away)", sl._crew.all(func(c): return c["node"].visible and not c["node"].armed))
			check("...the Marines would never", not get_meta("by")["marine"].spec["yields"])
			# --- holes, flooding, fires (pirates out of the way)
			for s in get_nodes_in_group("enemy_ships"):
				s.queue_free()
			ship.place(get_meta("sea"), 0.0)
			ship.hull = 400.0
			ship.flood = 0.0
			ship.breaches.clear()
			ship.fires.clear()
			# (a hole is a 15% chance a hit now: 30 hits all but surely make one)
			for k in range(30):
				ship.hull_hit(14.0, ship.global_transform * Vector3(2.9, 0.0, -3.0))
				ship.hull = 400.0
			check("hits hole her now and then (%d holes) and can set her alight (%d fires)" % [ship.breaches.size(), ship.fires.size()], ship.breaches.size() > 0)
			check("...never more than %d holes and %d fires at once" % [ship.MAX_BREACHES, ship.MAX_FIRES], ship.breaches.size() <= ship.MAX_BREACHES and ship.fires.size() <= ship.MAX_FIRES)
			for b in ship.breaches.duplicate():
				ship.do_work("patch", int(b[0]), 0.0)
			for f in ship.fires.duplicate():
				ship.do_work("douse", int(f[0]), 0.0)
			ship.hull = 400.0
			p.global_position = ship.global_transform * Vector3(-1.0, 0.8, 3.5)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			wait = 1.5
			step = 220
		220:
			# her height afloat, dry, then half full of water
			ys.append(ship._y)
			if ys.size() < 90:
				return false
			set_meta("dry", ys.reduce(func(a, b): return a + b) / ys.size())
			ys.clear()
			ship.flood = 0.6
			wait = 2.0
			step = 221
		221:
			ys.append(ship._y)
			if ys.size() < 90:
				return false
			var wet: float = ys.reduce(func(a, b): return a + b) / ys.size()
			print("   half full of water she sits %.2f m lower" % (float(get_meta("dry")) - wet))
			check("water in her: she sits lower", wet < float(get_meta("dry")) - 0.2)
			ship.flood = 0.0
			ship.add_breach(1.0, -3.0)
			wait = 6.0
			step = 23
		23:
			print("   one hole, 6 s: water %.2f, a hole drawn %s" % [ship.flood, ship._holes.size() == 1])
			check("a hole lets the water in (slowly)", ship.flood > 0.02 and ship.flood < 0.06)
			check("...the hull bar shows the water", get_first_node_in_group("hud")._flood_bar.visible)
			var spot: Vector3 = ship.breaches[0][1]
			p.global_position = ship.global_transform * (spot + Vector3(0, 0.5, 0))
			p.reset_physics_interpolation()
			Input.action_press("interact")
			wait = ship.PATCH_TIME + 0.8
			step = 24
		24:
			Input.action_release("interact")
			check("holding F at the rail above it patches the hole", ship.breaches.is_empty() and ship._holes.is_empty())
			# (half full: what a long fight leaves in her)
			ship.flood = 0.5
			set_meta("flood0", ship.flood)
			p.global_position = ship.global_transform * (ship.PUMP_AT + Vector3(0.3, 0.5, 0.6))
			p.reset_physics_interpolation()
			Input.action_press("interact")
			wait = 3.0
			step = 25
		25:
			Input.action_release("interact")
			print("   pumped 3 s: water %.3f -> %.3f" % [get_meta("flood0"), ship.flood])
			check("working the pump bails her out fast (half full, 3 s: %.2f)" % ship.flood, ship.flood < float(get_meta("flood0")) - 0.25)
			ship.add_fire(Vector3(-1.0, ship.DECK_Y, 2.0))
			hp0 = p.health_component.current_health
			p.global_position = ship.global_transform * Vector3(-1.0, 0.8, 2.0)
			p.reset_physics_interpolation()
			wait = 1.6
			step = 26
		26:
			check("standing in a fire burns", p.health_component.current_health < hp0)
			Input.action_press("interact")
			wait = ship.DOUSE_TIME + 0.8
			step = 27
		27:
			Input.action_release("interact")
			check("holding F beats the fire out", ship.fires.is_empty())
			ship.add_breach(-1.0, 3.0)
			ship.flood = 0.995
			wait = 1.0
			step = 28
		28:
			check("awash, she founders: crippled", ship.crippled)
			ship.breaches.clear()
			ship.flood = 0.0
			ship.hull = 400.0
			ship.crippled = false
			ship._send_damage()
			# --- out on the open sea: reefs, fog, whirlpools, storm cells
			var sf = get_first_node_in_group("sea_features")
			print("   sea features: %d reefs, %d fog banks, %d whirlpools, %d storm cells" % [sf.reefs.size(), sf.fogs.size(), sf.whirls.size(), sf.storms.size()])
			check("the sea has reefs, fog banks, whirlpools and storm cells", sf.reefs.size() >= 2 and sf.fogs.size() >= 2 and sf.whirls.size() >= 1 and sf.storms.size() == 2)
			# run her onto a reef's shoals at speed
			var rf: Array = sf.reefs[0]
			var rc := Vector3(rf[0].x, 0, rf[0].y)
			var from := rc + Vector3(float(rf[1]) + 6.0, 0, 0)
			ship.place(from, atan2(-(rc - from).x, -(rc - from).z))
			ship.speed = 10.0
			p.global_position = ship.global_transform * Vector3(0, 0.8, 1.0)
			p.reset_physics_interpolation()
			wait = 3.0
			step = 29
		29:
			print("   on the reef: hull %.0f, speed %.1f, holes %d" % [ship.hull, ship.speed, ship.breaches.size()])
			check("a reef grinds her hull and slows her", ship.hull < 395.0 and ship.speed < 8.0)
			ship.breaches.clear()
			ship.hull = 400.0
			ship._send_damage()
			# adrift by a whirlpool
			var sf = get_first_node_in_group("sea_features")
			var w: Array = sf.whirls[0]
			var wc := Vector3(w[0].x, 0, w[0].y)
			var start := wc + Vector3(float(w[1]) * 0.7, 0, 0)
			ship.place(start, 0.0)
			ship.sail = 0.0
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, 0.8, 1.0)
			p.reset_physics_interpolation()
			set_meta("wstart", start)
			set_meta("wc", wc)
			wait = 4.0
			step = 30
		30:
			var wc: Vector3 = get_meta("wc")
			var st: Vector3 = get_meta("wstart")
			var now: Vector3 = ship.global_position * Vector3(1, 0, 1)
			var d0 := st.distance_to(wc)
			var d1 := now.distance_to(wc)
			var turned := Vector2(st.x - wc.x, st.z - wc.z).angle_to(Vector2(now.x - wc.x, now.z - wc.z))
			print("   whirlpool: %.1f -> %.1f m from the eye, carried %.2f rad round" % [d0, d1, turned])
			check("a whirlpool drags her round and in", d1 < d0 - 2.0 and absf(turned) > 0.15)
			# a storm cell's middle: the swell and the weather
			var sf = get_first_node_in_group("sea_features")
			var sc: Vector2 = sf.storm_at(0)
			print("   swell in the middle of a storm cell x%.2f, out of it x%.2f" % [root.get_node("Ocean").local_swell(sc.x, sc.y), root.get_node("Ocean").local_swell(sc.x + 400.0, sc.y)])
			check("a storm cell's swell is bigger", root.get_node("Ocean").local_swell(sc.x, sc.y) > 1.9 and is_equal_approx(root.get_node("Ocean").local_swell(sc.x + 400.0, sc.y + 400.0), 1.0))
			ship.place(Vector3(sc.x, 0, sc.y), 0.0)
			wait = 0.2
			step = 301
		301:
			# (a moved hull reports its new place after the next physics step)
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, 0.8, 1.0)
			p.reset_physics_interpolation()
			wait = 1.0
			step = 31
		31:
			var wx = root.get_node("Weather")
			print("   in the storm cell: storm %.2f rain %.2f" % [wx.storm, wx.rain])
			check("...and the weather closes in under it", wx.storm > 0.8 and wx.rain > 0.8)
			var sf = get_first_node_in_group("sea_features")
			var fb: Array = sf.fogs[0]
			ship.place(Vector3(fb[0].x, 0, fb[0].y), 0.0)
			wait = 0.2
			step = 311
		311:
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, 0.8, 1.0)
			p.reset_physics_interpolation()
			wait = 1.0
			step = 32
		32:
			var wx = root.get_node("Weather")
			print("   in a fog bank: fog %.2f" % wx.fog)
			check("inside a fog bank the fog closes in", wx.fog > 0.8)
			# --- wrecks, bottles, buried treasure
			var sf = get_first_node_in_group("sea_features")
			var gm = root.get_node("GameManager")
			print("   %d wrecks, %d bottles, %d treasures" % [sf.wrecks.size(), sf.bottles.size(), sf.treasures.size()])
			check("wrecks, bottles and buried treasure out there", sf.wrecks.size() >= 2 and sf.bottles.size() >= 2 and sf.treasures.size() >= 2)
			var chest = sf.get_node("Wreck0/WreckChest0")
			check("a wreck heeled over in the water, a chest still aboard", chest != null and absf(sf.get_node("Wreck0").rotation.z) > 0.2)
			chest._on_interact(p)
			check("...looted, and remembered", gm.opened.has("wreck_0"))
			var bt: int = int(sf.bottles[0][1])
			check("no X on the beach before the map's found", not sf._treasure_nodes[bt].visible)
			sf._bottle_nodes[0].get_node("Grab").interacted.emit(p)
			wait = 0.6
			step = 33
		33:
			var sf = get_first_node_in_group("sea_features")
			var gm = root.get_node("GameManager")
			var bt: int = int(sf.bottles[0][1])
			check("fishing out a bottle gives a treasure map", gm.maps.has(bt) and not sf._bottle_nodes[0].visible)
			check("...and its X shows on the beach", sf._treasure_nodes[bt].visible)
			var before: int = root.find_children("DugChest*", "", true, false).size()
			sf._treasure_nodes[bt].get_node("Dig").interacted.emit(p)
			check("digging there turns up a chest", root.find_children("DugChest*", "", true, false).size() == before + 1 and gm.opened.has("treasure_%d" % bt))
			wait = 0.6
			step = 34
		34:
			var sf = get_first_node_in_group("sea_features")
			var bt: int = int(sf.bottles[0][1])
			check("...once (the X is gone)", not sf._treasure_nodes[bt].visible)
			# --- the sea chart: sailing near things puts them on it
			var gm = root.get_node("GameManager")
			var rf: Array = sf.reefs[1]
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(rf[0].x + 60.0, 2.0, rf[0].y)
			p.reset_physics_interpolation()
			set_meta("had_reef", gm.charted.has("reef:1"))
			wait = 1.2
			step = 35
		35:
			var gm = root.get_node("GameManager")
			check("passing near a reef charts it", gm.charted.has("reef:1") and not get_meta("had_reef"))
			var info: Dictionary = root.get_node("World/Islands").island_infos[0]
			p.global_position = Vector3(info["pos"].x + float(info["radius"]) + 150.0, 2.0, info["pos"].y)
			p.reset_physics_interpolation()
			wait = 1.2
			step = 36
		36:
			var gm = root.get_node("GameManager")
			var info: Dictionary = root.get_node("World/Islands").island_infos[0]
			check("coming near an island charts it (%s)" % info["name"], gm.charted.has("island:" + str(info["name"])))
			var menu = root.get_node("GameMenu")
			menu.open("chart")
			check("M opens the sea chart", menu._current == "chart" and menu._chart.visible)
			menu.close()
			step = 360
		360:
			# --- the Sea King: sail into its waters
			var sf = get_first_node_in_group("sea_features")
			var sk = sf.sea_king
			check("a Sea King lurks out there, unseen", sk != null and not sk.visible and sk.state == 0)
			for e in get_nodes_in_group("enemy_ships"):
				e.queue_free()
			p.state_machine.force_state("Idle", {})
			ship.place(Vector3(sk.lair.x + 60.0, 0.0, sk.lair.y), 0.0)
			wait = 0.3
			step = 37
		37:
			p.global_position = ship.global_transform * Vector3(0, 0.8, 1.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			wait = 3.0
			step = 38
		38:
			var sk = get_first_node_in_group("sea_kings")
			var gm = root.get_node("GameManager")
			print("   sea king: state %d, head %s, ship %s" % [sk.state, sk.head_position(), ship.global_position])
			check("it rises beside a manned ship", sk.visible and sk.state in [1, 2])
			check("...and goes on the chart", gm.charted.has("king"))
			sk._next = 999.0
			wait = 1.5
			step = 39
		39:
			var sk = get_first_node_in_group("sea_kings")
			var off: float = sk.head_position().distance_to(ship.global_position)
			check("it circles her, head high (%.1f m off)" % off, sk.state == 2 and off > 12.0 and off < 40.0 and sk.head_position().y > 2.0)
			# the bite, aimed where our captain stands
			p.global_position = ship.global_transform * Vector3(0.5, 0.8, 1.0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			sk._start_rear(ship)
			var l: Vector3 = ship.global_transform.affine_inverse() * p.global_position
			sk._bite_local = Vector3(l.x, 0.32, l.z)
			check("a ring on the deck warns of the bite, riding with her", ship.find_child("Telegraph", true, false) != null)
			hull0 = ship.hull
			hp0 = p.health_component.current_health
			wait = 2.1
			step = 40
		40:
			var sk = get_first_node_in_group("sea_kings")
			print("   bite: hull %.0f -> %.0f, hp %.0f -> %.0f, state %d (%s)" % [hull0, ship.hull, hp0, p.health_component.current_health, sk.state, p.current_state_name()])
			check("it bites down on the deck: the hull takes it", ship.hull < hull0 - 30.0)
			check("...and our captain in the ring with it", p.health_component.current_health < hp0)
			var deck: Vector3 = ship.global_transform * sk._bite_local
			check("its head lies on the deck a moment", sk.state == 5 and sk.head_position().distance_to(deck) < 2.5)
			var before: float = sk.hp
			var hd := HitData.new()
			hd.damage = 60.0
			sk.hurtbox.take_hit(hd, p)
			check("...and a blade on its head hurts it", sk.hp < before - 59.0)
			wait = 2.0
			step = 41
		41:
			var sk = get_first_node_in_group("sea_kings")
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
			p.reset_physics_interpolation()
			sk._next = 999.0
			sk._start_tail(ship)
			set_meta("thrown", false)
			t0 = t
			wait = 0.6
			step = 42
		42:
			var sk = get_first_node_in_group("sea_kings")
			if p.current_state_name() == "Downed":
				set_meta("thrown", true)
			if ship.find_child("Telegraph", true, false) != null and not bool(get_meta("thrown", false)):
				set_meta("warned", true)
			if t - t0 > 1.0:
				set_meta("tail_y", maxf(float(get_meta("tail_y", -99.0)), (sk._seg_pos[sk.SEGS - 1] as Vector3).y))
			if t - t0 < 3.0:
				return false
			print("   tail: tip rose to %.1f m, captain thrown %s" % [get_meta("tail_y"), get_meta("thrown")])
			check("its tail rises out of the sea", float(get_meta("tail_y")) > 5.0)
			check("...a roar and a ring on deck warn before it comes down", bool(get_meta("warned", false)))
			check("...and slams down: our captain is thrown off their feet", bool(get_meta("thrown")))
			# a cannonball from our side into it (held still, abeam)
			p.state_machine.force_state("Idle", {})
			sk.set_physics_process(false)
			sk._head.global_position = ship.global_transform * Vector3(18.0, 4.0, -1.0)
			sk._pose_segs()
			set_meta("hp_gun", sk.hp)
			var fired := false
			for c in ship.cannons:
				c.cool = 0.0
				if not fired and c.aim_at(sk._head.global_transform * sk.HEAD_C):
					fired = c.fire(p)
			check("one of our guns bears on it", fired)
			wait = 1.5
			step = 43
		43:
			var sk = get_first_node_in_group("sea_kings")
			print("   cannon: sea king hp %.0f -> %.0f" % [get_meta("hp_gun"), sk.hp])
			check("a cannonball strikes it (siege hits count extra)", sk.hp < float(get_meta("hp_gun")) - 40.0)
			sk.set_physics_process(true)
			sk.hp = 10.0
			var hd := HitData.new()
			hd.damage = 30.0
			sk.hurtbox.take_hit(hd, p)
			check("killed, it sinks", sk.is_dead())
			check("...and its hoard floats up", current_scene.find_child("SeaKingHoard*", true, false) != null)
			wait = 7.0
			step = 44
		44:
			var sk = get_first_node_in_group("sea_kings")
			check("...gone under after a while", not sk.visible)
			finish()
	return false
func get_root_halves() -> Array:
	var out: Array = []
	for n in current_scene.get_children():
		if n is RigidBody3D and n.get("_wet") != null:
			out.append(n)
	return out
