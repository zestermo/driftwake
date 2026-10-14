extends PlayerState
## Player is in a conversation: stand still, face the speaker.
## The Dialogue autoload enters/exits this state. The captain gestures through
## their own lines, nods now and then through the other's, and hands something
## over when a trade or a task is settled ("shop:..." / "...:got" / "...:pay" events).

var _face_target: Vector3 = Vector3.ZERO


func enter(data: Dictionary) -> void:
	_face_target = data.get("face", Vector3.ZERO)
	if player.armed:
		player.sheathe_weapon()
	Dialogue.line_shown.connect(_on_line)
	Dialogue.dialogue_event.connect(_on_event)


func exit() -> void:
	Dialogue.line_shown.disconnect(_on_line)
	Dialogue.dialogue_event.disconnect(_on_event)


func _on_line(speaker: String, _text: String) -> void:
	if speaker == Dialogue.PLAYER_SPEAKER:
		player.gesture(str(EmotePoses.TALK.pick_random()).trim_prefix("gesture_"))
	elif randf() < 0.35 and not player.body_model.is_busy():
		player.gesture("nod")


func _on_event(ev: String) -> void:
	if ev.begins_with("shop:") or ev.ends_with(":got") or ev.ends_with(":pay"):
		player.gesture("hand")


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
	player.move_and_slide()
	if _face_target != Vector3.ZERO:
		var dir := _face_target - player.global_position
		dir.y = 0.0
		face_direction(dir.normalized(), delta)
