extends Node3D
## What lives in the water and goes for swimmers, round each island: a shark patrolling a wreck or a dive
## spot, moray eels in their holes by the reefs, and jellyfish fields drifting just under the surface.
## Sharks and eels are Creatures (the host runs them, named and placed from the island's seed in a fixed
## order so every screen has the same ones). Jellyfish are pure data drifting by the world clock: each
## screen draws its own (one MultiMesh a field, glowing at night) and each captain is stung on their own
## machine: a jolt of damage and a slower stroke for a moment. DiveSites builds it ("SeaThreats").

const SHARK := preload("res://scripts/enemies/sea/shark.gd")
const MORAY := preload("res://scripts/enemies/sea/moray.gd")
## A field's jellies, radius (m), and how close a swimmer's body must come to one to be stung.
const JELLIES := 18
const FIELD_R := 11.0
const STING_R := 0.95
const STING_DMG := 7.0
const STING_SLOW := 2.0
const STING_COOL := 1.2
## Drawn within this of the camera, moved this often.
const DRAW_RANGE := 90.0
const MOVE_EVERY := 0.08
const BELL := Color(0.95, 0.55, 0.85)

## island key -> holder (sharks, eels, fields)
var _sites := {}
## [centre (world), seed, MultiMeshInstance3D, base offsets [Vector3], phases]
var _fields: Array = []
var _move_t := 0.0
var _sting_cool := 0.0
static var _jelly_mesh: Mesh
static var _jelly_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("sea_threats")


## `spots`: kind -> [world positions] from DiveSites (the wreck, reefs...); `open`: other seabed spots.
func build_island(key: String, seed_value: int, spots: Dictionary, open: Array, home: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Threats_" + key
	add_child(holder)
	_sites[key] = holder
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "threats"])
	# a shark at the wreck (or a dive spot); a chain island may have a second
	var lairs: Array = spots.get("wreck", []) + spots.get("ruin", []) + spots.get("chest", [])
	var sharks := 1 if home else rng.randi_range(1, 2)
	for i in range(mini(sharks, lairs.size())):
		var s := SHARK.new()
		s.name = "Shark%d" % i
		s.setup(lairs[i] + Vector3(0, 3.0, 0), {"size": 1.0 if home else rng.randf_range(0.95, 1.25)})
		holder.add_child(s)
		s.global_position = lairs[i] + Vector3(0, 3.0, 0)
	# morays by the reefs and the wreck
	var holes: Array = spots.get("reef", []) + spots.get("wreck", [])
	for i in range(holes.size()):
		if rng.randf() > 0.6:
			continue
		var m := MORAY.new()
		var at: Vector3 = holes[i] + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		m.name = "Moray%d" % i
		m.setup(at)
		holder.add_child(m)
		m.global_position = at
		m.rotation.y = rng.randf() * TAU
	# a jellyfish field or two over open seabed
	var n := 1 if home else rng.randi_range(1, 2)
	for i in range(mini(n, open.size())):
		_add_field(holder, open[open.size() - 1 - i], hash([seed_value, "jelly", i]))


func drop_island(key: String) -> void:
	if not _sites.has(key):
		return
	var holder: Node = _sites[key]
	_fields = _fields.filter(func(f): return is_instance_valid(f[2]) and (f[2] as Node).get_parent() != holder)
	holder.queue_free()
	_sites.erase(key)


