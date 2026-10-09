extends Node

## The swell: several crossing wave trains of different lengths, headings and
## speeds (longer waves run faster, like real water), with peaked crests and
## broad troughs, and slow wave groups rolling across them. One table drives
## both the game (get_wave_height) and the ocean shader, so the sea you see is
## the sea everything floats on.
## [heading (deg), wavelength (m), amplitude (m), phase]
const WAVES := [
	[31.0, 10.5, 0.39, 0.0],
	[58.0, 15.3, 0.29, 1.7],
	[2.0, 7.1, 0.22, 4.1],
	[97.0, 4.6, 0.12, 2.3],
	[-38.0, 5.7, 0.10, 5.2],
	[44.0, 27.0, 0.26, 0.9],
]
## How fast waves run relative to deep water (1 = real; gentler reads better).
const SPEED := 0.62
## Crest shape: 2 * ((sin + 1) / 2)^2, minus its mean so sea level stays at 0.
const CREST_POW := 2.0
const CREST_MEAN := 0.75
## Wave groups: the whole swell swells and settles over a few hundred metres.
const ENV_AMOUNT := 0.22
const ENV_A := Vector2(0.019, 0.011)
const ENV_B := Vector2(-0.008, 0.016)
const ENV_SPEED := Vector2(0.05, 0.037)
## Rogue crests are eased down past CREST_KNEE (they can't climb more than
## CREST_ROOM above it), so the odd pile-up of every train at once doesn't
## wash up the beach; storms still scale it all with amp_mult.
const CREST_KNEE := 0.85
const CREST_ROOM := 0.4

## Unpacked WAVES: [dir.x, dir.y, k, omega], [amplitude, phase]
var _w4: Array[Vector4] = []
var _w2: Array[Vector2] = []
var _amp_total: float = 0.0

var ocean_material: ShaderMaterial
## Rough seas (Weather sets it: 1 calm .. ~1.8 in a storm). Scales both waves
## for the game and the shader alike.
var amp_mult: float = 1.0
var _amp_sent: float = -1.0
## Storm cells at sea (SeaFeatures, from world time): Vector4(x, z, radius,
## extra swell). The swell grows toward a cell's middle - here and in the shader.
var storm_cells: Array = []
const MAX_CELLS := 2
## Whirlpools (SeaFeatures): Vector4(x, z, radius, funnel depth). The sea
## sinks into a funnel toward each eye - here and in the shader.
var whirls: Array = []
const MAX_WHIRLS := 2
## Foam wakes behind moving hulls (wake()): per hull a trail of points
## Vector4(x, z, clock, strength), one every WAKE_EVERY s; the shader draws
## foam along them, spreading and fading as they age. The two nearest trails
## to the camera are sent (WAKE_SLOTS points, a zero point between them).
const WAKE_PTS := 18
const WAKE_EVERY := 0.45
const WAKE_LIFE := 8.0
const WAKE_SLOTS := 40
## Only trails whose hull is this close to the camera are drawn.
const WAKE_SEND := 180.0
var _wakes: Dictionary = {}
## The newest end of each trail: the stern itself, this tick.
var _wake_heads: Dictionary = {}
## Turquoise shallows (WorldGenerator.bake_shallows): seabed depth maps,
## r = depth below the sea / SHOAL_DEPTH. The world's terrain, and a finer map
## over Brinehollow's own; rects are (x0, z0, size, on).
const SHOAL_DEPTH := 14.0
var shoal_map: Texture2D
var shoal_rect := Vector4.ZERO
var shoal_fine: Texture2D
var fine_rect := Vector4.ZERO
## The chain's islands built now ([texture, rect] each, GenIsland.shallows; two at most).
const MAX_ISLES := 2
var isle_shoals: Array = []
var _shoals_sent: Array = []


## The sea mesh: 1 m cells near the camera so the surface you see is the
## surface the game computes (characters, the ship and enemies sample the same
## sine waves); cells grow toward the horizon. One grid, no seams.
const NEAR_HALF := 120.0
const FAR_HALF := 1000.0
const SNAP := 8.0
## Cell growth per line beyond NEAR_HALF (the shader mirrors it to fade
## waves the grid is too coarse to draw).
const GROWTH := 1.08
static var _graded: ArrayMesh
var _mesh_node: MeshInstance3D


