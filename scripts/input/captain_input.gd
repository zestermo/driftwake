class_name CaptainInput
extends RefCounted
## Where a captain's held input comes from (Player.inp): the stick, held buttons, the view's yaw (what "forward"
## means) and the aim. The local captain's is the keyboard/pad and the camera (this class); a captain-style AI's is a
## BrainInput its brain sets every tick. Discrete presses (attacks, dodge, parry) go through the InputBuffer either
## way; skills, the ultimate and drawing call the Player directly.


func pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func release(action: String) -> void:
	Input.action_release(action)


## The move stick (x right, y back, as Input.get_vector).
func stick() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


## The yaw "forward" is measured from (the camera rig's), or NAN with no view.
func view_yaw(p: Node3D) -> float:
	var camera := p.get_viewport().get_camera_3d()
	if not camera:
		return NAN
	# CameraRig is Camera3D -> SpringArm3D -> CameraRig
	var rig := camera.get_parent().get_parent() as Node3D
	return rig.global_rotation.y if rig else NAN


## A brain's input: what it holds, taps and steers this tick.
class BrainInput extends CaptainInput:
	var held := {}
	var taps := {}
	var move := Vector2.ZERO
	var yaw := 0.0

	func pressed(action: String) -> bool:
		return held.get(action, false) or just_pressed(action)

	## A tap reads as just pressed on the physics tick it was made in (the brain thinks before the states).
	func just_pressed(action: String) -> bool:
		return int(taps.get(action, -1)) == Engine.get_physics_frames()

	func release(action: String) -> void:
		held.erase(action)

	func stick() -> Vector2:
		return move.limit_length(1.0)

	func view_yaw(_p: Node3D) -> float:
		return yaw

	func hold(action: String, on: bool) -> void:
		if on:
			held[action] = true
		else:
			held.erase(action)

	func tap(action: String) -> void:
		taps[action] = Engine.get_physics_frames()
