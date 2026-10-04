extends Node3D
## Spins around local Y (lighthouse lamp, windmills...).

@export var speed: float = 1.0


func _process(delta: float) -> void:
	rotate_y(speed * delta)
