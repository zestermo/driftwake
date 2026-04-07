extends Area3D
class_name Interactable

signal interacted(player: Player)

@export var prompt_text: String = "Interact"
@export var enabled: bool = true


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
