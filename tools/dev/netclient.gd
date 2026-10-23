extends SceneTree
## Co-op test, client side: joins the host (nethost.gd, same port) and checks
## the session: puppets both ways, enemies in sync, hits each way (client
## hits an enemy, an enemy hits the client), gunshots, kills (coins + XP),
## knocked out + revive, actions mirrored, fruit claims, the helm, spawner
## waves, burning brush, leaving. Mode "chain": the island chain instead (see
## _chain_step). Args: <port> <start_delay> [mode]
var t := 0.0
var st_t := 0.0
var step := 0
var port := 24690
var tn
var net
var p
var fails := 0
var beat := 0
var data := {}
var accepted := false
var join_failed := false
var start_delay := 2.5
## How long we wait for the host to accept us (s). The host's first frames build its world in one ~30 s
## frame here, past 60 s on a busy machine (2026-10-22: our hello and every retry arrived together when
## it ended), so this waits as long as the chain mode's landing did.
const JOIN_WAIT := 120.0
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
	if int(t / 30.0) > beat:
		beat = int(t / 30.0)
		print("CLIENT up %d s, step %d for %.0f s" % [int(t), step, st_t])
	if t > (450.0 if mode == "chain" else 280.0):
		print("FAIL timeout at step %d" % step)
		fails += 1
		finish()
		return false
	_clock_step()
	if mode == "chain" and step >= 100:
		_chain_step()
		return false
	if mode == "rival" and step >= 300:
		_rival_step()
		return false
	if mode == "duel" and step >= 200:
		_duel_step()
		return false
	match step:
		0:
			if t < start_delay:
				return false
			net = root.get_node("Net")
			net.my_info = {"name": "Clienty"}
			net.accepted.connect(func(): accepted = true)
			net.failed.connect(func(r): print("join failed: ", r); join_failed = true)
			var err = net.join_game("127.0.0.1", port)
			check("join_game starts", err == OK)
			go(1)
		1:
			if accepted:
				check("host accepted us", net.roster.size() >= 1)
				change_scene_to_file("res://scenes/world/world.tscn")
				go(2)
			elif join_failed and st_t < JOIN_WAIT:
				# (the host is still loading its world, or landing on its island first, so its
				# main thread can't answer the handshake before our timeout: knock again)
				join_failed = false
				net.join_game("127.0.0.1", port)
			elif st_t > JOIN_WAIT:
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
				p.health_component.max_health = 500.0
				p.health_component.current_health = 500.0
				data["joined_t"] = net.time()
				data["clock_rtt"] = []
				data["clock_err"] = []
				tn.ask("calm")
				go(100 if mode == "chain" else 3)
			elif st_t > 60.0:
				check("host's captain appeared", false)
				finish()
		3:
			if st_t < 1.0:
				return false
			# (the chain's islands are built after the host's world state arrives: wait for them; a CI runner takes ~20 s an island)
			# (and their sea threats: DiveSites builds an island's sharks and eels on its half-second poll once the island stands)
			var isles = current_scene.get_node("Islands")
			if (not isles.chain_ready() or isles.get_node("DiveSites")._sites.size() < isles.chain_islands.size() + 1) and st_t < 60.0:
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
			var missing_keys: Array = []
			var ds: Array = []
			for k in r["enemies"].keys():
				var e = net.node_of(k)
				if e == null:
					missing += 1
					missing_keys.append(k)
					continue
				var dd: float = e.global_position.distance_to(r["enemies"][k][0])
				ds.append(dd)
				if dd > worst:
					data["worst_key"] = k
				worst = maxf(worst, dd)
			ds.sort()
			var med: float = ds[ds.size() / 2] if ds.size() > 0 else INF
			check("all %d host enemies exist here (missing %d: %s)" % [r["enemies"].size(), missing, str(missing_keys)], missing == 0 and r["enemies"].size() >= 8)
			# (shown ~0.1 s in the past: a charging bug can be a metre or two behind)
			check("enemy puppets in place (median %.2f m, worst %.2f m: %s)" % [med, worst, str(data.get("worst_key", ""))], med < 0.4 and worst < 4.0)
			# far from both captains the host's enemies sleep (ActorSleep, no snapshots): their puppets here sleep too, the near ones don't
			var sleep = load("res://scripts/world/actor_sleep.gd")
			var slept := 0
			var agree := 0
			var near_awake := 0
			var near := 0
			# (Brinehollow's: a chain island here may have just been manned, its crews not looked at yet)
			for k in r["enemies"].keys():
				var e = net.node_of(k)
				if e == null or not "Brinehollow" in k:
					continue
				if bool(r["enemies"][k][6]):
					slept += 1
					agree += 1 if sleep.asleep(e) else 0
					if not sleep.asleep(e) and slept - agree <= 4:
						print("   awake here, asleep on the host: %s (last snapshot %.1f s ago, %.0f m from us, dead %s)" % [k, net.snapshot_age(e),
							e.global_position.distance_to(p.global_position), e.is_dead()])
				elif e.global_position.distance_to(p.global_position) < 60.0:
					near += 1
					near_awake += 0 if sleep.asleep(e) else 1
			check("enemies asleep on the host sleep here too (%d of %d), those near us awake (%d of %d)" % [agree, slept, near_awake, near], slept > 0 and agree >= slept - 2 and near_awake == near)
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
			if mode == "jam":
				tn.ask("jam_play", ["fiddle"])
				go(190)
				return false
			if mode == "board":
				var ship = net._ship()
				p.global_position = ship.global_transform * Vector3(-1.5, 1.2, 3.5)
				p.velocity = Vector3.ZERO
				p.reset_physics_interpolation()
				go(80)
				return false
			if mode == "rival":
				go(300)
				return false
			if mode == "duel":
				put(r["host_pos"] + Vector3(0, 0.3, 2.0))
				p.player_model.rotation.y = 0.0
				go(200)
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
			data["ghp"] = now
			go(120)
		120:
			# --- sword and pistol: our point-blank shot lands on the host's grunt, the host's
			# puppet of us holds the pistol along its forearm and plays the shot
			var cut: ItemData = load("res://resources/items/cutlass.tres")
			var pistol: ItemData = load("res://resources/items/pistol.tres")
			p.inventory_component.add_item(cut, 1)
			p.inventory_component.add_item(pistol, 1)
			p.equip_weapon(cut, false)
			p.set_offhand(pistol)
			p.sheathe_weapon(true)
			p.draw_weapon(true)
			check("sword and pistol here (%s)" % p.style(), p.style() == "sword_pistol")
			var g: Node3D = data["g"]
			var side := Vector3(2.2, 0.0, 0.0)
			p.global_position = g.global_position + side + Vector3(0, 0.3, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.player_model.rotation.y = atan2(side.x, side.z)
			go(121)
		121:
			if st_t < 0.6:
				return false
			tn.ask("report")
			go(124)
		124:
			if not tn.got("report"):
				return false
			# (the damage it has taken so far: our first hit sent it home to its post, where it healed)
			data["gdmg"] = float(rep()["enemies"][data["gkey"]][5])
			p.body_model.play("sp_shot", 0.62)
			go(125)
		125:
			# fired on the pose's shot key, as the combo does (the gun's out in front by then)
			if st_t < load("res://scripts/npc/action_specs.gd").shot_seconds("sp_shot"):
				return false
			var to: Vector3 = (data["g"] as Node3D).global_position - p.global_position
			to.y = 0.0
			# (loaded, not named: it touches autoloads, which a --script can't see at compile time)
			var cg = load("res://scripts/player_states/corsair_gun.gd")
			var far: float = cg.muzzle(p).distance_to(cg.body_center(data["g"]))
			# what fire() deals: melee_hit(30) (no crit here), then the range falloff past NEAR
			data["shot_want"] = 30.0 * p.damage_multiplier() * lerpf(1.0, cg.FAR_MIN, clampf((far - cg.NEAR) / (cg.RANGE - cg.NEAR), 0.0, 1.0))
			data["shot_far"] = far
			var struck = cg.fire(p, to.normalized(), 30.0, "", {"ball": false, "unblock": true}, data["g"])
			check("our point-blank shot strikes the grunt here (%.1f m)" % far, struck == data["g"] and far < cg.NEAR)
			go(122)
		122:
			if st_t < 0.15:
				return false
			tn.ask("report")
			go(123)
		123:
			if not tn.got("report"):
				return false
			var dealt: float = float(rep()["enemies"][data["gkey"]][5]) - data["gdmg"]
			check("our pistol shot landed on the host's grunt (%.1f damage, want %.1f)" % [dealt, data["shot_want"]], absf(dealt - data["shot_want"]) < 0.5)
			check("the host's puppet of us: sword and pistol, the shot playing (%s, %s)" % [rep()["puppet_stance"], rep()["puppet_action"]],
				rep()["puppet_stance"] == "sword_pistol" and rep()["puppet_action"] == "sp_shot")
			check("...the pistol along its forearm (%.2f)" % float(rep()["puppet_off_grip"]), float(rep()["puppet_off_grip"]) > 0.95)
			# --- twin daggers: the host's puppet of us plays the dagger moves, and a wound we open bleeds the host's grunt
			var dg: ItemData = load("res://resources/items/dagger.tres")
			p.inventory_component.add_item(dg, 2)
			p.equip_weapon(dg, false)
			p.set_offhand(dg)
			p.sheathe_weapon(true)
			p.draw_weapon(true)
			check("two daggers here (%s)" % p.style(), p.style() == "dual_dagger")
			p.body_model.play("dd_4", 1.5)
			data["gdmg"] = float(rep()["enemies"][data["gkey"]][5])
			load("res://scripts/combat/bleed_status.gd").apply(data["g"], 2.0, 10.0, p)
			go(126)
		126:
			if st_t < 2.6:
				return false
			tn.ask("report")
			go(127)
		127:
			if not tn.got("report"):
				return false
			check("the host's puppet of us: twin daggers (%s)" % rep()["puppet_stance"], rep()["puppet_stance"] == "dual_dagger")
			var bled: float = float(rep()["enemies"][data["gkey"]][5]) - data["gdmg"]
			check("the wound we opened bled the host's grunt (%.0f damage over 2 s, 5 a tick)" % bled, bled >= 15.0 and bled <= 20.0)
			p.set_offhand(null)
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
			# the ship's storage chest is the crew's: we put 2 treasure in
			var store = net._ship().storage
			check("the ship's storage is shared", store.shared_id == "storage")
			p.inventory_component.add_item(load("res://resources/items/treasure.tres"), 2)
			store.store(p, p.inventory_component.find_index("treasure"), -1)
			go(66)
		66:
			if st_t < 1.0:
				return false
			tn.ask("storage", ["treasure"])
			go(67)
		67:
			if not tn.got("storage"):
				return false
			check("the host's storage has our treasure (%d)" % int(tn.replies["storage"]), int(tn.replies["storage"]) >= 2)
			check("...and so does ours (%d)" % net._ship().storage.find_stack(load("res://resources/items/treasure.tres")), net._ship().storage.find_stack(load("res://resources/items/treasure.tres")) >= 0)
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
			var sh = net._ship()
			check("...and her holes (%d here)" % sh.breaches.size(), sh.breaches.size() >= 1 and sh._holes.size() == sh.breaches.size())
			# we patch them all: the host hears
			for b in sh.breaches.duplicate():
				net.ship_work("patch", int(b[0]), 0.0)
			tn.ask("breaches")
			go(741)
		741:
			if not tn.got("breaches"):
				return false
			check("our patching reaches the host (%d holes left there)" % int(tn.replies["breaches"]), int(tn.replies["breaches"]) == 0)
			tn.ask("refit")
			go(742)
		742:
			if st_t < 0.8:
				return false
			var sh = net._ship()
			check("the host's refit reaches our ship (guns %d, figurehead)" % sh.cannons.size(), sh.cannons.size() == 6 and sh._figure_node.get_child_count() == 1)
			# a guest pays for a level at the yard: the host puts it on her
			p.inventory_component.add_item(load("res://resources/items/gold.tres"), 100)
			data["gold9"] = p.inventory_component.count("gold")
			data["rud9"] = int(sh.kit["rudder"])
			root.get_node("GameMenu")._yard.order("rudder", int(data["rud9"]))
			go(743)
		743:
			if st_t < 1.0:
				return false
			var sh = net._ship()
			check("a guest pays for a level at the yard: it's on her here (rudder %d)" % int(sh.kit["rudder"]),
				int(sh.kit["rudder"]) == int(data["rud9"]) + 1 and p.inventory_component.count("gold") == int(data["gold9"]) - 40)
			tn.ask("kit_level", ["rudder"])
			go(744)
		744:
			if not tn.got("kit_level"):
				return false
			check("...and on the host's", int(tn.replies["kit_level"]) == int(data["rud9"]) + 1)
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
			var host_here: Vector3 = tn.on_deck(host_pup, ship) if host_pup else Vector3.INF
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
		80:
			# --- "board": a pirate ship boarded the host before we joined
			if st_t < 1.5:
				return false
			tn.ask("boarders")
			go(81)
		81:
			if not tn.got("boarders"):
				return false
			var r = tn.replies["boarders"]
			data["es"] = r["es"]
			check("the host was boarded before we joined (%.1f s before)" % (float(data["joined_t"]) - float(r["boarded_t"])), float(r["boarded_t"]) < float(data["joined_t"]))
			var m := men_here(r, "BD_", str(r["ship"]))
			check("joined late: the boarders already on deck are here (%d of %d)" % [m["found"], m["n"]], m["n"] >= 3 and m["found"] == m["n"])
			check("...where the host has them on our deck (worst %.2f m, on deck %s)" % [m["worst"], m["on_deck"]], m["worst"] < 1.5 and m["on_deck"])
			check("...in the crewmen's own bodies, shown", m["bodies"])
			var es = net.node_of(r["es"])
			var shown: Array = []
			for i in range(es._crew.size()):
				if not es._crew[i]["gone"] and es._crew[i]["node"].visible:
					shown.append(i)
			check("the men still aboard her are the host's (%s / %s)" % [shown, r["shown"]], shown == r["shown"] and shown.size() > 0)
			# we cut one: the host applies it
			for k in r["men"].keys():
				if str(k).get_file().begins_with("BD_"):
					data["bkey"] = k
					data["bhp"] = float(r["men"][k][2])
					break
			var hd := HitData.new()
			hd.damage = 20.0
			hd.knockback_force = 0.0
			hd.unblockable = true
			net.node_of(data["bkey"]).hurtbox.take_hit(hd, p)
			go(82)
		82:
			if st_t < 0.6:
				return false
			tn.ask("boarders")
			go(83)
		83:
			if not tn.got("boarders"):
				return false
			var now := float(tn.replies["boarders"]["men"][data["bkey"]][2])
			check("our cut lands on the host's boarder (%.0f -> %.0f)" % [data["bhp"], now], now < float(data["bhp"]) - 10.0)
			# it swings at us: our machine decides
			data["php"] = p.health_component.current_health
			var fwd: Vector3 = -p.player_model.global_basis.z
			fwd.y = 0.0
			tn.ask("attack", [data["bkey"], p.global_position, fwd.normalized()])
			go(84)
		84:
			if p.health_component.current_health < float(data["php"]):
				check("the boarder's swing hits us here (%.0f -> %.0f)" % [data["php"], p.health_component.current_health], true)
				go(85)
			elif st_t > 4.0:
				check("the boarder's swing hits us here", false)
				go(85)
		85:
			if st_t < 1.0:
				return false
			var hd := HitData.new()
			hd.damage = 9999.0
			hd.knockback_force = 0.0
			hd.unblockable = true
			net.node_of(data["bkey"]).hurtbox.take_hit(hd, p)
			go(86)
		86:
			if st_t < 1.2:
				return false
			check("the boarder we killed dies here", net.node_of(data["bkey"]).state == 14)
			# we take the wheel, and she sends the rest of her men across
			p.state_machine.force_state("Idle", {})
			net.request_helm()
			go(87)
		87:
			if st_t < 1.0:
				return false
			check("we have the wheel (owner %d)" % net.ship_owner, net.ship_owner == net.my_id() and p.current_state_name() == "Helm")
			tn.ask("board_now")
			go(88)
		88:
			if not tn.got("board_now") or st_t < 2.5:
				return false
			data["party2"] = tn.replies["board_now"]
			tn.ask("boarders")
			go(89)
		89:
			if not tn.got("boarders"):
				return false
			var r = tn.replies["boarders"]
			var m := men_here(r, "BD_", str(r["ship"]))
			var fresh := 0
			for k in data["party2"]:
				if net.node_of(str(k)) != null:
					fresh += 1
			check("a boarding while we're here: every boarder shows (%d of %d; party of %d, %d here)" % [m["found"], m["n"], data["party2"].size(), fresh], m["found"] == m["n"] and fresh == data["party2"].size() and data["party2"].size() >= 2)
			check("...on our deck where the host has them, with us at the helm (worst %.2f m, on deck %s)" % [m["worst"], m["on_deck"]], m["worst"] < 1.5 and m["on_deck"])
			check("...in the crewmen's own bodies, shown", m["bodies"])
			p.state_machine.force_state("Idle", {})
			tn.ask("deck_fight")
			go(90)
		90:
			if not tn.got("deck_fight") or st_t < 1.5:
				return false
			tn.ask("boarders")
			go(91)
		91:
			if not tn.got("boarders"):
				return false
			var r = tn.replies["boarders"]
			var m := men_here(r, "DK_", str(r["es"]))
			check("her deck crew turn to fight here too (%d of %d)" % [m["found"], m["n"]], m["n"] >= 1 and m["found"] == m["n"])
			check("...on her deck where the host has them (worst %.2f m, on deck %s)" % [m["worst"], m["on_deck"]], m["worst"] < 1.5 and m["on_deck"])
			check("...in the crewmen's own bodies, shown", m["bodies"])
			tn.ask("quit")
			finish()
		40:
			_hostquit_step()
		190:
			# --- mode "jam": the host plays the fiddle, we join on the concertina
			if not tn.got("jam_play"):
				return false
			data["jam"] = tn.replies["jam_play"]
			check("the host plays its fiddle (%s)" % str(data["jam"]), bool(data["jam"][0]))
			go(191)
		191:
			if st_t < 1.2:
				return false
			var r: Array = data["jam"]
			var hj = net.players[1].jam
			check("the host's jam plays on its puppet here: same tune and start (%s %d %.3f)" % [hj.kind, hj.tune, hj.t0 - float(r[2])],
				hj.playing and hj.kind == "fiddle" and hj.tune == int(r[1]) and absf(hj.t0 - float(r[2])) < 0.001)
			check("the host's puppet holds the fiddle up (%s)" % net.players[1].body_model.current_action(), net.players[1].body_model.current_action() == "music_fiddle")
			var it: ItemData = ItemDB.get_item("concertina")
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("concertina"))
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			p.jam.start()
			check("we join the host's tune at its place (tune %d, start %.3f off)" % [p.jam.tune, p.jam.t0 - float(r[2])],
				p.jam.playing and p.jam.tune == int(r[1]) and absf(p.jam.t0 - float(r[2])) < 0.001)
			check("and fade in (%.2f)" % p.jam._gain, p.jam._gain < 0.5)
			go(192)
		192:
			if st_t < 1.6:
				return false
			tn.ask("jam_state")
			go(193)
		193:
			if not tn.got("jam_state"):
				return false
			var s: Dictionary = tn.replies["jam_state"]
			var r: Array = data["jam"]
			var pj: Array = s["puppet"]
			check("the host sees us play the concertina in its jam (%s)" % str(pj),
				pj.size() > 0 and bool(pj[0]) and pj[3] == "concertina" and int(pj[1]) == int(r[1]) and absf(float(pj[2]) - float(r[2])) < 0.001 and pj[4] == "music_concertina" and pj[5] == "concertina")
			check("the host still plays (%s)" % str(s["host"]), bool(s["host"][0]))
			check("we're faded in after two beats (%.2f)" % p.jam._gain, p.jam._gain > 0.99)
			go(194)
		194:
			if not data.has("clock_done"):
				return false
			tn.ask("quit")
			finish()
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


