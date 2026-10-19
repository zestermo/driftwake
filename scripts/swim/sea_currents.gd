extends Node3D
## Rip currents off the islands' beaches: a narrow channel of water running straight out to sea from the
## surf, strong near the beach and dying away 50 m out. Swim against one and you go nowhere; swim along
## the shore and you're out of it. Each one shows: flecks of foam and churned sand riding out along it at its
## speed, and foam thrown seaward (each screen its own, near the camera only).
## Placed from the island's seed on gentle, exposed shores clear of the dock (the same on every screen).
## DiveSites builds it ("SeaCurrents", group "sea_currents") and keeps its islands in step with its own.

## Strongest flow (m/s): a plain stroke (3.2) barely holds against it, a sprint (4.6) beats it.
const RIP_SPEED := 2.6
const RIP_LEN := 50.0
const RIP_WIDTH := 8.0
## Rips per island (Brinehollow, a chain island), and how far apart they keep.
const HOME_RIPS := 3
const GEN_RIPS := 2
const RIP_GAP := 80.0
const DOCK_KEEP := 80.0
## The churn: how often, and from how far it's drawn.
const CHURN_EVERY := 0.3
const CHURN_RANGE := 60.0

## island key -> [[from (x, z), to (x, z), width], ...] in world space
var rips := {}
var _churn_t := 0.0


func _ready() -> void:
	add_to_group("sea_currents")


func build_island(key: String, isl: Node3D, ground: Callable, seed_value: int, count: int, dock: Vector2, r_min: float, r_max: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "rips"])
	var list: Array = []
	var start := rng.randf() * TAU
	for k in range(48):
		if list.size() >= count:
			break
		var a := start + TAU * float(k) / 48.0
		var d := Vector2(cos(a), sin(a))
		var r := r_min
		while r < r_max and float(ground.call(d.x * r, d.y * r)) > -0.3:
			r += 2.0
		if r >= r_max:
			continue
		var w := d * r
		# a beach: the bottom shelves gently out (not a cliff, not a reef flat), on a shore the swell reaches
		var out := float(ground.call(w.x + d.x * 30.0, w.y + d.y * 30.0))
		if out > -1.5 or out < -7.0 or w.distance_to(dock) < DOCK_KEEP:
			continue
		var wa := isl.to_global(Vector3(w.x - d.x * 4.0, 0.0, w.y - d.y * 4.0))
		var wb := isl.to_global(Vector3(w.x + d.x * RIP_LEN, 0.0, w.y + d.y * RIP_LEN))
		if float(Ocean.shore_at(wa.x, wa.z).w) < 0.35:
			continue
		var a2 := Vector2(wa.x, wa.z)
		if list.any(func(e): return (e[0] as Vector2).distance_to(a2) < RIP_GAP):
			continue
		list.append([a2, Vector2(wb.x, wb.z), RIP_WIDTH])
	rips[key] = list


func drop_island(key: String) -> void:
	rips.erase(key)
	for id in _fleck_nodes.keys():
		if str(id).begins_with(key + ":"):
			(_fleck_nodes[id] as Node).queue_free()
			_fleck_nodes.erase(id)


