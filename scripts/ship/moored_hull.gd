class_name MooredHull
extends AnimatableBody3D
## A ship tied up at a pier: rides the swell where it lies (you can walk its deck), and holds still with nobody near.

const HEAVE := 0.7
## Rides the swell within NEAR of a captain or the ship under way; holds still past FAR.
const NEAR := 80.0
const FAR := 90.0
const CHECK_TICKS := 15

## Origin height above the water, and how far bow and stern are from the middle.
var freeboard := HullBuilder.FREEBOARD
var half_len := HullBuilder.STERN_Z
var riding := true

var _base: Transform3D
var _check := 0


func _ready() -> void:
	_base = global_transform
	_check = get_instance_id() % CHECK_TICKS


func _physics_process(_delta: float) -> void:
	_check -= 1
	if _check <= 0:
		_check = CHECK_TICKS
		riding = _anyone_within(FAR if riding else NEAR)
	if not riding:
		return
	var p := _base.origin
	var fwd := -_base.basis.z
	var hb := Ocean.get_wave_height(p + fwd * half_len)
	var hs := Ocean.get_wave_height(p - fwd * half_len)
	var hc := Ocean.get_wave_height(p)
	var pitch := atan2(hb - hs, half_len * 2.0) * 0.6
	global_transform = Transform3D(_base.basis * Basis(Vector3.RIGHT, pitch), Vector3(p.x, (hb + hs + hc) / 3.0 * HEAVE + freeboard, p.z))


func _anyone_within(r: float) -> bool:
	var o := _base.origin
	for c in get_tree().get_nodes_in_group("players"):
		if (c as Node3D).global_position.distance_squared_to(o) < r * r:
			return true
	# (the ship only while she's under way: moored in the harbour she'd keep every hull in it riding)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	return ship != null and absf(float(ship.get("speed"))) > 0.5 and ship.global_position.distance_squared_to(o) < r * r
