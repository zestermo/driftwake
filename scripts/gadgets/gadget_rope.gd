class_name GadgetRope
extends Node3D
## The grappling hook's line: a rope shot out from the hand to the hook (it flies out over shoot_time), held between
## the two ends while you're hauled up it, then reeled back in. Same calls as VineRope (set_ends / arrived / retract /
## `_b` / `_retracting`), so Player._rope_end shows it on the crew's screens too. Lives only while it's out.

var shoot_time := 0.12
var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _reach := 0.0
var _retracting := false
var _line: MeshInstance3D
var _hook: MeshInstance3D
var tier := 0

static var _cyl: CylinderMesh


static func make(parent: Node, from: Vector3, to: Vector3, t: int) -> GadgetRope:
	var r := GadgetRope.new()
	r.name = "GadgetRope"
	r.tier = t
	r._a = from
	r._b = to
	parent.add_child(r)
	return r


func _ready() -> void:
	if _cyl == null:
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 0.018
		_cyl.bottom_radius = 0.018
		_cyl.height = 1.0
		_cyl.radial_segments = 4
		_cyl.rings = 1
		_cyl.material = PSXMat.lit("rope")
	_line = MeshInstance3D.new()
	_line.mesh = _cyl
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_hook = MeshInstance3D.new()
	_hook.mesh = GadgetModels.mesh("grapple", tier)
	_hook.scale = Vector3.ONE * 2.0
	_hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hook)
	top_level = true
	_draw()


func set_ends(from: Vector3, to: Vector3) -> void:
	_a = from
	_b = to


func arrived() -> bool:
	return _reach >= 1.0


func retract(secs: float = 0.14) -> void:
	_retracting = true
	shoot_time = secs


func _process(delta: float) -> void:
	_reach += (-1.0 if _retracting else 1.0) * delta / maxf(shoot_time, 0.01)
	if _retracting and _reach <= 0.0:
		queue_free()
		return
	_reach = clampf(_reach, 0.0, 1.0)
	_draw()


func _draw() -> void:
	var tip := _a.lerp(_b, _reach)
	var d := tip - _a
	var len := maxf(d.length(), 0.01)
	var up := d / len
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	_line.global_transform = Transform3D(Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3(1, len, 1)), _a + d * 0.5)
	_hook.global_transform = Transform3D(Basis(side, -up, side.cross(-up)) * Basis.from_scale(Vector3.ONE * 2.0), tip)
