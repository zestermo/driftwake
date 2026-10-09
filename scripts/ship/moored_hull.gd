class_name MooredHull
extends AnimatableBody3D
## A ship tied up at a pier: rides the swell where it lies (you can walk its deck).

const HEAVE := 0.7

## Origin height above the water, and how far bow and stern are from the middle.
var freeboard := HullBuilder.FREEBOARD
var half_len := HullBuilder.STERN_Z

var _base: Transform3D


func _ready() -> void:
	_base = global_transform


func _physics_process(_delta: float) -> void:
	var p := _base.origin
	var fwd := -_base.basis.z
	var hb := Ocean.get_wave_height(p + fwd * half_len)
	var hs := Ocean.get_wave_height(p - fwd * half_len)
	var hc := Ocean.get_wave_height(p)
	var pitch := atan2(hb - hs, half_len * 2.0) * 0.6
	global_transform = Transform3D(_base.basis * Basis(Vector3.RIGHT, pitch), Vector3(p.x, (hb + hs + hc) / 3.0 * HEAVE + freeboard, p.z))
