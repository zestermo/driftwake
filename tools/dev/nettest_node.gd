extends Node
## Co-op test helper: the same node (/root/NetTest) on the host and the
## client. The client sends commands, the host runs them and replies.

var replies: Dictionary = {}


func net() -> Node:
	return get_node("/root/Net")


func ask(name_: String, args: Array = []) -> void:
	replies.erase(name_)
	cmd.rpc_id(1, name_, args)


func got(name_: String) -> bool:
	return replies.has(name_)


@rpc("any_peer", "call_remote", "reliable")
func reply(name_: String, result) -> void:
	replies[name_] = result


@rpc("any_peer", "call_remote", "reliable")
func cmd(name_: String, args: Array) -> void:
	var from := multiplayer.get_remote_sender_id()
	var r = _run(name_, args, from)
	reply.rpc_id(from, name_, r)


func _world() -> Node:
	return get_tree().current_scene


## The chain as this machine has it: its state and every chain island standing
## (the host's and the guest's are compared).
func chain_report() -> Dictionary:
	var n := net()
	var gm := get_node("/root/GameManager")
	var w := get_tree().get_first_node_in_group("world_gen")
	var isles := {}
	for id in w.chain_islands.keys():
		var isl = w.chain_islands[id]
		var crew: Array = []
		for g in isl.get_node("Site_camp/Camp").grunts:
			if is_instance_valid(g) and int(g.state) != 14:
				crew.append([n.key_of(g), str(g.title)])
		crew.sort()
		var people: Array = []
		for c in isl.get_children():
			if c.is_in_group("npcs"):
				people.append([c.npc_name, c.dialogue_id, c.shop_id])
		people.sort()
		var chests: Array = []
		for b in isl.find_children("*", "LootBag", true, false):
			if not b.is_queued_for_deletion() and b.save_id != "":
				chests.append(b.save_id)
		chests.sort()
		var arena = isl.get_node("Site_boss/Arena")
		isles[int(id)] = {"name": isl.island_name, "pos": isl.position, "radius": isl.radius, "sites": isl.sites,
			"crew": crew, "people": people, "chests": chests,
			"ape": n.key_of(arena.boss) if is_instance_valid(arena.boss) else ""}
	var ids: Array = isles.keys()
	ids.sort()
	return {"seed": gm.chain_seed, "at": gm.chain_at, "set": gm.chain_set, "since": gm.chain_since,
		"is_set": gm.log_pose_set(), "ready": w.chain_ready(), "ids": ids, "isles": isles, "opened": gm.opened.keys()}


