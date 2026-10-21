extends Node
## The gamepad (Xbox layout, Godot's joypad API) on top of the InputMap (autoload Pad). The base layer's
## pad events live in project.godot beside the keys. Holding LB brings in the skills layer (LAYER): each pad
## input the layer uses comes off its base action and goes onto the layer's, and back when LB lets go. Input
## marks an action pressed as an event is parsed, before any node sees it, so one button bound to two actions
## would press both; swapping the bindings keeps Input's own state right. On a swap, whatever a still-held
## swapped input was pressing is let go (its release would otherwise match the other layer's action).
## L3 is a sprint latch: click it and you sprint until the stick sits centred or your stamina runs out.
## Also here: which device you used last (Glyphs reads it) and the right stick's look, curved, at
## Settings' pad sensitivity.

signal device_changed(pad: bool)

## The skills layer, held on LB: action -> its pad input (a button index, or [axis, sign]).
const LAYER := {
	"skill_1": JOY_BUTTON_X, "skill_2": JOY_BUTTON_Y, "skill_3": JOY_BUTTON_B, "skill_4": JOY_BUTTON_A,
	"skill_5": JOY_BUTTON_RIGHT_SHOULDER, "ultimate": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"lantern": JOY_BUTTON_DPAD_UP, "summon_ship": JOY_BUTTON_DPAD_DOWN, "log_pose": JOY_BUTTON_DPAD_LEFT,
	"emote": JOY_BUTTON_DPAD_RIGHT, "ping_marker": JOY_BUTTON_RIGHT_STICK, "transform": JOY_BUTTON_LEFT_STICK,
	"skill_map": JOY_BUTTON_BACK,
}
const MODIFIER := JOY_BUTTON_LEFT_SHOULDER
const SPRINT := JOY_BUTTON_LEFT_STICK
const MOVE := ["move_left", "move_right", "move_forward", "move_back"]
const LOOK := ["look_left", "look_right", "look_up", "look_down"]
## A full push's turn (rad/s, yaw and pitch) at sensitivity 1, and the response curve's power past the deadzone.
const LOOK_RATE := Vector2(3.5, 2.4)
const LOOK_CURVE := 2.0
## The latch lets go once the stick has sat centred this long (a flick through the middle keeps it).
const LATCH_GRACE := 0.15

## The last thing touched was the pad (prompts show pad buttons).
var using_pad := false
## LB is held: the skills layer is on.
var layer := false
var sprint_latched := false
var _down := {}
var _axis := {}
var _taken: Array = []
var _added: Array = []
var _idle := 0.0
var _lb_real := false
var _edge := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_deadzones()
	Settings.changed.connect(func(section: String, key: String, _v):
		if section == "controls" and key.ends_with("_deadzone"):
			_apply_deadzones())


func _apply_deadzones() -> void:
	for a in MOVE:
		InputMap.action_set_deadzone(a, float(Settings.get_value("controls", "pad_move_deadzone")))
	for a in LOOK:
		InputMap.action_set_deadzone(a, float(Settings.get_value("controls", "pad_look_deadzone")))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		_down[b.button_index] = b.pressed
		if b.pressed:
			_saw(true)
		if b.button_index == MODIFIER:
			set_layer(b.pressed)
		elif b.button_index == SPRINT and b.pressed and not layer:
			_latch(not sprint_latched)
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		_axis[m.axis] = m.axis_value
		if absf(m.axis_value) > 0.4:
			_saw(true)
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_saw(false)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 6.0:
		_saw(false)


