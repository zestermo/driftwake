extends Node3D
class_name EnemyFleet
## Keeps pirate ships on patrol: one per stretch of sea (`add_zone`). A sunk
## ship is replaced after a while, out of sight of every captain.
##
## Co-op: a spawner (net_spawner); the host decides when ships come back and
## the wave numbers name them the same on every machine.

@export var respawn_time: float = 150.0
@export var respawn_clearance: float = 220.0
## Crews are seeded from this (a fleet on a sea leg has its own, so its men differ).
var seed_base: int = 7000
## The first ships wait for their crews' bodies, built on a worker thread (no hitch
## when a sea leg's fleet appears mid-voyage).
var warm: bool = false

var zones: Array = []   # {center: Vector3, radius: float, kinds: Array, level: int, ship: EnemyShip, gen: int, timer: float}


## `kinds` (EnemyShip.KINDS): what sails this stretch, in turn as ships are sunk and replaced.
## `level`: the island it lies before (a sea leg's; 0 = Brinehollow's sea).
func add_zone(center: Vector3, radius: float, kinds: Array = ["sloop"], level: int = 0) -> void:
	zones.append({"center": center, "radius": radius, "kinds": kinds, "level": level, "ship": null, "gen": 0, "timer": 0.0})


func _ready() -> void:
	add_to_group("net_spawner")
	_spawn_all.call_deferred()


func _spawn_all() -> void:
	for i in range(zones.size()):
		if warm:
			zones[i]["warming"] = true
			Humanoid.prebuild(_looks(i, 0))
		else:
			_spawn(i)


func _looks(i: int, gen: int) -> Array:
	return EnemyShip.crew_plan(_seed_of(i, gen), _kind_of(i, gen)).map(func(e): return e[0])


func _spawn(i: int) -> void:
	var z: Dictionary = zones[i]
	z["warming"] = false
	var old = z["ship"]
	if old != null and is_instance_valid(old) and not (old as EnemyShip).is_dead():
		(old as Node).queue_free()
	var a := float(z["gen"]) * 2.1 + i * 1.3
	var r: float = z["radius"]
	var c: Vector3 = z["center"]
	var pos := c + Vector3(cos(a), 0.0, sin(a)) * r
	var s := EnemyShip.new()
	s.name = "ES%d_%d" % [i, int(z["gen"])]
	s.setup(c, r, a + 0.6, _seed_of(i, int(z["gen"])), _kind_of(i, int(z["gen"])))
	s.fleet = self
	s.xp_k = 0.5 if int(z["gen"]) > 0 else 1.0
	s.level = int(z["level"])
	add_child(s)
	var tangent := Vector3(-sin(a), 0.0, cos(a))
	s.global_transform = Transform3D(Basis(Vector3.UP, atan2(-tangent.x, -tangent.z)), Vector3(pos.x, 0.85, pos.z))
	s._pos = Vector3(pos.x, 0, pos.z)
	s._heading = atan2(-tangent.x, -tangent.z)
	s.reset_physics_interpolation()
	z["ship"] = s
	z["timer"] = 0.0


func _process(delta: float) -> void:
	for i in range(zones.size()):
		var z: Dictionary = zones[i]
		if z.get("warming", false):
			if Humanoid.prebuilt_for(_looks(i, int(z["gen"]))):
				_spawn(i)
			continue
		var s = z["ship"]
		if s != null and is_instance_valid(s) and not (s as EnemyShip).is_dead():
			continue
		# the next ship's crew, built on a worker thread while she's away
		if int(z.get("prebuilt", -1)) != int(z["gen"]) + 1:
			z["prebuilt"] = int(z["gen"]) + 1
			Humanoid.prebuild(_looks(i, int(z["gen"]) + 1))
		if Net.is_client():
			continue  # (the host decides when she comes back)
		z["timer"] = float(z["timer"]) + delta
		if float(z["timer"]) < respawn_time or (s != null and is_instance_valid(s)):
			continue
		var c: Vector3 = z["center"]
		var watched := false
		for p in Net.all_players():
			if (p as Node3D).global_position.distance_to(c) < respawn_clearance:
				watched = true
		if watched:
			continue
		z["gen"] = int(z["gen"]) + 1
		_spawn(i)
		Net.spawned(self, net_gen())


func _seed_of(i: int, gen: int) -> int:
	return seed_base + i * 31 + gen


func _kind_of(i: int, gen: int) -> String:
	var kinds: Array = zones[i]["kinds"]
	return kinds[gen % kinds.size()]


func net_gen():
	var g: Array = []
	for z in zones:
		g.append(int(z["gen"]))
	return g


func net_set_gen(g) -> void:
	var arr: Array = g
	for i in range(mini(arr.size(), zones.size())):
		if int(arr[i]) != int(zones[i]["gen"]):
			zones[i]["gen"] = int(arr[i])
			_spawn(i)


func ships() -> Array:
	var out: Array = []
	for z in zones:
		var s = z["ship"]
		if s != null and is_instance_valid(s):
			out.append(s)
	return out