func _init() -> void:
	for w in WAVES:
		var a := deg_to_rad(float(w[0]))
		var k := TAU / float(w[1])
		_w4.append(Vector4(cos(a), sin(a), k, SPEED * sqrt(9.8 * k)))
		_w2.append(Vector2(float(w[2]), float(w[3])))
		_amp_total += float(w[2])


## The biggest crest the calm swell can make (before amp_mult), for foam.
func amplitude_total() -> float:
	return _amp_total


func _ready() -> void:
	# tick the clock before anything that floats on the sea
	process_physics_priority = -100
	await get_tree().process_frame
	_adopt_mesh()


## Swap the scene's ocean PlaneMesh for the graded grid (keeps its material).
func _adopt_mesh() -> void:
	var ocean_mesh := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	if ocean_mesh == null or ocean_mesh.mesh == null or ocean_mesh == _mesh_node:
		return
	_mesh_node = ocean_mesh
	_amp_sent = -1.0
	ocean_material = ocean_mesh.mesh.material as ShaderMaterial
	if ocean_material == null:
		ocean_material = ocean_mesh.get_active_material(0) as ShaderMaterial
	var m := graded_mesh()
	ocean_mesh.mesh = m
	if ocean_material:
		ocean_mesh.material_override = ocean_material
	# (it covers far more than it seems: don't let culling drop it)
	ocean_mesh.extra_cull_margin = 16.0
	# Re-positioned every frame on a grid; interpolating would make it slide.
	ocean_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


static func _lines() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var far: Array = []
	var x := NEAR_HALF
	var step := 1.25
	while x < FAR_HALF:
		x = minf(x + step, FAR_HALF)
		far.append(x)
		step *= GROWTH
	for i in range(far.size() - 1, -1, -1):
		out.append(-float(far[i]))
	var n := int(NEAR_HALF)
	for i in range(-n, n + 1):
		out.append(float(i))
	for v in far:
		out.append(float(v))
	return out


static func graded_mesh() -> ArrayMesh:
	if _graded:
		return _graded
	var ls := _lines()
	var n := ls.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	uvs.resize(n * n)
	norms.resize(n * n)
	for j in range(n):
		for i in range(n):
			var k := j * n + i
			verts[k] = Vector3(ls[i], 0.0, ls[j])
			uvs[k] = Vector2(ls[i], ls[j]) / (FAR_HALF * 2.0) + Vector2(0.5, 0.5)
			norms[k] = Vector3.UP
	var idx := PackedInt32Array()
	idx.resize((n - 1) * (n - 1) * 6)
	var c := 0
	for j in range(n - 1):
		for i in range(n - 1):
			var a := j * n + i
			var b := a + 1
			var d := a + n
			var e := d + 1
			idx[c] = a; idx[c + 1] = b; idx[c + 2] = d
			idx[c + 3] = b; idx[c + 4] = e; idx[c + 5] = d
			c += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	_graded = ArrayMesh.new()
	_graded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_graded.custom_aabb = AABB(Vector3(-FAR_HALF, -6.0, -FAR_HALF), Vector3(FAR_HALF * 2.0, 12.0, FAR_HALF * 2.0))
	return _graded


var _net: Node


## The swell's clock. It advances with the physics ticks (so swimmers, the
## ship and enemies are pushed by exactly the waves of that tick, however the
## frame rate stutters) and drifts toward the session clock (the host's in
## co-op, so every player sees the same waves). Rendering uses the same time
## interpolated within the tick, so the sea you see is the sea they float on.
var _phys_t: float = -1.0


func _session_time() -> float:
	if _net == null:
		_net = get_node_or_null("/root/Net")
	if _net and _net.active:
		return _net.time()
	return Time.get_ticks_usec() * 0.000001


func clock() -> float:
	if _phys_t < 0.0:
		_phys_t = _session_time()
	if Engine.is_in_physics_frame():
		return _phys_t
	var tick := 1.0 / float(Engine.physics_ticks_per_second)
	return _phys_t + Engine.get_physics_interpolation_fraction() * tick


func _physics_process(delta: float) -> void:
	var target := _session_time()
	if _phys_t < 0.0 or absf(target - _phys_t) > 0.5:
		_phys_t = target
	else:
		_phys_t += delta + (target - _phys_t) * 0.02


