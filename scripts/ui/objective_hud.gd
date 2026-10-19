class_name ObjectiveHud
extends Control
## What you're following, top left: the story's objective (Story) or the quest you track in the crew
## journal (Journal.tracked), with how far it is, and a gold marker over who or where (pinned to the
## screen's edge when it's off screen, gone once you're there). It flashes when it changes.

## Close enough: the marker goes (an NPC you can talk to, a fight you're in).
const NPC_NEAR := 3.5
const PLACE_NEAR := 22.0
const EDGE := 16.0
const GOLD := Color(1.0, 0.82, 0.3)

## (set while a menu's open: the HUD is paused then, so it hides now)
var hidden_by_menu: bool = false:
	set(v):
		hidden_by_menu = v
		if _box and v:
			_box.visible = false
var _box: VBoxContainer
var _head: Label
var _goal: Label
var _flash: float = 0.0
var _t: float = 0.0
var _poll: float = 0.0
var _font: Font
var _player: Player
## What's shown: {"kind": "story" / "quest", "goal", "who", "pos", "person": bool} ({} for nothing).
var _obj := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_box = VBoxContainer.new()
	_box.position = Vector2(8, 5)
	_box.add_theme_constant_override("separation", 0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_head = Label.new()
	_head.add_theme_font_override("font", _font)
	_head.add_theme_font_size_override("font_size", 8)
	_head.add_theme_color_override("font_color", GOLD)
	_head.add_theme_color_override("font_outline_color", Color.BLACK)
	_head.add_theme_constant_override("outline_size", 3)
	_box.add_child(_head)
	_goal = UIStyle.label("", 12, UIStyle.TEXT)
	_goal.add_theme_color_override("font_outline_color", Color.BLACK)
	_goal.add_theme_constant_override("outline_size", 4)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD
	_goal.custom_minimum_size = Vector2(210, 0)
	_box.add_child(_goal)
	Story.changed.connect(_refresh)
	Journal.changed.connect(_on_journal)
	_refresh()


## How tall the tracker is (the HUD moves what's under it down by this).
func tracker_height() -> float:
	return _box.size.y + 6.0 if _box.visible else 0.0


func flash() -> void:
	_flash = 3.0
	_refresh()


func _on_journal() -> void:
	var was: String = _obj.get("goal", "")
	_refresh()
	if _obj.get("kind", "") == "quest" and _obj["goal"] != was:
		_flash = 3.0


func _refresh() -> void:
	_obj = objective()
	_goal.text = str(_obj.get("goal", ""))


## The tracked quest, else the story while it's on, else nothing.
func objective() -> Dictionary:
	var id: String = Journal.tracked
	if Journal.has(id) and not Journal.is_done(id):
		return {"kind": "quest", "goal": Journal.goal(id), "who": str(Journal.entries[id]["title"]), "id": id}
	if id != "" and Story.active():
		var c := Story.current()
		return {"kind": "story", "goal": Story.goal(), "who": str(c.get("who", "")), "person": c.has("npc")}
	return {}


func _target() -> Vector3:
	match str(_obj.get("kind", "")):
		"quest":
			return Journal.target(_obj["id"])
		"story":
			return Story.target_pos()
	return Vector3.INF


func _person() -> bool:
	return Journal.target_is_person(_obj["id"]) if _obj.get("kind", "") == "quest" else bool(_obj.get("person", false))


func _wake() -> bool:
	return _player != null and _player.current_state_name() == "Wake"


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_t += delta
	_poll -= delta
	if _poll <= 0.0 and _obj.get("kind", "") == "quest":
		# (how many of a fetch's items you've got)
		_poll = 0.25
		_refresh()
	_box.visible = not _obj.is_empty() and not hidden_by_menu and not _wake() and not Dialogue.active
	_flash = maxf(_flash - delta, 0.0)
	var pulse := 0.5 + 0.5 * sin(_flash * 9.0) if _flash > 0.0 else 0.0
	var quest: bool = _obj.get("kind", "") == "quest"
	_head.text = ("NEW " if _flash > 0.0 else "") + ("QUEST" if quest else "OBJECTIVE")
	_goal.modulate = Color.WHITE.lerp(GOLD, pulse)
	var d := _distance()
	if d >= 0.0 and _box.visible:
		_head.text += "   %dm" % int(d)
	queue_redraw()


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
	var txt := "%s  %dm" % [str(_obj.get("who", "")), int(d)]
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var tp := Vector2(clampf(p.x - w * 0.5, 2.0, vs.x - w - 2.0), p.y + r + 11.0)
	if tp.y > vs.y - 4.0:
		tp.y = p.y - r - 5.0
	draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
	draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
