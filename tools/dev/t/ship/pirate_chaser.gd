extends SceneTree
## A pirate sloop runs down an upgraded crew sloop (1.30, playtest 2026-11-02 "no ship could catch us"): hunting, she
## crowds on the crew's speed and an edge that grows with the gap, reaches broadside range, then holds a running fight
## abreast of her (no hunt-broadside loop falling astern) and gets a volley off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var ship
var es
var step := 0
var until := 0
var fails := 0
var secs := 0
var worst := 0.0


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
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship = stage.ship
			ship.hull = 99999.0
			var k: Dictionary = ship.kit.duplicate()
			k["sails"] = 5
			k["copper"] = 2
			ship.apply_kit(k)
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(10.0)
		1:
			var at: Vector3 = ship.global_position + ship.global_basis.z * 140.0
			es = load("res://scripts/ship/enemy_ship.gd").new().setup(at, 30.0, 0.0, 13, "sloop")
			es.transform = Transform3D(Basis(Vector3.UP, ship.global_rotation.y), Vector3(at.x, 0.85, at.z))
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_ticks(3)
		2:
			es._set_state(es.S.HUNT)
			secs = 0
			until = TK.wait_secs(1.0)
		3:
			secs += 1
			var d: float = es.global_position.distance_to(ship.global_position)
			var far_r: float = es.spec["range"][1]
			if secs % 10 == 0:
				print("   %d s: crew %.1f m/s, pirate %.1f m/s (own %.1f), %.0f m, %s" % [secs, ship.speed, es.speed, float(es.spec["speed"]), d, es.S.keys()[es.state]])
			if d > far_r and secs < 90 and es.pursuing():
				until = TK.wait_secs(1.0)
				return false
			check("a pirate sloop 140 m astern reaches broadside range of an upgraded sloop (%d s, %.0f m, crew %.1f m/s)" % [secs, d, ship.speed], d <= far_r and secs < 90)
			secs = 0
			until = TK.wait_secs(1.0)
		4:
			secs += 1
			var d: float = es.global_position.distance_to(ship.global_position)
			worst = maxf(worst, d)
			if secs < 30:
				until = TK.wait_secs(1.0)
				return false
			check("...and holds the fight 30 s at her side, never falling back to hunt her (worst %.0f m, %s)" % [worst, es.S.keys()[es.state]], worst < float(es.spec["range"][1]) + 30.0 and es.pursuing())
			check("...with a volley off (%d)" % es._volleys, es._volleys >= 1)
			return TK.done(fails)
	step += 1
	return false
