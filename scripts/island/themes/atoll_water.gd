extends Node3D
## The coral atoll's clear lagoon (1.30): while the camera is near an atoll, the sea's shader gets its lagoon as a disc
## (ocean.gdshader `lagoon_disc`: the water inside clear tropical blue however deep, the floor showing), fading in over
## FADE m and gone when you sail off. Each screen sets its own; nothing is sent. A diver's fog is KitStyle "under"
## (Weather). Checks twice a second; the nearest atoll holds the disc.

## Faded in from this far past the lagoon's edge (m) to full at the first number. (Its strength also makes the deep
## water round the atoll opaque, hiding the edge of the island's square of seabed: out to past the fog's end.)
const FADE := Vector2(900.0, 1300.0)
const EVERY := 0.5

static var _holder: Node

var radius := 0.0
var _t := 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = EVERY
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := global_position
	var d := Vector2(cam.global_position.x - c.x, cam.global_position.z - c.z).length()
	var k := 1.0 - smoothstep(radius + FADE.x, radius + FADE.y, d)
	if k <= 0.0:
		if _holder == self:
			_send(Vector4.ZERO)
			_holder = null
		return
	if _holder != null and _holder != self and is_instance_valid(_holder):
		return
	_holder = self
	_send(Vector4(c.x, c.z, radius, k))


func _exit_tree() -> void:
	if _holder == self:
		_send(Vector4.ZERO)
		_holder = null


func _send(v: Vector4) -> void:
	var mat: ShaderMaterial = get_node("/root/Ocean").ocean_material
	if mat:
		mat.set_shader_parameter("lagoon_disc", v)
