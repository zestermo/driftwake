extends SceneTree
## The Admiralty's ships come without a hitch (1.30, playtest 2026-11-02: a ring froze every machine 2-3 s): a deed's
## blockade, the ring once she's at sea and a patrol on her wake are made only once their crews' bodies are built on a
## worker (Humanoid.prebuild), at most one ship a frame; no body is built on the main thread (Perf's mark) the whole time.
const TK := preload("res://tools/dev/test_kit.gd")
const MARK := "a body built on the main thread"
var stage
var ship
var adm
var step := 0
var until := 0
var fails := 0
var watching := false
var marks := 0
var most := 0
var last := 0
var secs := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ships() -> int:
	return adm.get_children().filter(func(c): return c.has_method("pursuing")).size()


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (every frame: the marks made since Perf's last frame, and how many ships appeared at once)
	if watching:
		marks += (root.get_node("Perf")._marks as Array).count(MARK)
		var n := _ships()
		most = maxi(most, n - last)
		last = n
	if TK.ticking(until):
		return false
	var p = stage.player
	var ES = load("res://scripts/ship/enemy_ship.gd")
	match step:
		0:
			ship = stage.ship
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			ship.hull = 99999.0
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			p.bounty = 70000
			var c: Vector3 = ship.global_position - ship.global_basis.x * 260.0
			ES.no_go = [[Vector2(c.x, c.z), 60.0]]
			var A = load("res://scripts/ship/admiralty.gd")
			adm = A.ensure(self)
			watching = true
			A.deed(self, c + Vector3(20, 0, 0), "boss")
			secs = 0.0
			until = TK.wait_secs(0.5)
		1:
			secs += 0.5
			var roles: Array = adm.get_children().filter(func(c): return c.has_method("pursuing")).map(func(s): return s.role)
			var out: bool = roles.count("block") == 3 and roles.count("ring") >= 3
			if not out and secs < 30.0:
				until = TK.wait_secs(0.5)
				return false
			check("a blockade and a ring are out (%s in %.1f s)" % [roles, secs], out)
			adm.send_patrol(ship, 3)
			secs = 0.0
			until = TK.wait_secs(0.5)
		2:
			secs += 0.5
			var roles: Array = adm.get_children().filter(func(c): return c.has_method("pursuing")).map(func(s): return s.role)
			if roles.count("patrol") < 2 and secs < 30.0:
				until = TK.wait_secs(0.5)
				return false
			check("...and a patrol (%d in %.1f s)" % [roles.count("patrol"), secs], roles.count("patrol") == 2)
			check("no body built on the main thread for any of them (%d)" % marks, marks == 0)
			check("...and no more than one ship made a frame (%d)" % most, most == 1)
			check("nothing left waiting (%d)" % adm._pending.size(), adm._pending.is_empty())
			ES.no_go = []
			return TK.done(fails)
	step += 1
	return false
