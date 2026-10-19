extends SceneTree
## Cold water round a snow island saps a swimmer's stamina: treading water there it falls where at home it
## comes back, the warning shows, and still no health is lost.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var isle
var step := 0
var until := 0
var fails := 0
var st0 := 0.0
var hp0 := 0.0


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
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			p.stamina = 50.0
			until = TK.wait_secs(0.5)
		1:
			st0 = p.stamina
			until = TK.wait_secs(3.0)
		2:
			print("   home waters, treading 3 s: stamina ", snappedf(st0, 0.1), " -> ", snappedf(p.stamina, 0.1))
			check("in home waters treading water brings stamina back", p.stamina > st0)
			check("...no cold", sw.cold < 0.01)
			# a snow island right here
			isle = load("res://scripts/island/gen_island.gd").new()
			isle.theme = "snow"
			isle.radius = 60.0
			# (enough of an island for the systems that look the chain's islands over: the map's fog)
			isle.node = {"id": 99, "name": "Frost Test", "theme": "snow", "seed": 1}
			isle.half = 60.0
			isle.extent = 120.0
			isle.res = 40
			isle.position = Vector3(stage.SHORE_X - 20.0, 0, 0)
			stage.get_node("NoIslands").chain_islands[99] = isle
			p.stamina = 50.0
			hp0 = p.health_component.current_health
			until = TK.wait_secs(0.5)
		3:
			st0 = p.stamina
			until = TK.wait_secs(3.0)
		4:
			print("   off a snow island, treading 3 s: stamina ", snappedf(st0, 0.1), " -> ", snappedf(p.stamina, 0.1), " cold ", snappedf(sw.cold, 0.01))
			check("off a snow island the water's cold (%.2f)" % sw.cold, sw.cold > 0.9)
			check("...treading water there stamina falls (%.1f -> %.1f)" % [st0, p.stamina], p.stamina < st0 - 5.0)
			check("...no health lost", is_equal_approx(p.health_component.current_health, hp0))
			stage.get_node("NoIslands").chain_islands.erase(99)
			isle.free()
			return TK.done(fails)
	step += 1
	return false
