class_name BladeTrail
extends MeshInstance3D
## A ribbon traced by the weapons in a Humanoid's hands: each blade's base and tip are
## sampled every frame and drawn as a strip that fades over LIFE seconds, in world space,
## so it always follows the real swing (the anim lab's clean view and its renders).
## `manual`: the owner calls sample() itself (tools stepping the rig by hand).

const LIFE := 0.16

var body: Humanoid
var manual := false
var _im := ImmediateMesh.new()
var _clock := 0.0
## per hand: [[time, base, tip], ...]
var _pts: Array = [[], []]
static var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(delta: float) -> void:
	if not manual:
		sample(delta)


func sample(delta: float) -> void:
	_clock += delta
	_im.clear_surfaces()
	var blades: Array = [body.weapon, body.offhand]
	for i in 2:
		var w: MeshInstance3D = blades[i]
		var pts: Array = _pts[i]
		if w != null and is_instance_valid(w) and w.get_parent() in [body.hand_r, body.hand_l] and not body._guns_out():
			var tip_z := w.mesh.get_aabb().position.z
			pts.append([_clock, w.global_transform * Vector3(0, 0, tip_z * 0.3), w.global_transform * Vector3(0, 0, tip_z)])
		while not pts.is_empty() and _clock - float(pts[0][0]) > LIFE:
			pts.pop_front()
		if pts.size() < 2:
			continue
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
		for p in pts:
			var a := 1.0 - (_clock - float(p[0])) / LIFE
			_im.surface_set_color(Color(1.0, 0.97, 0.85, 0.15 * a))
			_im.surface_add_vertex(p[1])
			_im.surface_set_color(Color(1.0, 1.0, 1.0, 0.8 * a))
			_im.surface_add_vertex(p[2])
		_im.surface_end()