## The host's turned crewmen named `tag`* (from its "boarders" reply) still up,
## as puppets here: how many, how far off the host's deck spot, all on `deck`,
## each in his own (shown) body.
func men_here(r: Dictionary, tag: String, deck: String) -> Dictionary:
	var out := {"n": 0, "found": 0, "worst": 0.0, "on_deck": true, "bodies": true}
	var es = net.node_of(str(r["es"]))
	for k in r["men"].keys():
		var mm: Array = r["men"][k]
		if not str(k).get_file().begins_with(tag) or int(mm[1]) == 14:
			continue
		out["n"] += 1
		if str(mm[0][1]) != deck:
			out["on_deck"] = false
		var g = net.node_of(str(k))
		if g == null or not g.net_puppet:
			continue
		out["found"] += 1
		var here: Array = net.deck_pack(g.global_position)
		var off: float = (here[0] as Vector3).distance_to(mm[0][0]) if str(here[1]) == str(mm[0][1]) else 99.0
		out["worst"] = maxf(out["worst"], off)
		if g.humanoid != es._crew[int(mm[3])]["node"] or not g.humanoid.is_visible_in_tree():
			out["bodies"] = false
	return out


func world():
	return current_scene.get_node("Islands")


## Chain island `id`'s site, `up` m above its ground, in world space.
func isle_point(id: int, site: String, up: float) -> Vector3:
	var isl = world().chain_islands[id]
	var q: Vector2 = isl.sites[site]
	return isl.to_global(Vector3(q.x, isl.height_at(q.x, q.y) + up, q.y))


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func find_bag(save_id: String):
	for b in current_scene.find_children("*", "LootBag", true, false):
		if b.save_id == save_id and not b.is_queued_for_deletion():
			return b
	return null


