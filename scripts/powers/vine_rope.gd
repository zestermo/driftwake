class_name VineRope
extends Node3D
## A vine stretched between two points (Vine Swing, the grapple): a twisted
## green stem with a few leaves along it. It shoots out from the hand to its
## target over `shoot_time`, follows both ends every frame (set_ends), and
## withers back into the hand when let go (retract).

const LEAVES := 5

var shoot_time: float = 0.1
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _t: float = 0.0
var _reach: float = 0.0   # 0..1 how far it has shot out
var _retracting: bool = false
var _stem: MeshInstance3D
var _leaves: Array[MeshInstance3D] = []
static var _stem_mat: StandardMaterial3D
static var _leaf_mat: StandardMaterial3D


static func make(parent: Node, from: Vector3, to: Vector3, shoot: float = 0.1) -> VineRope:
	var v := VineRope.new()
	v.name = "VineRope"
	v.shoot_time = shoot
	parent.add_child(v)
	v.set_ends(from, to)
	return v


func _ready() -> void:
	top_level = true
	if _stem_mat == null:
		_stem_mat = StandardMaterial3D.new()
		_stem_mat.albedo_color = Color(0.26, 0.55, 0.17)
		_leaf_mat = StandardMaterial3D.new()
		_leaf_mat.albedo_color = Color(0.42, 0.78, 0.26)
		_leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stem = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.032
	cm.bottom_radius = 0.042
	cm.height = 1.0
	cm.radial_segments = 5
	cm.rings = 1
	_stem.mesh = cm
	_stem.material_override = _stem_mat
	_stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stem)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.09)
	for i in range(LEAVES):
		var lf := MeshInstance3D.new()
		lf.mesh = qm
		lf.material_override = _leaf_mat
		lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lf)
		_leaves.append(lf)
	_layout()


func set_ends(from: Vector3, to: Vector3) -> void:
	_a = from
	_b = to
	if is_inside_tree():
		_layout()


## Has it reached its target yet?
func arrived() -> bool:
	return _reach >= 1.0


## Wither back into the hand, then go.
func retract(secs: float = 0.14) -> void:
	if _retracting:
		return
	_retracting = true
	shoot_time = secs


func _process(delta: float) -> void:
	_t += delta
	if _retracting:
		_reach -= delta / maxf(shoot_time, 0.01)
		if _reach <= 0.0:
			queue_free()
			return
	else:
		_reach = minf(_reach + delta / maxf(shoot_time, 0.01), 1.0)
	_layout()


func _layout() -> void:
	if _stem == null:
		return
	var seg := (_b - _a) * clampf(_reach, 0.0, 1.0)
	var l := seg.length()
	visible = l > 0.05
	if l < 0.05:
		return
	var up := seg / l
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	var b := Basis(side, up, fwd).orthonormalized()
	# a slow twist along the stem
	b = b * Basis(Vector3.UP, _t * 3.0)
	_stem.global_transform = Transform3D(b.scaled_local(Vector3(1, l, 1)), _a + seg * 0.5)
	for i in range(_leaves.size()):
		var f := (float(i) + 0.6) / float(_leaves.size() + 0.4)
		var p := _a + seg * f
		var ang := float(i) * 2.3 + _t * 0.5
		var out := (side * cos(ang) + fwd * sin(ang))
		var lb := Basis.looking_at(out, up)
		_leaves[i].global_transform = Transform3D(lb, p + out * 0.06)