func _add_field(holder: Node3D, centre: Vector3, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var offs: Array = []
	var phases: Array = []
	for i in range(JELLIES):
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * FIELD_R
		offs.append(Vector3(cos(a) * r, -rng.randf_range(0.4, 1.6), sin(a) * r))
		phases.append(rng.randf() * TAU)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = jelly_mesh()
	mm.instance_count = JELLIES
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Jellies%d" % _fields.size()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = DRAW_RANGE
	holder.add_child(mmi)
	var c := Vector3(centre.x, 0.0, centre.z)
	mmi.global_position = c
	_fields.append([c, seed_value, mmi, offs, phases])
	_place(_fields[-1])


## Where jelly `i` of a field is now (world): drifting round its spot and pulsing up and down, by the world clock.
static func jelly_at(f: Array, i: int) -> Vector3:
	var t: float = Weather.world_time()
	var o: Vector3 = f[3][i]
	var ph: float = f[4][i]
	var drift := Vector3(sin(t * 0.07 + ph) * 2.0, sin(t * 0.9 + ph) * 0.25, cos(t * 0.05 + ph * 1.3) * 2.0)
	var p: Vector3 = (f[0] as Vector3) + o + drift
	p.y = float(Ocean.surface_at(p)) + o.y + drift.y
	return p


func _place(f: Array) -> void:
	var mmi: MultiMeshInstance3D = f[2]
	var t: float = Weather.world_time()
	for i in range(JELLIES):
		var p := jelly_at(f, i)
		var pulse := 1.0 + sin(t * 2.4 + float(f[4][i])) * 0.12
		var b := Basis(Vector3.UP, float(f[4][i])).scaled(Vector3(pulse, 2.0 - pulse, pulse))
		mmi.multimesh.set_instance_transform(i, Transform3D(b, p - mmi.global_position))


## Sharks and morays far from every captain sleep (Creature.set_lod): awake within WAKE m, asleep past SLEEP,
## hidden past HIDE; looked at every LOD_EVERY s.
const WAKE := 120.0
const SLEEP := 140.0
const HIDE := 220.0
const LOD_EVERY := 0.4
var _lod_t := 0.0


func _update_lod() -> void:
	var caps: Array = Net.all_players()
	for holder in _sites.values():
		for c in (holder as Node).get_children():
			if not (c is Creature):
				continue
			var cr := c as Creature
			var d := INF
			for p in caps:
				d = minf(d, (p as Node3D).global_position.distance_to(cr.global_position))
			var l: int = cr.lod
			if d < WAKE:
				l = Creature.LOD_FULL
			elif d > HIDE:
				l = Creature.LOD_HIDDEN
			elif d > SLEEP:
				l = Creature.LOD_SLEEP
			if l != cr.lod:
				cr.set_lod(l)


func _process(delta: float) -> void:
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = LOD_EVERY
		_update_lod()
	_move_t -= delta
	if _move_t > 0.0:
		return
	_move_t = MOVE_EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _jelly_mat:
		_jelly_mat.emission_energy_multiplier = lerpf(0.6, 2.2, float(Weather.night))
	for f in _fields:
		if is_instance_valid(f[2]) and cam.global_position.distance_to(f[0]) < DRAW_RANGE + FIELD_R:
			_place(f)


## Our captain swimming through a field gets stung (on this machine: hits on a captain are theirs).
func _physics_process(delta: float) -> void:
	_sting_cool -= delta
	if _sting_cool > 0.0 or _fields.is_empty():
		return
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null or not me.is_swimming():
		return
	# the swimmer's body: a line from the feet to the head (floating, diving or treading)
	var feet := me.global_position
	var head: Vector3 = me.body_model.head.global_position
	for f in _fields:
		if Vector2(feet.x - f[0].x, feet.z - f[0].z).length() > FIELD_R + 3.0:
			continue
		for i in range(JELLIES):
			var j := jelly_at(f, i)
			if j.distance_to(Geometry3D.get_closest_point_to_segment(j, feet, head)) < STING_R:
				sting(me, j)
				return


static func sting(me: Player, at: Vector3) -> void:
	var tree := me.get_tree()
	var threats := tree.get_first_node_in_group("sea_threats")
	if threats:
		threats.set("_sting_cool", STING_COOL)
	me.health_component.take_damage(STING_DMG * (1.0 - me.damage_reduction()))
	var sw := me.get_node("StateMachine/Swim")
	sw.set("stung", STING_SLOW)
	Net.fx("sparkle", [at, 10, BELL])
	Net.fx("sfx", ["jelly_zap", at, -2.0, 0.1])
	CombatManager.apply_camera_shake(0.12)
	me.call("_toast", "Stung by a jellyfish!")


## A bell with a frilled rim and trailing tentacles, glowing (shared by every field).
static func jelly_mesh() -> Mesh:
	if _jelly_mesh:
		return _jelly_mesh
	_jelly_mat = StandardMaterial3D.new()
	_jelly_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_jelly_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_jelly_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_jelly_mat.vertex_color_use_as_albedo = true
	_jelly_mat.albedo_color = Color(1, 1, 1, 0.7)
	_jelly_mat.emission_enabled = true
	_jelly_mat.emission = BELL * 0.5
	_jelly_mat.emission_energy_multiplier = 0.6
	var mb := MeshBuilder.new()
	mb.add_cylinder(_jelly_mat, Transform3D(Basis(), Vector3(0, 0, 0)), 0.32, 0.05, 0.28, 8, 1.0, BELL, true, false)
	for k in range(6):
		var a := float(k) / 6.0 * TAU
		var top := Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		mb.add_tube(_jelly_mat, PackedVector3Array([top, top * 0.8 + Vector3(0, -0.35, 0), top * 1.1 + Vector3(0, -0.8, 0)]), 0.02, 0.008, 3, 1.0, BELL.lightened(0.3))
	_jelly_mesh = mb.commit()
	return _jelly_mesh