## The rips' pull at `p` (m/s, flat).
func rip_at(p: Vector3) -> Vector3:
	var q := Vector2(p.x, p.z)
	var out := Vector2.ZERO
	for list in rips.values():
		for e in list:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var ab := b - a
			var t := clampf((q - a).dot(ab) / ab.length_squared(), -0.1, 1.1)
			var across := q.distance_to(a + ab * clampf(t, 0.0, 1.0))
			var w: float = e[2]
			if across > w or t < -0.05 or t > 1.0:
				continue
			var k := (1.0 - smoothstep(w * 0.45, w, across)) * (1.0 - smoothstep(0.55, 1.0, t))
			out += ab.normalized() * RIP_SPEED * k
	return Vector3(out.x, 0.0, out.y)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := Vector2(cam.global_position.x, cam.global_position.z)
	_churn_t -= delta
	var churn := _churn_t <= 0.0
	if churn:
		_churn_t = CHURN_EVERY
	# (the flecks move a frame in FLECK_FRAMES: a PS1 step, and a third of the wave sampling)
	_frame += 1
	var move := _frame % FLECK_FRAMES == 0
	var t: float = Ocean.clock()
	for key in rips:
		for i in range((rips[key] as Array).size()):
			var e: Array = rips[key][i]
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var near := c.distance_to((a + b) * 0.5) < CHURN_RANGE + RIP_LEN * 0.5
			var flecks := _flecks(key, i, near)
			if not near:
				continue
			if move:
				_drift_flecks(flecks, a, b, float(e[2]), t)
			if churn:
				# foam thrown seaward somewhere along its first half
				var q := a.lerp(b, randf_range(0.05, 0.5)) + (b - a).normalized().orthogonal() * randf_range(-2.5, 2.5)
				var at := Vector3(q.x, 0.0, q.y)
				at.y = float(Ocean.surface_at(at)) + 0.05
				var dir := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
				FX.spray(at, (dir + Vector3.UP * 0.6).normalized(), 4, Color(0.9, 0.96, 1.0), 2.4)


## The telltale: flecks of foam and churned sand riding out along the rip at its own speed (each screen its
## own, near the camera only). One MultiMesh a rip, made the first time it's near.
const FLECKS := 36
const FLECK_FRAMES := 3
var _fleck_nodes := {}
var _frame := 0
static var _fleck_mesh: QuadMesh


func _flecks(key: String, i: int, near: bool) -> MultiMeshInstance3D:
	var id := "%s:%d" % [key, i]
	var mmi: MultiMeshInstance3D = _fleck_nodes.get(id)
	if mmi == null and near:
		if _fleck_mesh == null:
			_fleck_mesh = QuadMesh.new()
			_fleck_mesh.size = Vector2(1.1, 0.7)
			_fleck_mesh.orientation = PlaneMesh.FACE_Y
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_texture = load("res://assets/textures/fx/dust.png")
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.albedo_color = Color(0.93, 0.97, 1.0, 0.8)
			mat.vertex_color_use_as_albedo = true
			_fleck_mesh.material = mat
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _fleck_mesh
		mm.instance_count = FLECKS
		mmi = MultiMeshInstance3D.new()
		mmi.name = "Rip_" + id.replace(":", "_")
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = CHURN_RANGE + RIP_LEN
		add_child(mmi)
		_fleck_nodes[id] = mmi
	if mmi:
		mmi.visible = near
	return mmi


func _drift_flecks(mmi: MultiMeshInstance3D, a: Vector2, b: Vector2, w: float, t: float) -> void:
	var ab := b - a
	var along := ab.normalized()
	var across := along.orthogonal()
	var yaw := atan2(-along.x, -along.y)
	for k in range(FLECKS):
		# each fleck has its own lane and phase; it rides out over the rip's length, then starts again
		var h := float(k) * 0.618034
		var u := fmod(h + t * RIP_SPEED * 0.8 / RIP_LEN, 1.0)
		var off := (fmod(h * 7.31, 1.0) - 0.5) * w * 1.1
		var q := a + ab * u * 0.8 + across * off
		var p := Vector3(q.x, 0.0, q.y)
		p.y = float(Ocean.surface_at(p)) + 0.06
		var fade := sin(u * PI)
		mmi.multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, yaw + h).scaled(Vector3.ONE * (0.6 + fmod(h * 3.7, 1.0) * 0.8)), p))
		var sandy := fmod(h * 5.3, 1.0) < 0.35
		mmi.multimesh.set_instance_color(k, (Color(0.82, 0.74, 0.55) if sandy else Color.WHITE) * Color(1, 1, 1, fade))
