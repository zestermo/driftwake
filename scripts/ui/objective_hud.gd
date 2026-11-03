class_name ObjectiveHud
extends Control
## What you're following, top left in a gold-rimmed box: the quest you track in the crew journal (Journal.tracked),
## else the chain's next step (ChainGoal: the story while it's on, then the next island, its trouble, its beast), so
## it's never blank. A head (what it is, how far), the goal, a dim line under it, and a gold marker over who or where
## (pinned to the screen's edge when it's off screen, gone once you're there). It flashes when it changes.

## Close enough: the marker goes (an NPC you can talk to, a fight you're in).
const NPC_NEAR := 3.5
const PLACE_NEAR := 22.0
const EDGE := 16.0
const GOLD := Color(1.0, 0.82, 0.3)
const MARK := "quest"
const W := 216.0
const BOLD := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")

## (set while a menu's open: the HUD is paused then, so it hides now)
var hidden_by_menu: bool = false:
	set(v):
		hidden_by_menu = v
		if _box and v:
			_box.visible = false
			_pin.visible = false
## The box and, under it, the pinned news card (1.30): important news stays there until you open the log (J).
var _stack: VBoxContainer
var _box: PanelContainer
var _pin: PanelContainer
var _pin_head: Label
var _pin_title: Label
var _pin_text: Label
var _head: Label
var _dist: Label
var _goal: Label
var _sub: Label
var _district: Label
var _flash: float = 0.0
var _t: float = 0.0
var _poll: float = 0.0
var _font: Font
var _player: Player
## What's shown: {"kind": "quest" / "story" / "chain", "goal", "sub", "who", "head", "id", "pos", "person"} ({} for nothing).
var _obj := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_stack = VBoxContainer.new()
	_stack.position = Vector2(6, 4)
	_stack.add_theme_constant_override("separation", 3)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	_box = PanelContainer.new()
	_box.custom_minimum_size = Vector2(W, 0)
	_box.add_theme_stylebox_override("panel", _frame(GOLD))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_box)
	_build_pin()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(vb)
	# (the stronghold's districts: what to do in the one you stand in)
	_district = _small_label(UIStyle.CORAL)
	_district.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_district.custom_minimum_size = Vector2(W - 10.0, 0)
	_district.visible = false
	vb.add_child(_district)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	_head = _small_label(GOLD)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head.clip_text = true
	row.add_child(_head)
	_dist = _small_label(GOLD)
	row.add_child(_dist)
	_goal = UIStyle.label("", 12, UIStyle.TEXT)
	_goal.add_theme_font_override("font", BOLD)
	_goal.add_theme_constant_override("line_spacing", -4)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.custom_minimum_size = Vector2(W - 10.0, 0)
	vb.add_child(_goal)
	_sub = _small_label(UIStyle.TEXT_DIM)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(W - 10.0, 0)
	vb.add_child(_sub)
	Story.changed.connect(_refresh)
	Journal.changed.connect(_on_journal)
	Journal.news_changed.connect(_refresh_pin)
	_refresh()
	_refresh_pin()


