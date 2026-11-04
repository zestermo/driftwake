class_name StrongholdReinforce
extends GruntCamp
## Where the stronghold's reinforcements come from (1.30, docs/v1_30_plan.md round 3: "a raised alarm brings visible
## reinforcements through doors, from barracks and by boat"). StrongholdAlarm (host) calls muster(); each muster is a
## wave of SIZE fodder hunters (FodderMarine), the same on every machine by its gen (sent like any camp's respawn:
## Net.spawned), added to whoever is still up from the waves before. Kinds:
##   door  a hall's door (the Barracks, the Mess, the Casting Hall, the Command Hall): they muster inside and run out
##   gate  a door of its own in a wall (the prison drum's): its leaves swing open as a wave comes out
##   boat  a longboat rows in from the sea gate to the quay, and its marines leap ashore
## Attack turns are shared with the district's garrison (its camp hands them out), so a district's men take turns as one.

const SIZE := {"door": 5, "gate": 4, "boat": 6}
const BOAT_RUN := 34.0
const BOAT_IN := 7.0
const BOAT_WAIT := 3.0
const BOAT_OUT := 7.0
const GATE_OPEN := 5.0
const FODDER := "res://scripts/enemies/fodder_marine.gd"

var district := ""
var kind := "door"
## Out of the door (frame xz): the way the wave runs out, and the boat's way in reversed.
var face := Vector2(0, 1)
## The district's garrison camp (attack turns).
var squad: GruntCamp
var _gate_l: Node3D
var _gate_r: Node3D
var _open_t := 0.0
var _boat: AnimatableBody3D
var _boat_t := -1.0
var _boat_landed := false


func setup(isl: Node3D, d: String, k: String, at: Vector2, out_dir: Vector2, idx: int) -> StrongholdReinforce:
	district = d
	kind = k
	face = out_dir.normalized()
	name = "Reinforce_%s_%d" % [d, idx]
	respawn_time = 1.0e9
	level = int(isl.node["level"])
	var y := 0.0 if k == "boat" else float(StrongholdPlan.ground(at))
	position = Vector3(at.x, y, at.y)
	return self


func size() -> int:
	return int(SIZE[kind])


func _ready() -> void:
	super()
	match kind:
		"gate":
			_build_gate()
		"boat":
			_build_boat()
	Humanoid.prebuild(wave_specs(1).map(func(c): return PirateGrunt.look_for(c)))


