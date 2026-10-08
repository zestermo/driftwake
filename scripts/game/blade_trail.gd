class_name BladeTrail
extends MeshInstance3D
## A ribbon traced by the weapons in a Humanoid's hands: each blade's base and tip are
## sampled every frame and drawn as a strip that fades over `life` seconds, in world space,
## so it always follows the real swing. The anim lab's clean view keeps one on the captain
## for good (emit -1); FX.blade_swoosh makes a coloured one for a strike that samples for
## `emit` seconds, fades and frees itself.
## `manual`: the owner calls sample() itself (tools stepping the rig by hand).

const LIFE := 0.16

var body: Humanoid
var manual := false
var color := Color(1, 1, 1)
var life := LIFE
## Seconds left to sample (-1: for good); when it runs out the trail fades and frees itself.
var emit := -1.0
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
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _process(delta: float) -> void:
	if not manual:
		sample(delta)


func sample(delta: float) -> void:
	if body == null or not is_instance_valid(body):
		queue_free()
		return
	_clock += delta
	var emitting := emit != 0.0
	if emit > 0.0:
		emit = maxf(emit - delta, 0.0)
	_im.clear_surfaces()
	var blades: Array = [body.weapon, body.offhand]
	var any := false
	for i in 2:
		var w: MeshInstance3D = blades[i]
		var pts: Array = _pts[i]
		if emitting and w != null and is_instance_valid(w) and w.get_parent() in [body.hand_r, body.hand_l] and not body._guns_out():
			var tip_z := w.mesh.get_aabb().position.z
			pts.append([_clock, w.global_transform * Vector3(0, 0, tip_z * 0.3), w.global_transform * Vector3(0, 0, tip_z)])
		while not pts.is_empty() and _clock - float(pts[0][0]) > life:
			pts.pop_front()
		if pts.size() < 2:
			continue
		any = true
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
		for p in pts:
			var a := 1.0 - (_clock - float(p[0])) / life
			_im.surface_set_color(Color(color.r, color.g, color.b, 0.2 * a))
			_im.surface_add_vertex(p[1])
			var tip := color.lerp(Color.WHITE, 0.5)
			_im.surface_set_color(Color(tip.r, tip.g, tip.b, 0.9 * a))
			_im.surface_add_vertex(p[2])
		_im.surface_end()
	if emit == 0.0 and not any:
		queue_free()
