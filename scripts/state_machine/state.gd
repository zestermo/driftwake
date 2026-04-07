extends Node
class_name State

signal transitioned(state: State, new_state_name: String, data: Dictionary)


func enter(_data: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
