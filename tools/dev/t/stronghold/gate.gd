extends SceneTree
## Act 1, the Landing's gate (1.30, StrongholdActs.Gate): the portcullis at the grand stair's head is down and solid; its
## charge mark is there to blow; the winch raises it only while a captain stays at it (walk off and it stops), and once
## wound the gate is up for good, passable, its charge spent. The hoist in the Command Hall carries a captain up onto
## the Verdict's roof (a deck that holds them) and back down.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var gate
var step := 0
var until := 0
var fails := 0
var p0 := 0.0


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
			until = TK.wait_secs(12.0)
		2:
			gate = isl.city.get_node("Gate")
			check("the gate's portcullis is down and solid", not _flag("sh_gate_open") and gate.bars.collision_layer == 1 and gate.bars.position.y < 0.1)
			check("...a charge's mark on it, not blown", gate._charge != null and not gate._charge.done)
			# a ray along the stair through the gate hits the bars
			var from: Vector3 = isl.city_global(Vector2(0, 24), 13.2)
			var to: Vector3 = isl.city_global(Vector2(0, 14), 13.2)
			var hit = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
			check("...it bars the stair", not hit.is_empty() and hit["collider"] == gate.bars)
			# (the Landing cleared quietly first: the winch's clank would bring its boats down on the captain)
			for g in isl.city.get_node("Garrison_landing").grunts:
				if is_instance_valid(g):
					g.health.take_damage(99999.0)
			_at(load("res://scripts/island/stronghold_acts.gd").WINCH + Vector2(0.6, 0.6), StrongholdPlan.ground(load("res://scripts/island/stronghold_acts.gd").WINCH))
			until = TK.wait_ticks(10)
		3:
			gate._winch.interacted.emit(p)
			until = TK.wait_secs(3.0)
		4:
			p0 = gate.progress
			check("the winch winds while the captain stays at it (%.2f)" % p0, p0 > 0.25 and p0 < 0.6 and not _flag("sh_gate_open"))
			_at(Vector2(0, 30), StrongholdPlan.ground(Vector2(0, 30)))
			until = TK.wait_secs(1.5)
		5:
			check("...walk off and it stops (%.2f)" % gate.progress, absf(gate.progress - p0) < 0.05 and not gate._winding)
			_at(load("res://scripts/island/stronghold_acts.gd").WINCH + Vector2(0.6, 0.6), StrongholdPlan.ground(load("res://scripts/island/stronghold_acts.gd").WINCH))
			until = TK.wait_ticks(5)
		6:
			gate._winch.interacted.emit(p)
			until = TK.wait_secs(load("res://scripts/island/stronghold_acts.gd").WINCH_SECS + 3.0)
		7:
			check("wound all the way: the gate is up for good", _flag("sh_gate_open") and gate.bars.collision_layer == 0 and gate.bars.position.y > 5.0)
			check("...its charge spent, the winch done", gate._charge.done and not gate._winch.enabled)
			# the hoist up
			var acts = load("res://scripts/island/stronghold_acts.gd")
			_at(acts.HOIST_DOWN, 30.0)
			until = TK.wait_ticks(10)
		8:
			isl.city.get_node("Hoist_30/Use").interacted.emit(p)
			until = TK.wait_secs(1.5)
		9:
			var acts = load("res://scripts/island/stronghold_acts.gd")
			var l: Vector3 = isl.city.to_local(p.global_position)
			check("the hoist carries the captain up onto the Verdict's roof, and it holds them (%s)" % l, absf(l.y - acts.ROOF_Y) < 0.6 and p.is_on_floor())
			isl.city.get_node("Hoist_63/Use").interacted.emit(p)
			until = TK.wait_secs(1.0)
		10:
			var l: Vector3 = isl.city.to_local(p.global_position)
			check("...and back down to the Command Hall (%s)" % l, absf(l.y - 30.0) < 0.6)
			return TK.done(fails)
	step += 1
	return false
