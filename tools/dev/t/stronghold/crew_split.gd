extends SceneTree
## The stronghold's crew-split objectives (1.30 piece 4, StrongholdActs), each one a lone captain can still finish:
## the gate's winch rouses the Landing (one winds, the others hold off its alarm's boats); the perch up the ward's front
## wall holds a captain and its rack hands out one long gun; the vault's two locks open it only pulled together (a lone
## captain gets a window long enough to run between them); the prison's riot breaks out of its own cell block.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var acts
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


func _flag(f: String) -> bool:
	return root.get_node("GameManager").world_flags.has(f)


func _process(_d: float) -> bool:
	if stage.up:
		stage.player.health_component.current_health = stage.player.health_component.max_health
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			acts = load("res://scripts/island/stronghold_acts.gd")
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1300)
			p.reset_physics_interpolation()
			until = TK.wait_secs(12.0)
		2:
			var q: Vector2 = acts.WINCH + Vector2(0.6, 0.6)
			p.global_position = isl.city_global(q, StrongholdPlan.ground(q) + 0.3)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		3:
			check("no alarm on the Landing before the winch", not isl.city.get_node("Alarm").alarmed("landing"))
			isl.city.get_node("Gate")._winch.interacted.emit(p)
			until = TK.wait_secs(1.0)
		4:
			check("the winch's clank rouses the Landing: its alarm's up", isl.city.get_node("Alarm").alarmed("landing"))
			# the perch: on its deck, the rack
			var c: Vector2 = acts.PERCH.get_center()
			p.state_machine.force_state("Idle", {})
			p.global_position = isl.city_global(c, acts.PERCH_Y + 0.3)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
		5:
			var l: Vector3 = isl.city.to_local(p.global_position)
			check("the perch on the ward's front wall holds a captain (%.1f)" % l.y, absf(l.y - acts.PERCH_Y) < 0.6 and p.is_on_floor())
			var mid: Vector2 = (acts.PERCH_STAIR[0] + acts.PERCH_STAIR[1]) * 0.5
			var hit = p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(isl.city_global(mid, 25.0), isl.city_global(mid, 10.0), 1))
			check("...its stair climbs to it (%s)" % (isl.city.to_local(hit["position"]) if not hit.is_empty() else "nothing"),
				not hit.is_empty() and absf(isl.city.to_local(hit["position"]).y - 15.0) < 1.0)
			var rack = isl.city.get_node("Perch/Rack")
			var n0: int = p.inventory_component.count("musket")
			rack.interacted.emit(p)
			rack.interacted.emit(p)
			check("...its rack hands out one long gun (%d -> %d)" % [n0, p.inventory_component.count("musket")], p.inventory_component.count("musket") == maxi(n0, 1))
			# the vault's locks
			root.get_node("Net").world_flag("sh_seal_keep")
			var locks = isl.city.get_node("VaultLocks")
			check("...a lone captain gets the long window (%.0f s)" % locks.window(), is_equal_approx(locks.window(), acts.LOCK_WINDOW_SOLO))
			locks.pull(0)
			until = TK.wait_secs(acts.LOCK_WINDOW_SOLO + 1.0)
		6:
			var locks = isl.city.get_node("VaultLocks")
			locks.pull(1)
			check("the vault's locks pulled too far apart: still shut", not _flag("sh_vault_unlocked"))
			until = TK.wait_secs(2.0)
		7:
			var locks = isl.city.get_node("VaultLocks")
			locks.pull(0)
			until = TK.wait_ticks(5)
		8:
			check("...pulled together: unlocked", _flag("sh_vault_unlocked"))
			# the cell block and the riot inside it
			var cells = isl.city.get_node_or_null("CellBlock")
			var enc = isl.city.get_node("Encounter_cells_marrow")
			var inside := true
			for s in enc.wave_specs(1):
				var q: Vector3 = enc.to_global(s["post"])
				var l: Vector3 = isl.city.to_local(q)
				inside = inside and acts.CELLS.has_point(Vector2(l.x, l.z))
			check("the prison yard's cell block stands, and the riot musters inside it", cells != null and inside)
			return TK.done(fails)
	step += 1
	return false
