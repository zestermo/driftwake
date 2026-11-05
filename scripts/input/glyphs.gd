class_name Glyphs
## What to call an action's button in a prompt, for the device in use (Pad.using_pad; Pad.device_changed says
## when it flips): "Space" / "Left click" / "F" on the keyboard and mouse (from the InputMap, so the web's
## C-for-dodge shows right), "A" / "RB" / "LB+X" on an Xbox pad (Pad.base and Pad.LAYER).
## A few pseudo-actions name the sticks: "move", "look", "sprint" (Pad's L3 latch, not in the InputMap).

const BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const AXES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
	JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick", JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick"}
const MOUSE := {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click", MOUSE_BUTTON_MIDDLE: "Middle click",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4", MOUSE_BUTTON_XBUTTON2: "Mouse 5"}
const SHORT_MOUSE := {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB", MOUSE_BUTTON_MIDDLE: "MMB",
	MOUSE_BUTTON_XBUTTON1: "M4", MOUSE_BUTTON_XBUTTON2: "M5"}
const KEYS_PSEUDO := {"move": "W A S D", "look": "Mouse"}
const PAD_PSEUDO := {"move": "Left stick", "look": "Right stick", "sprint": "L3"}


static func pad() -> bool:
	var p = Engine.get_main_loop().root.get_node_or_null("Pad") if Engine.get_main_loop() is SceneTree else null
	return p != null and p.using_pad


## The action's button for the device in use.
static func of(action: String) -> String:
	return pad_of(action) if pad() else key_of(action)


## "<button>: <what>" for the device in use.
static func hint(action: String, what: String) -> String:
	return "%s: %s" % [of(action), what]


static func key_of(action: String) -> String:
	if KEYS_PSEUDO.has(action):
		return KEYS_PSEUDO[action]
	if not InputMap.has_action(action):
		return "?"
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			return event_name(e)
	return "?"


## The action's first key or mouse button in a few letters, for a small key cap ("LMB", "Ctrl", "5").
static func short_of(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton:
			return SHORT_MOUSE.get((e as InputEventMouseButton).button_index, "M")
		if e is InputEventKey:
			return event_name(e)
	return "?"


## A key's name on this keyboard's layout (a headless run has no layout: the US name), or a mouse button's.
static func event_name(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		return MOUSE.get((e as InputEventMouseButton).button_index, "Mouse")
	var k := e as InputEventKey
	var code := k.keycode
	if code == KEY_NONE:
		code = k.physical_keycode if DisplayServer.get_name() == "headless" \
			else DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
	return OS.get_keycode_string(code)


## A prompt's text with "{action}" turned into that action's button for the device in use.
static func fill(text: String) -> String:
	var out := text
	var at := out.find("{")
	while at != -1:
		var end := out.find("}", at)
		if end == -1:
			break
		var a := out.substr(at + 1, end - at - 1)
		var name_ := of(a) if InputMap.has_action(a) or KEYS_PSEUDO.has(a) else "{" + a + "}"
		out = out.substr(0, at) + name_ + out.substr(end + 1)
		at = out.find("{", at + name_.length())
	return out


static func pad_of(action: String) -> String:
	if PAD_PSEUDO.has(action):
		return PAD_PSEUDO[action]
	var p = Engine.get_main_loop().root.get_node_or_null("Pad") if Engine.get_main_loop() is SceneTree else null
	if p == null:
		return "?"
	if p.LAYER.has(action):
		return "LB+" + name_of(p.LAYER[action])
	if p.base.has(action):
		return name_of(p.base[action])
	return "-"


## A pad input's name: a button index, or [axis, sign].
static func name_of(spec) -> String:
	if spec is Array:
		return AXES.get(int(spec[0]), "Stick")
	return BUTTONS.get(int(spec), "?")
