extends SceneTree
## Grell's cliff path (KitCliffPath on Brinehollow): the sea ladder pulled up until a
## captain has stood on the top (then let down, in the save and the world state guests
## get); Grell waits by his shack while his crew fights, and comes once a captain is at
## the fire; the cave (small bugs, a brute that takes a run of hits with no boss bar,
## spitters in the roof, dripstone, a light); every gap driven with the player's own
## jump (none a step; a run jump or a sprint jump as it asks; the longest with a run and
## the double jump), a walk off a sea gap into the sea and a swim back to the beach at
## the foot, and the broken bridge's chain (F at the lip, and caught in mid-jump).
const TK := preload("res://tools/dev/test_kit.gd")
const SWIM_DEPTH := -1.0
var step := 0
var until := 0
var fails := 0
var t := 0.0
var p
var isl
var path
var lad
var grell
var guard
var jumps: Array = []
var ji := 0
var drive := {}
var hp_brute := 0.0
var swim_pts: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _put(at: Vector3, face := Vector3.ZERO) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	if face != Vector3.ZERO:
		_rig().global_rotation.y = atan2(-face.x, -face.z)


func _rig() -> Node3D:
	return p.get_viewport().get_camera_3d().get_parent().get_parent() as Node3D


func _g(v: Vector3) -> Vector3:
	return isl.to_global(v)


func _l(v: Vector3) -> Vector3:
	return isl.to_local(v)


func _release_all() -> void:
	for a in ["move_forward", "sprint", "jump"]:
		TK.release(a)


## Run at a gap from `run` m back, jump at its lip, land on the far side; true when it's over.
## d: {"lip", "far", "dir" (island), "sprint", "double", "jump_at" (0: from the lip), "grab"}
func _drive(dt: float) -> bool:
	var lip: Vector3 = _g(drive["lip"])
	var far: Vector3 = _g(drive["far"])
	var dir: Vector3 = isl.global_basis * (drive["dir"] as Vector3)
	var at: Vector3 = p.global_position
	drive["t"] = float(drive["t"]) + dt
	var aim: Vector3 = far + dir * 1.2 if drive["jumped"] else lip + dir * 0.5
	var to := aim - at
	_rig().global_rotation.y = atan2(-to.x, -to.z)
	var st: String = p.current_state_name()
	if not drive["jumped"]:
		if p.is_on_floor() and (lip - at).dot(dir) < float(drive.get("jump_at", 0.3)):
			TK.press("jump")
			drive["jumped"] = true
			drive["jt"] = 0.0
		return float(drive["t"]) > 6.0
	drive["jt"] = float(drive["jt"]) + dt
	var jt: float = drive["jt"]
	if jt > 0.32 and not drive.get("up", false):
		TK.release("jump")
		drive["up"] = true
	if drive["double"] and jt > 0.42 and not drive.get("dj", false):
		TK.press("jump")
		drive["dj"] = true
	if drive.get("dj", false) and jt > 0.75:
		TK.release("jump")
	if st == "Swing":
		return false
	return (jt > 0.25 and p.is_on_floor() and st != "Swing") or st == "Swim" or jt > 5.0


## Where the drive ended: on the far side's floor, past its lip?
func _landed() -> Array:
	var l := _l(p.global_position)
	var far: Vector3 = drive["far"]
	var dir: Vector3 = drive["dir"]
	var past := (l - far).dot(dir)
	var fy: float = path.floor_at(path.bearing(Vector2(l.x, l.z)))
	return [p.is_on_floor() and absf(l.y - fy) < 0.3 and past > -0.15 and p.current_state_name() != "Swim", past, l.y - fy]


