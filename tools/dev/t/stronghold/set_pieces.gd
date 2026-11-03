extends SceneTree
## The stronghold's set-piece bosses (1.30, StrongholdBoss): Kesh's fight starts as a captain walks into the Casting
## Hall, a faster brain (pace under 1); his signature leap marks a captain's spot and lands on it; at half health the
## crucible pours molten iron on the hall's floor in turn and burns a captain standing in the pour. Fall in his hall and
## you get back up at its checkpoint outside the door; the whole crew down is a wipe: the fight starts over (flags cleared,
## Kesh healed, waiting). Commodore Vane at 65% leaps up onto the Verdict's roof; at 30% the Scouring is ordered.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var kesh
var vane
var step := 0
var until := 0
var fails := 0
var t0 := 0
var leaps := 0
var hp0 := 0.0
var heal := true


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _flag(f: String) -> bool:
	return root.get_node("GameManager").world_flags.has(f)


func _at(q: Vector2, y: float) -> void:
	var p = stage.player
	p.state_machine.force_state("Idle", {})
	p.global_position = isl.city_global(q, y + 0.3)
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if stage.up and heal:
		stage.player.health_component.current_health = stage.player.health_component.max_health
	if stage.up and kesh and kesh.boss and is_instance_valid(kesh.boss) and kesh.boss.current_state_name() == "BossLeap" and step == 4:
		leaps = 1
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
			until = TK.wait_secs(12.0)
		2:
			kesh = isl.city.get_node("Boss_kesh")
			vane = isl.city.get_node("Boss_vane")
			_at(Vector2(78.0, -23.0), 14.0)
			until = TK.wait_secs(2.0)
		3:
			check("into the Casting Hall: Kesh's fight is on, his intro card shown", _flag("sh_kesh_on") and kesh.boss != null and kesh._carded)
			check("...a faster, harder brain (pace %.2f)" % kesh.boss.get_node("Brain").pace, kesh.boss.get_node("Brain").pace < 1.0)
			kesh._sig_t = 0.0
			t0 = Engine.get_physics_frames()
			until = TK.wait_secs(0.5)
		4:
			if leaps == 0 and Engine.get_physics_frames() - t0 < 60 * 8:
				until = TK.wait_ticks(5)
				return false
			check("his signature leap comes at the captain", leaps > 0)
			root.get_node("Net").world_flag("sh_kesh_p2")
			# a pour's spot, while it burns
			t0 = Engine.get_physics_frames()
			step = 5
			return false
		5:
			var now: Array = kesh.pour_now()
			if str(now[1]) != "burn" and Engine.get_physics_frames() - t0 < 60 * 12:
				until = TK.wait_ticks(5)
				return false
			check("half health: the crucible pours in turn (%s)" % [now], str(now[1]) == "burn" and kesh._pour_streams[int(now[0])].visible)
			var q: Vector2 = kesh.POURS[int(now[0])]
			p.global_position = kesh.to_global(Vector3(q.x, 0.3, q.y))
			p.reset_physics_interpolation()
			heal = false
			hp0 = p.health_component.current_health
			until = TK.wait_secs(1.2)
		6:
			check("...and burns a captain standing in the pour (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			heal = true
			var cp: Vector3 = kesh.checkpoint()
			check("fall in his hall and you'd get up at its checkpoint, outside the door", kesh.rejoin_point(p.global_position).distance_to(cp) < 0.1
				and not kesh.contains(cp) and kesh.rejoin_point(isl.city_global(Vector2(0, 0), 12.0)) == Vector3.INF)
			# the whole crew down: a wipe
			heal = false
			p.health_component.take_damage(99999.0)
			until = TK.wait_secs(1.0)
		7:
			check("the whole crew down: the fight starts over (flags cleared, Kesh healed and waiting) [on %s p2 %s hp %.0f/%.0f order %s, captain %s standing %s]" % [_flag("sh_kesh_on"), _flag("sh_kesh_p2"),
				kesh.boss.health_component.current_health, kesh.boss.health_component.max_health, kesh.boss.get_node("Brain").order, p.current_state_name(), p.is_standing()], not _flag("sh_kesh_on") and not _flag("sh_kesh_p2")
				and kesh.boss.health_component.current_health >= kesh.boss.health_component.max_health * 0.99 and kesh.boss.get_node("Brain").order == "hold")
			until = TK.wait_secs(kesh.REJOIN_SECS + 2.0)
		8:
			heal = true
			check("...and the captain is back up at the checkpoint (%.1f m off)" % p.global_position.distance_to(kesh.checkpoint()),
				p.global_position.distance_to(kesh.checkpoint()) < 3.0 and p.is_standing())
			# Vane: the hall, then the roof
			for f in ["sh_gate_open", "sh_seal_arsenal", "sh_seal_prison"]:
				root.get_node("Net").world_flag(f)
			_at(Vector2(0.0, -80.0), 30.0)
			until = TK.wait_secs(2.0)
		9:
			check("into the Command Hall: Vane's fight is on", _flag("sh_vane_on") and vane.boss != null)
			vane.boss.health_component.current_health = vane.boss.health_component.max_health * 0.6
			until = TK.wait_secs(4.0)
		10:
			var l: Vector3 = isl.city.to_local(vane.boss.global_position)
			check("at 65%%: up onto the Verdict's roof (%s)" % l, _flag("sh_vane_p2") and absf(l.y - load("res://scripts/island/stronghold_acts.gd").ROOF_Y) < 1.5)
			vane.boss.health_component.current_health = vane.boss.health_component.max_health * 0.25
			until = TK.wait_secs(1.0)
		11:
			check("at 30%: the Verdict, and the Scouring is ordered", _flag("sh_vane_p3") and _flag("sh_scouring"))
			return TK.done(fails)
	step += 1
	return false