func _build_pin() -> void:
	_pin = PanelContainer.new()
	_pin.custom_minimum_size = Vector2(W, 0)
	var sb := _frame(UIStyle.CORAL)
	sb.bg_color = UIStyle.CREAM
	_pin.add_theme_stylebox_override("panel", sb)
	_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin.visible = false
	_stack.add_child(_pin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin.add_child(vb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	_pin_head = _small_label(UIStyle.CORAL)
	_pin_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pin_head.clip_text = true
	row.add_child(_pin_head)
	row.add_child(_small_label(UIStyle.CORAL))
	(row.get_child(1) as Label).text = "J TO OPEN"
	_pin_title = UIStyle.label("", 12, UIStyle.PARCH_INK)
	_pin_title.add_theme_font_override("font", BOLD)
	_pin_title.add_theme_constant_override("line_spacing", -4)
	_pin_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pin_title.custom_minimum_size = Vector2(W - 10.0, 0)
	vb.add_child(_pin_title)
	_pin_text = _small_label(UIStyle.PARCH_DIM)
	_pin_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pin_text.custom_minimum_size = Vector2(W - 10.0, 0)
	vb.add_child(_pin_text)


## The newest pinned news on the card ("+2 MORE" when there are others), none once the log's been opened.
func _refresh_pin() -> void:
	var ps: Array = Journal.pinned()
	if ps.is_empty():
		_pin_title.text = ""
		return
	var n: Dictionary = ps[-1]
	_pin_head.text = "! PINNED - %s%s" % [str(n["kind"]).to_upper(), " +%d MORE" % (ps.size() - 1) if ps.size() > 1 else ""]
	_pin_title.text = str(n["title"])
	_pin_text.text = str(n["text"])
	_pin_text.visible = _pin_text.text != ""


static func _frame(rim: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIStyle.BG_DARK, 0.92)
	sb.border_color = rim
	sb.set_border_width_all(2)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	return sb


func _small_label(col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## How tall the tracker is (the HUD moves what's under it down by this).
func tracker_height() -> float:
	return (_box.size.y + 6.0 if _box.visible else 0.0) + (_pin.size.y + 3.0 if _pin.visible else 0.0)


func flash() -> void:
	_flash = 3.0
	_refresh()


func _on_journal() -> void:
	var was: String = _obj.get("goal", "")
	_refresh()
	if _obj.get("kind", "") == "quest" and _obj["goal"] != was:
		_flash = 3.0


func _refresh() -> void:
	var was: String = _obj.get("goal", "")
	_obj = objective()
	_goal.text = str(_obj.get("goal", ""))
	_sub.text = str(_obj.get("sub", ""))
	_sub.visible = _sub.text != ""
	if _obj.get("kind", "") == "chain" and was != "" and _obj["goal"] != was:
		_flash = 3.0


## The tracked quest while it's live, else the chain's next step (the story while it's on).
func objective() -> Dictionary:
	return ChainGoal.followed(get_tree())


func _target() -> Vector3:
	match str(_obj.get("kind", "")):
		"quest":
			return Journal.target(_obj["id"])
		"story":
			return Story.target_pos()
	if _obj.get("id", "") != "":
		return Journal.target(_obj["id"])
	return _obj.get("pos", Vector3.INF)


func _person() -> bool:
	return Journal.target_is_person(_obj["id"]) if _obj.get("kind", "") == "quest" else bool(_obj.get("person", false))


func _wake() -> bool:
	return _player != null and _player.current_state_name() == "Wake"


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		# (how many of a fetch's items you've got, where the chain's step is, and where the mark on the held map goes)
		_poll = 0.25
		_refresh()
		_map_mark()
		_district.text = LineQuests.district_hint(get_tree(), _player.global_position) if _player else ""
		_district.visible = _district.text != ""
	var up := not hidden_by_menu and not _wake() and not Dialogue.active
	_box.visible = not _obj.is_empty() and up
	_pin.visible = _pin_title.text != "" and up
	_flash = maxf(_flash - delta, 0.0)
	var pulse := 0.5 + 0.5 * sin(_flash * 9.0) if _flash > 0.0 else 0.0
	_head.text = ("NEW " if _flash > 0.0 else "* ") + str(_obj.get("head", "OBJECTIVE"))
	_goal.modulate = Color.WHITE.lerp(GOLD, pulse)
	var d := _distance()
	_dist.text = dist_text(d) if d >= 0.0 else ""
	queue_redraw()


static func dist_text(d: float) -> String:
	return "%.1f KM" % (d / 1000.0) if d >= 1000.0 else "%dm" % int(d)


## What's followed, on this screen's held map (MapMarks "quest").
func _map_mark() -> void:
	var t := _target()
	if t == Vector3.INF:
		MapMarks.clear(MARK)
	else:
		MapMarks.put(MARK, t, "quest", str(_obj.get("who", "")))


func _exit_tree() -> void:
	MapMarks.clear(MARK)


func _distance() -> float:
	var t := _target()
	if t == Vector3.INF or _player == null:
		return -1.0
	return Vector2(t.x - _player.global_position.x, t.z - _player.global_position.z).length()


func _draw() -> void:
	if not _box.visible or _player == null:
		return
	var pos := _target()
	var cam := get_tree().root.get_camera_3d()
	if pos == Vector3.INF or cam == null:
		return
	var d := _distance()
	if d < (NPC_NEAR if _person() else PLACE_NEAR):
		return
	var vs := get_viewport_rect().size
	var behind := cam.is_position_behind(pos)
	var sp := PixelCanvas.project(cam, pos, vs)
	if behind:
		sp = vs - sp
	var inside := not behind and Rect2(Vector2(EDGE, EDGE + 30.0), vs - Vector2(EDGE * 2.0, EDGE * 2.0 + 30.0)).has_point(sp)
	var at := sp
	if not inside:
		var mid := vs * 0.5
		var dv := sp - mid
		if dv.length() < 1.0:
			dv = Vector2(0, 1)
		var half := mid - Vector2(EDGE, EDGE)
		at = mid + dv * minf(half.x / maxf(absf(dv.x), 0.001), half.y / maxf(absf(dv.y), 0.001))
	var bob := sin(_t * 5.0) * 2.0 if inside else 0.0
	var p := at + Vector2(0, bob)
	var r := 7.0 + (2.0 if _flash > 0.0 else 0.0)
	var dia := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.8, 0), p + Vector2(0, r), p + Vector2(-r * 0.8, 0)])
	var rim := PackedVector2Array([p + Vector2(0, -r - 2), p + Vector2(r * 0.8 + 2, 0), p + Vector2(0, r + 2), p + Vector2(-r * 0.8 - 2, 0)])
	draw_colored_polygon(rim, Color(0, 0, 0, 0.8))
	draw_colored_polygon(dia, GOLD)
	draw_string(_font, p + Vector2(-2, 4), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.1, 0.02))
	if not inside:
		var dir := (sp - at).normalized() if (sp - at).length() > 0.5 else (sp - vs * 0.5).normalized()
		var side := Vector2(-dir.y, dir.x) * 3.5
		draw_colored_polygon(PackedVector2Array([p + dir * (r + 7.0), p + dir * (r + 1.0) + side, p + dir * (r + 1.0) - side]), GOLD)
	var txt := "%s  %s" % [str(_obj.get("who", "")), dist_text(d)]
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var tp := Vector2(clampf(p.x - w * 0.5, 2.0, vs.x - w - 2.0), p.y + r + 11.0)
	if tp.y > vs.y - 4.0:
		tp.y = p.y - r - 5.0
	draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
	draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
