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


func add_grunt(cfg: Dictionary) -> void:
	specs.append(cfg)


func _ready() -> void:
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	grunts.clear()
	_tokens.clear()
	for cfg in specs:
		var c: Dictionary = (cfg as Dictionary).duplicate()
		c["post"] = to_global(c["post"])
		var patrol: Array = []
		for q in c.get("patrol", []):
			patrol.append(to_global(q))
		c["patrol"] = patrol
		var g := PirateGrunt.new()
		g.name = "Grunt"
		g.setup(c)
		g.camp = self
		add_child(g)
		g.global_position = c["post"] + Vector3.UP * 0.2
		g.reset_physics_interpolation()
		grunts.append(g)


func request_token(g: Node) -> bool:
	_tokens = _tokens.filter(func(t: Node) -> bool: return is_instance_valid(t) and (t as PirateGrunt).state != PirateGrunt.S.DEAD)
	if g in _tokens:
		return true
	if _tokens.size() < max_attackers:
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
	if specs.is_empty() or alive_count() > 0:
		_empty_t = 0.0
		return
	_empty_t += delta
	if _empty_t < respawn_time:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position) < respawn_clearance:
		return
	_empty_t = 0.0
	_spawn_all()
