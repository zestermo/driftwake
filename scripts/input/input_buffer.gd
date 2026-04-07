extends Node
class_name InputBuffer

@export var buffer_window: float = 0.15

var buffer: Array[Dictionary] = []


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("light_attack"):
		buffer_action("light_attack")
	elif event.is_action_pressed("heavy_attack"):
		buffer_action("heavy_attack")
	elif event.is_action_pressed("dodge"):
		buffer_action("dodge")
	elif event.is_action_pressed("parry"):
		buffer_action("parry")


func buffer_action(action: String) -> void:
	buffer.append({"action": action, "time": Time.get_ticks_msec() / 1000.0})


func consume_action(action: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(buffer.size() - 1, -1, -1):
		if buffer[i].action == action and (now - buffer[i].time) <= buffer_window:
			buffer.remove_at(i)
			return true
	_clean_buffer()
	return false


func has_action(action: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for entry in buffer:
		if entry.action == action and (now - entry.time) <= buffer_window:
			return true
	return false


func _clean_buffer() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	buffer = buffer.filter(func(entry: Dictionary) -> bool: return (now - entry.time) <= buffer_window)