func _run(name_: String, args: Array, from: int):
	var n := net()
	var lp = n.local_player
	match name_:
		"report":
			var enemies := {}
			for e in get_tree().get_nodes_in_group("net_sync"):
				if e.get("health") == null:
					continue
				enemies[n.key_of(e)] = [e.global_position, int(e.state), e.health.current_health, e.health.max_health,
					float(e.get_meta("min_hp", e.health.max_health))]
			var pup = n.players.get(from)
			var camp = _world().find_children("SmugglersCamp", "", true, false)
			var burned: Array = get_node("/root/GameManager").burned.keys()
			return {
				"host_pos": lp.global_position, "host_hp": lp.health_component.current_health,
				"puppet_pos": pup.global_position if pup else Vector3.INF,
				"puppet_state": pup.current_state_name() if pup else "",
				"puppet_bleeding": pup.is_bleeding() if pup else false,
				"puppet_action": pup.body_model.current_action() if pup else "",
				"puppet_head": pup.body_model.head.global_position if pup else Vector3.INF,
				"puppet_hips": pup.body_model.hips.global_position if pup else Vector3.INF,
				"puppet_swim": pup.body_model.swimming if pup else false,
				"puppet_name": pup.display_name() if pup else "",
				"puppet_plate": pup._nameplate.text if pup and pup._nameplate else "",
				"host_name": lp.display_name(),
				"surface_at_puppet": get_node("/root/Ocean").get_wave_height(pup.global_position) if pup else 0.0,
				"enemies": enemies, "roster": n.roster.size(), "players": n.players.size(),
				"ship_owner": n.ship_owner, "ship_pos": n._ship().global_position,
				"ship_sail": n._ship().sail, "ship_speed": n._ship().speed,
				"puppet_on_ship": n._ship().to_local(pup.global_position) if pup else Vector3.INF,
				"host_on_ship": n._ship().to_local(lp.global_position), "host_aboard": n._ship().aboard(lp.global_position),
				"host_on_floor": lp.is_on_floor(),
				"claims": get_node("/root/GameManager").fruit_claims.duplicate(),
				"camp_gen": camp[0].gen if camp.size() > 0 else -1,
				"burned": burned, "time": n.time(),
			}
		"tp":
			lp.global_position = args[0]
			lp.velocity = Vector3.ZERO
			lp.reset_physics_interpolation()
			return true
		"calm":
			# keep the enemies from swinging on their own (and note the
			# lowest health each one reaches)
			for e in get_tree().get_nodes_in_group("enemies"):
				var en = e
				e.health.health_changed.connect(func(c, _m): en.set_meta("min_hp", minf(float(en.get_meta("min_hp", 99999.0)), c)))
				_calm(e)
			return true
		"board_setup":
			# the crew's ship out in open sea, the host aboard, a pirate ship lashed
			# alongside to starboard (every pirate's AI held: they're placed by hand)
			var ship = n._ship()
			var es = null
			for s in get_tree().get_nodes_in_group("enemy_ships"):
				s.set_physics_process(false)
				if es == null and s._crew.size() >= 6:
					es = s
			set_meta("es", n.key_of(es))
			var sc: Vector2 = _world().get_node("Islands").starter_center
			var c := Vector3(sc.x + 420.0, 0, sc.y)
			for k in range(32):
				var a := k * TAU / 32.0
				c = Vector3(sc.x + cos(a) * 420.0, 0, sc.y + sin(a) * 420.0)
				if es.huntable_at(c) and es.huntable_at(c + Vector3(30, 0, 0)) and es.huntable_at(c - Vector3(30, 0, 0)):
					break
			ship.place(Vector3(c.x, 0.5, c.z), 0.0)
			# (her node keeps its old transform until the next physics step: sync_to_physics)
			var xf := Transform3D(Basis.IDENTITY, Vector3(c.x, ship.global_position.y, c.z))
			var bp: Vector3 = xf * Vector3(EnemyShip.ALONGSIDE, 0, 0)
			es._pos = Vector3(bp.x, 0, bp.z)
			es._heading = 0.0
			es.speed = 0.0
			es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), Vector3(bp.x, 0.85, bp.z))
			es.reset_physics_interpolation()
			lp.global_position = xf * Vector3(0, 1.2, 3.0)
			lp.velocity = Vector3.ZERO
			lp.reset_physics_interpolation()
			return n.key_of(es)
		"board_now":
			var es = n.node_of(str(get_meta("es")))
			var before: Array = es.boarders.duplicate()
			es._board(n._ship())
			var keys: Array = []
			for g in es.boarders:
				if g not in before:
					_calm(g)
					keys.append(n.key_of(g))
			set_meta("boarded_t", n.time())
			return keys
		"deck_fight":
			var es = n.node_of(str(get_meta("es")))
			es._start_deck_fight()
			for g in es.deck_crew:
				_calm(g)
			return es.deck_crew.size()
		"boarders":
			# every crewman turned grunt: [deck-relative spot, state, hp, crew index]
			var es = n.node_of(str(get_meta("es")))
			var men := {}
			var shown: Array = []
			for i in range(es._crew.size()):
				var c: Dictionary = es._crew[i]
				var g = c.get("grunt")
				if is_instance_valid(g):
					men[n.key_of(g)] = [n.deck_pack(g.global_position), int(g.state), g.health.current_health, i]
				elif not c["gone"] and c["node"].visible:
					shown.append(i)
			return {"men": men, "shown": shown, "es": n.key_of(es), "ship": n.key_of(n._ship()),
				"boarded_t": float(get_meta("boarded_t", INF)), "crew_gone": es._crew_gone}
		"attack":
			var g = n.node_of(str(args[0]))
			var at: Vector3 = args[1]
			var dir: Vector3 = args[2]
			g.humanoid.seated = false
			g.global_position = at + dir * 1.5
			g.reset_physics_interpolation()
			g._yaw = atan2(dir.x, dir.z)
			g.facing.rotation.y = g._yaw
			g._has_token = true
			g._attack = "combo"
			g._swing_i = 1
			g._start_wind()
			return n.key_of(g)
		"shoot":
			var hd := HitData.new()
			hd.ranged = true
			hd.damage = 15.0
			hd.knockback_force = 4.0
			var g = n.node_of(str(args[2]))
			return n.shot(args[0], args[1], hd, g)
		"revive":
			n.revive(int(args[0]))
			return true
		"action":
			lp.body_model.play(str(args[0]), float(args[1]))
			return true
		"host_pistols":
			var pistol: ItemData = load("res://resources/items/pistol.tres")
			lp.inventory_component.add_item(pistol, 2)
			lp.equip_weapon(pistol, false)
			lp.set_offhand(pistol)
			lp.sheathe_weapon(true)
			lp.draw_weapon(true)
			return true
		"respawn_camp":
			var camp = _world().find_children("SmugglersCamp", "", true, false)[0]
			camp.gen += 1
			camp._spawn_all()
			n.spawned(camp, camp.gen)
			return camp.gen
		"drops":
			var out := {}
			for b in _world().find_children("Drop_*", "", false, false):
				var ids: Array = []
				for c in b.contents:
					ids.append([c.item.id, c.quantity])
				out[str(b.name)] = ids
			return {"drops": out, "inv": lp.inventory_component.count(str(args[0])) if args.size() > 0 else 0}
		"host_drop":
			var it = load("res://resources/items/%s.tres" % str(args[0]))
			lp.inventory_component.add_item(it, 1)
			var idx := -1
			for i in range(lp.inventory_component.items.size()):
				if lp.inventory_component.items[i].item == it:
					idx = i
			return lp.drop_from_bag(idx, 1)
		"host_take":
			var b = _world().get_node_or_null(str(args[0]))
			if b == null:
				return false
			b.take_all(lp)
			return true
		"storage":
			return get_node("/root/GameManager").stored_count(str(args[0]))
		"net8":
			var hud = get_tree().get_first_node_in_group("hud")
			var balls := 0
			for b in _world().find_children("*", "Cannonball", true, false):
				balls += 1
			var ships := {}
			for s in get_tree().get_nodes_in_group("enemy_ships"):
				ships[n.key_of(s)] = s.global_position
			var bosses := {}
			for b in get_tree().get_nodes_in_group("bosses"):
				if str(b.name).begins_with("Morrow"):
					bosses[n.key_of(b)] = b.global_position
			return {"pings": n.pings.duplicate(), "markers": hud.markers.markers.keys() if hud and hud.markers else [],
				"seats": n.seats.duplicate(), "balls": balls, "hull": n._ship().hull, "ships": ships, "bosses": bosses,
				"weather": [get_node("/root/Weather").world_time(), get_node("/root/Weather").current_state(), get_node("/root/Weather").forced]}
		"weather":
			get_node("/root/Weather").force(int(args[0]))
			return true
		"kneel_revive":
			# walk up to the downed client and hold F
			var pup = n.players.get(from)
			lp.global_position = pup.global_position + Vector3(1.0, 0.3, 0)
			lp.velocity = Vector3.ZERO
			lp.reset_physics_interpolation()
			Input.action_press("interact")
			get_tree().create_timer(4.0).timeout.connect(func(): Input.action_release("interact"))
			return true
		"hull_hit":
			n._ship().hull_hit(float(args[0]), n._ship().global_position)
			# and a hole for certain, for the damage sync
			n._ship().add_breach(1.0, -3.0)
			return n._ship().hull
		"breaches":
			return n._ship().breaches.size()
		"refit":
			var k: Dictionary = get_node("/root/GameManager").ship_kit.duplicate()
			k["guns"] = true
			k["figure"] = 2
			n.set_ship_kit(k)
			return true
		"boss_aoe":
			for b in get_tree().get_nodes_in_group("bosses"):
				if str(b.name).begins_with("Morrow"):
					b._aoe(args[0], 3.0, 10.0, false)
			return true
		"seat_try":
			return n.request_seat(n.node_of(str(args[0])))
		"fx_count":
			return _world().find_children("*", "CPUParticles3D", true, false).size()
		"chain":
			return chain_report()
		"chain_skip":
			# F7's way: the host moves the world clock on for everyone
			var wx = get_node("/root/Weather")
			n.everyone("_all_weather", [wx.forced, wx.forced_at, wx.world_offset + float(args[0])])
			return true
		"chest_take":
			for b in _world().find_children("*", "LootBag", true, false):
				if b.save_id == str(args[0]) and not b.is_queued_for_deletion():
					b.take_all(lp)
					return true
			return false
		"quit":
			get_tree().create_timer(0.5).timeout.connect(func(): get_tree().quit())
			return true
		"expect_leave":
			# the client is about to leave: check its puppet goes, then quit
			var gone_id := from
			get_tree().create_timer(2.5).timeout.connect(func():
				var ok: bool = not n.players.has(gone_id) and not n.roster.has(gone_id) and get_tree().current_scene.get_node_or_null("P%d" % gone_id) == null
				print(("PASS " if ok else "FAIL ") + "host: the client's captain left (players %d)" % n.players.size())
				print("HOST RESULT ", "OK" if ok else "FAILED")
				_quit_when_alone(60.0))
			return true
	return null


## Keep an enemy from swinging or shooting on its own.
func _calm(e: Node) -> void:
	e._cooldown = 999.0
	if e.get("_pistol_cd") != null:
		e._pistol_cd = 999.0
		e._shot_cd = 999.0
		e._shove_cd = 999.0
		e._peril_cd = 999.0


func _quit_when_alone(left: float) -> void:
	if net().roster.size() <= 1 or left <= 0.0:
		get_tree().quit()
		return
	get_tree().create_timer(0.5).timeout.connect(func(): _quit_when_alone(left - 0.5))
