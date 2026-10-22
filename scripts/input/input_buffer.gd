extends Node
class_name InputBuffer

@export var buffer_window: float = 0.15

var buffer: Array[Dictionary] = []
signal pressed(action: String, at: float)


func _unhandled_input(event: InputEvent) -> void:
	if Pad.pressed(event, "light_attack"):
		buffer_action("light_attack")
	elif Pad.pressed(event, "heavy_attack"):
		buffer_action("heavy_attack")
	elif Pad.pressed(event, "dodge"):
		buffer_action("dodge")
	elif Pad.pressed(event, "parry"):
		buffer_action("parry")


func _now() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func buffer_action(action: String) -> void:
	buffer.append({"action": action, "time": _now()})
	pressed.emit(action, _now())


func consume_action(action: String) -> bool:
	var now := _now()
	for i in range(buffer.size() - 1, -1, -1):
		if buffer[i].action == action and (now - buffer[i].time) <= buffer_window:
			buffer.remove_at(i)
			return true
	_clean_buffer()
	return false


func has_action(action: String) -> bool:
	var now := _now()
	for entry in buffer:
		if entry.action == action and (now - entry.time) <= buffer_window:
			return true
	return false


func _clean_buffer() -> void:
	var now := _now()
	buffer = buffer.filter(func(entry: Dictionary) -> bool: return (now - entry.time) <= buffer_window)
