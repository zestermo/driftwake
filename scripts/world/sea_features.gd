extends Node3D
## What's out on the open sea besides the islands, placed from the world seed
## (the same on every screen): reefs that scrape and hole a hull that runs
## over them, fog banks, whirlpools that drag ships round and in, and storm
## cells - heavy weather with a bigger swell - drifting before the wind.
## Group "sea_features"; WorldGenerator builds it.

const WHIRL_PULL := 4.5
const WHIRL_EYE := 8.0
const STORM_SWELL := 1.1
const STORM_RADIUS := 170.0
const FOG_RADIUS := 150.0
## Ships keep this far off reefs and whirlpools (EnemyShip.no_go).
const REEF_KEEP := 30.0

var gen: Node3D
## [centre (x, z), radius]
var reefs: Array = []
var fogs: Array = []
var whirls: Array = []
## [home (x, z), wander phase]: where a cell is now comes from world time
var storms: Array = []
var _spots: Array = []
var _rng := RandomNumberGenerator.new()
var _foam_t: float = 0.0
const WHIRL_DEPTH := 2.6


func _ready() -> void:
	add_to_group("sea_features")
	_rng.seed = int(gen.get("world_seed")) * 17 + 5
	for i in range(4):
		var c := _open_spot(26.0)
		if c != Vector2.INF:
			reefs.append([c, _rng.randf_range(18.0, 26.0)])
			_build_reef(c, float(reefs[-1][1]))
	for i in range(3):
		var c := _open_spot(FOG_RADIUS * 0.6)
		if c != Vector2.INF:
			fogs.append([c, FOG_RADIUS * _rng.randf_range(0.8, 1.2)])
			_build_fog(c, float(fogs[-1][1]))
	for i in range(2):
		var c := _open_spot(60.0)
		if c != Vector2.INF:
			whirls.append([c, _rng.randf_range(38.0, 48.0)])
	# (the sea itself sinks into the funnel and spins the foam: the ocean shader)
	var wv: Array = []
	for w in whirls:
		wv.append(Vector4(w[0].x, w[0].y, float(w[1]), WHIRL_DEPTH))
	Ocean.whirls = wv
	for i in range(2):
		var c := _open_spot(80.0)
		if c != Vector2.INF:
			storms.append([c, _rng.randf() * TAU])
	for r in reefs:
		EnemyShip.no_go.append([r[0], float(r[1]) + REEF_KEEP])
	for w in whirls:
		EnemyShip.no_go.append([w[0], float(w[1]) + 10.0])


func _exit_tree() -> void:
	# (the title screen's sea has none of this)
	Ocean.whirls = []
	Ocean.storm_cells = []


## Somewhere out on deep water, clear of land, the patrol lanes and the
## other features (INF if the sea's too crowded).
func _open_spot(r: float) -> Vector2:
	var sc: Vector2 = gen.get("starter_center")
	for k in range(60):
		var a := _rng.randf() * TAU
		var c := sc + Vector2(cos(a), sin(a)) * _rng.randf_range(450.0, 1500.0)
		if not gen.call("_deep_enough", c, r + 20.0) or not EnemyShip.huntable_at(Vector3(c.x, 0, c.y)):
			continue
		var clear := true
		for s in _spots:
			if c.distance_to(s) < 260.0:
				clear = false
		if clear:
			_spots.append(c)
			return c
	return Vector2.INF


# --------------------------------------------------------------------------
# What they do (every screen: all of it comes from the seed and world time)
# --------------------------------------------------------------------------
## Where storm cell `i` is now: wandering slowly about its home.
func storm_at(i: int) -> Vector2:
	var s: Array = storms[i]
	var t: float = Weather.world_time()
	var ph: float = s[1]
	return (s[0] as Vector2) + Vector2(sin(t / 700.0 + ph), cos(t / 910.0 + ph * 1.7)) * 180.0


## The weather out here at `p`: x = storm (0..1), y = fog (0..1).
func local_weather(p: Vector3) -> Vector2:
	var q := Vector2(p.x, p.z)
	var s := 0.0
	for i in range(storms.size()):
		s = maxf(s, 1.0 - smoothstep(STORM_RADIUS * 0.4, STORM_RADIUS, q.distance_to(storm_at(i))))
	var f := 0.0
	for fb in fogs:
		f = maxf(f, (1.0 - smoothstep(float(fb[1]) * 0.45, float(fb[1]), q.distance_to(fb[0]))) * 0.95)
	return Vector2(s, f)


