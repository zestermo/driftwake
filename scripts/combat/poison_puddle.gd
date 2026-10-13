class_name PoisonPuddle
extends Node3D
## A pool of venom where a glob landed (PoisonGlob): bright green, bubbling,
## gone after a few seconds. A captain standing in it is poisoned (a short dose
## that keeps topping up while they stay; dot ticks never flinch). Jumping or
## dodge-rolling across it is safe. Every screen lands its own copy of the glob
## and so its own puddle; each machine checks only its own captain.

const LIFE := 4.5
const FADE := 1.2
const DOSE := 1.2
const CHECK := 0.2
const MAX := 24
const RIM := Color(0.55, 1.0, 0.28)
const MID := Color(0.22, 0.62, 0.1)

var radius: float = 0.85
var dps: float = 3.0
var _t: float = 0.0
var _check: float = 0.0
var _bub: float = 0.0
var _mat: StandardMaterial3D
var _disc: MeshInstance3D

static var _base_mat: StandardMaterial3D
static var _meshes: Array = []
static var _all: Array = []


static func spawn(parent: Node, at: Vector3, normal: Vector3, size: float, dose_dps: float) -> PoisonPuddle:
	var pp := PoisonPuddle.new()
	pp.name = "PoisonPuddle"
	pp.radius = 0.85 * size
	pp.dps = dose_dps
	parent.add_child(pp)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	pp.global_transform = Transform3D(Basis(side, up, side.cross(up)).rotated(up, randf() * TAU), at + up * 0.025)
	_all.append(pp)
	while _all.size() > MAX:
		var old = _all.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return pp


## The puddles on the ground right now.
static func live() -> Array:
	return _all.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())


func _ready() -> void:
	if _base_mat == null:
		_base_mat = StandardMaterial3D.new()
		_base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_base_mat.vertex_color_use_as_albedo = true
		_base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_base_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for i in range(3):
			_meshes.append(_blob_mesh())
	_mat = _base_mat.duplicate() as StandardMaterial3D
	_mat.albedo_color = Color(1, 1, 1, 0.85)
	_disc = MeshInstance3D.new()
	_disc.mesh = _meshes[randi() % _meshes.size()]
	_disc.material_override = _mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.scale = Vector3.ONE * radius * 0.3
	add_child(_disc)
	create_tween().tween_property(_disc, "scale", Vector3.ONE * radius, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bub = 0.1


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf((LIFE - _t) / FADE, 0.0, 1.0)
	if _t > 0.2:
		_disc.scale = Vector3.ONE * radius * lerpf(0.7, 1.0, k)
	_mat.albedo_color.a = 0.85 * k
	if _t >= LIFE:
		queue_free()
		return
	_bub -= delta
	if _bub <= 0.0:
		_bub = 0.3
		var a := randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * randf() * radius * 0.7
		FX.poison(global_position + global_basis * off, 1, 0.24 * radius)
	_check -= delta
	if _check > 0.0 or k < 0.35:
		return
	_check = CHECK
	var p: Node3D = Net.local_player if Net.active else GameManager.player
	if p and is_instance_valid(p) and _stands_in(p, k):
		var ps := p.get_node_or_null("Poison") as PoisonStatus
		if ps and not ps.is_queued_for_deletion():
			ps.time_left = maxf(ps.time_left, DOSE)
			ps.dps = maxf(ps.dps, dps)
		else:
			PoisonStatus.apply(p, DOSE, dps, null)


func _stands_in(p: Node3D, k: float) -> bool:
	if not BurnStatus.alive(p):
		return false
	var hb := p.get_node_or_null("Hurtbox") as Hurtbox
	if hb == null or not hb.monitorable:
		return false
	var d := global_basis.inverse() * (p.global_position - global_position)
	return d.y > -0.4 and d.y < 0.45 and Vector2(d.x, d.z).length() < radius * lerpf(0.7, 1.0, k)


## A lumpy unit pool (flat, +Y up): a main blob and a few run-offs, bright at
## the rim and darker in the middle.
static func _blob_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var blobs := [[Vector2.ZERO, 1.0]]
	for i in range(randi_range(2, 4)):
		var a := randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * randf_range(0.55, 0.85), randf_range(0.25, 0.45)])
	for bl in blobs:
		var c: Vector2 = bl[0]
		var r: float = bl[1]
		var seg := 14 if r > 0.5 else 8
		var ph := randf() * TAU
		var rim: Array = []
		for k in range(seg):
			var a := float(k) / seg * TAU
			rim.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.18 * sin(3.0 * a + ph)))
		for k in range(seg):
			var p0: Vector2 = rim[k]
			var p1: Vector2 = rim[(k + 1) % seg]
			st.set_color(MID)
			st.add_vertex(Vector3(c.x, 0, c.y))
			st.set_color(RIM)
			st.add_vertex(Vector3(p1.x, 0, p1.y))
			st.add_vertex(Vector3(p0.x, 0, p0.y))
	return st.commit()
