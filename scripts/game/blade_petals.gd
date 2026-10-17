class_name BladePetals
extends MeshInstance3D
## Cloud and sakura on the awakened katana (the katana tree's first mastery, "elem_katana"): a
## wisp of the cloud strip (petal_trail.png) billowing off the back of the blade and flowing to
## the tip, in two crossed sheets so it reads from any side, and petals let go from the tip
## now and then. A child of the weapon's mesh; Player keeps it (BladePetals.keep) on every
## screen through the NF_PETALS snapshot flag.

## The wisp's height off the spine (m) and how far up the blade it starts (share of the length).
const W := 0.13
const FROM := 0.22
const SAMPLES := 18
const FLOW := 1.3
const FPS := 10.0
const TRAIL_FRAMES := 8
## The katana's curve (WeaponDesigns._katana: "curve" 0.32, the blade bending toward +Y, its spine).
const CURVE := 0.32
static var _mat: StandardMaterial3D
static var _meshes: Dictionary = {}
static var _clock := 0.0
static var _ticked := -1
var _petals: CPUParticles3D


## Show or hide the cloud on `body`'s katana (made on first need).
static func keep(body: Humanoid, on: bool) -> void:
	var w := body.weapon as MeshInstance3D
	if w == null or not is_instance_valid(w) or w.mesh == null:
		return
	var bp := w.get_node_or_null("BladePetals") as BladePetals
	if bp == null:
		if not on:
			return
		bp = BladePetals.new()
		bp.name = "BladePetals"
		w.add_child(bp)
	var show := on and w.get_parent() in [body.hand_r, body.hand_l]
	if bp.visible != show:
		bp.visible = show
		bp._petals.emitting = show


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 45.0
	var tip := (get_parent() as MeshInstance3D).mesh.get_aabb().position.z
	var key := snappedf(tip, 0.01)
	if not _meshes.has(key):
		_meshes[key] = _build(tip)
	mesh = _meshes[key]
	_petals = CPUParticles3D.new()
	_petals.amount = 4
	_petals.lifetime = 1.3
	_petals.local_coords = false
	_petals.position = _spine(1.0, tip)
	_petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_petals.emission_sphere_radius = 0.05
	_petals.direction = Vector3.UP
	_petals.spread = 70.0
	_petals.gravity = Vector3(0, -0.9, 0)
	_petals.initial_velocity_min = 0.2
	_petals.initial_velocity_max = 0.6
	_petals.damping_min = 1.5
	_petals.damping_max = 1.5
	_petals.angle_min = -180.0
	_petals.angle_max = 180.0
	_petals.anim_speed_min = 1.5
	_petals.anim_speed_max = 2.5
	_petals.anim_offset_max = 1.0
	_petals.scale_amount_min = 0.7
	_petals.scale_amount_max = 1.1
	# (the autoload by path: Player loads this, and tools compile Player before the autoloads)
	_petals.mesh = get_node("/root/FX").sakura_quad(0.2)
	_petals.visibility_range_end = 45.0
	_petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_petals)
	_petals.emitting = visible


func _process(delta: float) -> void:
	if not visible:
		return
	rotation.z = 0.08 * sin(_clock * 2.1)
	# every blade shares the material: step its strip once a frame
	if _ticked != Engine.get_process_frames():
		_ticked = Engine.get_process_frames()
		_clock += delta
		material().uv1_offset = Vector3(-floorf(_clock * FLOW * 256.0) / 256.0, float(int(_clock * FPS) % TRAIL_FRAMES) / TRAIL_FRAMES, 0.0)


static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_mat.alpha_scissor_threshold = 0.5
		_mat.albedo_texture = load("res://assets/textures/fx/petal_trail.png")
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mat.texture_repeat = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat


## A point on the blade's spine `f` of the way from the guard to the tip (local: the blade runs
## down -Z from 0.06 m, bending toward +Y; the spine is its +Y edge).
static func _spine(f: float, tip: float) -> Vector3:
	var length := -tip - 0.06
	return Vector3(0.0, length * CURVE * pow(f, 2.6) / 2.6 + 0.016, -0.06 - length * f)


## Two crossed sheets of the strip rising off the spine from FROM to just past the tip: one in
## the blade's plane, one leaned across it, swelling past the middle and thinning to the tip.
static func _build(tip: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var v0 := 0.5 / 512.0
	var v1 := 1.0 / TRAIL_FRAMES - 0.5 / 512.0
	for sheet in 2:
		var up := Vector3.UP if sheet == 0 else Vector3(1, 0.4, 0).normalized()
		var along := 0.0
		var rows: Array = []
		for i in SAMPLES + 1:
			var f := lerpf(FROM, 1.06, float(i) / SAMPLES)
			var p := _spine(f, tip)
			var w := W * pow(sin(PI * clampf((f - FROM) / (1.06 - FROM), 0.0, 1.0)), 0.6) * (1.0 if sheet == 0 else 0.8)
			if i > 0:
				along += p.distance_to(_spine(lerpf(FROM, 1.06, float(i - 1) / SAMPLES), tip))
			rows.append([p + up * w, p - up * w * 0.15, along / (W * 4.0) + sheet * 0.37])
		for i in SAMPLES:
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			verts.append_array([a[0], b[0], a[1], a[1], b[0], b[1]])
			uvs.append_array([Vector2(a[2], v0), Vector2(b[2], v0), Vector2(a[2], v1), Vector2(a[2], v1), Vector2(b[2], v0), Vector2(b[2], v1)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material())
	return m
