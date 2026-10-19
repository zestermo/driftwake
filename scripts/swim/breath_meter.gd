extends Control
## The breath meter (HUD): a row of bubbles over the skill bar while you hold your breath on a dive or
## it's coming back. Each bubble is a tenth of your breath; the last one shrinks as it goes. At a third
## left they turn amber and pulse; empty, the row flashes red with "SURFACE!" and the screen's edges
## pulse red with every hurt (SwimState.gasping). In cold water "FREEZING" shows over it.

const BUBBLES := 10
const R := 4.0
const GAP := 11.0
## The row's middle, up from the bottom of the 800x450 canvas (over the skill bar).
const LIFT := 86.0
const FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const FULL := Color(0.72, 0.92, 1.0)
const LOW := Color(1.0, 0.68, 0.25)
const EMPTY := Color(1.0, 0.25, 0.2)

var _swim: Node
var _player: Node
var _shown := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func _process(delta: float) -> void:
	_t += delta
	if _swim == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
		_swim = _player.get_node("StateMachine/Swim")
	var frac := _frac()
	var swimming: bool = _player.current_state_name() == "Swim"
	var want := 1.0 if swimming and (frac < 0.999 or float(_swim.cold) > 0.3) else 0.0
	_shown = move_toward(_shown, want, delta * (4.0 if want > _shown else 1.2))
	visible = _shown > 0.0
	if visible:
		queue_redraw()


func _frac() -> float:
	return clampf(float(_swim.breath) / maxf(float(_swim.breath_max()), 0.01), 0.0, 1.0)


func _draw() -> void:
	var frac := _frac()
	var gasping: bool = _swim.gasping
	var a := _shown
	if gasping:
		_vignette(0.18 + 0.14 * absf(sin(_t * 5.0)))
	var c := Vector2(size.x * 0.5, size.y - LIFT)
	if float(_swim.cold) > 0.3:
		_text(c + Vector2(-60.0, -9.0 if frac >= 0.999 else -19.0), "FREEZING", Color(0.7, 0.88, 1.0, a * (0.75 + 0.25 * sin(_t * 3.0))), 120.0)
	if frac >= 0.999:
		return
	var x0 := c.x - (BUBBLES - 1) * GAP * 0.5
	var col := FULL
	if frac <= 0.3:
		col = LOW.lerp(EMPTY, 1.0 - frac / 0.3)
	var pulse := 1.0 if frac > 0.3 else 0.7 + 0.3 * absf(sin(_t * (6.0 if frac > 0.0 else 10.0)))
	for i in range(BUBBLES):
		var p := Vector2(x0 + i * GAP, c.y)
		var fill := clampf(frac * BUBBLES - i, 0.0, 1.0)
		draw_circle(p, R + 1.5, Color(0, 0, 0, 0.55 * a))
		if fill <= 0.0:
			draw_arc(p, R, 0.0, TAU, 12, Color(col.r, col.g, col.b, 0.35 * a), 1.0)
			continue
		var r := R * (0.45 + 0.55 * fill)
		draw_circle(p, r, Color(col.r * 0.55, col.g * 0.7, col.b * 0.8, 0.9 * a * pulse))
		draw_arc(p, r, 0.0, TAU, 12, Color(col.r, col.g, col.b, a * pulse), 1.0)
		draw_rect(Rect2(p + Vector2(-r * 0.5, -r * 0.55), Vector2(1, 1)), Color(1, 1, 1, 0.9 * a))
	if gasping and int(_t * 4.0) % 2 == 0:
		_text(c + Vector2(-60.0, -9.0), "SURFACE!", EMPTY, 120.0)


func _text(pos: Vector2, s: String, col: Color, w: float) -> void:
	draw_string_outline(FONT, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, 8, 3, Color(0, 0, 0, 0.9))
	draw_string(FONT, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, 8, col)


## Red in from the screen's edges (out of breath: every hurt pulses it).
func _vignette(k: float) -> void:
	var bands := 6
	for i in range(bands):
		var t := float(i) / bands
		var w := 34.0 * (1.0 - t)
		var col := Color(0.55, 0.0, 0.02, k * (1.0 - t) * 0.5)
		draw_rect(Rect2(0, 0, size.x, w), col)
		draw_rect(Rect2(0, size.y - w, size.x, w), col)
		draw_rect(Rect2(0, 0, w, size.y), col)
		draw_rect(Rect2(size.x - w, 0, w, size.y), col)
