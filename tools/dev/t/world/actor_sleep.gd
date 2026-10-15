extends SceneTree
## Far actors sleep (ActorSleep) and wake as they were: grunts, scuttlebugs, a spitter, a villager and an
## enemy ship sleep with the captain far off (no processing, hurtbox out of the space, net_idle, hidden past
## the hide range; the ship stays in sight), keep their state and position while asleep, don't sleep or wake
## between the two ranges (hysteresis), and wake where they were with their timers where they stopped.
## A boarder never sleeps (left behind, it slips away).
const TK := preload("res://tools/dev/test_kit.gd")
## Pedestals for the captain, west of the stage (the sea is east): x = -650 (everyone far), -140 (between
## the people's wake and sleep ranges), -100 (within their wake range).
const FAR_X := -650.0
const MID_X := -140.0
const NEAR_X := -100.0
var AS
var stage
var p
var walker
var sitter
var boarder
var nest
var ship
var npc
var actors: Array = []
var frozen := {}
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true,
		"grunts": [{"post": Vector3(-4, 0, -30), "yaw": 0.0, "mode": "patrol", "seed": 11,
				"patrol": [Vector3(-4, 0, -30), Vector3(-14, 0, -30)]},
			{"post": Vector3(4, 0, -30), "yaw": 0.0, "mode": "sit", "seed": 12, "role": "rifle"}],
		"npc": {"name": "Sleepy Villager", "at": Vector3(-6, 0, 4), "waypoints": [Vector3(-6, 3, 4), Vector3(-16, 3, 4)]}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _box(x: float) -> void:
	var b := StaticBody3D.new()
	b.name = "Pedestal%d" % absi(int(x))
	b.position = Vector3(x, stage.GROUND_Y - 1.0, 0)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(20, 2, 20)
	cs.shape = sh
	b.add_child(cs)
	stage.add_child(b)


