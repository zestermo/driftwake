extends SceneTree
## Officers in the stronghold's crowds (1.27, StrongholdOfficers): none until a captain comes near a district; then
## that district fields one (a captain-style AI, detuned: less health than a rival, on the captains); reaching the
## other districts brings theirs; never more than 5 standing at once; beating one makes room for another.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var off
var step := 0
var until := 0
var fails := 0
var leg := 0


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
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			off = isl.city.get_node("Officers")
			check("no officer before a captain comes near", off.standing().is_empty())
			var ward = isl.city.get_node("Garrison_ward")
			p.global_position = ward.global_position + Vector3(0, 1, 6)
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.5)
		3:
			var s: Array = off.standing()
			check("reaching the ward: its officer comes (%d)" % s.size(), s.size() == 1)
			if s.is_empty():
				return TK.done(fails)
			var o = s[0]
			check("...a captain-style AI on the captains, detuned (%.0f health)" % o.health_component.max_health, o.is_ai and o.get_node("Brain").order == "fight" and o.health_component.max_health < 100.0)
			# the other districts in turn
			for key in ["landing", "arsenal", "prison", "keep"]:
				off.spawn_near(isl.city.get_node("Garrison_" + key))
			check("one per district: five standing (%d)" % off.standing().size(), off.standing().size() == 5)
			off.spawn_near(isl.city.get_node("Garrison_ward"))
			check("...and no more than five at once (%d)" % off.standing().size(), off.standing().size() == 5)
			var first = off.standing()[0]
			first.health_component.take_damage(first.health_component.max_health * 2.0)
			until = TK.wait_secs(1.0)
		4:
			check("one beaten: four standing (%d)" % off.standing().size(), off.standing().size() == 4)
			check("...room for another", off.spawn_near(isl.city.get_node("Garrison_keep")) != null and off.standing().size() == 5)
			return TK.done(fails)
	step += 1
	return false
