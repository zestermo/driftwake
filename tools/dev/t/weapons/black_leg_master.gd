extends SceneTree
## 1.23 masters, 1.24.1's spar: Bao's test ("master:black_leg", from his dialogue): his pupil Tomo goes out to the
## sparring spot (here a few steps ahead: no teahouse) and drills, waiting, bare-handed and kicking; walk up and he asks
## if you're ready; ready, you both bow and a 3-2-1 counts in; only then does he fight. Put him down and you've learned
## black leg (the tree shows, Dialogue flag "master_black_leg"); nothing paid, he leaves.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var bout
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			check("(not taught yet)", not p.knows_black_leg())
			root.get_node("Net").request_arena("master:black_leg", 0)
			until = TK.wait_secs(0.5)
		1:
			var bouts := get_nodes_in_group("arena_bouts")
			bout = bouts[0] if not bouts.is_empty() else null
			check("the test starts: Tomo goes out to the spot", bout != null and is_instance_valid(bout.rival))
			if bout == null:
				return TK.done(fails + 1)
			check("...bare-handed, kicking (%s)" % bout.rival.style(), bout.rival.equipped_weapon == null and bout.rival.style() == "black_leg")
			check("...and waits there, not fighting (%s, %s)" % [bout.phase, bout.rival.get_node("Brain").order], bout.phase == "wait" and bout.rival.get_node("Brain").order == "rest")
			p.global_position = bout.rival.global_position + Vector3(0, 0, 2.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		2:
			var dlg = root.get_node("Dialogue")
			check("walk up: he asks if you're ready", dlg.active and dlg._id == "spar")
			dlg.dialogue_event.emit("spar:go")
			dlg._close()
			until = TK.wait_ticks(4)
		3:
			check("ready: the bow, not the fight yet (%s)" % bout.phase, bout.phase == "bow" and bout.rival.get_node("Brain").order == "hold")
			until = TK.wait_secs(5.0)
		4:
			check("after the bow and the 3-2-1: the fight (%s)" % bout.phase, bout.phase == "fight" and bout.rival.get_node("Brain").order == "fight")
			bout.rival.health_component.current_health = 1.0
			until = TK.wait_secs(0.5)
		5:
			check("put him down: black leg learned", p.knows_black_leg() and p.progression.visible_trees("combat").has("black_leg"))
			check("...remembered (Bao won't offer again)", root.get_node("Dialogue").has_flag("master_black_leg"))
			return TK.done(fails)
	step += 1
	return false
