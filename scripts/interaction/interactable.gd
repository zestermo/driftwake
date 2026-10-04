extends Area3D
class_name Interactable

signal interacted(player: Player)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true
## Can be used while swimming (ladders). Everything else needs dry feet.
@export var usable_in_water: bool = false


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