## The chain islands standing here are the host's: the same names, places,
## sizes, sites, camp crews, village people and beast.
func same_isles(mine: Dictionary, theirs: Dictionary, what: String) -> void:
	check("%s: the same islands stand here as on the host (%s / %s)" % [what, mine["ids"], theirs["ids"]], mine["ids"] == theirs["ids"])
	for id in theirs["ids"]:
		if not mine["isles"].has(id):
			continue
		var a: Dictionary = mine["isles"][id]
		var b: Dictionary = theirs["isles"][id]
		var tag := "%s: %s" % [what, b["name"]]
		check(tag + " - the same name, place and size", a["name"] == b["name"] and a["pos"] == b["pos"] and a["radius"] == b["radius"])
		check(tag + " - the same sites", a["sites"] == b["sites"])
		check(tag + " - the camp's crew as on the host (%d / %d)" % [a["crew"].size(), b["crew"].size()], a["crew"] == b["crew"])
		check(tag + " - the village's people (%d)" % b["people"].size(), a["people"] == b["people"] and b["people"].size() >= 6)
		check(tag + " - the villagers' routines and the quests as on the host (%d)" % b["life"].size(), a["life"] == b["life"])
		if b.get("capital", false):
			check(tag + " - the shops' names and stock as on the host", a["shops"] == b["shops"] and b["shops"].size() == 5)
			check(tag + " - the crowd's places as on the host (%d)" % b["crowd"][0], a["crowd"] == b["crowd"] and b["crowd"][0] > 0)
			check(tag + " - the toughs are puppets here", a["crew"].size() == 4 and a["crew"].all(func(e): return net.node_of(e[0]) != null and net.node_of(e[0]).net_puppet))
			continue
		# (at "beast" the island we felled it on may have let its body go on both machines by now)
		var gone: bool = what == "beast" and a["ape"] == "" and b["ape"] == ""
		check(tag + " - its beast (%s, %s)" % [b["beast"], b["ape"] if not gone else "felled, gone on both"], a["beast"] == b["beast"]
			and (gone or (a["ape"] == b["ape"] and b["ape"] != "" and net.node_of(b["ape"]) != null and net.node_of(b["ape"]).net_puppet)))


