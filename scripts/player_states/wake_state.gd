extends PlayerState
## A new game's first moments (Story): lying on the sand as the screen fades
## in, a gull glides down beside your head and caws, you jolt and get up
## slowly, a hand to your head, and the first objective comes up. Nothing you
## press does anything until you're standing (the camera still turns).

const LEN := 7.0
## When the gull caws (the action's WAKE_CAW of LEN), lands, takes fright.
const CAW_AT := 2.8
const LAND_AT := 1.0
const SCARED_AT := 3.6

var _t: float = 0.0
var _gull: Seagull
var _cawed: int = 0
var _head: Vector3
var _side: Vector3
## Eyelids over the screen: shut, a squint, shut again, then open.
var _eyes: CanvasLayer
var _lids: Control


func _open_amount(t: float) -> float:
	if t < 0.6:
		return 0.0
	if t < 1.2:
		return smoothstep(0.6, 1.2, t) * 0.22
	if t < 1.5:
		return (1.0 - smoothstep(1.2, 1.5, t)) * 0.22
	return smoothstep(1.6, 2.6, t)


func enter(_data: Dictionary) -> void:
	_t = 0.0
	_cawed = 0
	_eyes = CanvasLayer.new()
	_eyes.layer = 60
	_lids = Control.new()
	_lids.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lids.draw.connect(func():
		var vs := _lids.size
		var o := _open_amount(_t)
		var h := vs.y * 0.5 * (1.0 - o)
		_lids.draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0, 0, 0, 0.55 * (1.0 - o)))
		_lids.draw_rect(Rect2(0, 0, vs.x, h), Color.BLACK)
		_lids.draw_rect(Rect2(0, vs.y - h, vs.x, h), Color.BLACK))
	_eyes.add_child(_lids)
	player.add_child(_eyes)
	player.velocity = Vector3.ZERO
	player.input_locked = true
	player.body_model.play("wake", LEN)
	# face up, the head lies behind the root; the gull lands on the right of it
	var yaw := player.player_model.rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	_side = Vector3(cos(yaw), 0, -sin(yaw))
	_head = player.global_position - fwd * 0.95
	# the camera beside the head on that side, looking down along the body
	var cam := player.get_viewport().get_camera_3d()
	var rig := cam.get_parent().get_parent() if cam else null
	if rig and rig.has_method("set_showcase"):
		rig.rotation.y = yaw + PI * 0.5 + 0.55
		(rig.get_node("SpringArm3D") as Node3D).rotation.x = -0.5
		rig.set("current_zoom", 3.4)


func physics_update(delta: float) -> void:
	_t += delta
	if _eyes:
		_lids.queue_redraw()
		if _t > 2.7:
			_eyes.queue_free()
			_eyes = null
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	if _t >= LAND_AT and _gull == null:
		_gull = Seagull.new()
		player.get_tree().current_scene.add_child(_gull)
		var spot := _head + _side * 0.55
		var to_head := _head - spot
		_gull.land(spot + _side * 6.0 + Vector3.UP * 4.0, spot, atan2(-to_head.x, -to_head.z))
	if _cawed == 0 and _t >= CAW_AT:
		_cawed = 1
		if is_instance_valid(_gull):
			_gull.caw()
	if _cawed == 1 and _t >= SCARED_AT:
		_cawed = 2
		if is_instance_valid(_gull):
			_gull.fly_off(_side + Vector3(0.3, 0, 0))
	if _t >= LEN:
		transitioned.emit(self, "Idle", {})


func exit() -> void:
	player.input_locked = false
	if _eyes:
		_eyes.queue_free()
		_eyes = null
	if _t < LEN:
		player.body_model.stop_action()
	var hud := player.get_tree()
	hud.call_group("hud", "show_banner", "Where am I...?", "You can't remember a thing. Head into town.", true)
	if Story.active():
		hud.call_group("hud", "show_objective_banner", Story.goal())
