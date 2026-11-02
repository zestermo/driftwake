class_name FishFightHud
extends Control
## The legendary fight's bars (FishState, 1.28): the line's tension (green to red, the snap mark at the top) and how
## far in the fish is, with what to do. Laid out on the UI canvas (800x450), low in the middle.

var fight: FishFight
var fish_name := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fight == null:
		return
	var font := get_theme_default_font()
	var w := 220.0
	var x := size.x * 0.5 - w * 0.5
	var y := size.y * 0.74
	draw_string(font, Vector2(x, y - 22), fish_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(1.0, 0.75, 0.3))
	# tension
	var r := Rect2(x, y - 12, w, 9)
	draw_rect(r.grow(1), Color(0.05, 0.04, 0.03))
	var k := fight.tension
	var col := Color(0.4, 0.85, 0.35).lerp(Color(1.0, 0.25, 0.15), smoothstep(0.45, 0.95, k))
	draw_rect(Rect2(r.position, Vector2(w * k, r.size.y)), col)
	draw_line(Vector2(r.end.x - w * 0.12, r.position.y - 2), Vector2(r.end.x - w * 0.12, r.end.y + 2), Color(1, 1, 1, 0.5), 1.0)
	draw_string(font, Vector2(x - 54, r.end.y), "LINE", HORIZONTAL_ALIGNMENT_RIGHT, 50, 8, Color(0.9, 0.88, 0.8))
	# distance: the fish's mark slides in to the rod
	var d := Rect2(x, y + 4, w, 5)
	draw_rect(d.grow(1), Color(0.05, 0.04, 0.03))
	draw_rect(Rect2(d.position, Vector2(w * fight.progress(), d.size.y)), Color(0.35, 0.6, 0.95))
	draw_string(font, Vector2(x - 54, d.end.y + 1), "IN", HORIZONTAL_ALIGNMENT_RIGHT, 50, 8, Color(0.9, 0.88, 0.8))
	var tip := "IT'S RUNNING - EASE OFF" if fight.running else "HOLD F TO REEL"
	if fight.tension <= 0.05:
		tip = "SLACK - REEL OR IT THROWS THE HOOK"
	draw_string(font, Vector2(x, y + 24), tip, HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color(1.0, 0.5, 0.35) if fight.running else Color(0.9, 0.9, 0.85))
