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
## Opacity (the dither pool, a little see-through)
const ALPHA := 0.75

var radius: float = 0.85
var dps: float = 3.0
var _t: float = 0.0
var _check: float = 0.0
var _bub: float = 0.0
var _mat: ShaderMaterial
var _disc: MeshInstance3D

## A quad whose sheet pool (gen_dither_fx.py) reaches about `radius` at scale 1.
static var _quad: QuadMesh
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
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2.56, 2.56)
		_quad.orientation = PlaneMesh.FACE_Y
	_mat = PSXMat.decal_sheet("dither_puddle_poison", Color(1, 1, 1, ALPHA), {"unshaded": true, "fps": 6.0})
	_disc = MeshInstance3D.new()
	_disc.mesh = _quad
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
	_mat.set_shader_parameter("albedo_color", Color(1, 1, 1, ALPHA * k))
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
