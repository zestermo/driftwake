class_name StrongholdEncounter
extends GruntCamp
## A sealed fight room in the stronghold (1.27, docs/v1_27_raids_fruits_plan.md preview v2: "the gates drop when you
## enter, the waves are fixed, nothing respawns inside, and once beaten they stay beaten"). A GruntCamp that musters
## nothing until a captain walks into its room (StrongholdPlan.ROOMS); then an iron grate drops across the door and
## WAVES waves come one after another, each when the last is down. The last one down raises the grate for good (a world
## flag, "sh_cleared_<room>"). The host decides each wave (gen, sent like any camp's respawn: Net.spawned); every
## machine works out the grate from the wave and who's left standing, so it needs no message of its own.

const WAVES := 3
## Each wave's size, and how long the room stands quiet between two waves.
const SIZES := [4, 5, 6]
const BETWEEN := 2.5

## The room (a StrongholdPlan.ROOMS row) and the island it's on.
var rm: Array = []
var isl: Node3D
var _door: StaticBody3D
var _check := 0.0
var _quiet := 0.0


## Ready to go under the island's City node at the room's middle, on its floor.
func setup(island: Node3D, room: Array) -> StrongholdEncounter:
	isl = island
	rm = room
	name = "Encounter_" + str(room[0])
	respawn_time = 1.0e9
	max_attackers = 3
	level = int(island.node["level"])
	var c: Vector2 = (room[2] as Rect2).get_center()
	position = Vector3(c.x, float(room[3]), c.y)
	return self


func _ready() -> void:
	# (a camp, but nothing musters until someone walks in)
	add_to_group("net_spawner")
	add_to_group("grunt_camps")
	_build_door()


func flag() -> String:
	return "sh_cleared_" + str(rm[0])


func cleared() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has(flag())


## Wave g's men (the same on every machine): Admiralty marines spread across the back of the room, facing the door,
## riflemen from the second wave, the last wave led by an officer.
func wave_specs(g: int) -> Array:
	var out: Array = []
	var r: Rect2 = rm[2]
	var door: Vector2 = rm[5]
	var n: int = SIZES[clampi(g - 1, 0, SIZES.size() - 1)]
	for i in range(n):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([str(rm[0]), g, i])
		var lk := PirateGrunt.crew_look(rng)
		var officer := g == WAVES and i == 0
		EnemyShip.marine_look(lk, rng, officer)
		# (rows across the room, back from the door)
		var across := (float(i % 3) - 1.0) * minf(r.size.x, r.size.y) * 0.22
		var back := -0.25 - 0.15 * float(i / 3)
		var side := Vector2(-door.y, door.x)
		var p: Vector2 = side * across + door * back * (r.size.x if absf(door.x) > 0.5 else r.size.y)
		out.append({"post": Vector3(p.x, 0.0, p.y), "yaw": atan2(door.x, door.y), "mode": "stand", "look": lk,
			"title": "Admiralty officer" if officer else "Admiralty marine", "seed": hash([str(rm[0]), g, i]),
			"role": "rifle" if g >= 2 and i == n - 1 else "sword"})
	return out


func _spawn_all() -> void:
	specs = wave_specs(gen) if gen >= 1 else []
	super()


func _process(delta: float) -> void:
	_update_door()
	if Net.is_client() or cleared():
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	if gen == 0:
		if _anyone_inside():
			_next()
		return
	if alive_count() > 0:
		_quiet = 0.0
		return
	_quiet += 0.25
	if _quiet < BETWEEN:
		return
	if gen < WAVES:
		_next()
	else:
		Net.world_flag(flag())


func _next() -> void:
	_quiet = 0.0
	gen += 1
	_spawn_all()
	Net.spawned(self, gen)


## Is a captain inside the room (its walls' inside, floor to ceiling)?
func _anyone_inside() -> bool:
	var r: Rect2 = rm[2]
	for p in Net.all_players():
		var l := to_local((p as Node3D).global_position)
		if absf(l.x) < r.size.x * 0.5 - 1.4 and absf(l.z) < r.size.y * 0.5 - 1.4 and l.y > -1.0 and l.y < float(rm[4]):
			return true
	return false


## Shut while a wave's up or another is to come; open before it starts and once the last is down (or it's cleared).
func door_shut() -> bool:
	if gen <= 0 or cleared():
		return false
	return not (gen >= WAVES and alive_count() == 0)


func _update_door() -> void:
	var shut := door_shut()
	if _door.visible != shut:
		_door.visible = shut
		_door.collision_layer = 1 if shut else 0


## The grate across the door's gap (iron bars and two cross bars), its collider on layer 1 while it's down.
func _build_door() -> void:
	var r: Rect2 = rm[2]
	var door: Vector2 = rm[5]
	var dw: float = rm[6]
	var dh := minf(float(rm[4]) * 0.6, 9.0)
	_door = StaticBody3D.new()
	_door.name = "Grate"
	var half := (r.size.x if absf(door.x) > 0.5 else r.size.y) * 0.5 - 0.6
	_door.position = Vector3(door.x * half, 0.0, door.y * half)
	_door.rotation.y = atan2(door.x, door.y)
	var mb := MeshBuilder.new()
	mb.all_faces = true
	var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
	var bars := int(dw / 0.5)
	for k in range(bars + 1):
		mb.add_box(iron, Transform3D(Basis(), Vector3(-dw * 0.5 + k * dw / bars, dh * 0.5, 0)), Vector3(0.12, dh, 0.12), 0.5)
	for y: float in [dh * 0.3, dh * 0.7]:
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, y, 0)), Vector3(dw, 0.14, 0.14), 0.5)
	_door.add_child(mb.to_instance("Bars"))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(dw + 0.2, dh, 0.4)
	cs.shape = sh
	cs.position = Vector3(0, dh * 0.5, 0)
	_door.add_child(cs)
	_door.visible = false
	_door.collision_layer = 0
	add_child(_door)
