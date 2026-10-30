extends SceneTree
## The stronghold's garrison and its sealed room (1.27, StrongholdGarrison, StrongholdEncounter): a squad of Admiralty
## marines in each district, a rifleman among them, and a wiped squad comes back once no captain's near; the Mess Hall
## musters nothing until a captain walks in, then its grate drops and three waves come, each when the last is down;
## the last one down raises the grate and the room stays cleared.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var enc
var step := 0
var until := 0
var fails := 0
var seen: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _kill_all(camp) -> void:
	for g in camp.grunts:
		if is_instance_valid(g):
			g.health.take_damage(99999.0)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			# (the captain off at sea while the squads muster: their bodies are built a grunt a frame)
			p.global_position = Vector3(900, 2, 1300)
			p.reset_physics_interpolation()
			until = TK.wait_secs(10.0)
		2:
			var squads: Array = isl.garrison.filter(func(c): return str(c.name).begins_with("Garrison_"))
			var counts: Array = squads.map(func(c): return c.alive_count())
			check("a squad in each district (%s)" % [counts], squads.size() == 5 and counts.all(func(n): return n >= 4))
			var ward = squads.filter(func(c): return str(c.name) == "Garrison_ward")[0]
			check("...Admiralty marines, a rifleman among them", ward.grunts.all(func(g): return g.get("role") != null) and ward.grunts.any(func(g): return str(g.role) == "rifle"))
			# a wiped squad comes back once no captain's near (sooner here)
			ward.respawn_time = 2.0
			_kill_all(ward)
			until = TK.wait_secs(4.5)
		3:
			var ward = isl.garrison.filter(func(c): return str(c.name) == "Garrison_ward")[0]
			check("...a wiped squad comes back (wave %d, %d up)" % [ward.gen, ward.alive_count()], ward.gen >= 1 and ward.alive_count() >= 4)
			enc = isl.garrison.filter(func(c): return str(c.name) == "Encounter_mess")[0]
			check("the Mess Hall: nobody there yet, its door open", enc.gen == 0 and enc.alive_count() == 0 and not enc.door_shut())
			var r: Rect2 = enc.rm[2]
			p.global_position = isl.city.to_global(Vector3(r.get_center().x + 3.0, float(enc.rm[3]) + 0.4, r.get_center().y))
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		4, 5, 6:
			var want: int = enc.SIZES[step - 4]
			seen.append([enc.gen, enc.alive_count()])
			check("wave %d: %d marines, the grate down" % [step - 3, enc.alive_count()], enc.gen == step - 3 and enc.alive_count() == want and enc.door_shut() and enc._door.collision_layer == 1)
			_kill_all(enc)
			until = TK.wait_secs(enc.BETWEEN + 1.5)
		7:
			check("the last one down: the grate up, the hall cleared for good", not enc.door_shut() and enc.cleared() and enc._door.collision_layer == 0)
			return TK.done(fails)
	step += 1
	return false
