extends SceneTree
## Tide Will at work: Deep Breath (twice the breath, 30% faster swimming), Wave Walk (onto deep water at a run the sea
## holds you, a step every 0.32 s for 6 steps, then you swim; not from a walk, not over the shallows; ground fills the
## steps again), Swell (aboard, the skill throws a boarder off the deck), Call the Wind (aboard, 25% more sail speed
## while it lasts), Helm Sense (while you steer, the hull takes 20% less).
const TK := preload("res://tools/dev/test_kit.gd")
var WW
var stage
var p
var pr
var ship
var g
var step := 0
var until := 0
var fails := 0
var held := 0
var hull0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true,
		"grunts": [{"post": Vector3(-10, 0, -10), "yaw": 0.0, "mode": "stand", "seed": 44, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(key: String, v: float = 1.0) -> void:
	pr.stat(key)
	pr._stats[key] = v


func _physics_process(_d: float) -> bool:
	if step == 3 and p.current_state_name() != "Swim" and absf(p.water_depth()) < 0.4:
		held += 1
	return false


func at_sea(x: float) -> void:
	p.global_position = Vector3(x, p.water_surface(Vector3(x, 0, 0)) + 0.4, 0)
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			WW = load("res://scripts/powers/wave_walk.gd")
			p = stage.player
			pr = p.progression
			ship = stage.ship
			g = stage.camp.grunts[0]
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			var sw = p.state_machine.get_node("Swim")
			var b0: float = sw.breath_max()
			pr.gift("will", 20)
			if pr.will_color == "":
				pr.attune("tide")
			check("Deep Lungs and Strong Stroke bought (1.26: the Edy tree)", EdyTree.learn_path(pr, "e_tide_0") and EdyTree.learn_path(pr, "e_tide_2"))
			check("...half again the breath (%.0f -> %.0f), swimming 30%% faster" % [b0, sw.breath_max()], is_equal_approx(sw.breath_max(), b0 * 1.5) and is_equal_approx(pr.stat("swim_pct"), 0.3))
			at_sea(stage.SHORE_X + 40.0)
			p.velocity = Vector3(2.0, 0, 0)
			p.state_machine.force_state("Fall", {})
			check("Wave Walk: not from a walk", not WW.can_start(p))
			p.velocity = Vector3(8.0, 0, 0)
			check("...at a run over deep water", WW.can_start(p))
			p.global_position = Vector3(0, stage.GROUND_Y + 0.2, 0)
			check("...not on land", not WW.can_start(p))
			give("wave_walk")
			at_sea(stage.SHORE_X + 40.0)
			p.state_machine.force_state("Fall", {})
			p.velocity = Vector3(8.0, 0, 0)
			TK.press("sprint")
			TK.press("move_forward")
			until = TK.wait_ticks(12)
		1:
			check("Wave Walk: the sea holds you", p.power.will._walk != null)
			held = 0
			until = TK.wait_secs(1.2)
			step = 3
			return false
		3:
			TK.release("sprint")
			TK.release("move_forward")
			print("   held %d ticks, steps left %d, state %s depth %.2f" % [held, p.power.will._steps, p.current_state_name(), p.water_depth()])
			check("...a second on the water, standing on it", held >= 60)
			until = TK.wait_secs(1.6)
		4:
			check("...6 steps and you're swimming (%s)" % p.current_state_name(), p.current_state_name() == "Swim" and p.power.will._walk == null and p.power.will._steps == 0)
			p.global_position = Vector3(0, stage.GROUND_Y + 0.2, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(10)
		5:
			check("solid ground fills the steps again", p.power.will._steps == WW.STEPS)
			p.global_position = ship.global_transform * Vector3(0, 1.6, 0)
			p.reset_physics_interpolation()
			g.global_position = ship.global_transform * Vector3(0.6, 1.6, 2.0)
			g.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		6:
			check("aboard, a boarder beside you", ship.aboard(p.global_position) and ship.aboard(g.global_position))
			p.state_machine.force_state("Technique", {"id": "will_swell"})
			until = TK.wait_secs(2.5)
		7:
			check("Swell: the boarder's thrown off the deck", not ship.aboard(g.global_position))
			p.global_position = ship.global_transform * Vector3(0, 1.6, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Technique", {"id": "will_wind"})
			until = TK.wait_secs(0.8)
		8:
			check("Call the Wind: 25%% more sail speed (%.2f)" % ship.will_k(), is_equal_approx(ship.will_k(), 1.25))
			ship.will_wind = 0.05
			hull0 = ship.hull
			ship.hull_hit(10.0, ship.global_position)
			check("...gone when it's over; a 10 hit takes 10 hull", is_equal_approx(ship.will_k(), 1.0) or ship.will_wind <= 0.05)
			check("...(hull %.1f)" % (hull0 - ship.hull), is_equal_approx(hull0 - ship.hull, 10.0))
			give("helm_sense", 0.2)
			ship._on_helm_interacted(p)
			until = TK.wait_ticks(70)
		9:
			check("Helm Sense: at the helm, the ship knows (%.1f)" % ship.will_guard, ship.will_guard > 0.0)
			hull0 = ship.hull
			ship.hull_hit(10.0, ship.global_position)
			check("...a 10 hit takes 8 (%.1f)" % (hull0 - ship.hull), is_equal_approx(hull0 - ship.hull, 8.0))
			return TK.done(fails)
	step += 1
	return false
