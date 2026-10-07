extends Area3D
class_name Interactable

signal interacted(player: Player)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true
## Can be used while swimming (ladders). Everything else needs dry feet.
@export var usable_in_water: bool = false
## Right next to it only: within this flat distance of its origin (and 1.8 m
## up or down). 0 = wherever its shape meets yours.
@export var reach: float = 0.0
## A test of its own instead (feet position -> bool), e.g. a ladder's ends.
var reach_test: Callable


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)


func in_reach(feet: Vector3) -> bool:
	if reach_test.is_valid():
		return bool(reach_test.call(feet))
	if reach <= 0.0:
		return true
	var d := feet - global_position
	return Vector2(d.x, d.z).length() <= reach and absf(d.y) < 1.8
