extends SceneTree
## Spearfishing (1.28): a deep dive brings a school of 3-5 of the waters' fish round the diver (never a legendary);
## right mouse held aims (no strike), a throw at a fish lands it (the bag, the journal); the spear recovers before
## another throw; surfacing sends the school away.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var step := 0
var until := 0
var fails := 0
var target_id := ""


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			sw = p.get_node("StateMachine/Swim")
			p.global_position = Vector3(stage.SHORE_X + 16.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
			step = 1
		1:
			check("no school treading water", sw.school == null)
			TK.press("dodge")
			until = TK.wait_secs(1.6)
			step = 2
		2:
			var s = sw.school
			check("a deep dive brings a school", s != null)
			if s == null:
				print("RESULT FAILED (%d)" % (fails + 1))
				quit(1)
				return true
			check("3 to 5 fish (%d)" % s.fish.size(), s.fish.size() >= 3 and s.fish.size() <= 5)
			check("never a legendary", s.fish.all(func(f): return FishTable.rarity_of(str(f["id"])) < 4))
			TK.press("heavy_attack")
			until = TK.wait_ticks(3)
			step = 3
		3:
			check("right mouse held aims the spear", sw.school.aiming)
			check("...and doesn't strike", sw._strike_hit < 0.0)
			TK.release("heavy_attack")
			# hold the school still and throw straight at one
			for f in sw.school.fish:
				f["spd"] = 0.0
			until = TK.wait_ticks(2)
			step = 4
		4:
			var f: Dictionary = sw.school.fish[0]
			target_id = str(f["id"])
			var to: Vector3 = (f["mi"] as Node3D).global_position - sw.school._chest()
			check("the throw flies", sw.school.throw(to))
			check("...and the spear recovers before another", not sw.school.throw(to))
			until = TK.wait_secs(0.8)
			step = 5
		5:
			# (the first fish the spear passes through is the one landed: maybe not the one aimed at)
			var got: Array = p.progression.fish_log.keys()
			check("a speared fish is landed (aimed at %s, got %s)" % [target_id, str(got)], sw.school.caught == 1 and got.size() == 1 and p.inventory_component.count(str(got[0])) >= 1)
			check("...one fewer in the school", sw.school.fish.size() >= 2)
			TK.release("dodge")
			TK.press("jump")
			until = TK.wait_secs(3.0)
			step = 6
		6:
			TK.release("jump")
			check("surfaced, the school's gone", sw.school == null and stage.find_children("SpearSchool", "", true, false).is_empty())
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 7
	return false
