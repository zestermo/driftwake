extends Control
## The cooking game (GameMenu screen "cook", GameMenu.open_cook_game): the menu steps aside and the camera
## goes to the captain's eyes over a counter (CookScene) while CookTiming runs the beats. F, Space or a click
## presses; Esc gives up (nothing cooked, nothing used: GameMenu.give_up). This screen draws the words over it: the beat and
## what to do, each press's call-out, the pan's heat bar with its gold band, the beats' marks along the
## bottom and the grade at the end, then `done(quality, grade)` and back to where it was opened from.

const RESULT_SECS := 1.6
const HOW := {"stir": "STIR: press as the spoon passes the glint (3 times)",
	"flip": "FLIP: press when the heat's in the gold band",
	"plate": "PLATE: press when the plate's under the dish"}
const BEAT_NAMES := {"stir": "Stir", "flip": "Flip", "plate": "Plate"}

var _menu: Node
var timing: CookTiming
var scene: CookScene
var _done: Callable
var _back := ""
var _title: Label
var _how: Label
var _call: Label
var _grade: Label
var _call_t := 0.0
var _end_t := -1.0


func _init(menu: Node) -> void:
	_menu = menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (the canvas is the PixelCanvas's, 640x360 at 720p: rows are placed by fractions of its height)
	_title = _row(UIStyle.title(""), 0.04)
	_how = _row(UIStyle.label("", 12, UIStyle.TEXT), 0.11)
	_grade = _row(UIStyle.title("", 30), 0.4)
	_call = _row(UIStyle.title("", 22), 0.72)
	_row(UIStyle.label("F / Space / Click: press     Esc: stop", 8, UIStyle.TEXT_DIM), 0.95)


## A centred line across the screen at `y` of its height.
func _row(l: Label, y: float) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = y
	l.anchor_bottom = y
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(l)
	return l


## The heat bar: at the right, a third of the screen tall.
func _bar() -> Rect2:
	return Rect2(size.x * 0.86, size.y * 0.3, 16, size.y * 0.42)


## Start a game for the local captain: `meal_id` sets the dish's colours, `back` the screen to return to
## ("" closes the menu), `done` gets (quality, grade) once it's over.
func start(title: String, meal_id: String, done: Callable, opts: Dictionary, back: String) -> void:
	timing = CookTiming.new(opts)
	_done = done
	_back = back
	_end_t = -1.0
	_call.text = ""
	_grade.text = ""
	_title.text = title
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if scene:
		scene.leave()
	scene = CookScene.make(p, meal_id) if p else null
	if scene:
		scene.timing = timing
	UIStyle.sfx("sizzle")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or timing == null:
		return
	var hit: bool = event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not hit or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	press()


## A press (tests call it too).
func press() -> void:
	if timing.done():
		return
	var beat := timing.current()
	var px := timing.plate_x()
	var s := timing.press()
	if s < 0.0:
		return
	if scene:
		scene.pressed(beat, s, px)
	_shout(s)


func _shout(s: float) -> void:
	_call.text = CookTiming.call_out(s)
	_call.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if s >= 0.95 else (Color(0.6, 0.95, 0.5) if s >= 0.6 else Color(0.95, 0.5, 0.4)))
	_call_t = 0.8
	UIStyle.sfx("confirm" if s >= 0.6 else "deny")


func _process(delta: float) -> void:
	if timing == null or not is_visible_in_tree():
		return
	var n := timing.scores.size() + timing.stir_hits.size()
	timing.tick(delta)
	# a beat that ran out without a press
	if timing.scores.size() + timing.stir_hits.size() > n and timing.last.size() == 2 and _call_t <= 0.0:
		_shout(float(timing.last[1]))
	_call_t = maxf(_call_t - delta, 0.0)
	if _call_t <= 0.0:
		_call.text = ""
	_how.text = HOW.get(timing.current(), "")
	if timing.done():
		if _end_t < 0.0:
			_end_t = RESULT_SECS
			var g := CookTiming.grade_of(timing.quality())
			_grade.text = CookTiming.GRADE_NAMES[g]
			_grade.add_theme_color_override("font_color", ItemData.RARITY_COLORS[g])
			UIStyle.sfx("level_up" if g == 3 else ("confirm" if g >= 1 else "deny"))
		_end_t -= delta
		if _end_t <= 0.0:
			_finish(true)
	queue_redraw()


## Esc (GameMenu sees it first): stop, nothing cooked, back where it came from.
func give_up() -> void:
	if timing != null:
		_finish(false)


## The menu closed under it: just the set cleared away and the camera back.
func clear() -> void:
	timing = null
	if scene:
		scene.leave()
		scene = null


## Over: the set cleared away, `done` told (only when it finished), back to the screen it came from.
func _finish(finished: bool) -> void:
	var t := timing
	clear()
	if _back != "":
		_menu.open(_back)
	else:
		_menu.close()
	if finished and _done.is_valid():
		var q := t.quality()
		_done.call(q, CookTiming.grade_of(q))


func _draw() -> void:
	if timing == null:
		return
	# the beats along the bottom: done ones show their grade's colour
	var beats := timing.beats
	var w := 70.0
	var x0 := size.x * 0.5 - w * beats.size() * 0.5
	for i in range(beats.size()):
		var r := Rect2(x0 + i * w + 4, size.y * 0.84, w - 8, 20)
		var on := i == timing.beat
		var col := UIStyle.BG
		if i < timing.scores.size():
			col = ItemData.RARITY_COLORS[CookTiming.grade_of(float(timing.scores[i]))].darkened(0.35)
		draw_rect(r, col)
		draw_rect(r, UIStyle.ACCENT if on else UIStyle.BORDER, false, 2.0 if on else 1.0)
		var label := str(BEAT_NAMES[beats[i]])
		if beats[i] == "stir" and on:
			label += " %d/%d" % [timing.stir_hits.size(), CookTiming.STIR_PRESSES]
		draw_string(get_theme_default_font(), r.position + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, UIStyle.TEXT)
	# the heat bar while flipping: the gold band, the cold line, the level
	if timing.current() == "flip":
		var bar := _bar()
		draw_rect(bar.grow(2), UIStyle.BORDER)
		draw_rect(bar, Color(0.1, 0.08, 0.07))
		var band := CookTiming.FLIP_BAND
		draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * band.y, bar.size.x, bar.size.y * (band.y - band.x)), Color(1.0, 0.8, 0.25, 0.85))
		var cold_y := bar.end.y - bar.size.y * CookTiming.FLIP_COLD
		draw_line(Vector2(bar.position.x - 4, cold_y), Vector2(bar.end.x + 4, cold_y), Color(0.5, 0.7, 1.0), 1.0)
		var h := clampf(timing.heat(), 0.0, 1.0)
		draw_rect(Rect2(bar.position.x + 3, bar.end.y - bar.size.y * h, bar.size.x - 6, bar.size.y * h), Color(1.0, 0.35, 0.1).lerp(Color(1.0, 0.95, 0.6), h))
		draw_string(get_theme_default_font(), bar.position + Vector2(-16, -6), "HEAT", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x + 32, 8, UIStyle.TEXT)
