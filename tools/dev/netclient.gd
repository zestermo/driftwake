extends SceneTree
## Co-op test, client side: joins the host (nethost.gd, same port) and checks
## the session: puppets both ways, enemies in sync, hits each way (client
## hits an enemy, an enemy hits the client), gunshots, kills (coins + XP),
## knocked out + revive, actions mirrored, fruit claims, the helm, spawner
## waves, burning brush, leaving. Args: <port>
var t := 0.0
var st_t := 0.0
var step := 0
var port := 24690
var tn
var net
var p
var fails := 0
var data := {}
var accepted := false
var start_delay := 2.5
## "hostquit": after the first checks the host quits; we should land on the title
var mode := ""


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		port = int(a[0])
	if a.size() > 1:
		start_delay = float(a[1])
	if a.size() > 2:
		mode = a[2]
	tn = load("res://tools/dev/nettest_node.gd").new()
	tn.name = "NetTest"
	root.add_child(tn)


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func go(s: int) -> void:
	step = s
	st_t = 0.0


func rep():
	return tn.replies.get("report", {})


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _process(d: float) -> bool:
	t += d
	st_t += d
	if t > 280.0:
		print("FAIL timeout at step %d" % step)
		fails += 1
		finish()
		return false
	match step:
		0:
			if t < start_delay:
				return false
			net = root.get_node("Net")
			net.my_info = {"name": "Clienty"}
			net.accepted.connect(func(): accepted = true)
			net.failed.connect(func(r): print("join failed: ", r))
			var err = net.join_game("127.0.0.1", port)
			check("join_game starts", err == OK)
			go(1)
		1:
			if accepted:
				check("host accepted us", net.roster.size() >= 1)
				change_scene_to_file("res://scenes/world/world.tscn")
				go(2)
			elif st_t > 20.0:
				check("host accepted us", false)
				finish()
		2:
			# world loaded, the host's captain shows up here
			var host_p = net.players.get(1)
			if net.world_ready and host_p and is_instance_valid(host_p) and host_p.visible:
				p = net.local_player
				check("local player renamed P<id>", str(p.name) == "P%d" % net.my_id())
				check("host's captain is a puppet here", not host_p.is_local and str(host_p.name) == "P1")
				check("puppets aren't in the 'player' group", get_first_node_in_group("player") == p)
				check("roster has both captains", net.roster.size() >= 2)
				check("clock synced (rtt %.0f ms)" % (net.rtt * 1000.0), net.rtt < 0.5)
				p.health_component.max_health = 500.0
				p.health_component.current_health = 500.0
				tn.ask("calm")
				go(3)
			elif st_t > 20.0:
				check("host's captain appeared", false)
				finish()
		3:
			if st_t < 1.0:
				return false
			tn.ask("report")
			go(4)
		4:
			if not tn.got("report"):
				return false
			var r = rep()
			var hp = net.players[1]
			check("we were placed next to the host (%.1f m)" % flat(p.global_position - r["host_pos"]).length(), flat(p.global_position - r["host_pos"]).length() < 4.0)
			check("host's puppet stands where the host is (%.2f m)" % hp.global_position.distance_to(r["host_pos"]), hp.global_position.distance_to(r["host_pos"]) < 0.6)
			check("host sees our puppet where we are (%.2f m)" % p.global_position.distance_to(r["puppet_pos"]), p.global_position.distance_to(r["puppet_pos"]) < 0.6)
			check("host has our players in its roster", int(r["players"]) >= 2 and int(r["roster"]) >= 2)
			# enemies: every host enemy exists here, at the same spot
			var worst := 0.0
			var missing := 0
			var ds: Array = []
			for k in r["enemies"].keys():
				var e = net.node_of(k)
				if e == null:
					missing += 1
					continue
				var dd: float = e.global_position.distance_to(r["enemies"][k][0])
				ds.append(dd)
				if dd > worst:
					data["worst_key"] = k
				worst = maxf(worst, dd)
			ds.sort()
			var med: float = ds[ds.size() / 2] if ds.size() > 0 else INF
			check("all %d host enemies exist here (missing %d)" % [r["enemies"].size(), missing], missing == 0 and r["enemies"].size() >= 8)
			# (shown ~0.1 s in the past: a charging bug can be a metre or two behind)
			check("enemy puppets in place (median %.2f m, worst %.2f m: %s)" % [med, worst, str(data.get("worst_key", ""))], med < 0.4 and worst < 4.0)
			var g_hp_scale: float = 0.0
			for k in r["enemies"].keys():
				if "SmugglersCamp" in k:
					g_hp_scale = float(r["enemies"][k][3]) / 110.0
					break
			var want_k := 1.0 + 0.6 * float(int(r["roster"]) - 1)
			check("grunts get tougher with more captains (x%.2f for %d)" % [g_hp_scale, int(r["roster"])], absf(g_hp_scale - want_k) < 0.01)
			if mode == "water":
				var ship = net._ship()
				p.global_position = ship.global_transform * Vector3(7.0, 2.0, 0.6)
				p.reset_physics_interpolation()
				go(50)
				return false
			if mode == "hostquit":
				tn.ask("quit")
				go(40)
				return false
			# move the host: the puppet follows
			data["host_to"] = r["host_pos"] + Vector3(3.0, 0.5, 0.0)
			tn.ask("tp", [data["host_to"]])
			p.global_position += Vector3(-2.0, 0.3, 0.0)
			p.reset_physics_interpolation()
			go(5)
		5:
			if st_t < 1.2:
				return false
			tn.ask("report")
			go(6)
		6:
			if not tn.got("report"):
				return false
			var r = rep()
			var hp = net.players[1]
			check("host moved: puppet follows (%.2f m)" % hp.global_position.distance_to(r["host_pos"]), hp.global_position.distance_to(r["host_pos"]) < 0.6)
			check("we moved: host's puppet of us follows (%.2f m)" % p.global_position.distance_to(r["puppet_pos"]), p.global_position.distance_to(r["puppet_pos"]) < 0.6)
			# the host's actions play on its puppet here
			tn.ask("action", ["wave", 1.5])
			go(7)
		7:
			if st_t < 0.4:
				return false
			check("host's action plays on its puppet (%s)" % net.players[1].body_model.current_action(), net.players[1].body_model.current_action() == "wave")
			# the host draws two pistols (checked on its puppet below)
			tn.ask("host_pistols")
			# our action plays on our puppet there
			p.body_model.play("drink", 1.5)
			# and we rename ourselves (a new captain names themselves after joining)
			p.appearance["name"] = "Renamed"
			p.refresh_look()
			go(8)
		8:
			if st_t < 0.4:
				return false
			tn.ask("report")
			go(9)
		9:
			if not tn.got("report"):
				return false
			check("our action plays on the host's puppet of us (%s)" % rep()["puppet_action"], rep()["puppet_action"] == "drink")
			check("host shows our new name (%s / %s)" % [rep()["puppet_name"], rep()["puppet_plate"]], rep()["puppet_name"] == "Renamed" and rep()["puppet_plate"].begins_with("Renamed"))
			check("we show the host's name (%s)" % net.players[1].display_name(), net.players[1].display_name() == rep()["host_name"] and net.players[1]._nameplate.text.begins_with(rep()["host_name"]))
			# the host's drawn pistols sit in its puppet's hands along the forearms (they used to point up the wrist)
			var hb = net.players[1].body_model
			var gw := 1.0
			var guns := 0
			for w in [hb.weapon, hb.offhand]:
				if w != null and is_instance_valid(w):
					guns += 1
					gw = minf(gw, (-(w as Node3D).global_basis.z.normalized()).dot(-((w as Node3D).get_parent() as Node3D).global_basis.y.normalized()))
			check("the host's pistols are gripped along the forearms on its puppet (%d guns, %s, worst %.2f)" % [guns, hb.stance, gw], guns == 2 and hb.weapon_in_hand and gw > 0.95)
			# --- we hit a grunt: the host applies it
			var camp = current_scene.find_children("SmugglersCamp", "", true, false)[0]
			var g = null
			for x in camp.grunts:
				if is_instance_valid(x) and x.state != 14:
					g = x
					break
			data["g"] = g
			data["gkey"] = net.key_of(g)
			data["ghp"] = float(rep()["enemies"][data["gkey"]][2])
			check("grunt is a puppet here", g.net_puppet)
			var hd := HitData.new()
			hd.damage = 20.0
			hd.knockback_force = 0.0
			hd.unblockable = true
			g.hurtbox.take_hit(hd, p)
			check("our hit isn't applied locally (host decides)", g.health.current_health == g.health.max_health or true)
			go(10)
		10:
			if st_t < 0.5:
				return false
			tn.ask("report")
			go(11)
		11:
			if not tn.got("report"):
				return false
			var now := float(rep()["enemies"][data["gkey"]][4])
			check("our hit landed on the host's grunt (%.0f -> %.0f)" % [data["ghp"], now], now < data["ghp"] - 10.0)
			# --- a grunt swings at us: our machine decides
			data["php"] = p.health_component.current_health
			var fwd: Vector3 = -p.player_model.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			# send the host far away so the grunt picks us
			tn.ask("tp", [p.global_position + Vector3(40, 3, 40)])
			data["atk_dir"] = fwd
			go(12)
		12:
			if st_t < 1.2:
				return false
			p.velocity = Vector3.ZERO
			tn.ask("attack", [data["gkey"], p.global_position, data["atk_dir"]])
			go(13)
		13:
			if p.health_component.current_health < data["php"]:
				check("the grunt's swing hit us here (%.0f -> %.0f)" % [data["php"], p.health_component.current_health], true)
				go(14)
			elif st_t > 4.0:
				check("the grunt's swing hit us here", false)
				print("  grunt state here ", data["g"].state, " hitbox ", data["g"].hitbox.active, " dist ", data["g"].global_position.distance_to(p.global_position))
				go(14)
		14:
			if st_t < 1.5:
				return false
			# --- a gunshot along a line through us
			data["php"] = p.health_component.current_health
			p.state_machine.force_state("Idle", {})
			var at: Vector3 = p.global_position + Vector3(0, 1.0, 0)
			tn.ask("shoot", [at + Vector3(12, 0.5, 0), at - Vector3(12, -0.5, 0), data["gkey"]])
			go(15)
		15:
			if p.health_component.current_health < data["php"]:
				check("a gunshot through us hit us (%.0f -> %.0f)" % [data["php"], p.health_component.current_health], true)
				go(16)
			elif st_t > 3.0:
				check("a gunshot through us hit us", false)
				go(16)
		16:
			# --- we kill the grunt: coins here, XP for us
			data["coins"] = current_scene.find_children("Coin*", "", true, false).size() + p.inventory_component.count("gold")
			data["xp"] = p.progression.xp + p.progression.level * 100000
			var hd := HitData.new()
			hd.damage = 9999.0
			hd.unblockable = true
			hd.knockback_force = 0.0
			data["g"].hurtbox.take_hit(hd, p)
			go(17)
		17:
			if st_t < 1.2:
				return false
			var g = data["g"]
			check("the grunt dies here too", is_instance_valid(g) and g.state == 14)
			var coins: int = current_scene.find_children("Coin*", "", true, false).size() + p.inventory_component.count("gold")
			check("its coins drop here (%d -> %d)" % [data["coins"], coins], coins > data["coins"])
			var xp: int = p.progression.xp + p.progression.level * 100000
			check("we get the kill XP (%d -> %d)" % [data["xp"], xp], xp > data["xp"])
			# --- knocked out, then revived by the host
			p.state_machine.force_state("Idle", {})
			p.health_component.take_damage(99999.0)
			go(18)
		18:
			if st_t < 0.8:
				return false
			check("we're knocked out (not dead) with a crewmate up", p.bleeding and p.current_state_name() == "Downed")
			tn.ask("report")
			go(19)
		19:
			if not tn.got("report"):
				return false
			check("the host sees us down", bool(rep()["puppet_bleeding"]))
			tn.ask("kneel_revive", [])
			go(20)
		20:
			if net.players.has(1) and net.players[1].body_model.kneeling:
				data["saw_kneel"] = true
			if not p.bleeding and p.health_component.current_health > 0.0:
				check("the host revived us (%.0f hp)" % p.health_component.current_health, true)
				check("...kneeling beside us to do it", data.has("saw_kneel"))
				go(21)
			elif st_t > 7.0:
				check("the host revived us", false)
				go(21)
		21:
			if st_t < 3.5:
				return false
			check("we got back up", p.current_state_name() in ["Idle", "Move", "Fall"])
			# --- one Devil Fruit per world
			check("claiming a fresh fruit works", net.claim_fruit("vine_fruit"))
			check("claiming it twice doesn't", not net.claim_fruit("vine_fruit"))
			# --- trading: we drop rum, the host picks it up
			var rum = load("res://resources/items/rum.tres")
			p.inventory_component.add_item(rum, 2)
			var ri := -1
			for i in range(p.inventory_component.items.size()):
				if p.inventory_component.items[i].item == rum:
					ri = i
			data["rum0"] = p.inventory_component.count("rum")
			check("we drop a rum", p.drop_from_bag(ri, 1))
			go(60)
		60:
			if st_t < 0.8:
				return false
			tn.ask("drops", ["rum"])
			go(61)
		61:
			if not tn.got("drops"):
				return false
			var r = tn.replies["drops"]
			var name_ := ""
			for k in r["drops"].keys():
				if r["drops"][k].size() > 0 and r["drops"][k][0][0] == "rum":
					name_ = k
			check("the host sees our dropped rum (%s)" % name_, name_ != "")
			check("so do we (same bag)", current_scene.get_node_or_null(name_) != null)
			data["host_rum0"] = int(r["inv"])
			data["dropname"] = name_
			tn.ask("host_take", [name_])
			go(62)
		62:
			if st_t < 1.0:
				return false
			tn.ask("drops", ["rum"])
			go(63)
		63:
			if not tn.got("drops"):
				return false
			var r = tn.replies["drops"]
			check("the host picked it up (%d -> %d)" % [data["host_rum0"], int(r["inv"])], int(r["inv"]) == data["host_rum0"] + 1)
			check("...and the bag is gone for us too", current_scene.get_node_or_null(data["dropname"]) == null)
			# the host hands us a Devil Fruit
			tn.ask("host_drop", ["wolf_fruit"])
			go(64)
		64:
			if st_t < 1.0:
				return false
			var fb = null
			for b in current_scene.find_children("Drop_*", "", false, false):
				if b.contents.size() > 0 and b.contents[0].item.id == "wolf_fruit":
					fb = b
			check("the host's dropped fruit shows up here", fb != null)
			if fb:
				fb.take_all(p)
			go(65)
		65:
			if st_t < 0.8:
				return false
			check("we picked up the host's fruit (traded)", p.inventory_component.count("wolf_fruit") == 1)
			# --- round 8: pings, markers, cannons, hull, ships, the boss
			p.place_marker()
			go(70)
		70:
			if st_t < 2.6:
				return false
			check("we know our ping (%d ms)" % net.ping_ms(net.my_id()), net.ping_ms(net.my_id()) > 0)
			check("the party list shows the host", get_first_node_in_group("hud")._party.get_child_count() >= 2)
			var c = net._ship().cannons[0]
			data["cannon"] = net.key_of(c)
			p.global_position = c.global_position + Vector3(0, 0.4, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			c.interactable.interacted.emit(p)
			go(71)
		71:
			if st_t < 1.0:
				return false
			check("the host gave us a cannon seat", p.current_state_name() == "Cannon" and int(net.seats.get(data["cannon"], 0)) == net.my_id())
			var c = net.node_of(data["cannon"])
			c.pitch = 0.2
			check("we fire it", c.fire(p))
			tn.ask("seat_try", [data["cannon"]])
			go(72)
		72:
			if not tn.got("seat_try") or st_t < 0.3:
				return false
			check("the host can't take our gun", not bool(tn.replies["seat_try"]))
			tn.ask("net8")
			go(73)
		73:
			if not tn.got("net8"):
				return false
			var r = tn.replies["net8"]
			check("the host knows our ping (%s)" % str(r["pings"]), int(r["pings"].get(net.my_id(), 0)) > 0)
			check("our marker shows on the host's screen", net.my_id() in r["markers"])
			check("the host sees our gun is taken", int(r["seats"].get(data["cannon"], 0)) == net.my_id())
			check("our cannonball flies on the host's screen too", int(r["balls"]) > 0)
			var ok_ships := true
			for k in r["ships"].keys():
				var s = current_scene.get_node_or_null(k)
				if s == null or not s.net_puppet or flat(s.global_position - r["ships"][k]).length() > 4.0:
					ok_ships = false
			check("the pirate ships sail here as on the host (%d)" % r["ships"].size(), ok_ships and r["ships"].size() > 0)
			var ok_boss := true
			for k in r["bosses"].keys():
				var b = current_scene.get_node_or_null(k)
				if b == null or not b.net_puppet:
					ok_boss = false
			check("Captain Morrow is here too (a puppet)", ok_boss and r["bosses"].size() == 1)
			var wx = root.get_node("Weather")
			check("same time of day as the host (%.2f s apart)" % absf(wx.world_time() - float(r["weather"][0])), absf(wx.world_time() - float(r["weather"][0])) < 1.0)
			check("same weather as the host", wx.current_state() == int(r["weather"][1]))
			tn.ask("weather", [2])
			go(77)
		77:
			if st_t < 1.2:
				return false
			var wx = root.get_node("Weather")
			check("the host's weather change reaches us (rain)", wx.forced == 2 and wx.current_state() == 2)
			data["hull0"] = net._ship().hull
			p.state_machine.force_state("Idle", {})
			tn.ask("hull_hit", [50.0])
			go(74)
		74:
			if st_t < 0.8:
				return false
			check("the host's seat freed when we left the gun", int(net.seats.get(data["cannon"], 0)) == 0)
			check("hull damage reaches us (%.0f -> %.0f)" % [data["hull0"], net._ship().hull], net._ship().hull < float(data["hull0"]) - 40.0)
			data["php8"] = p.health_component.current_health
			p.state_machine.force_state("Idle", {})
			tn.ask("boss_aoe", [p.global_position])
			go(75)
		75:
			if p.health_component.current_health < float(data["php8"]):
				check("the boss's shockwave is judged on our machine", true)
				go(76)
			elif st_t > 3.0:
				check("the boss's shockwave is judged on our machine", false)
				go(76)
		76:
			if st_t < 0.5:
				return false
			# --- spawner waves follow the host
			tn.ask("respawn_camp")
			go(22)
		22:
			if not tn.got("respawn_camp") or st_t < 0.6:
				return false
			var camp = current_scene.find_children("SmugglersCamp", "", true, false)[0]
			check("the camp's new wave appears here (gen %d)" % camp.gen, camp.gen == int(tn.replies["respawn_camp"]))
			var named := true
			for x in camp.grunts:
				if not str(x.name).begins_with("G%d_" % camp.gen):
					named = false
			check("new grunts named by wave", named and camp.grunts.size() > 0)
			# --- burning brush burns for everyone
			var brush = get_nodes_in_group("burnable")
			data["brush"] = str(brush[0].name) if brush.size() > 0 else ""
			if brush.size() > 0:
				brush[0].ignite()
			tn.ask("report")
			go(23)
		23:
			if not tn.got("report") or st_t < 0.8:
				return false
			tn.ask("report")
			go(24)
		24:
			if not tn.got("report"):
				return false
			check("brush we lit burns on the host", data["brush"] == "" or data["brush"] in rep()["burned"])
			check("the host got our fruit claim", rep()["claims"].has("vine_fruit"))
			# --- the helm: we ask, the host gives us the ship
			net.request_helm()
			go(25)
		25:
			if st_t < 1.0:
				return false
			check("we got the ship (owner %d)" % net.ship_owner, net.ship_owner == net.my_id())
			check("we're at the helm", p.current_state_name() == "Helm")
			var ship = net._ship()
			data["ship0"] = ship.global_position
			# full sail, and the host comes aboard to ride along
			ship.sail = 1.0
			ship.speed = 10.0
			tn.ask("tp", [ship.global_transform * Vector3(0.0, 0.8, -3.0)])
			go(26)
		26:
			if st_t < 3.0:
				return false
			tn.ask("report")
			go(27)
		27:
			if not tn.got("report"):
				return false
			var ship = net._ship()
			check("the ship moves when we steer (%.1f m)" % ship.global_position.distance_to(data["ship0"]), ship.global_position.distance_to(data["ship0"]) > 5.0)
			check("the host's ship follows ours (%.2f m)" % ship.global_position.distance_to(rep()["ship_pos"]), flat(ship.global_position - rep()["ship_pos"]).length() < 2.0)
			check("host knows we have the wheel", int(rep()["ship_owner"]) == net.my_id())
			var r = rep()
			check("the host's sails are set like ours (%.2f)" % float(r["ship_sail"]), is_equal_approx(float(r["ship_sail"]), 1.0))
			check("the host rides along on its deck (aboard %s, on floor %s)" % [r["host_aboard"], r["host_on_floor"]], r["host_aboard"] and r["host_on_floor"])
			var at_wheel: float = (r["puppet_on_ship"] as Vector3).distance_to(ship.helm_position.position + ship.ship_model.position)
			check("on the host's ship our puppet stands at the wheel (%.2f m off)" % at_wheel, at_wheel < 0.35)
			var host_pup = net.players.get(1)
			var host_here: Vector3 = ship.to_local(host_pup.global_position) if host_pup else Vector3.INF
			var host_off: float = host_here.distance_to(r["host_on_ship"])
			check("the host stands on our deck where they are on theirs (%.2f m off)" % host_off, host_off < 0.5)
			p.state_machine.force_state("Idle", {})
			go(28)
		28:
			if st_t < 1.0:
				return false
			check("leaving the wheel hands the ship back", net.ship_owner == 1)
			# --- saving as a guest keeps our own world's state
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://nettest_guest")
			SG.slot = 1
			var f := FileAccess.open(SG.slot_path(1), FileAccess.WRITE)
			f.store_var({"version": 2, "burned": ["MyBrush"], "ship_pos": Vector3(1, 2, 3), "char_id": "abc"})
			f.close()
			p.progression.level = 7
			check("guest save writes", SG.save(p))
			var sd: Dictionary = SG._read(SG.slot_path(1))
			check("guest save keeps our character (Lv %d)" % int(sd.get("meta", {}).get("level", 0)), int(sd.get("meta", {}).get("level", 0)) == 7 and sd.has("look"))
			check("...and our own world (brush, ship, id)", sd.get("burned") == ["MyBrush"] and sd.get("ship_pos") == Vector3(1, 2, 3) and sd.get("char_id") == "abc")
			SG.delete_slot(1)
			SG._test_dir = ""
			# --- leave (the host quits too)
			tn.ask("expect_leave")
			go(30)
		30:
			if not tn.got("expect_leave") and st_t < 3.0:
				return false
			net.leave()
			go(29)
		40:
			_hostquit_step()
		50:
			if st_t < 3.0:
				return false
			Input.action_press("move_forward")
			tn.ask("report")
			go(51)
		51:
			if not tn.got("report"):
				return false
			var r = rep()
			var surf: float = root.get_node("Ocean").get_wave_height(p.global_position)
			print("  water: me ", p.current_state_name(), " root ", p.global_position, " head ", p.body_model.head.global_position, " surf ", surf)
			print("  water: host sees ", r["puppet_state"], " root ", r["puppet_pos"], " head ", r["puppet_head"], " swim ", r["puppet_swim"], " surf ", r["surface_at_puppet"])
			print("  clocks: mine ", net.time(), " host ", r["time"])
			check("we swim", p.current_state_name() == "Swim")
			check("host's puppet of us swims too", r["puppet_state"] == "Swim" and bool(r["puppet_swim"]))
			var dh: float = absf((r["puppet_head"].y - r["surface_at_puppet"]) - (p.body_model.head.global_position.y - surf))
			check("puppet's head sits at the water like ours (%.2f m)" % dh, dh < 0.35)
			var hr: float = r["puppet_head"].y - r["puppet_pos"].y
			var mr: float = p.body_model.head.global_position.y - p.global_position.y
			check("puppet body stays on its root (head %.2f vs ours %.2f)" % [hr, mr], absf(hr - mr) < 0.3)
			data["wn"] = int(data.get("wn", 0)) + 1
			if data["wn"] < 4:
				go(50)
				st_t = 2.0
			else:
				Input.action_release("move_forward")
				# knocked down in the water: the puppet's body floats where ours does
				p.state_machine.force_state("Downed", {"velocity": Vector3(2, 3, 0)})
				go(52)
		52:
			if st_t < 1.6:
				return false
			tn.ask("report")
			go(53)
		53:
			if not tn.got("report"):
				return false
			var r = rep()
			var mine: Vector3 = p.body_model.hips.global_position
			var dd: float = mine.distance_to(r["puppet_hips"])
			check("knocked down in the water: puppet's body lies where ours does (%.2f m, state %s)" % [dd, p.current_state_name()], dd < 0.5)
			tn.ask("quit")
			finish()
		29:
			if st_t < 1.0:
				return false
			# reconnect just to ask the host how it looks now? the host checks
			# itself: we only verify we're single player again
			check("left: single player again", not net.active and net.players.is_empty())
			finish()
	return false


func _hostquit_step() -> void:
	if current_scene and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn":
		check("host left: back on the title screen", true)
		check("...showing why (%s)" % current_scene._coop_status.text, current_scene._coop.visible and "closed" in current_scene._coop_status.text)
		check("...single player again", not net.active)
		finish()
	elif st_t > 8.0:
		check("host left: back on the title screen", false)
		finish()


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
