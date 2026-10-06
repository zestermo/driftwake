extends SceneTree
## Round 8: markers, kneeling, cannons (man, fire, reload, leave), helm
## broadside, cannonballs vs an enemy ship's hull, enemy ship hunting and
## firing, boarders, sinking + floating plunder, Captain Morrow's phases,
## crew call, shockwave, death + hoard, reset, music, HUD bars.
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var fort
var es
var boss
var fails := 0
var saw := {}
var t0 := 0.0
var c


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func hud():
	return get_first_node_in_group("hud")


func music():
	return root.get_node("Music")


func siege(dmg: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.siege = true
	h.unblockable = true
	h.ranged = true
	return h


func _process(d: float) -> bool:
	t += d
	if boss and is_instance_valid(boss) and boss.get("_special") != null and str(boss._special) != "":
		saw["special_" + str(boss._special)] = true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			p = get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = get_first_node_in_group("ship")
			fort = root.find_children("*", "RedtideFort", true, false)[0]
			es = get_nodes_in_group("enemy_ships")[0]
			boss = get_first_node_in_group("bosses")
			check("Redtide Rock is out at sea, north of Brinehollow", fort.global_position.distance_to(Vector3(150, 0, 150)) > 330.0)
			check("a pirate ship patrols", es != null and es.state == 0)
			check("Captain Morrow waits in his fort", boss != null and boss.health.max_health >= 900.0 and boss.state == 0)
			check("the crew's ship has four cannons", ship.cannons.size() == 4)
			check("music: island tune at the dock", music().current == "island")
			# --- markers
			p.place_marker()
			check("G drops a crew marker", hud().markers.markers.size() == 1)
			# --- kneel pose
			p.set_physics_process(false)
			p.body_model.kneeling = true
			wait = 0.4
			step = 1
		1:
			var h = p.body_model
			check("kneeling: hips drop low", h.pivot.position.y < h.hip_y - 0.25)
			h.kneeling = false
			p.set_physics_process(true)
			# --- man a cannon
			c = ship.cannons[3]
			p.global_position = c.global_position + Vector3(0, 0.3, 0)
			p.reset_physics_interpolation()
			c.interactable.interacted.emit(p)
			wait = 0.4
			step = 2
		2:
			check("F at a cannon: manning it", p.current_state_name() == "Cannon" and p.context == 2)
			check("...the gun's camera is on", c.camera.current)
			check("...the body crouches at the breech", p.body_model.manning)
			var y0: float = c.yaw
			var mm := InputEventMouseMotion.new()
			mm.screen_relative = Vector2(-60, -30)
			p.state_machine.current_state.handle_input(mm)
			check("the mouse swings the barrel", c.yaw > y0 + 0.05)
			c.yaw = 0.0
			c.pitch = 0.1
			saw["balls0"] = root.find_children("*", "Cannonball", true, false).size()
			Input.action_press("light_attack")
			wait = 0.15
			step = 3
		3:
			Input.action_release("light_attack")
			check("left click fires a ball", root.find_children("*", "Cannonball", true, false).size() > int(saw["balls0"]))
			check("...then it reloads", not c.loaded())
			Input.action_press("interact")
			wait = 0.2
			step = 4
		4:
			Input.action_release("interact")
			check("F again: off the gun", p.current_state_name() != "Cannon" and p.context == 0)
			check("...the seat is free", c.holder() == 0 and not c.aiming_locally)
			# --- helm broadside
			c.cool = 0.0
			for cc in ship.cannons:
				cc.cool = 0.0
			var n: int = ship.broadside(1.0, ship.global_position + ship.global_basis.x * 40.0, p)
			check("a broadside fires every loaded gun on that side", n == 2)
			wait = 0.6
			step = 5
		5:
			var fired := 0
			for cc in ship.side_cannons(1.0):
				if not cc.loaded():
					fired += 1
			check("...both starboard guns went off", fired == 2)
			# --- a direct hit on a pirate ship
			var h0: float = es.hull
			es.hurtbox.take_hit(siege(30.0), p)
			check("cannon fire wears down a pirate hull", es.hull < h0 - 29.0)
			var swd := HitData.new()
			swd.damage = 50.0
			var h1: float = es.hull
			es.hurtbox.take_hit(swd, p)
			check("...a sword doesn't", es.hull == h1)
			check("...and it turns to fight", es.state != 0)
			# a real ball fired at it
			var from: Vector3 = es.global_position + Vector3(30, 4, 0)
			var to: Vector3 = es.global_position + Vector3(0, 0.6, 0)
			var dist := Vector2(to.x - from.x, to.z - from.z).length()
			var pitch = load("res://scripts/ship/cannon.gd").solve_pitch(dist, to.y - from.y, 46.0, 14.0)
			var flat := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
			var v: Vector3 = flat * cos(float(pitch)) * 46.0 + Vector3.UP * sin(float(pitch)) * 46.0
			saw["hull_before_ball"] = es.hull
			load("res://scripts/ship/cannonball.gd").launch(self, from, v + es.hull_velocity(), "crew", true, p, null)
			wait = 1.6
			step = 6
		6:
			check("a cannonball flies true and holes the hull", es.hull < float(saw["hull_before_ball"]) - 10.0)
			# --- the pirates hunt the crew's ship: put it out past the harbour
			# (step off the deck first: a teleporting deck flings you)
			p.global_position = Vector3(150, 3, 100)
			p.reset_physics_interpolation()
			# (open sea: they leave ships alone near land, the Redtide rock included)
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			for k in range(32):
				var a := k * TAU / 32.0
				var c := Vector3(sc.x + cos(a) * 420.0, 0, sc.y + sin(a) * 420.0)
				if es.huntable_at(c) and es.huntable_at(c + es._right() * 40.0):
					es._pos = c
					es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), c + Vector3(0, 0.85, 0))
					break
			var spot: Vector3 = es._pos + es._right() * 34.0
			ship.place(Vector3(spot.x, 0.5, spot.z), es.global_rotation.y)
			wait = 0.3
			step = 7
		7:
			p.global_position = ship.global_position + Vector3(0, 1.4, 0)
			p.reset_physics_interpolation()
			es._set_state(0)
			saw["hull_ship0"] = ship.hull
			saw["balls_enemy"] = 0
			wait = 0.5
			step = 8
			t0 = t
		8:
			if es.state in [1, 2]:
				saw["hunt"] = true
			for b in root.find_children("*", "Cannonball", true, false):
				if b.team == "enemy":
					saw["balls_enemy"] = int(saw["balls_enemy"]) + 1
			if t - t0 < 14.0 and not (saw.has("hunt") and int(saw["balls_enemy"]) > 0):
				return false
			check("a pirate ship spots the crew's ship and gives chase", saw.has("hunt"))
			check("...and fires a broadside", int(saw["balls_enemy"]) > 0)
			check("music: combat while a ship hunts you", music().current == "combat")
			wait = 4.0
			step = 9
		9:
			check("hull bar on the HUD while aboard", hud()._hull_box.visible or ship.hull >= 399.5)
			# --- its crew, on deck before anyone boards
			var on_board := 0
			for c in es._crew:
				var lp: Vector3 = es.to_local(c["node"].global_position)
				if c["node"].visible and absf(lp.y - 0.32) < 0.1 and absf(lp.x) < 2.9 and lp.z > -8.0 and lp.z < 6.6:
					on_board += 1
			check("the pirate ship's crew stand on its deck (%d of %d)" % [on_board, es._crew.size()], on_board == 6)
			check("...cutlasses out for the fight (helmsman at the wheel)", es._crew.slice(1).all(func(c): return c["node"].armed) and not es._crew[0]["node"].armed)
			# --- boarders (force it)
			var bp: Vector3 = ship.global_position + ship.global_basis.x * 8.0
			es._pos = Vector3(bp.x, 0, bp.z)
			es._heading = ship.global_rotation.y
			es._set_state(4)
			wait = 0.3
			step = 90
		90:
			set_meta("crew_at", es._crew[1]["node"].global_position)
			es._board(ship)
			check("boarders come over the side", es.boarders.size() >= 3)
			check("...leaping", es.boarders.all(func(g): return g.state == 20))
			var b0 = es.boarders[0]
			check("the boarders are the crew who were on deck (same look, from where he stood: %.2f m)" % b0.global_position.distance_to(get_meta("crew_at")),
				b0.look == es._crew[1]["look"] and b0.global_position.distance_to(get_meta("crew_at")) < 0.6)
			var left = es._crew.filter(func(c): return c["node"].visible)
			check("...they're gone from its deck, the rest stay aboard (%d left)" % left.size(), left.size() == es._crew.size() - es.boarders.size() and es._crew[0]["node"].visible)
			wait = 2.5
			step = 10
		10:
			var on_deck := 0
			for g in es.boarders:
				if is_instance_valid(g) and g.global_position.distance_to(ship.global_position) < 8.0 and g.global_position.y > 0.8:
					on_deck += 1
			check("...and land on the crew's deck", on_deck >= 2)
			for g in es.boarders:
				if is_instance_valid(g):
					g.health.take_damage(9999.0)
			# --- sink it
			es.hurtbox.take_hit(siege(9999.0), p)
			check("enough fire and she sinks", es.state == 5)
			wait = 2.5
			step = 11
		11:
			var fl = root.find_children("Flotsam_*", "", true, false)
			check("...leaving plunder on the waves", fl.size() == 1)
			if fl.size() == 1:
				check("...bobbing at the surface", absf(fl[0].global_position.y) < 2.0)
				check("...reachable while swimming", fl[0].interactable.usable_in_water)
			wait = 9.0
			step = 12
		12:
			check("the wreck goes under for good", not is_instance_valid(es))
			# --- the boss fight
			p.global_position = fort.to_global(Vector3(0, 6.4, 2.0))
			p.reset_physics_interpolation()
			ship.place(Vector3(150, 0.5, 40), 0.0)
			p.global_position = fort.to_global(Vector3(0, 6.4, 2.0))
			p.reset_physics_interpolation()
			wait = 1.5
			step = 13
		13:
			check("walking in: Morrow comes for you", boss.in_combat())
			check("boss bar on the HUD", hud()._boss_box.visible)
			check("music: the boss theme", music().current == "boss")
			# phase two
			boss.health.current_health = boss.health.max_health * 0.55
			wait = 0.5
			step = 14
		14:
			check("below 60%: phase two", boss.phase == 2)
			check("...he roars", saw.has("special_roar"))
			check("...and his crew comes over the walls", fort.crew.size() >= 3)
			wait = 2.5
			step = 15
		15:
			# a slam on the player
			for g in fort.crew:
				if is_instance_valid(g):
					g.health.take_damage(9999.0)
			p.global_position = boss.global_position + boss._fwd() * 6.0
			p.reset_physics_interpolation()
			# (the roar may have floored you: back on your feet first)
			if p.current_state_name() == "Downed":
				p.body_model.end_ragdoll()
				p.body_model.reset_pose()
			p.state_machine.force_state("Idle", {})
			p.hurtbox.monitorable = true
			boss._special = ""
			boss._set_state(3)
			boss._attack = "slam"
			boss._begin_special("slam")
			saw["hp_slam"] = p.health_component.current_health
			wait = 2.2
			step = 16
		16:
			check("he leaps and slams down where the ring was", saw.has("special_slam"))
			check("...the shockwave catches you", p.health_component.current_health < float(saw["hp_slam"]) or p.current_state_name() == "Downed")
			boss.health.current_health = boss.health.max_health * 0.25
			wait = 2.4
			step = 17
		17:
			check("below 30%: Red Tide", boss.phase == 3 and boss._red)
			# leave: he resets
			p.global_position = fort.to_global(Vector3(0, 2.0, 60.0))
			p.reset_physics_interpolation()
			wait = 6.5
			step = 18
		18:
			check("everyone left: he heals and goes back", boss.phase == 1 and boss.health.current_health >= boss.health.max_health - 1.0)
			check("...the boss bar goes away", not hud()._boss_box.visible)
			p.global_position = fort.to_global(Vector3(0, 6.4, 2.0))
			p.reset_physics_interpolation()
			wait = 1.2
			step = 19
		19:
			boss.alert()
			var h := HitData.new()
			h.damage = 99999.0
			h.unblockable = true
			boss.hurtbox.take_hit(h, p)
			wait = 0.8
			step = 20
		20:
			check("Morrow falls", boss.state == 14)
			var hoard = fort.get_node_or_null("Hoard")
			check("...his hoard appears", hoard != null)
			if hoard:
				var ids := []
				for s in hoard.contents:
					ids.append(s.item.id)
				check("...with his cutlass in it", "morrow_cutlass" in ids)
				hoard.take_all(p)
			wait = 0.5
			step = 21
		21:
			check("the cutlass is yours", p.inventory_component.count("morrow_cutlass") == 1)
			check("...and the hoard is remembered", root.get_node("GameManager").opened.has("redtide_hoard"))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