func go(x: float) -> void:
	p.global_position = Vector3(x, stage.GROUND_Y + 0.05, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _hurtbox_found(a: Node3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.7
	q.shape = s
	q.transform = Transform3D(Basis(), a.global_position + Vector3(0, 0.9, 0))
	q.collision_mask = 32
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in stage.get_world_3d().direct_space_state.intersect_shape(q, 8):
		if (hit["collider"] as Node).owner == a or (hit["collider"] as Node).get_parent() == a:
			return true
	return false


func _all(asleep: bool, list: Array, loud := true) -> bool:
	var ok := true
	for a in list:
		if AS.asleep(a) != asleep or (a.process_mode == Node.PROCESS_MODE_DISABLED) != asleep:
			ok = false
			if loud:
				print("   %s: asleep %s, mode %d, sleep_ok %s, state %s, %.0f m" % [a.name, AS.asleep(a), a.process_mode, a.sleep_ok(),
				str(a.get("state")), (a as Node3D).global_position.distance_to(p.global_position)])
	return ok


func _snap(a: Node3D) -> Dictionary:
	return {"pos": a.global_position, "st_t": float(a.get("st_t")) if a.get("st_t") != null else 0.0}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			for x in [FAR_X, MID_X, NEAR_X]:
				_box(x)
			walker = stage.camp.grunts[0]
			sitter = stage.camp.grunts[1]
			npc = stage.npc
			AS = load("res://scripts/world/actor_sleep.gd")
			nest = load("res://scripts/enemies/scuttlebug_nest.gd").new()
			nest.name = "Nest"
			nest.position = Vector3(12, stage.GROUND_Y, -12)
			nest.add_spot(Vector3.ZERO)
			nest.add_spot(Vector3(3, 0, 1), true)
			nest.add_spitter(Vector3(-2, 7, 2), Vector3(-2, 0, 2))
			stage.add_child(nest)
			boarder = load("res://scripts/enemies/pirate_grunt.gd").new()
			boarder.name = "Boarder"
			boarder.setup({"post": Vector3(20, stage.GROUND_Y, 20), "yaw": 0.0, "mode": "stand", "seed": 13})
			boarder.boarder = true
			stage.add_child(boarder)
			boarder.global_position = Vector3(20, stage.GROUND_Y + 0.2, 20)
			ship = load("res://scripts/ship/enemy_ship.gd").new().setup(Vector3(90, 0, 0), 25.0, 0.0, 7001, "sloop")
			ship.name = "ES_test"
			# (placed before it joins: at the origin it would find the captain aboard)
			ship.transform = Transform3D(Basis(), Vector3(115, 0.85, 0))
			stage.add_child(ship)
			until = TK.wait_secs(1.5)
		1:
			actors = [walker, sitter, npc, ship]
			for s in nest.spots:
				actors.append(s["bug"])
			check("a nest of two bugs and a spitter",nest.spots.size() == 3 and actors.size() == 7)
			check("everyone near the captain is awake", _all(false, actors + [boarder]))
			check("the sitter sits at its post", sitter.humanoid.seated and sitter.state == 0)
			check("an awake grunt's hurtbox is in the physics space", _hurtbox_found(walker))
			go(FAR_X)
			until = TK.wait_secs(1.0)
		2:
			check("650 m off, every actor sleeps", _all(true, actors))
			check("a boarder stays awake", not AS.asleep(boarder) and boarder.can_process())
			check("asleep, a grunt's hurtbox is out of the physics space (nothing can target it)", not _hurtbox_found(walker))
			check("asleep, the host sends no snapshots (net_idle)", walker.net_idle and nest.spots[0]["bug"].net_idle and ship.net_idle)
			check("past the hide range grunts, bugs and the villager are hidden", not walker.visible and not sitter.visible and not npc.visible and not nest.spots[0]["bug"].visible)
			check("a sleeping ship stays in sight", ship.visible)
			for a in actors:
				frozen[a] = _snap(a)
			frozen["patrol"] = [walker._patrol_i, walker._patrol_wait]
			until = TK.wait_secs(3.0)
		3:
			var still := actors.all(func(a): return (a as Node3D).global_position.is_equal_approx(frozen[a]["pos"]) and float(a.get("st_t") if a.get("st_t") != null else 0.0) == float(frozen[a]["st_t"]))
			check("3 s asleep: nobody moved and no state clock ran", still)
			check("the patrol hasn't moved on", [walker._patrol_i, walker._patrol_wait] == frozen["patrol"])
			go(MID_X)
			until = TK.wait_secs(1.0)
		4:
			check("140 m off (between wake and sleep): the people stay asleep", _all(true, actors.filter(func(a): return a != ship)))
			check("140 m off they show again (inside the show range)", walker.visible and npc.visible)
			check("the ship wakes within its own range", not AS.asleep(ship))
			go(NEAR_X)
		5:
			# (each frame: catch the moment they wake; the ship woke a second ago and sails on)
			if not _all(false, actors, false):
				return false
			var where := actors.all(func(a): return a == ship or (a as Node3D).global_position.distance_to(frozen[a]["pos"]) < 0.3)
			check("100 m off everyone wakes where they slept (no teleport)", where)
			check("woken, the clocks pick up where they stopped (no fast-forward)", float(walker.st_t) - float(frozen[walker]["st_t"]) < 0.5)
			check("woken, snapshots go out again", not walker.net_idle and not ship.net_idle)
			check("the sitter is still seated", sitter.humanoid.seated)
			until = TK.wait_secs(3.0)
		6:
			check("woken, the hurtbox is back in the physics space", _hurtbox_found(walker))
			check("awake again, the patrol walks on", walker.global_position.distance_to(frozen[walker]["pos"]) > 0.3 or walker._patrol_wait > 0.0)
			go(MID_X)
			until = TK.wait_secs(1.0)
		7:
			check("140 m off (between the ranges) awake people stay awake", _all(false, [walker, sitter, npc]))
			AS.enabled = false
			go(FAR_X)
			until = TK.wait_secs(1.5)
		8:
			check("the boarder, left behind, slipped away (it never slept)", not is_instance_valid(boarder) or boarder.is_dead())
			check("ActorSleep off (the bench's nosleep): nobody sleeps", _all(false, [walker, sitter, npc, ship]))
			AS.enabled = true
			until = TK.wait_secs(1.0)
		9:
			check("on again: they sleep", _all(true, [walker, sitter, npc, ship]))
			return TK.done(fails)
	step += 1
	return false