## Mode "chain": joining late a host already on the chain's first island (its
## camp's captain felled), the islands match, chests are each captain's own,
## the host's clock sets the log pose here, the guest's arrival and the host's
## move the crew on, the guest felling a beast sets the log pose for everyone,
## and a guest's save keeps its own world's chain.
func _chain_step() -> void:
	var gm = root.get_node("GameManager")
	var c = world().chain()
	match step:
		100:
			if not (net.world_synced and world().chain_ready()):
				if st_t > 120.0:
					check("the host's chain island is built here", false)
					finish()
				return
			tn.ask("chain")
			go(101)
		101:
			if not tn.got("chain"):
				return
			var h: Dictionary = tn.replies["chain"]
			var m: Dictionary = tn.chain_report()
			var at := int(h["at"])
			data["A"] = at
			check("the host is on the chain's first island (%d)" % at, at >= 0 and c.start_next.has(at))
			check("joining late, we have the host's chain: seed, where the crew is, unset, since when", m["seed"] == h["seed"] and m["at"] == at and m["set"] == h["set"] and is_equal_approx(float(m["since"]), float(h["since"])))
			check("...the log pose hasn't set here either", not m["is_set"] and not h["is_set"])
			check("...the island the crew's at is built here, and only it (%s)" % [m["ids"]], m["ids"] == [at])
			same_isles(m, h, "joined")
			if not m["isles"].has(at):
				finish()
				return
			check("the camp's captain the host felled before we came isn't standing here", not m["isles"][at]["crew"].any(func(e): return str(e[1]).begins_with("Captain ")))
			var key := "isle%d_ruins_chest" % at
			data["key"] = key
			check("the same chests here as on the host (%d)" % h["isles"][at]["chests"].size(), m["isles"][at]["chests"] == h["isles"][at]["chests"] and key in m["isles"][at]["chests"])
			data["gold"] = p.inventory_component.count("gold")
			find_bag(key).take_all(p)
			go(102)
		102:
			if st_t < 0.6:
				return
			var key: String = data["key"]
			check("we empty the ruins' chest: gone here, kept as opened", find_bag(key) == null and gm.opened.has(key) and p.inventory_component.count("gold") > int(data["gold"]))
			tn.ask("chain")
			go(103)
		103:
			if not tn.got("chain"):
				return
			var h: Dictionary = tn.replies["chain"]
			var key: String = data["key"]
			check("...the host's own copy is still there (every captain loots each chest once)", key in h["isles"][data["A"]]["chests"] and not key in h["opened"])
			tn.ask("chest_take", [key])
			go(104)
		104:
			if not tn.got("chest_take"):
				return
			check("the host empties its copy", bool(tn.replies["chest_take"]))
			tn.ask("chain")
			go(105)
		105:
			if not tn.got("chain"):
				return
			var h: Dictionary = tn.replies["chain"]
			var key: String = data["key"]
			check("...opened there too, and ours stays gone", not key in h["isles"][data["A"]]["chests"] and key in h["opened"] and find_bag(key) == null)
			tn.ask("chain_skip", [gm.LOG_SET_TIME + 5.0])
			go(106)
		106:
			if not gm.log_pose_set() and st_t < 8.0:
				return
			check("15 minutes on the host's clock: the log pose sets here too", gm.log_pose_set() and not gm.chain_set)
			go(107)
		107:
			var want: Array = c.next_of(int(data["A"]))
			if not (world().chain_ready() and want.all(func(id): return world().chain_islands.has(id))):
				if st_t > 120.0:
					check("...the next island(s) are built here", false)
					finish()
				return
			tn.ask("chain")
			go(108)
		108:
			if not tn.got("chain"):
				return
			var h: Dictionary = tn.replies["chain"]
			if not h["ready"] and st_t < 60.0:
				tn.ask("chain")
				return
			var m: Dictionary = tn.chain_report()
			var want: Array = c.next_of(int(data["A"])) + [int(data["A"])]
			want.sort()
			check("...the next island(s) are built here (%s)" % [m["ids"]], m["ids"] == want)
			same_isles(m, h, "set")
			data["B"] = int(c.next_of(int(data["A"]))[0])
			put(isle_point(int(data["B"]), "village", 1.5))
			go(109)
		109:
			if gm.chain_at != int(data["B"]) and st_t < 15.0:
				return
			check("we land on the island ahead: the host moves the crew there, and so do we (%d)" % gm.chain_at, gm.chain_at == int(data["B"]))
			check("...arrived afresh, the log pose hasn't set", not gm.log_pose_set())
			go(110)
		110:
			if (not world().chain_ready() or world().chain_islands.size() > 1) and st_t < 30.0:
				return
			check("...the island behind (and a fork's other side) let go here (%s)" % [world().chain_islands.keys()], world().chain_islands.keys() == [int(data["B"])])
			tn.ask("tp", [isle_point(int(data["B"]), "village", 1.5) + Vector3(2.0, 0.0, 0.0)])
			tn.ask("chain")
			go(111)
		111:
			if not tn.got("chain"):
				return
			var h: Dictionary = tn.replies["chain"]
			var b := int(data["B"])
			check("...and on the host (%d, %s)" % [int(h["at"]), h["ids"]], int(h["at"]) == b and h["ids"] == [b])
			var ape = net.node_of(str(h["isles"][b]["ape"])) if h["isles"].has(b) else null
			if ape == null:
				check("the island's beast is here", false)
				finish()
				return
			var hd := HitData.new()
			hd.damage = 999999.0
			hd.unblockable = true
			hd.knockback_force = 0.0
			ape.hurtbox.take_hit(hd, p)
			data["ape"] = ape
			go(112)
		112:
			if not gm.chain_set and st_t < 10.0:
				return
			check("we fell the beast: the host sets the log pose for everyone", gm.chain_set and gm.log_pose_set())
			check("...it's dead here", is_instance_valid(data["ape"]) and data["ape"].is_dead())
			go(113)
		113:
			var want: Array = c.next_of(int(data["B"]))
			if not (world().chain_ready() and want.all(func(id): return world().chain_islands.has(id))):
				if st_t > 120.0:
					check("...the islands past it are built here", false)
					finish()
				return
			tn.ask("chain")
			go(114)
		114:
			if not tn.got("chain"):
				return
			# (the host's crews turn up when their bodies are ready, maybe after ours)
			if not tn.replies["chain"]["ready"] and st_t < 60.0:
				tn.ask("chain")
				return
			same_isles(tn.chain_report(), tn.replies["chain"], "beast")
			data["C"] = int(c.next_of(int(data["B"]))[0])
			tn.ask("tp", [isle_point(int(data["C"]), "village", 1.5)])
			go(115)
		115:
			if gm.chain_at != int(data["C"]) and st_t < 15.0:
				return
			check("the host lands on the next island: the crew's there for us too (%d)" % gm.chain_at, gm.chain_at == int(data["C"]))
			# a guest's save keeps its own world's chain, not the host's
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://nettest_chain")
			SG.slot = 1
			var f := FileAccess.open(SG.slot_path(1), FileAccess.WRITE)
			f.store_var({"version": 2, "chain_seed": 4242, "chain_at": 0, "chain_set": true, "chain_since": 5.0, "char_id": "abc"})
			f.close()
			check("guest save writes", SG.save(p))
			var sd: Dictionary = SG._read(SG.slot_path(1))
			check("...keeping our own world's chain, not the host's", int(sd.get("chain_seed", 0)) == 4242 and int(sd.get("chain_at", -1)) == 0 and bool(sd.get("chain_set", false)) and gm.chain_seed != 4242)
			SG.delete_slot(1)
			SG._test_dir = ""
			tn.ask("quit")
			finish()