## Wave g's men (the same on every machine): rows behind the door (or on the boat's thwarts), facing out.
func wave_specs(g: int) -> Array:
	var out: Array = []
	var side := Vector2(-face.y, face.x)
	for i in range(size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([str(name), g, i])
		var lk := PirateGrunt.crew_look(rng)
		EnemyShip.marine_look(lk, rng, false)
		var p: Vector2
		var y := 0.0
		if kind == "boat":
			p = side * (float(i % 2) - 0.5) * 0.9 + face * (float(i / 2) - 1.0) * 1.4
			y = 0.75
		else:
			p = side * (float(i % 3) - 1.0) * 1.3 - face * float(i / 3) * 1.3
		out.append({"post": Vector3(p.x, y, p.y), "yaw": atan2(-face.x, -face.y), "mode": "stand", "look": lk,
			"title": "Admiralty marine", "seed": hash([str(name), g, i]), "role": "sword", "script": FODDER, "hunt": true})
	return out


## (host) The next wave: through the door now, or once the boat is in.
func muster() -> void:
	if kind == "boat":
		if _boat_t >= 0.0:
			return
		_launch()
		Net.event(self, "boat", [])
		return
	_next()


func busy() -> bool:
	return kind == "boat" and _boat_t >= 0.0


func _next() -> void:
	gen += 1
	_wave(gen)
	Net.spawned(self, gen)


func _wave(g: int) -> void:
	specs = wave_specs(g)
	for i in range(specs.size()):
		_spawn_one(i)
		if kind == "boat" and not Net.is_client():
			var gr: PirateGrunt = grunts[grunts.size() - 1]
			var q := Vector2(-face.y, face.x) * (float(i % 3) - 1.0) * 1.6 - face * (7.0 + float(i / 3) * 1.4)
			gr.leap(to_global(Vector3(q.x, StrongholdPlan.QUAY_Y + 0.2, q.y)), 0.8)
	_open_t = GATE_OPEN
	Humanoid.prebuild(wave_specs(g + 1).map(func(c): return PirateGrunt.look_for(c)))


func _spawn_all() -> void:
	pass


func request_token(g: Node) -> bool:
	return squad.request_token(g) if squad else super(g)


func release_token(g: Node) -> void:
	if squad:
		squad.release_token(g)
	else:
		super(g)


func net_gen():
	return gen


## Co-op client: the host is on wave g. The next wave comes as it's called; a captain who joined late (more than one
## wave behind) gets the current wave only, the earlier ones aren't replayed (the island's catch-up frees the dead).
func net_set_gen(g) -> void:
	if int(g) - gen > 1:
		gen = int(g) - 1
	while gen < int(g):
		gen += 1
		_wave(gen)


func net_event(what: String, _args: Array) -> void:
	if what == "boat":
		_launch()


func _process(delta: float) -> void:
	if _gate_l:
		_open_t -= delta
		var want := deg_to_rad(105.0) if _open_t > 0.0 else 0.0
		_gate_l.rotation.y = move_toward(_gate_l.rotation.y, -want, delta * 2.5)
		_gate_r.rotation.y = move_toward(_gate_r.rotation.y, want, delta * 2.5)
	if _boat and _boat_t >= 0.0:
		_boat_t += delta
		_boat.visible = true
		var u := 0.0
		if _boat_t < BOAT_IN:
			u = 1.0 - ease(_boat_t / BOAT_IN, 0.5)
		elif _boat_t < BOAT_IN + BOAT_WAIT:
			u = 0.0
			if not _boat_landed:
				_boat_landed = true
				if not Net.is_client():
					_next()
		else:
			u = ease(clampf((_boat_t - BOAT_IN - BOAT_WAIT) / BOAT_OUT, 0.0, 1.0), 2.0)
		_boat.position = Vector3(face.x, 0.0, face.y) * BOAT_RUN * u + Vector3(0, 0.12 * sin(_boat_t * 1.7), 0)
		if _boat_t > BOAT_IN + BOAT_WAIT + BOAT_OUT:
			_boat_t = -1.0
			_boat.visible = false


func _launch() -> void:
	_boat_t = 0.0
	_boat_landed = false


## The prison drum's door: two iron-banded leaves in a stone frame, hinged at the frame's sides.
func _build_gate() -> void:
	var root := Node3D.new()
	root.name = "Gate"
	root.rotation.y = atan2(face.x, face.y)
	root.position = -Vector3(face.x, 0.0, face.y) * 1.6
	add_child(root)
	var stone := PSXMat.lit("stone_brick", Color(0.55, 0.58, 0.62))
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.3, 0.31, 0.34))
	var mb := MeshBuilder.new()
	mb.add_box(stone, Transform3D(Basis(), Vector3(-2.0, 2.1, 0)), Vector3(0.7, 4.2, 0.9))
	mb.add_box(stone, Transform3D(Basis(), Vector3(2.0, 2.1, 0)), Vector3(0.7, 4.2, 0.9))
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 4.5, 0)), Vector3(4.7, 0.7, 0.9))
	var frame := mb.to_instance("Frame")
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.visibility_range_end = 160.0
	root.add_child(frame)
	for s: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(s * 1.65, 0, 0.1)
		root.add_child(hinge)
		var lb := MeshBuilder.new()
		lb.add_box(wood, Transform3D(Basis(), Vector3(-s * 0.825, 1.9, 0)), Vector3(1.6, 3.8, 0.16))
		for y: float in [0.8, 3.0]:
			lb.add_box(iron, Transform3D(Basis(), Vector3(-s * 0.825, y, 0.02)), Vector3(1.62, 0.16, 0.18))
		var leaf := lb.to_instance("Leaf")
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaf.visibility_range_end = 160.0
		hinge.add_child(leaf)
		if s < 0.0:
			_gate_l = hinge
		else:
			_gate_r = hinge


## The boat that brings a landing's wave: a longboat out at sea (hidden) until a muster rows it in.
func _build_boat() -> void:
	_boat = AnimatableBody3D.new()
	_boat.name = "Boat"
	_boat.sync_to_physics = false
	TraderShips.longboat(_boat)
	_boat.collision_layer = 0
	_boat.collision_mask = 0
	_boat.rotation.y = atan2(face.x, face.y)
	_boat.position = Vector3(face.x, 0.0, face.y) * BOAT_RUN
	_boat.visible = false
	add_child(_boat)