func _process(delta: float) -> void:
	# a real pad's LB, in case a screen ate its event (only on a change, so a pad lying idle leaves tests be)
	var lb := false
	for d in Input.get_connected_joypads():
		lb = lb or Input.is_joy_button_pressed(d, MODIFIER)
	if lb != _lb_real:
		_lb_real = lb
		set_layer(lb)
	if sprint_latched:
		var mv := Input.get_vector(MOVE[0], MOVE[1], MOVE[2], MOVE[3])
		_idle = _idle + delta / maxf(Engine.time_scale, 0.05) if mv.length() < 0.2 else 0.0
		var p := get_tree().get_first_node_in_group("player")
		if _idle >= LATCH_GRACE or (p and p.has_method("can_sprint") and not p.can_sprint()):
			_latch(false)


func _saw(pad: bool) -> void:
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(pad)


func _latch(on: bool) -> void:
	if on == sprint_latched:
		return
	sprint_latched = on
	_idle = 0.0
	if on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


## event.is_action_pressed(action), once per press: a trigger's or stick's motion events keep matching while
## it's held past its deadzone, so only the one that took it past (Input's just-pressed, once a frame) counts.
func pressed(event: InputEvent, action: String) -> bool:
	if not event.is_action_pressed(action):
		return false
	if not event is InputEventJoypadMotion:
		return true
	var f := Engine.get_process_frames()
	if not Input.is_action_just_pressed(action) or int(_edge.get(action, -1)) == f:
		return false
	_edge[action] = f
	return true


## The right stick's look this frame (radians: x turns right, y tilts down), past the deadzone, curved, at
## Settings' pad sensitivity. dt in real seconds (a hit-stop shouldn't slow the camera).
func look(dt: float) -> Vector2:
	var v := Input.get_vector(LOOK[0], LOOK[1], LOOK[2], LOOK[3])
	if v == Vector2.ZERO:
		return v
	v *= pow(v.length(), LOOK_CURVE - 1.0)
	return v * LOOK_RATE * float(Settings.get_value("controls", "pad_look_sensitivity")) * dt


## The right stick's raw direction (deadzoned, uncurved): the wheels point with it.
func stick() -> Vector2:
	return Input.get_vector(LOOK[0], LOOK[1], LOOK[2], LOOK[3])


func set_layer(on: bool) -> void:
	if on == layer:
		return
	_release_held()
	layer = on
	if on:
		for a in LAYER:
			var ev := _event_of(LAYER[a])
			for b in InputMap.get_actions():
				if str(b).begins_with("ui_") or LAYER.has(b):
					continue
				for e in InputMap.action_get_events(b):
					if _same(e, ev):
						InputMap.action_erase_event(b, e)
						_taken.append([b, e])
			InputMap.action_add_event(a, ev)
			_added.append([a, ev])
	else:
		for pair in _added:
			InputMap.action_erase_event(pair[0], pair[1])
		for pair in _taken:
			InputMap.action_add_event(pair[0], pair[1])
		_added.clear()
		_taken.clear()


## Let go of what the swapped inputs still held are pressing in the layer that's going away.
func _release_held() -> void:
	for a in LAYER:
		var spec = LAYER[a]
		if not _held(spec):
			continue
		var ev := _event_of(spec)
		for b in InputMap.get_actions():
			if str(b).begins_with("ui_") or not Input.is_action_pressed(b):
				continue
			for e in InputMap.action_get_events(b):
				if _same(e, ev):
					Input.action_release(b)
					break


func _held(spec) -> bool:
	if spec is Array:
		return float(_axis.get(spec[0], 0.0)) * float(spec[1]) > 0.5
	if _down.get(spec, false):
		return true
	for d in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(d, spec):
			return true
	return false


static func _event_of(spec) -> InputEvent:
	if spec is Array:
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = spec[0]
		m.axis_value = spec[1]
		return m
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = spec
	b.pressed = true
	return b


static func _same(e: InputEvent, ev: InputEvent) -> bool:
	if e is InputEventJoypadButton and ev is InputEventJoypadButton:
		return (e as InputEventJoypadButton).button_index == (ev as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion and ev is InputEventJoypadMotion:
		var a := e as InputEventJoypadMotion
		var b := ev as InputEventJoypadMotion
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false