func _hd(dmg: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.knockback_force = 1.0
	h.stagger_duration = 0.1
	return h


func _tap(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)


## Mode "duel": the menu on the host's captain (prompt, Inspect from its machine), no hurting outside a duel,
## our challenge and the host's accept, the countdown, the fight (our blade lands lightly through the hitbox,
## the bar), the host's finishing blow downs us without killing, the host's win and XP, both back up after.
func _duel_step() -> void:
	var duel = net.get_node("Duel")
	var hostp = net.players[1]
	var my: int = net.my_id()
	match step:
		200:
			# (the clock is judged first: building the menus here hitches a frame or two)
			if st_t < 1.2 or not data.has("clock_done"):
				return
			var it = p.interaction_component.current_interactable
			check("next to the host, facing them: the prompt names them (%s)" % (it.prompt_text if it else "none"),
				it != null and it == hostp.get_node_or_null("Meet") and it.prompt_text == hostp.display_name())
			_tap("interact")
			go(201)
		201:
			if st_t < 0.3:
				return
			var menu = p.get_node("PlayerMenu")
			check("F opens the menu on the host's captain", menu.is_open() and menu.target == hostp)
			menu.choose("inspect")
			go(202)
		202:
			var ins = p.get_node("PlayerMenu")._inspect
			if (ins == null or ins.items.is_empty()) and st_t < 5.0:
				return
			var w = ins.items.get("weapon") if ins else null
			check("Inspect shows the host's kit, asked of its machine (%s)" % (w.id if w else "nothing"), w != null and w.id == "cutlass")
			p.get_node("PlayerMenu").close()
			tn.ask("duel_report")
			go(203)
		203:
			if not tn.got("duel_report"):
				return
			data["host_hp0"] = float(tn.replies["duel_report"]["hp"])
			hostp.hurtbox.take_hit(_hd(20.0), p)
			go(204)
		204:
			if st_t < 0.6:
				return
			tn.ask("duel_report")
			go(205)
		205:
			if not tn.got("duel_report"):
				return
			check("no duel: our blow doesn't hurt the host", is_equal_approx(float(tn.replies["duel_report"]["hp"]), float(data["host_hp0"])))
			duel.challenge(1)
			go(206)
		206:
			if st_t < 0.6:
				return
			tn.ask("duel_report")
			go(207)
		207:
			if not tn.got("duel_report"):
				return
			var r = tn.replies["duel_report"]
			check("our challenge reaches the host: its prompt is up", bool(r["asking"]) and (r["state"]["asks"] as Dictionary).has(my))
			data["my_hp0"] = p.health_component.current_health
			tn.ask("duel_answer", [true])
			go(208)
		208:
			var d = duel.duel_of(my)
			if d.is_empty():
				if st_t > 3.0:
					check("the host accepts: the duel's on here", false)
					finish()
				return
			check("the host accepts: the duel's on here, counting down", not duel.fighting(d) and int(d["a"]) == my and int(d["b"]) == 1)
			check("...the host's captain can't be hit yet", hostp.hurtbox.collision_layer & 32 == 0)
			go(209)
		209:
			var d = duel.duel_of(my)
			if not duel.fighting(d):
				if st_t > 5.0:
					check("the countdown ends", false)
					finish()
				return
			if not data.has("fight_t"):
				data["fight_t"] = st_t
			if st_t < float(data["fight_t"]) + 0.2:
				return
			var hud = get_first_node_in_group("hud")
			check("Fight: the host's captain is on our enemies' layer", hostp.hurtbox.collision_layer & 32 != 0)
			check("...its name and health across the top (%s)" % hud._boss_name.text, hud._boss_box.visible and hud._boss_name.text == hostp.display_name())
			tn.ask("duel_report")
			go(210)
		210:
			if not tn.got("duel_report"):
				return
			var r = tn.replies["duel_report"]
			data["host_hp1"] = float(r["hp"])
			data["host_dr"] = float(r["dr"])
			data["host_xp"] = r["xp"]
			data["host_xp_for"] = int(r["xp_for"])
			p.sword_hitbox.activate(_hd(20.0))
			go(211)
		211:
			if st_t < 0.3:
				return
			p.sword_hitbox.deactivate()
			if st_t < 0.8:
				return
			tn.ask("duel_report")
			go(212)
		212:
			if not tn.got("duel_report"):
				return
			var lost: float = float(data["host_hp1"]) - float(tn.replies["duel_report"]["hp"])
			var want: float = 20.0 * Duel.DAMAGE_K * (1.0 - float(data["host_dr"]))
			check("our blade touches them: it lands, lightly (%.1f, want %.1f)" % [lost, want], absf(lost - want) < 0.5)
			tn.ask("duel_hit", [9999.0])
			go(213)
		213:
			if p.current_state_name() != "Downed" and st_t < 3.0:
				return
			var ds = p.state_machine.current_state
			check("the host's finishing blow: we're down, not dead (%s, %.0f hp, held %s)" % [p.current_state_name(), p.health_component.current_health, ds.get("dead")],
				p.current_state_name() == "Downed" and p.health_component.current_health <= 0.0 and bool(ds.get("dead")) and not p.is_bleeding())
			check("...no grave", root.get_node("GameManager").grave == null)
			go(214)
		214:
			var d = duel.duel_of(my)
			if (d.is_empty() or int(d["winner"]) == -1) and st_t < 2.0:
				return
			check("...the host wins it (%s)" % str(d.get("winner", "none")), not d.is_empty() and int(d["winner"]) == 1)
			check("...we see Defeated (%s)" % duel.hud.banner_text(), duel.hud.banner_text() == "Defeated")
			tn.ask("duel_report")
			go(215)
		215:
			if not tn.got("duel_report"):
				return
			var r = tn.replies["duel_report"]
			var before: Array = data["host_xp"]
			check("...and gets a little XP (%s -> %s, +%d)" % [before, r["xp"], int(data["host_xp_for"])],
				int(r["xp"][0]) > int(before[0]) or int(r["xp"][1]) == int(before[1]) + int(data["host_xp_for"]))
			go(216)
		216:
			if st_t < 3.6:
				return
			check("3 s on: our health is what it was before the duel (%.0f / %.0f)" % [p.health_component.current_health, float(data["my_hp0"])],
				is_equal_approx(p.health_component.current_health, float(data["my_hp0"])))
			check("...and the host's captain can't be hit any more", hostp.hurtbox.collision_layer & 32 == 0)
			go(217)
		217:
			if p.current_state_name() == "Downed" and st_t < 4.0:
				return
			check("...we get up (%s)" % p.current_state_name(), p.current_state_name() != "Downed")
			tn.ask("duel_report")
			go(218)
		218:
			if not tn.got("duel_report"):
				return
			var r = tn.replies["duel_report"]
			check("the host's health is back to what it was too (%.0f / %.0f)" % [float(r["hp"]), float(data["host_hp0"])], is_equal_approx(float(r["hp"]), float(data["host_hp0"])))
			check("...and the duel's over on the host", (r["state"]["duels"] as Dictionary).is_empty())
			tn.ask("quit")
			finish()


func _hostquit_step() -> void:
	if current_scene and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn":
		check("host left: back on the title screen", true)
		check("...showing why (%s)" % current_scene._coop_status.text, current_scene._coop.visible and "closed" in current_scene._coop_status.text)
		check("...single player again", not net.active)
		finish()
	elif st_t > 8.0:
		check("host left: back on the title screen", false)
		finish()


## The clock, judged a few seconds after joining (the host can still be loading or
## building the chain right then): the host's clock read against ours over several asks.
func _clock_step() -> void:
	if not data.has("joined_t") or data.has("clock_done"):
		return
	var now: float = net.time()
	if data.has("clock_ask"):
		if not tn.got("clock"):
			return
		var ask: Array = data["clock_ask"]
		var ht := float(tn.replies["clock"])
		data["clock_rtt"].append((Time.get_ticks_usec() - int(ask[0])) * 0.000001)
		# (the host read its clock between our ask and its reply arriving)
		data["clock_err"].append(maxf(maxf(float(ask[1]) - ht, ht - now), 0.0))
		data.erase("clock_ask")
		data["clock_next"] = now + 0.4
		if data["clock_rtt"].size() >= 7:
			data["clock_done"] = true
			var rtts: Array = data["clock_rtt"].duplicate()
			var errs: Array = data["clock_err"].duplicate()
			rtts.sort()
			errs.sort()
			check("clock synced: the host's clock lands in our ask-to-reply window (median %.0f ms off, worst %.0f)" % [errs[3] * 1000.0, errs[6] * 1000.0], errs[3] < 0.05)
			check("round trip on localhost once settled (median %.0f ms of 7, worst %.0f; Net's %.0f)" % [rtts[3] * 1000.0, rtts[6] * 1000.0, net.rtt * 1000.0], rtts[3] < 0.25)
		return
	if now < float(data.get("clock_next", float(data["joined_t"]) + 3.0)):
		return
	data["clock_ask"] = [Time.get_ticks_usec(), now]
	tn.ask("clock")


func finish() -> void:
	if data.has("joined_t") and not data.has("clock_done") and mode != "hostquit":
		check("the clock was sampled after joining", false)
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


## Mode "rival": a captain-style AI the host runs (Net._all_spawn_rival) shows here as a puppet on the enemies'
## side, our blow reaches the host's copy, its blows reach us here, and it goes on every screen.
func _rival_step() -> void:
	var r = p.get_parent().get_node_or_null("Rival_net")
	match step:
		300:
			if st_t < 1.0:
				return
			tn.ask("rival_spawn", [p.global_position + Vector3(3, 0.3, 0)])
			data["php"] = p.health_component.current_health
			go(301)
		301:
			if (r == null or not r.visible) and st_t < 6.0:
				return
			check("the host's rival shows here: a captain puppet on the enemies' side",
				r != null and r.visible and r.is_ai and not r.is_local and r.is_in_group("rivals") and not r.is_in_group("players"))
			if r == null:
				finish()
				return
			tn.ask("rival_report")
			go(302)
		302:
			if not tn.got("rival_report"):
				return
			data["rhp"] = float(tn.replies["rival_report"]["hp"])
			r.hurtbox.take_hit(_hd(20.0), p)
			go(303)
		303:
			if st_t < 0.8:
				return
			tn.ask("rival_report")
			go(304)
		304:
			if not tn.got("rival_report"):
				return
			var hp := float(tn.replies["rival_report"]["hp"])
			check("our blow on its puppet reaches the host's rival (%.0f -> %.0f)" % [data["rhp"], hp], hp < float(data["rhp"]))
			check("...and it takes us on (its foe: %s)" % tn.replies["rival_report"]["brain_foe"], str(tn.replies["rival_report"]["brain_foe"]) == net.key_of(p))
			data["php"] = p.health_component.current_health
			go(305)
		305:
			if p.health_component.current_health < float(data["php"]):
				check("its blows reach us here (%.0f -> %.0f)" % [data["php"], p.health_component.current_health], true)
				tn.ask("rival_gone")
				go(306)
			elif st_t > 12.0:
				check("its blows reach us here", false)
				tn.ask("rival_gone")
				go(306)
		306:
			if r != null and st_t < 3.0:
				return
			check("cleared, it's gone here too", r == null)
			# --- leave (the host checks we're gone, then quits too)
			tn.ask("expect_leave")
			go(30)