func _start_drive(j: Dictionary, sprint: bool, double: bool, run_up := 4.5) -> void:
	var a: float = j["at"][0]
	var m: float = path.radius_at(a) * PI / 180.0
	# (no further back than the ledge goes: the gap before, or the foot)
	var back: float = path.th0
	for g in path.gaps:
		if float(g[1]) <= a:
			back = maxf(back, float(g[1]))
	run_up = minf(run_up, (a - back) * m - 0.3)
	var th: float = a - run_up / m
	var from: Vector3 = path.floor_point(th)
	var dir: Vector3 = j["dir"]
	_put(_g(from + Vector3.UP * 0.1), _g(j["from"]) - _g(from))
	drive = {"lip": j["from"], "far": j["to"], "dir": dir, "sprint": sprint, "double": double, "jumped": false, "t": 0.0}
	TK.press("move_forward")
	if sprint:
		TK.press("sprint")


func _process(dt: float) -> bool:
	t += dt
	if p != null:
		p.health_component.heal(9999.0)
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 2.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			isl = root.get_node("World/Islands/Brinehollow")
			path = isl.den_path
			jumps = isl.den_plan["jumps"]
			lad = isl.get_node("DenHoist").find_children("*", "Ladder", true, false)[0]
			# --- the plan
			var js := jumps.filter(func(j): return j["kind"] == "jump")
			check("five gaps to jump and the bridge to swing (%d, %d)" % [js.size(), jumps.size() - js.size()], js.size() == 5 and jumps.size() == 6)
			var space = p.get_world_3d().direct_space_state
			for j in js:
				check("  a gap of %.2f m, rising %.2f: no step, in reach" % [j["len"], j["rise"]], j["len"] > 1.8 and j["len"] < 4.8 and j["rise"] < 1.0)
				var roof := 0
				for q in [j["from"], (j["from"] + j["to"]) * 0.5, j["to"]]:
					var a: Vector3 = _g(q + Vector3.UP * 0.6)
					roof += 0 if space.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + Vector3.UP * 3.3, 1)).is_empty() else 1
				check("  ...with room overhead for a full jump", roof == 0)
			var longest := 0.0
			for j in js:
				longest = maxf(longest, j["len"])
			check("  bigger than the old climb's gaps (longest %.2f m, the old 2.0)" % longest, longest > 4.0)
			var arc: float = (path.th1 - path.th0) * PI / 180.0 * 35.0
			check("  round further: %.0f degrees of the cliff (%.0f m)" % [path.th1 - path.th0, arc], path.th1 - path.th0 > 110.0)
			var sea := 0
			for j in js:
				var mid: Vector3 = (j["from"] + j["to"]) * 0.5
				if isl.height_at(mid.x, mid.z) < -3.0:
					sea += 1
			check("  gaps straight down to the sea (%d)" % sea, sea >= 3)
			var start: Vector2 = isl.den_plan["start"]
			check("the path's foot on the beach (%.1f m up)" % isl.hv(start), isl.hv(start) > 1.0 and isl.hv(start) < 3.5)
			# --- the cave
			var spots: Array = path.nest.spots
			var small := spots.filter(func(s): return not s.has("anchor") and not s["big"]).size()
			var brutes := spots.filter(func(s): return s.get("brute", false)).size()
			var spit := spots.filter(func(s): return s.has("anchor")).size()
			check("the cave: %d small bugs, %d brute, %d spitters in the roof" % [small, brutes, spit], small >= 4 and brutes == 1 and spit >= 2)
			for s in spots.filter(func(s): return s.has("anchor")):
				var hang: float = (s["anchor"] as Vector3).y - (s["pos"] as Vector3).y
				check("  a spitter's roof %.1f m over the floor (room to drop and dangle)" % hang, hang > 4.0)
			var body: Node = isl.get_node("DenPath")
			check("  dripstone, lichen and its light", body.get_node_or_null("CaveDressing") != null and body.get_node_or_null("CaveLight") != null)
			# --- the ladder, before anyone's been up
			var foot: Vector3 = lad.to_global(Vector3(0, -lad.length + 0.4, 0.8))
			check("the sea ladder starts pulled up", lad.stowed() and not lad.in_reach(foot) and not root.get_node("GameManager").world_flags.has("den_ladder"))
			for g in isl.den.grunts:
				g.set_meta("no_sleep", true)
				if g.captain:
					grell = g
			check("Grell held back to his camp's middle", grell != null and not grell.hold.is_empty())
			until = TK.wait_secs(0.5)
		1:
			# --- up the cleft onto the top: the crew comes, Grell stays put
			var top: Vector2 = isl.den_plan["top"]
			var inward: Vector2 = (isl.DEN - top).normalized()
			var at := top + inward * 3.0
			_put(_g(Vector3(at.x, isl.hv(at) + 0.2, at.y)), _g(Vector3(isl.DEN.x, isl.DEN_TOP, isl.DEN.y)) - _g(Vector3(at.x, isl.DEN_TOP, at.y)))
			until = TK.wait_secs(3.0)
		2:
			var busy: Array = isl.den.grunts.filter(func(g): return is_instance_valid(g) and not g.captain and g.state != 0)
			check("on the top: the crew comes for you (%d)" % busy.size(), busy.size() >= 1)
			check("  Grell waits at his shack", grell.state == 0 and grell.global_position.distance_to(grell.post) < 1.2)
			var gm = root.get_node("GameManager")
			check("the top reached: the sea ladder's let down for everyone", gm.world_flags.has("den_ladder"))
			check("  in the world state a guest gets", root.get_node("Net")._world_state()["flags"].has("den_ladder"))
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://denpathtest")
			SG.slot = 1
			SG.save(p)
			gm.world_flags.clear()
			SG.load_into(p)
			check("  and kept in the save", gm.world_flags.has("den_ladder"))
			until = TK.wait_secs(2.0)
		3:
			check("  Grell still waits with the fight on (%s)" % grell.state, grell.state == 0)
			var foot: Vector3 = lad.to_global(Vector3(0, -lad.length + 0.4, 0.8))
			check("  unrolled down the cliff to the pier, in reach from there", not lad.stowed() and lad.in_reach(foot) and lad.interactable.enabled)
			_put(_g(Vector3(isl.DEN.x + 1.5, isl.DEN_TOP + 0.2, isl.DEN.y + 1.0)))
			until = TK.wait_secs(1.0)
		4:
			check("at the fire: Grell comes (%s)" % grell.state, grell.state != 0 and grell.hold.is_empty())
			for g in isl.den.grunts:
				if is_instance_valid(g):
					g.health.take_damage(999999.0)
			# --- the cave's bugs (alive: put next to the brute)
			var brute = null
			for s in path.nest.spots:
				if s.get("brute", false):
					brute = s["bug"]
			var small = path.nest.spots.filter(func(s): return not s.has("anchor") and not s["big"])[0]["bug"]
			check("the brute: bigger and tougher than a small bug (%d hp, %d)" % [brute.health.max_health, small.health.max_health],
				brute.size_k > 1.6 and brute.health.max_health > small.health.max_health * 3.0)
			brute.set_meta("no_sleep", true)
			_put(brute.global_position + Vector3(2.5, 0.5, 0))
			hp_brute = brute.health.current_health
			var hit := HitData.new()
			hit.damage = 18.0
			hit.knockback_force = 4.0
			hit.knockdown = true
			brute.hurtbox.take_hit(hit, p)
			set_meta("brute", brute)
			until = TK.wait_ticks(6)
		5:
			var brute = get_meta("brute")
			check("  a hit takes a bite out of it (%d -> %d)" % [hp_brute, brute.health.current_health], brute.health.current_health < hp_brute and brute.state != 9)
			check("  a light knockdown doesn't throw it", brute.state != 8)
			check("  it'd take a run of such hits (%d)" % ceili(brute.health.max_health / 18.0), brute.health.max_health / 18.0 >= 5.0)
			var hud = root.get_tree().get_first_node_in_group("hud")
			check("  not a boss: no bar across the top", not hud._boss_box.visible)
			for s in path.nest.spots:
				if s["bug"] and is_instance_valid(s["bug"]):
					s["bug"].health.take_damage(999999.0)
			path.nest.respawn_time = 99999.0
			ji = 0
			step = 10
			return false
		10:
			# --- every gap, jumped as it asks
			while ji < jumps.size() and jumps[ji]["kind"] != "jump":
				ji += 1
			if ji >= jumps.size():
				step = 20
				return false
			var j: Dictionary = jumps[ji]
			_start_drive(j, j["len"] > 3.2, false)
			until = TK.wait_ticks(2)
		11:
			if not _drive(dt):
				return false
			_release_all()
			var j: Dictionary = jumps[ji]
			var r := _landed()
			check("gap %d (%.2f m, %+.2f): made with a %s jump (%.2f m past its lip)" % [ji + 1, j["len"], j["rise"], "sprint" if drive["sprint"] else "run", r[1]], r[0])
			ji += 1
			step = 10
			until = TK.wait_ticks(10)
			return false
		20:
			# the longest at a run with the double jump
			var best: Dictionary = {}
			for j in jumps:
				if j["kind"] == "jump" and (best.is_empty() or j["len"] > best["len"]):
					best = j
			set_meta("best", best)
			p.set_ability("double_jump", true)
			_start_drive(best, false, true)
			until = TK.wait_ticks(2)
		21:
			if not _drive(dt):
				return false
			_release_all()
			var r := _landed()
			check("the longest (%.2f m) at a run with the double jump (%.2f m past)" % [get_meta("best")["len"], r[1]], r[0])
			p.set_ability("double_jump", false)
			# walking off a sea gap: into the sea
			var j: Dictionary = jumps[1]
			_start_drive(j, false, false)
			drive["jump_at"] = -9.0
			until = TK.wait_ticks(10)
		22:
			var wd: Vector3 = isl.global_basis * (drive["dir"] as Vector3)
			_rig().global_rotation.y = atan2(-wd.x, -wd.z)
			drive["t"] = float(drive["t"]) + dt
			if p.current_state_name() != "Swim" and float(drive["t"]) < 6.0:
				return false
			_release_all()
			check("walking off a gap over the sea: into the sea (%s)" % p.current_state_name(), p.current_state_name() == "Swim")
			# and back to the beach at the foot
			var start: Vector2 = isl.den_plan["start"]
			swim_pts = [path.point(128.0, 9.0), path.point(116.0, 10.0), start]
			drive = {"t": 0.0, "i": 0}
			TK.press("move_forward")
			step = 23
			return false
		23:
			drive["t"] = float(drive["t"]) + dt
			var q: Vector2 = swim_pts[drive["i"]]
			var to: Vector3 = _g(Vector3(q.x, 0, q.y)) - p.global_position
			_rig().global_rotation.y = atan2(-to.x, -to.z)
			if Vector2(to.x, to.z).length() < 3.0 and int(drive["i"]) < swim_pts.size() - 1:
				drive["i"] = int(drive["i"]) + 1
			# (at the beach's bank in deep water: Space climbs out, as a player would)
			var flat := Vector2(p.global_position.x, p.global_position.z)
			if flat.distance_to(drive.get("was", Vector2.INF)) > 0.5:
				drive["was"] = flat
				drive["still"] = 0.0
			drive["still"] = float(drive.get("still", 0.0)) + dt
			if float(drive["still"]) > 1.5 and p.current_state_name() == "Swim":
				TK.act("jump")
				drive["still"] = 0.0
				drive["climbs"] = int(drive.get("climbs", 0)) + 1
			var ashore: bool = p.current_state_name() != "Swim" and p.is_on_floor() and _l(p.global_position).y > 0.4
			if not (ashore and int(drive["i"]) == swim_pts.size() - 1 and Vector2(to.x, to.z).length() < 3.0) and float(drive["t"]) < 45.0:
				return false
			_release_all()
			check("  swum back and out on the beach at the path's foot (%.0f s, %.1f m from it, %d climbs out)" % [drive["t"], Vector2(to.x, to.z).length(), drive.get("climbs", 0)],
				ashore and Vector2(to.x, to.z).length() < 3.0)
			step = 30
			return false
		30:
			# --- the bridge's chain: F at the broken end, ride it over
			var j: Dictionary = jumps.filter(func(e): return e["kind"] == "swing")[0]
			set_meta("swing", j)
			_put(path.chain.grab_from + Vector3.UP * 0.1, isl.global_basis * (j["dir"] as Vector3))
			until = TK.wait_ticks(4)
		31:
			var j: Dictionary = get_meta("swing")
			path.chain.interactable.interacted.emit(p)
			check("the bridge: F at its broken end takes the chain", p.current_state_name() == "Swing")
			drive = {"lip": j["from"], "far": j["to"], "dir": j["dir"], "sprint": false, "double": false, "jumped": true, "jt": 0.0, "t": 0.0, "up": true}
			TK.press("move_forward")
			step = 32
			return false
		32:
			if _swing(dt):
				var r := _landed()
				_release_all()
				if has_meta("caught"):
					check("  ...and over onto the far side again (%.2f m past its lip)" % r[1], r[0] and r[1] > 0.5)
					step = 40
					return false
				check("  and swings you over onto the far side with room to spare (%.2f m past its lip)" % r[1], r[0] and r[1] > 0.5)
				var j: Dictionary = get_meta("swing")
				_start_drive(j, true, false, 3.5)
				step = 33
			return false
		33:
			# jumped off the lip into it: caught in the air
			if p.current_state_name() == "Swing":
				check("  jumping off the lip into the chain catches it", true)
				set_meta("caught", true)
				drive["t"] = 0.0
				step = 32
				return false
			if _drive(dt):
				_release_all()
				check("  jumping off the lip into the chain catches it (%s)" % p.current_state_name(), false)
				step = 40
			return false
		40:
			# the guide: the foot, then the top once on the path, then the den
			var start: Vector2 = isl.den_plan["start"]
			_put(_g(Vector3(start.x, isl.hv(start) + 0.3, start.y) + Vector3(-12, 0, 18)))
			var s1 := _l(isl.guide_to("den", p.global_position))
			check("the marker: first the path's foot", Vector2(s1.x, s1.z).distance_to(start) < 1.0)
			var on: Vector3 = (isl.den_plan["route"] as Array)[12]
			_put(_g(on + Vector3.UP * 0.2))
			var s2 := _l(isl.guide_to("den", p.global_position))
			check("  on the path: its top", Vector2(s2.x, s2.z).distance_to(isl.den_plan["top"]) < 1.0)
			return TK.done(fails)
	step += 1
	return false


## One frame on the chain: hold W toward the far side, let go near the top of the swing
## past the chain; true once it's over (on a floor, in the sea, or too long).
func _swing(dt: float) -> bool:
	drive["t"] = float(drive["t"]) + dt
	var far: Vector3 = _g(drive["far"]) + isl.global_basis * (drive["dir"] as Vector3) * 2.5
	var to: Vector3 = far - p.global_position
	_rig().global_rotation.y = atan2(-to.x, -to.z)
	var st: String = p.current_state_name()
	var past: float = (p.global_position - path.chain.global_position).dot(isl.global_basis * (drive["dir"] as Vector3))
	if st == "Swing" and past > 1.5 and not drive.get("let_go", false):
		TK.press("jump")
		drive["let_go"] = true
		drive["lt"] = 0.0
	if drive.get("let_go", false):
		drive["lt"] = float(drive["lt"]) + dt
		if float(drive["lt"]) > 0.3:
			TK.release("jump")
	return (st != "Swing" and st not in ["Jump", "Fall"]) or float(drive["t"]) > 8.0
