extends Node3D

@export var float_speed: float = 2.0
@export var lifetime: float = 0.8

var timer: float = 0.0

@onready var label: Label3D = $Label3D


func setup(damage: float, pos: Vector3) -> void:
	global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))
	if not label:
		label = $Label3D
	label.text = str(int(damage))
	if damage >= 30.0:
		label.modulate = Color(1.0, 0.3, 0.2)
		label.font_size = 48
	elif damage >= 15.0:
		label.modulate = Color(1.0, 0.65, 0.0)
		label.font_size = 40
	else:
		label.modulate = Color(1.0, 1.0, 1.0)
		label.font_size = 32


func _process(delta: float) -> void:
	timer += delta
	global_position.y += float_speed * delta
	var alpha := 1.0 - (timer / lifetime)
	label.modulate.a = alpha
	if timer >= lifetime:
		queue_free()
