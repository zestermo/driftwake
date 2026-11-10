class_name Keybinds
## (1.30.1) The keyboard and mouse bindings a player can change (Options > Controls). Pad bindings stay as they are.
## The InputMap holds the live bindings; Settings' "keys" section keeps only the actions that differ from
## project.godot's (action -> ["k<physical keycode>" / "m<mouse button>", ...]), applied on start (Settings._ready).

const GROUPS := [
	["Movement", [["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
		["move_right", "Move right"], ["sprint", "Sprint"], ["jump", "Jump / double jump"], ["dodge", "Dodge roll"],
		["crouch", "Sneak / crew technique"]]],
	["Combat", [["ready_weapon", "Ready / sheathe"], ["light_attack", "Light attack"],
		["heavy_attack", "Heavy attack"], ["parry", "Parry / block"], ["loadout", "Swap loadout"],
		["quick_item", "Eat / drink (hold: food and gadgets)"]]],
	["Abilities", [["skill_1", "Skill 1"], ["skill_2", "Skill 2"], ["skill_3", "Skill 3"], ["skill_4", "Skill 4"],
		["skill_5", "Skill 5"], ["ultimate", "Ultimate"], ["transform", "Zoan: shift form"],
		["gadget_fire", "Use gadget"], ["gadget_cycle", "Next gadget"]]],
	["Interface", [["interact", "Interact / talk"], ["inventory", "Inventory"], ["skill_map", "Skill map"],
		["sea_chart", "Map"], ["action_wheel", "Action wheel"], ["emote", "Emote wheel"],
		["log_pose", "Read the lodestone"], ["lantern", "Belt lantern"], ["summon_ship", "Summon your ship"],
		["ping_marker", "Ping a marker"], ["chat", "Crew chat (co-op)"]]],
]

## Mouse buttons a binding may use (the wheel zooms the camera).
const MOUSE_OK := [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

static var _defaults := {}
## Whether sprint is on Shift (Player._input lets go of a stuck sprint by Shift's state only then).
static var sprint_shift := true


static func actions() -> Array:
	var out := []
	for g in GROUPS:
		for row in g[1]:
			out.append(row[0])
	return out


static func label_of(action: String) -> String:
	for g in GROUPS:
		for row in g[1]:
			if row[0] == action:
				return row[1]
	return action


static func _kb(e: InputEvent) -> bool:
	return e is InputEventKey or e is InputEventMouseButton


static func events(action: String) -> Array:
	return InputMap.action_get_events(action).filter(_kb)


static func _capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for a in actions():
		_defaults[a] = events(a).map(encode)


static func encode(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		return "m%d" % (e as InputEventMouseButton).button_index
	var k := e as InputEventKey
	return "k%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)


static func decode(code: String) -> InputEvent:
	if code.begins_with("m"):
		var m := InputEventMouseButton.new()
		m.button_index = int(code.substr(1)) as MouseButton
		m.pressed = true
		return m
	var k := InputEventKey.new()
	k.physical_keycode = int(code.substr(1)) as Key
	return k


## A pressed key or mouse button the player may bind, as a fresh event (null: not one).
static func bindable(e: InputEvent) -> InputEvent:
	if e is InputEventKey and e.pressed and not e.echo:
		var code: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		if code == KEY_ESCAPE or code == KEY_NONE or (code >= KEY_F1 and code <= KEY_F12):
			return null
		return decode("k%d" % code)
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index in MOUSE_OK:
		return decode("m%d" % (e as InputEventMouseButton).button_index)
	return null


static func _put(action: String, codes: Array) -> void:
	var pads := InputMap.action_get_events(action).filter(func(e): return not _kb(e))
	InputMap.action_erase_events(action)
	for c in codes:
		InputMap.action_add_event(action, decode(c))
	for e in pads:
		InputMap.action_add_event(action, e)
	if action == "sprint":
		sprint_shift = codes.has("k%d" % KEY_SHIFT)


## The action (other than `except`) that `code` is bound to, or "".
static func owner_of(code: String, except: String) -> String:
	for a in actions():
		if a != except and events(a).map(encode).has(code):
			return a
	return ""


## Bind `action` to `e` alone; the action that had it takes `action`'s old key instead. Returns that action ("": none).
static func bind(action: String, e: InputEvent) -> String:
	_capture_defaults()
	var code := encode(e)
	var old: Array = events(action).map(encode)
	var other := owner_of(code, action)
	if other != "":
		var theirs: Array = events(other).map(encode)
		var i := theirs.find(code)
		if old.is_empty() or theirs.has(old[0]):
			theirs.remove_at(i)
		else:
			theirs[i] = old[0]
		_put(other, theirs)
	_put(action, [code])
	return other


static func reset() -> void:
	_capture_defaults()
	for a in actions():
		_put(a, _defaults[a])


## Settings' saved overrides onto the InputMap (on start, and a reload).
static func apply(saved: Dictionary) -> void:
	_capture_defaults()
	reset()
	for a in saved.keys():
		if _defaults.has(a):
			_put(a, Array(saved[a]))


## What differs from the defaults, for Settings' "keys" section.
static func overrides() -> Dictionary:
	_capture_defaults()
	var out := {}
	for a in actions():
		var now: Array = events(a).map(encode)
		if now != _defaults[a]:
			out[a] = now
	return out


## The action's keys for the page: "Tab / I".
static func keys_text(action: String) -> String:
	var names := events(action).map(Glyphs.event_name)
	return " / ".join(names) if not names.is_empty() else "-"