## The pull of any whirlpool at `p` (m/s, x/z): round and in, harder near the eye.
func current_at(p: Vector3) -> Vector3:
	var out := Vector3.ZERO
	for w in whirls:
		var c: Vector2 = w[0]
		var r: float = w[1]
		var d := Vector2(c.x - p.x, c.y - p.z)
		var l := d.length()
		if l > r or l < 0.01:
			continue
		var k := 1.0 - l / r
		var inward := d / l
		var round := Vector2(-inward.y, inward.x)
		var v := (inward * 0.55 + round) * WHIRL_PULL * (0.35 + k * 1.3)
		out += Vector3(v.x, 0.0, v.y)
	return out


## Within a whirlpool's eye (it grinds a hull).
func in_eye(p: Vector3) -> bool:
	for w in whirls:
		if Vector2(p.x, p.z).distance_to(w[0]) < WHIRL_EYE:
			return true
	return false


## Over a reef's shoals (the rocks show; the shallows around them don't).
func reef_at(p: Vector3) -> bool:
	for r in reefs:
		if Vector2(p.x, p.z).distance_to(r[0]) < float(r[1]):
			return true
	return false


func _physics_process(_delta: float) -> void:
	# the storm cells' swell goes to the sea (shader and floating things alike)
	var cells: Array = []
	for i in range(storms.size()):
		var c := storm_at(i)
		cells.append(Vector4(c.x, c.y, STORM_RADIUS, STORM_SWELL))
	Ocean.storm_cells = cells


func _process(delta: float) -> void:
	# surf breaks on the reefs near the camera
	_foam_t -= delta
	if _foam_t > 0.0:
		return
	_foam_t = 0.35
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for r in reefs:
		var c: Vector2 = r[0]
		if cam.global_position.distance_to(Vector3(c.x, 0, c.y)) > 220.0:
			continue
		var a := randf() * TAU
		var at := Vector3(c.x + cos(a) * float(r[1]) * 0.5, 0.0, c.y + sin(a) * float(r[1]) * 0.5)
		at.y = float(Ocean.get_wave_height(at)) + 0.1
		FX.splash(at, 4, 0.9)


# --------------------------------------------------------------------------
# Building them
# --------------------------------------------------------------------------
## Jagged black rocks breaking the surface; the big ones stop a hull.
func _build_reef(c: Vector2, r: float) -> void:
	var holder := Node3D.new()
	holder.name = "Reef%d" % reefs.size()
	add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var mesh: Mesh = Props.rock_mesh(900 + reefs.size(), 1.0, true)
	for i in range(9):
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.0, r * 0.75)
		var s := _rng.randf_range(1.2, 3.4)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = PSXMat.lit("rock", Color(0.32, 0.31, 0.3))
		mi.position = Vector3(cos(a) * d, -1.2 + s * 0.35, sin(a) * d)
		mi.rotation = Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))
		mi.scale = Vector3.ONE * s
		holder.add_child(mi)
		if s > 2.0:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = s * 0.55
			cyl.height = 6.0
			cs.shape = cyl
			cs.position = mi.position + Vector3(0, -1.5, 0)
			body.add_child(cs)


## A bank of low cloud sitting on the water: soft grey puffs (inside it, the
## weather closes in - Weather reads local_weather).
func _build_fog(c: Vector2, r: float) -> void:
	var holder := Node3D.new()
	holder.name = "FogBank%d" % fogs.size()
	add_child(holder)
	holder.global_position = Vector3(c.x, 0.0, c.y)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = load("res://assets/textures/fx/dust.png")
	mat.albedo_color = Color(0.86, 0.88, 0.9, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(80, 40)
	q.material = mat
	for i in range(60):
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r * 0.9
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * d, _rng.randf_range(6.0, 26.0), sin(a) * d)
		mi.scale = Vector3.ONE * _rng.randf_range(0.9, 1.8)
		holder.add_child(mi)

