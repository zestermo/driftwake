extends SceneTree
## The stronghold's placed garrison (1.30 rework, StrongholdGarrison, FodderMarine): every district holds its men from
## the start, standing where they were placed on their district's floor, mostly fodder with riflemen and a sergeant; a
## fodder marine falls to 2-4 light blows and doesn't grow with the crew; a district cleared quietly (no alarm) is
## cleared for good and nobody comes; the Mess Hall's sealed waves still come behind its grate.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var enc
var step := 0
var until := 0
var fails := 0


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
	if stage.up:
		stage.player.health_component.current_health = stage.player.health_component.max_health
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1300)
			p.reset_physics_interpolation()
			until = TK.wait_secs(14.0)
		2:
			var squads: Array = isl.garrison.filter(func(c): return str(c.name).begins_with("Garrison_"))
			var counts: Array = squads.map(func(c): return c.alive_count())
			var total: int = counts.reduce(func(a, b): return a + b, 0)
			print("garrison by district %s, %d in all" % [counts, total])
			check("a garrison in every district, every man up (%s)" % [counts], squads.size() == 5 and squads.all(func(c): return c.alive_count() == c.specs.size() and c.specs.size() >= 10))
			var all: Array = []
			for c in squads:
				all.append_array(c.grunts)
			var fod: Array = all.filter(func(g): return g.is_in_group("fodder"))
			check("most are fodder (%d of %d), riflemen and a sergeant among them" % [fod.size(), all.size()],
				fod.size() * 10 >= all.size() * 7 and all.any(func(g): return str(g.role) == "rifle" and not g.is_in_group("fodder")) and all.any(func(g): return g.elite_rank))
			check("sentries posted in every district", squads.all(func(c): return c.grunts.any(func(g): return g.is_in_group("fodder") and g.sentry)))
			var off: Array = []
			for g in all:
				var l: Vector3 = isl.city.to_local(g.global_position)
				var fl := StrongholdPlan.ground(Vector2(l.x, l.z))
				var drift: float = Vector2(g.global_position.x - g.post.x, g.global_position.z - g.post.z).length()
				if fl == -INF or absf(l.y - fl) > 1.2 or (g.idle_mode != "patrol" and drift > 1.5):
					off.append("%s %s (%.1f, %.1f, %.1f) floor %.1f drift %.1f" % [g.get_parent().name, g.name, l.x, l.y, l.z, fl, drift])
			check("every man stands where he was placed, on his district's floor %s" % [off], off.is_empty())
			# toughness: 2-4 light blows (a cutlass's 10-12 from a captain of the fortress's level: captains' blows grow as
			# foes' health does, Levels.hp_k), no co-op growth
			var f = fod[0]
			var blow: float = 11.0 * Levels.hp_k(f.level)
			var hits := ceili(f.health.max_health / blow)
			check("a fodder marine falls in 2-4 light blows (%d: %.0f health, %.1f a blow)" % [hits, f.health.max_health, blow], hits >= 2 and hits <= 4)
			var hp0: float = f.health.max_health
			f.net_rescale(2.7)
			var serg = all.filter(func(g): return g.elite_rank)[0]
			var s0: float = serg.health.max_health
			serg.net_rescale(2.7)
			check("...no more health for a bigger crew (the sergeant does get it)", is_equal_approx(f.health.max_health, hp0) and serg.health.max_health > s0 * 2.0)
			serg.net_rescale(1.0)
			# the ward cleared quietly: all down at once, no alarm, nobody comes
			var ward = isl.city.get_node("Garrison_ward")
			_kill_all(ward)
			until = TK.wait_secs(2.0)
		3:
			var gm = root.get_node("GameManager")
			check("the ward cleared quietly: cleared for good, no alarm", gm.world_flags.has("sh_clear_ward") and not gm.world_flags.has("sh_alarm_ward"))
			var src: Array = isl.garrison.filter(func(c): return str(c.name).begins_with("Reinforce_ward"))
			check("...and no reinforcements came", src.size() == 2 and src.all(func(c): return c.gen == 0))
			until = TK.wait_secs(3.0)
		4:
			check("...nobody comes back to the ward", isl.city.get_node("Garrison_ward").alive_count() == 0)
			enc = isl.garrison.filter(func(c): return str(c.name) == "Encounter_mess")[0]
			check("the Mess Hall: nobody there yet, its door open", enc.gen == 0 and enc.alive_count() == 0 and not enc.door_shut())
			var r: Rect2 = enc.rm[2]
			p.global_position = isl.city.to_global(Vector3(r.get_center().x + 3.0, float(enc.rm[3]) + 0.4, r.get_center().y))
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		5, 6, 7:
			var want: int = enc.SIZES[step - 5]
			check("wave %d: %d marines, the grate down" % [step - 4, enc.alive_count()], enc.gen == step - 4 and enc.alive_count() == want and enc.door_shut() and enc._door.collision_layer == 1)
			_kill_all(enc)
			p.health_component.current_health = p.health_component.max_health
			until = TK.wait_secs(enc.BETWEEN + 1.5)
		8:
			check("the last one down: the grate up, the hall cleared for good", not enc.door_shut() and enc.cleared() and enc._door.collision_layer == 0)
			return TK.done(fails)
	step += 1
	return false