func get_wave_height(world_pos: Vector3, time: float = -1.0) -> float:
	if time < 0.0:
		time = clock()
	var x := world_pos.x
	var z := world_pos.z
	var h := 0.0
	for i in range(_w4.size()):
		var w: Vector4 = _w4[i]
		var s := sin((x * w.x + z * w.y) * w.z + time * w.w + _w2[i].y)
		h += _w2[i].x * (2.0 * pow(maxf(0.5 + 0.5 * s, 0.0), CREST_POW) - CREST_MEAN)
	var env := 1.0 + ENV_AMOUNT * sin(x * ENV_A.x + z * ENV_A.y + time * ENV_SPEED.x) * sin(x * ENV_B.x + z * ENV_B.y - time * ENV_SPEED.y)
	h *= env
	if h > CREST_KNEE:
		h = CREST_KNEE + (h - CREST_KNEE) / (1.0 + (h - CREST_KNEE) / CREST_ROOM)
	return h * amp_mult * local_swell(x, z) + funnel(x, z)


## How far a whirlpool's funnel has dragged the sea down at (x, z) (<= 0).
func funnel(x: float, z: float) -> float:
	var f := 0.0
	for w in whirls:
		var wv: Vector4 = w
		var k := 1.0 - smoothstep(0.0, wv.z, Vector2(x - wv.x, z - wv.y).length())
		f -= wv.w * k * k
	return f


## The extra swell under storm cells at (x, z) (1 = none). Same as the shader's.
func local_swell(x: float, z: float) -> float:
	var a := 1.0
	for c in storm_cells:
		var cv: Vector4 = c
		var d := Vector2(x - cv.x, z - cv.y).length()
		a += cv.w * (1.0 - smoothstep(cv.z * 0.35, cv.z, d))
	return a


func get_wave_normal(world_pos: Vector3, time: float = -1.0) -> Vector3:
	if time < 0.0:
		time = clock()
	var eps := 0.1
	var h := get_wave_height(world_pos, time)
	var hx := get_wave_height(world_pos + Vector3(eps, 0.0, 0.0), time)
	var hz := get_wave_height(world_pos + Vector3(0.0, 0.0, eps), time)
	return Vector3(h - hx, eps, h - hz).normalized()


func _process(_delta: float) -> void:
	# follow whichever ocean the current world has (title -> game, loading)
	var om := get_tree().get_first_node_in_group("ocean_mesh") as MeshInstance3D
	if om and om != _mesh_node:
		_adopt_mesh()
	if ocean_material:
		var time := clock()
		ocean_material.set_shader_parameter("time_val", time)
		var cells := PackedVector4Array()
		for i in range(MAX_CELLS):
			cells.append(storm_cells[i] if i < storm_cells.size() else Vector4(0, 0, 0, 0))
		ocean_material.set_shader_parameter("storm_cells", cells)
		var wh := PackedVector4Array()
		for i in range(MAX_WHIRLS):
			wh.append(whirls[i] if i < whirls.size() else Vector4(0, 0, 0, 0))
		ocean_material.set_shader_parameter("whirls", wh)
		_send_wakes(time)
		var shoals := [shoal_map, shoal_rect, shoal_fine, fine_rect, ocean_material, isle_shoals.duplicate()]
		if shoals != _shoals_sent:
			_shoals_sent = shoals
			ocean_material.set_shader_parameter("shoal_map", shoal_map)
			ocean_material.set_shader_parameter("shoal_rect", shoal_rect)
			ocean_material.set_shader_parameter("shoal_fine", shoal_fine)
			ocean_material.set_shader_parameter("fine_rect", fine_rect)
			for i in range(MAX_ISLES):
				var s: Array = isle_shoals[i] if i < isle_shoals.size() else [null, Vector4.ZERO]
				ocean_material.set_shader_parameter("shoal_isle%d" % i, s[0])
				ocean_material.set_shader_parameter("isle_rect%d" % i, s[1])
		if absf(amp_mult - _amp_sent) > 0.0005:
			_amp_sent = amp_mult
			_send_waves()

	# Follow the camera on XZ (snapped, so the 1 m cells stay on whole metres)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var ocean_mesh := _mesh_node
		if ocean_mesh and is_instance_valid(ocean_mesh):
			# (the 1 m cells stay on whole metres of the world)
			ocean_mesh.global_position.x = snappedf(camera.global_position.x, SNAP)
			ocean_mesh.global_position.z = snappedf(camera.global_position.z, SNAP)
			ocean_mesh.global_position.y = 0.0


