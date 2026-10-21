class_name GruntCamp
extends Node3D
## A squad of pirate grunts holding a spot. Hands out attack turns (at most
## `max_attackers` swing at once; the rest circle and wait), spreads an alarm
## to everyone nearby, and when the whole crew is down it comes back after a
## while - but only once you're well away.

@export var max_attackers: int = 2
@export var respawn_time: float = 120.0
@export var respawn_clearance: float = 50.0

var specs: Array = []     # setup dicts for each grunt (positions local to this node)
var grunts: Array = []
var _tokens: Array = []
var _empty_t: float = 0.0
## Which wave this is (co-op: names the grunts the same on every machine).
var gen: int = 0
## Every crew it musters is this level (Levels; 0: unscaled).
var level: int = 0
var _prebuilt: int = -1


func add_grunt(cfg: Dictionary) -> void:
	specs.append(cfg)


## The first crew turns up once its bodies are built on a worker thread (a chain
## island's camp, put in the world mid-game: no hitch).
var warm_start := false
var _warming: Array = []
var _muster := -1


func _ready() -> void:
	add_to_group("net_spawner")
	if warm_start:
		_warming = specs.map(func(c): return PirateGrunt.look_for(c))
		Humanoid.prebuild(_warming)
	else:
		_spawn_all.call_deferred()


func _spawn_all() -> void:
	grunts.clear()
	_tokens.clear()
	for i in range(specs.size()):
		_spawn_one(i)


func _spawn_one(i: int) -> void:
	var c: Dictionary = (specs[i] as Dictionary).duplicate()
	c["post"] = to_global(c["post"])
	var patrol: Array = []
	for q in c.get("patrol", []):
		patrol.append(to_global(q))
	c["patrol"] = patrol
	if c.has("hold"):
		c["hold"] = [to_global(c["hold"][0]), c["hold"][1]]
	# (a setup's "script": a grunt of its own kind, the desert's bandit chief)
	var g: PirateGrunt = load(c["script"]).new() if c.has("script") else PirateGrunt.new()
	g.name = "G%d_%d" % [gen, i]
	g.setup(c)
	g.camp = self
	g.xp_k = 0.5 if gen > 0 else 1.0
	g.level = level
	add_child(g)
	g.global_position = c["post"] + Vector3.UP * 0.2
	g.reset_physics_interpolation()
	grunts.append(g)


func request_token(g: Node) -> bool:
	_tokens = _tokens.filter(func(t: Node) -> bool: return is_instance_valid(t) and (t as PirateGrunt).state != PirateGrunt.S.DEAD)
	if g in _tokens:
		return true
	# co-op: turns are handed out per captain (each one faces at most
	# max_attackers), with a cap on the whole squad
	var target = (g as PirateGrunt)._player
	var same := 0
	for t in _tokens:
		if (t as PirateGrunt)._player == target:
			same += 1
	var cap := max_attackers + (2 + Net.extra_attackers() if Net.coop() else 0)
	if same < max_attackers and _tokens.size() < cap:
		_tokens.append(g)
		return true
	return false


func release_token(g: Node) -> void:
	_tokens.erase(g)


func alert_all(from: Vector3) -> void:
	for g in grunts:
		if is_instance_valid(g) and (g as PirateGrunt).state == PirateGrunt.S.IDLE and (g as Node3D).global_position.distance_to(from) < 22.0:
			(g as PirateGrunt).alert(randf_range(0.15, 0.6))


func alive_count() -> int:
	var n := 0
	for g in grunts:
		if is_instance_valid(g) and (g as PirateGrunt).state != PirateGrunt.S.DEAD:
			n += 1
	return n


func _process(delta: float) -> void:
	if not _warming.is_empty():
		# its bodies built, the first crew turns up a grunt a frame (six at once was a 40 ms frame); manned once all are
		if _muster < 0:
			if not Humanoid.prebuilt_for(_warming):
				return
			_muster = 0
			grunts.clear()
			_tokens.clear()
		_spawn_one(_muster)
		_muster += 1
		if _muster >= specs.size():
			_muster = -1
			_warming = []
		return
	if specs.is_empty() or alive_count() > 0:
		_empty_t = 0.0
		return
	# the next crew's bodies, built on a worker thread while they're away
	if _prebuilt != gen + 1:
		_prebuilt = gen + 1
		Humanoid.prebuild(specs.map(func(c): return PirateGrunt.look_for(c)))
	if Net.is_client():
		return  # the host decides when the crew comes back
	_empty_t += delta
	if _empty_t < respawn_time:
		return
	for player in Net.all_players():
		if (player as Node3D).global_position.distance_to(global_position) < respawn_clearance:
			return
	_empty_t = 0.0
	gen += 1
	_spawn_all()
	Net.spawned(self, gen)


func net_gen():
	return gen


## Co-op client: the host's crew is on wave `g` (spawn it if we're behind).
func net_set_gen(g) -> void:
	if int(g) == gen:
		return
	gen = int(g)
	_warming = []
	_muster = -1
	for old in grunts:
		if is_instance_valid(old) and (old as PirateGrunt).state != PirateGrunt.S.DEAD:
			(old as Node).queue_free()
	_spawn_all()
