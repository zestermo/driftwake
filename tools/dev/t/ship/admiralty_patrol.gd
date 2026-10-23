extends SceneTree
## An Admiralty patrol (EnemyShip kind "marine", docs/v1_19_plan.md): in group "admiralty", her crew in the grey
## (steel helmets, the officer in a dark longcoat); she leaves a crew with no bounty alone, comes about once the crew's
## bounties together are Notorious, and sinking her raises the captain's bounty by an Admiralty ship's.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var es
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


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
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			p.bounty = 0
			var ES = load("res://scripts/ship/enemy_ship.gd")
			es = ES.new().setup(ship.global_position + Vector3(60, 0, 0), 30.0, 0.0, 11, "marine")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			var plan: Array = ES.crew_plan(11, "marine")
			check("an Admiralty cutter: in group admiralty, named so", es.is_in_group("admiralty") and ES.KINDS["marine"]["look"]["sail"].r < 0.7)
			check("...her crew in the grey: helmets, the officer in a dark longcoat (%s / %s)" % [plan[1][0]["hat"], plan[0][0]["coat"]],
				plan[1][0]["hat"] == "morion" and plan[0][0]["coat"] == "longcoat" and str(plan[0][0]["name"]).begins_with("Admiralty"))
			until = TK.wait_secs(5.0)
		1:
			check("a crew with no bounty: she keeps to her patrol (%s)" % es.S.keys()[es.state], es.state == es.S.PATROL)
			p.bounty = 25000
			until = TK.wait_secs(5.0)
		2:
			check("the crew notorious: she comes about for them (%s)" % es.S.keys()[es.state], es.state != es.S.PATROL)
			var b0: int = p.bounty
			es._start_sink()
			check("sunk: the captain's bounty up an Admiralty ship's (%d)" % (p.bounty - b0), p.bounty - b0 == 5000)
			return TK.done(fails)
	step += 1
	return false