## A hull under way leaves foam: call every tick with where its stern is.
func wake(hull: Node, stern: Vector3, strength: float) -> void:
	var now := clock()
	var trail: Array = _wakes.get(hull.get_instance_id(), [])
	if trail.is_empty() or now - float((trail[-1] as Vector4).z) >= WAKE_EVERY:
		trail.append(Vector4(stern.x, stern.z, now, strength))
		if trail.size() > WAKE_PTS:
			trail.pop_front()
	_wakes[hull.get_instance_id()] = trail
	_wake_heads[hull.get_instance_id()] = Vector4(stern.x, stern.z, now, strength)


func _send_wakes(now: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := Vector2(cam.global_position.x, cam.global_position.z) if cam else Vector2.ZERO
	var live: Array = []
	for id in _wakes.keys():
		var trail: Array = _wakes[id]
		while not trail.is_empty() and now - float((trail[0] as Vector4).z) > WAKE_LIFE:
			trail.pop_front()
		if trail.is_empty() or not is_instance_id_valid(id):
			_wakes.erase(id)
			_wake_heads.erase(id)
			continue
		var head: Vector4 = _wake_heads[id]
		var dist := Vector2(head.x, head.y).distance_to(eye)
		# (a far trail would only stretch the box every sea pixel tests against)
		if dist > WAKE_SEND:
			continue
		var pts: Array = trail.duplicate()
		if now - head.z < 0.2:
			pts.append(head)
		live.append([dist, pts])
	live.sort_custom(func(a, b): return a[0] < b[0])
	var out := PackedVector4Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for l in live:
		var pts: Array = l[1]
		if out.size() + pts.size() + 1 > WAKE_SLOTS:
			break
		for k in range(pts.size() - 1, -1, -1):
			var p: Vector4 = pts[k]
			out.append(Vector4(p.x, p.y, now - p.z, p.w))
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		out.append(Vector4.ZERO)
	while out.size() < WAKE_SLOTS:
		out.append(Vector4.ZERO)
	ocean_material.set_shader_parameter("wake", out)
	# (fragments outside the trails' box skip the loop; the V spreads ~9 m)
	var pad := 12.0
	ocean_material.set_shader_parameter("wake_box", Vector4(lo.x - pad, lo.y - pad, hi.x + pad, hi.y + pad) if not live.is_empty() else Vector4(1, 1, -1, -1))
	ocean_material.set_shader_parameter("wake_life", WAKE_LIFE)


func _send_waves() -> void:
	ocean_material.set_shader_parameter("waves", PackedVector4Array(_w4))
	ocean_material.set_shader_parameter("wave_amp_phase", PackedVector2Array(_w2))
	ocean_material.set_shader_parameter("amp_mult", amp_mult)
	ocean_material.set_shader_parameter("wave_total", _amp_total * amp_mult)
	ocean_material.set_shader_parameter("crest", Vector2(CREST_POW, CREST_MEAN))
	ocean_material.set_shader_parameter("env_dirs", Vector4(ENV_A.x, ENV_A.y, ENV_B.x, ENV_B.y))
	ocean_material.set_shader_parameter("env_params", Vector3(ENV_AMOUNT, ENV_SPEED.x, ENV_SPEED.y))
	ocean_material.set_shader_parameter("crest_cap", Vector2(CREST_KNEE, CREST_ROOM))
	ocean_material.set_shader_parameter("near_half", NEAR_HALF)
	ocean_material.set_shader_parameter("growth", GROWTH - 1.0)


## How deep the water is at a spot: wave surface minus the ground (world
## layer) under it. INF over open water with no bottom in reach; negative on
## dry land above the waves. calm: measured from the mean sea level instead of
## the passing wave.
func depth_at(world_pos: Vector3, exclude: Array = [], calm: bool = false) -> float:
	var vp := get_viewport()
	if vp == null or vp.world_3d == null:
		return -INF
	var surf := 0.0 if calm else get_wave_height(world_pos)
	var top := maxf(world_pos.y, surf) + 1.5
	var q := PhysicsRayQueryParameters3D.create(Vector3(world_pos.x, top, world_pos.z), Vector3(world_pos.x, surf - 40.0, world_pos.z), 1)
	q.exclude = exclude
	var hit := vp.world_3d.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return surf - (hit["position"] as Vector3).y
