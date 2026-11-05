extends CanvasLayer
## (1.31) The pad's pointer in menus (Pad.cursor, kept the root's last child so its _input sees pad events
## first). While a screen that takes the mouse is open (menu_open) and the pad was used last, the left stick
## moves a ring like a mouse and it feeds real mouse events (device Pad.CURSOR_DEVICE), so every custom-drawn
## screen, hover and drag works unchanged: A is the left button (hold to drag), X the right, the right stick
## the wheel. The left stick's own events are eaten in menus (they'd step Control focus too).
## Modes: AUTO (a screen's opened: the ring shows unless a button or slider has focus, which A then presses),
## CURSOR (the stick moved: the ring shows and owns A and X), NAV (the d-pad was pressed: focus steps, the
## ring hides). The mouse or a key hides it (Pad.using_pad). Played, the OS pointer follows it (warp) and
## hides under it; a test or tool never moves or hides the real mouse.

enum { AUTO, CURSOR, NAV }

const DEADZONE := 0.18
## Canvas px/s just past the deadzone and at full tilt, the curve between, and the pace over a button.
const SLOW := 60.0
const FAST := 860.0
const CURVE := 2.4
const OVER_BUTTON := 0.55
## Seconds between wheel notches, the right stick barely pushed and full.
const SCROLL_SLOW := 0.3
const SCROLL_FAST := 0.05
const BUTTONS := {JOY_BUTTON_A: MOUSE_BUTTON_LEFT, JOY_BUTTON_X: MOUSE_BUTTON_RIGHT}
const DPAD := [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]
## The ring's radius in canvas pixels (whole window pixels x the UI scale).
const R := 7
const LIGHT := Color("f4ecd2")
const DARK := Color("1a1410")
const HOT := Color("f2c45e")

## Where the pointer is, in the root's canvas (960x540 at 16:9).
var pos := Vector2(480, 270)
var shown := false
var active := false
var mode := AUTO
var _age := 0
var _held := {}
var _press := 0.0
var _hot := false
var _scroll_t := 0.0
var _warped := Vector2(-1e9, -1e9)
var _ring: Node2D
var _rings := {}


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring = Node2D.new()
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	for r in [R, R - 1]:
		_rings[r] = _ring_pixels(r)


## A screen that takes the mouse is up (not gameplay, a conversation, a wheel or the cooking game).
func menu_open() -> bool:
	if Dialogue.active or ChatBox.typing or RadialWheel.shown != null:
		return false
	if GameMenu.is_open():
		return GameMenu.screen() != "cook"
	if CharacterCreator.active or Journal.is_open() or get_tree().get_first_node_in_group("title_screen") != null:
		return true
	for m in get_tree().get_nodes_in_group("pad_menus"):
		if m.is_open():
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.device != Pad.CURSOR_DEVICE and event is InputEventMouseMotion and (event as InputEventMouseMotion).position.distance_to(_warped) < 1.5:
			get_viewport().set_input_as_handled()
			return
	Pad.seen(event)
	if event is InputEventMouse:
		return
	if not active:
		return
	if event is InputEventJoypadMotion:
		if (event as InputEventJoypadMotion).axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			Pad.note(event)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventJoypadButton:
		return
	var jb := event as InputEventJoypadButton
	if jb.button_index in DPAD and jb.pressed:
		mode = NAV
	elif BUTTONS.has(jb.button_index) and (shown or (not jb.pressed and _held.has(jb.button_index))):
		Pad.note(event)
		Pad.swallow(event)
		get_viewport().set_input_as_handled()
		if jb.pressed != _held.has(jb.button_index):
			_button(jb.button_index, jb.pressed)


