class_name LoadingScreen
extends CanvasLayer
## Between the title (or a load) and the world: a dusk card with the logo, a
## bar while the world's files load on a thread, "Raising Brinehollow" while
## the island builds (the game stands still for a moment there), and a fade
## into the game once the captain is in it. It lives on the root, so it
## outlasts the scene change, and frees itself.

const LOGO_FONT := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")
const SMALL_FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const TIPS := [
	"Stow your haul in the ship's storage chest. Whatever you carry is buried where you fall.",
	"Parry (Q) just as a blow lands to turn it aside.",
	"A heavy attack (right click) ends fights. A missed one ends you.",
	"Roll (Ctrl) through an attack, not away from it.",
	"Nessa buys anything that glitters. Treasure sells for more than gold weighs.",
	"Hold F at the capstan to drop or weigh anchor.",
	"Pirates only hunt ships with a captain aboard.",
	"Rum on a quick slot (5-7) heals you in a pinch.",
]

var scene_path: String = ""
var _stage: String = "load"
var _t: float = 0.0
var _stage_t: float = 0.0
var _shown: float = 0.0
var _packed: PackedScene
var _card: Control
var _tip: String = ""


## Load `scene_path` behind a loading screen.
static func go(tree: SceneTree, path: String) -> void:
	var ls: CanvasLayer = (load("res://scripts/ui/loading_screen.gd") as GDScript).new()
	ls.set("scene_path", path)
	tree.root.add_child(ls)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tip = TIPS[randi() % TIPS.size()]
	if OS.has_feature("web"):
		_tip = _tip.replace("(Ctrl)", "(C)")
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_card.draw.connect(_draw_card)
	add_child(_card)
	ResourceLoader.load_threaded_request(scene_path)


func _process(delta: float) -> void:
	_t += delta
	_stage_t += delta
	match _stage:
		"load":
			var progress := []
			var st := ResourceLoader.load_threaded_get_status(scene_path, progress)
			_shown = move_toward(_shown, float(progress[0]) * 0.7 if not progress.is_empty() else _shown, delta * 1.5)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				_packed = ResourceLoader.load_threaded_get(scene_path)
				_go("build")
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("LoadingScreen: couldn't load " + scene_path)
				_go("done")
		"build":
			_shown = move_toward(_shown, 0.75, delta)
			# draw "Raising Brinehollow" before the world's build freezes the frame
			if _stage_t > 0.15:
				get_tree().change_scene_to_packed(_packed)
				_go("wait")
		"wait":
			_shown = move_toward(_shown, 0.95, delta * 0.5)
			# the captain is in the world and the save has been applied
			var p := get_tree().get_first_node_in_group("player")
			if p and _stage_t > 0.6:
				_go("fade")
		"fade":
			_shown = move_toward(_shown, 1.0, delta * 2.0)
			_card.modulate.a = 1.0 - clampf(_stage_t / 0.7, 0.0, 1.0)
			if _stage_t >= 0.7:
				_go("done")
		"done":
			queue_free()
	_card.queue_redraw()


func _go(s: String) -> void:
	_stage = s
	_stage_t = 0.0


func _draw_card() -> void:
	var c := _card
	var w := c.size.x
	var h := c.size.y
	var horizon := h * 0.6
	var top := Color(0.04, 0.05, 0.12)
	var mid := Color(0.24, 0.13, 0.24)
	var low := Color(0.78, 0.4, 0.22)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, horizon * 0.65), Vector2(0, horizon * 0.65)]),
		PackedColorArray([top, top, mid, mid]))
	c.draw_polygon(PackedVector2Array([Vector2(0, horizon * 0.65), Vector2(w, horizon * 0.65), Vector2(w, horizon), Vector2(0, horizon)]),
		PackedColorArray([mid, mid, low, low]))
	var sea_far := Color(0.42, 0.22, 0.26)
	var sea_near := Color(0.03, 0.04, 0.1)
	c.draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([sea_far, sea_far, sea_near, sea_near]))
	# swell lines drifting by
	for row in range(7):
		var k := float(row) / 6.0
		var y := horizon + 5.0 + pow(k, 1.6) * (h - horizon - 6.0)
		var step := 12.0 + k * 26.0
		var x := fposmod(_t * (5.0 + k * 12.0) + row * 41.0, step) - step
		var col := sea_far.lerp(sea_near, k).lightened(0.2)
		while x < w:
			c.draw_line(Vector2(x, y), Vector2(x + step * 0.4, y - 1.0 - k), Color(col.r, col.g, col.b, 0.5), 1.0)
			x += step
	# a far island on the horizon
	var isl := PackedVector2Array([Vector2(w * 0.58, horizon), Vector2(w * 0.63, horizon - 10), Vector2(w * 0.67, horizon - 19),
		Vector2(w * 0.7, horizon - 15), Vector2(w * 0.76, horizon - 6), Vector2(w * 0.8, horizon)])
	c.draw_colored_polygon(isl, Color(0.16, 0.09, 0.16))
	# logo
	var lp := Vector2(44, horizon * 0.5)
	c.draw_string_outline(LOGO_FONT, lp + Vector2(0, 3), "DRIFTWAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 9, Color(0.08, 0.03, 0.02))
	c.draw_string(LOGO_FONT, lp + Vector2(0, 3), "DRIFTWAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.55, 0.25, 0.1))
	c.draw_string(LOGO_FONT, lp, "DRIFTWAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UIStyle.ACCENT)
	# the bar and what's happening
	var status := "Charting the waters" if _stage == "load" else ("Raising Brinehollow" if _stage == "build" else "Making landfall")
	status += ".".repeat(int(_t * 2.5) % 4)
	var bar := Rect2(44, h - 46, w - 88, 5)
	c.draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _shown, bar.size.y)), UIStyle.ACCENT)
	c.draw_string_outline(SMALL_FONT, Vector2(44, h - 52), status.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
	c.draw_string(SMALL_FONT, Vector2(44, h - 52), status.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 0.75))
	c.draw_string_outline(SMALL_FONT, Vector2(44, h - 26), _tip, HORIZONTAL_ALIGNMENT_LEFT, w - 88, 8, 3, Color.BLACK)
	c.draw_string(SMALL_FONT, Vector2(44, h - 26), _tip, HORIZONTAL_ALIGNMENT_LEFT, w - 88, 8, Color(0.85, 0.82, 0.78))
