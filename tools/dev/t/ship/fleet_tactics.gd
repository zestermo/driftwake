extends SceneTree
## Hunters and fleet tactics (docs/v1_23_plan.md, sea pursuit): a pirate hunter is light and quick, quicker still
## running before the wind; two ships on the crew take different parts (one on her wake, one cutting across her
## course ahead of her), and near land one steers for the open-water side of her, pinning her against the island.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var h1
var h2
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


func _hunter(n: String, off: Vector3):
	var es = load("res://scripts/ship/enemy_ship.gd").new().setup(ship.global_position + off, 60.0, 0.0, 31 + n.length(), "hunter")
	es.name = n
	stage.add_child(es)
	es.set_meta("no_sleep", true)
	es._pos = ship.global_position + off
	es._heading = ship.global_rotation.y
	es.global_transform = Transform3D(Basis(Vector3.UP, es._heading), es._pos + Vector3(0, 1.45, 0))
	es.reset_physics_interpolation()
	return es


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ES = load("res://scripts/ship/enemy_ship.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(6.0)
		1:
			var wd: Vector2 = root.get_node("Weather").wind_dir()
			var down := atan2(-wd.x, -wd.y)
			var h = _hunter("HunterA", Vector3(0, 0, 900))
			h._heading = down
			var run: float = h._max_speed()
			h._heading = down + PI
			var beat: float = h._max_speed()
			print("   hunter: %.1f m/s before the wind, %.1f m/s into it; a sloop %.1f" % [run, beat, float(ES.KINDS["sloop"]["speed"])])
			check("a hunter is quicker than a pirate sloop and the crew's ship at full sail", beat >= float(ES.KINDS["sloop"]["speed"]) and run > ship.MAX_SPEED * 1.2)
			check("...quicker still running before the wind (%.1f > %.1f)" % [run, beat], run > beat * 1.2)
			h.queue_free()
			var fwd: Vector3 = -ship.global_basis.z
			var right: Vector3 = ship.global_basis.x
			h1 = _hunter("HunterB", -fwd * 120.0 + right * 20.0)
			h2 = _hunter("HunterC", -fwd * 120.0 - right * 20.0)
			h1._set_state(ES.S.HUNT)
			h2._set_state(ES.S.HUNT)
			until = TK.wait_secs(1.0)
		2:
			var roles := [h1.tactic_role, h2.tactic_role]
			print("   roles %s" % [roles])
			check("two on her: one on her wake, one cutting across her course", "chase" in roles and "cut" in roles)
			var cutter = h1 if h1.tactic_role == "cut" else h2
			var fwd: Vector3 = -ship.global_basis.z
			var ahead: float = (cutter.tactic_at - ship.global_position).dot(fwd)
			check("...the cutter steers for a spot well ahead of her (%.0f m)" % ahead, ahead > 30.0)
			# an island off her port side
			var c: Vector3 = ship.global_position - ship.global_basis.x * 130.0
			ES.no_go = [[Vector2(c.x, c.z), 55.0]]
			until = TK.wait_secs(1.0)
		3:
			var roles := [h1.tactic_role, h2.tactic_role]
			print("   near land: roles %s" % [roles])
			check("near land one pins her against it", "pin" in roles)
			var pinner = h1 if h1.tactic_role == "pin" else h2
			var away: Vector3 = (ship.global_position - Vector3(ES.no_go[0][0].x, 0, ES.no_go[0][0].y)).normalized()
			check("...from the open-water side", (pinner.tactic_at - ship.global_position).dot(away) > 20.0)
			ES.no_go = []
			return TK.done(fails)
	step += 1
	return false
