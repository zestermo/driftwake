extends Control
## The pad's skill list (the HUD's bottom-left corner, only while the pad is the device in use): which skill
## is on which button of the LB layer, as words, no pictures. "HOLD LB" over a line a skill ("X  SORU" ...),
## empty slots left out. Dim while you play, bright while LB is held, and a line lights while its button is
## down. Buttons come from Pad.LAYER, so the list can't drift from the real bindings. Setting:
## gameplay.pad_skills. It redraws only when what it shows changes.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const FS := 8
const LINE := 9.0
## The rows: the layer's actions in button order, and each one's loadout slot.
const ROWS := [["skill_1", 0], ["skill_2", 1], ["skill_3", 2], ["skill_4", 3], ["skill_5", 5], ["ultimate", 4]]
const W := 150.0
const H := LINE * 7.0 + 2.0   # "HOLD LB" and the six rows
## How bright it sits while you play (LB held: full).
const IDLE := 0.6
## The loadout is looked at this often (s, real time); a change redraws.
const LOOK_EVERY := 0.5

var _k := 0.0
var _last := -1
var _lines: Array = []
var _look := 0.0


func _ready() -> void:
	name = "PadSkills"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the bottom-left corner: under the co-op chat (from -106 up), left of the health orb
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 8.0
	offset_right = offset_left + W
	offset_bottom = -5.0
	offset_top = offset_bottom - H
	visible = false


func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05)
	_look -= rd
	if _look <= 0.0:
		_look = LOOK_EVERY
		_lines = lines()
	var want := Pad.using_pad and bool(Settings.get_value("gameplay", "pad_skills")) and not _lines.is_empty()
	_k = move_toward(_k, 1.0 if want else 0.0, rd * 6.0)
	visible = _k > 0.0
	if not visible:
		return
	modulate.a = _k * (1.0 if Pad.layer else IDLE)
	var s := _state()
	if s != _last:
		_last = s
		queue_redraw()


## [button, skill name, action] for each equipped slot, in button order.
func lines() -> Array:
	var out := []
	var p := get_tree().get_first_node_in_group("player")
	if p == null or p.get("power") == null:
		return out
	for r in ROWS:
		var id := ""
		if int(r[1]) < p.power.loadout.size():
			id = p.power.loadout[int(r[1])]
		if id != "":
			out.append([Glyphs.name_of(Pad.LAYER[r[0]]), str(Skills.get_skill(id).get("name", id)).to_upper(), r[0]])
	return out


## The list, the layer and which lines are lit, as one number.
func _state() -> int:
	var h := (1 if Pad.layer else 0) + 2 * hash(_lines)
	for i in range(_lines.size()):
		if Pad.layer and Input.is_action_pressed(_lines[i][2]):
			h ^= 1 << (i + 1)
	return h


func _draw() -> void:
	var y := LINE
	_text(Vector2(0, y), "HOLD LB", UIStyle.SUN if Pad.layer else UIStyle.TEXT_DIM)
	var bw := FONT.get_string_size("RB  ", HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	for l in _lines:
		y += LINE
		var lit: bool = Pad.layer and Input.is_action_pressed(l[2])
		_text(Vector2(0, y), l[0], UIStyle.SUN)
		_text(Vector2(bw, y), l[1], UIStyle.SUN if lit else UIStyle.CREAM)


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string_outline(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, 2, UIStyle.OUTLINE)
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, c)
