extends SceneTree
## The snow's wildlife on the light stage: a wolf pack 9 m off notices the captain, its lead howls,
## the pack circles at a lunge's length and lunges one wolf at a time (never two crouched or lunging
## at once); snow hares near the captain bolt and get away; a walrus colony leaves you be until you
## walk into it, and a shagback herd ignores you.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var wolves: Array = []
var hares: Array = []
var shag
var walrus
var most_at_once := 0
var lunges := 0
var ringed := false
var noticed := false
var hare_d0 := 0.0
## Creature.S (loaded once the autoloads are up)
var S: Dictionary


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


var _spawned := 0


func _spawn(script: String, at: Vector3, args: Dictionary) -> Node3D:
	var c = load(script).new()
	_spawned += 1
	c.name = "%s_%d" % [script.get_file().get_basename(), _spawned]
	c.setup(at, args)
	c.position = at
	stage.add_child(c)
	return c


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	match step:
		0:
			S = load("res://scripts/enemies/fauna/creature.gd").S
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			for i in range(4):
				wolves.append(_spawn("res://scripts/enemies/fauna/wolf.gd", ground + Vector3(-1.5 + i, 0, -9.0 - i * 0.5), {"pack": 7, "lead": i == 0}))
			for i in range(2):
				hares.append(_spawn("res://scripts/enemies/fauna/snow_hare.gd", ground + Vector3(4.0 + i, 0, 3.0), {}))
			shag = _spawn("res://scripts/enemies/fauna/shagback.gd", ground + Vector3(-30.0, 0, 20.0), {"pack": 9})
			walrus = _spawn("res://scripts/enemies/fauna/walrus.gd", ground + Vector3(25.0, 0, 25.0), {"pack": 8, "lead": true})
			hare_d0 = hares[0].global_position.distance_to(p.global_position)
			until = TK.wait_ticks(2)
		1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20:
			# 8 s in 0.4 s looks
			var busy := 0
			for w in wolves:
				if w.state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK]:
					noticed = true
				if w.state in [S.TELL, S.ATTACK]:
					busy += 1
				if w.state == S.ATTACK and w.st_t < 0.45:
					lunges += 1
				var d: float = Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length()
				if w.state == S.CHASE and d > 3.0 and d < 8.0:
					ringed = true
			most_at_once = maxi(most_at_once, busy)
			until = TK.wait_secs(0.4)
		21:
			check("the pack noticed the captain 9 m off", noticed)
			check("it circled at a lunge's length", ringed)
			check("it lunged (%d looks caught a lunge)" % lunges, lunges > 0)
			check("one wolf at a time crouched or lunging (most at once %d)" % most_at_once, most_at_once <= 1)
			var hd: float = hares[0].global_position.distance_to(p.global_position)
			check("the hares bolted and got away (%.1f -> %.1f m)" % [hare_d0, hd], hares[0].state in [S.FLEE, S.WANDER] and hd > hare_d0 + 4.0)
			check("the shagback and the walrus far off minded their business", shag.state in [S.IDLE, S.WANDER] and walrus.state in [S.IDLE, S.WANDER])
			p.global_position = walrus.global_position + Vector3(0, 0.1, 2.5)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.5)
		22:
			check("walking into the colony, the bull rears and comes (%s)" % S.keys()[walrus.state], walrus.state in [S.NOTICE, S.CHASE, S.TELL, S.ATTACK, S.RECOVER])
			return TK.done(fails)
	step += 1
	return false
