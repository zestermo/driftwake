extends OmniLight3D
## Campfire / torch flicker.

@export var base_energy: float = 2.0
@export var flicker_amount: float = 0.6
@export var speed: float = 9.0

var _t: float = 0.0


func _ready() -> void:
	base_energy = light_energy
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = base_energy + (sin(_t) * 0.5 + sin(_t * 2.7) * 0.3 + randf_range(-0.2, 0.2)) * flicker_amount