func _process(delta: float) -> void:
	var want := Pad.using_pad and menu_open()
	if want != active:
		active = want
		mode = AUTO
		_age = 0
		if not want:
			_let_go()
	if not active:
		_show(false)
		return
	_age += 1
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child(self, -1)
	var dt := delta / maxf(Engine.time_scale, 0.05)
	var v := Vector2(Pad.axis_of(JOY_AXIS_LEFT_X), Pad.axis_of(JOY_AXIS_LEFT_Y))
	var hot := _over_button()
	if v.length() > DEADZONE:
		mode = CURSOR
		var t := clampf((v.length() - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		_move(v.normalized() * lerpf(SLOW, FAST, pow(t, CURVE)) * (OVER_BUTTON if hot else 1.0) * dt)
	_show(mode == CURSOR or (mode == AUTO and _age > 2 and not _focus_nav()))
	if shown:
		_scroll(Pad.axis_of(JOY_AXIS_RIGHT_Y), dt)
	var press := 1.0 if not _held.is_empty() else maxf(_press - dt * 8.0, 0.0)
	if hot != _hot or press != _press:
		_hot = hot
		_press = press
		_ring.queue_redraw()
	_place()


func _show(on: bool) -> void:
	if on == shown:
		return
	shown = on
	_ring.visible = on
	if on:
		_move(Vector2.ZERO, true)
	else:
		_let_go()
	if Settings.tool_run():
		return
	if on and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_warp()
	elif not on and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Put the pointer at `p` (root canvas) as the stick would (a render, a test).
func point_at(p: Vector2) -> void:
	_move(p - pos, true)


## `always`: a motion event even standing still (on show, so hover is where the ring is).
func _move(by: Vector2, always := false) -> void:
	var was := pos
	pos = (pos + by).clamp(Vector2.ZERO, get_tree().root.get_visible_rect().size - Vector2.ONE)
	if pos == was and not always:
		return
	var xf := get_tree().root.get_final_transform()
	var e := InputEventMouseMotion.new()
	_fill(e)
	e.relative = xf.basis_xform(pos - was)
	e.screen_relative = e.relative
	e.velocity = e.relative / maxf(get_process_delta_time(), 0.001)
	e.screen_velocity = e.velocity
	Input.parse_input_event(e)
	_warp()


## A pad button down or up as its mouse button.
func _button(jb: int, down: bool) -> void:
	if down:
		_held[jb] = true
		_press = 1.0
		_ring.queue_redraw()
	else:
		_held.erase(jb)
	var e := InputEventMouseButton.new()
	_fill(e)
	e.button_index = BUTTONS[jb]
	e.pressed = down
	Input.parse_input_event(e)


func _let_go() -> void:
	for jb in _held.keys():
		_button(jb, false)


func _scroll(y: float, dt: float) -> void:
	if absf(y) < DEADZONE or (GameMenu.is_open() and GameMenu.screen() == "skills"):
		_scroll_t = 0.0
		return
	_scroll_t -= dt
	if _scroll_t > 0.0:
		return
	_scroll_t = lerpf(SCROLL_SLOW, SCROLL_FAST, clampf((absf(y) - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0))
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		_fill(e)
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN if y > 0.0 else MOUSE_BUTTON_WHEEL_UP
		e.factor = 1.0
		e.pressed = down
		Input.parse_input_event(e)


func _fill(e: InputEventMouse) -> void:
	e.device = Pad.CURSOR_DEVICE
	e.position = get_tree().root.get_final_transform() * pos
	e.global_position = e.position
	var mask := 0
	for jb in _held.keys():
		mask |= 1 << (BUTTONS[jb] - 1)
	e.button_mask = mask


## Played: the OS pointer goes where the ring is (its motion echo is eaten in _input).
func _warp() -> void:
	if Settings.tool_run() or not shown:
		return
	_warped = (get_tree().root.get_final_transform() * pos).round()
	get_tree().root.warp_mouse(pos)


## A button or slider has focus in a screen on show (the d-pad and A work it).
func _focus_nav() -> bool:
	for vp in _viewports():
		var f: Control = vp.gui_get_focus_owner()
		if f and f.is_visible_in_tree() and (f is BaseButton or f is Range or f is LineEdit):
			return true
	return false


func _over_button() -> bool:
	if not shown:
		return false
	for vp in _viewports():
		var h: Control = vp.gui_get_hovered_control()
		if h and h is BaseButton and not (h as BaseButton).disabled:
			return true
	return false


func _viewports() -> Array:
	var out: Array = [get_tree().root]
	for pc in get_tree().get_nodes_in_group("pixel_canvas"):
		if pc.is_visible_in_tree():
			out.append(pc.viewport())
	return out


## Crisp at the UI scale: the ring's pixels are whole window pixels x k, its centre on that grid.
func _place() -> void:
	var win := get_tree().root
	var cs := float(win.size.y) / maxf(win.get_visible_rect().size.y, 1.0)
	var k := float(maxi(1, floori(win.size.y / 540.0)))
	var at := ((pos * cs) / k).floor() * k
	offset = at / cs
	scale = Vector2.ONE * (k / cs)


static func _ring_pixels(r: int) -> Array:
	var light := PackedVector2Array()
	var dark := PackedVector2Array()
	for y in range(-r - 3, r + 3):
		for x in range(-r - 3, r + 3):
			var d := absf(Vector2(x + 0.5, y + 0.5).length() - r)
			if d < 0.75:
				light.append(Vector2(x, y))
			elif d < 1.7:
				dark.append(Vector2(x, y))
	return [dark, light]


func _draw_ring() -> void:
	var px: Array = _rings[R - 1 if _press > 0.0 else R]
	for p in px[0]:
		_ring.draw_rect(Rect2(p, Vector2.ONE), DARK)
	for p in px[1]:
		_ring.draw_rect(Rect2(p, Vector2.ONE), LIGHT)
	_ring.draw_rect(Rect2(-2, -2, 4, 4), DARK)
	_ring.draw_rect(Rect2(-1, -1, 2, 2), HOT if _press > 0.0 or _hot else LIGHT)
