extends SceneTree
## MapMarks: a mark another system puts on the map (a quest's goal) shows on the island page there, in
## page pixels where the world point is; clearing it takes it off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var MM
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			MM = load("res://scripts/map/map_marks.gd")
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(6, 110.0)
			isle.add_to(self)
			MM.put("quest", Vector3(40, 3, -30), "quest", "The lost ring")
			check("a mark is put", MM.has("quest"))
			p.get_node("MapHold").preview(true)
			until = TK.wait_ticks(3)
		1:
			var view = p.get_node("MapHold").page.isle
			var drawn: Array = MM.placed(view.world_to_frame)
			var want: Vector2 = view.frame.size * 0.5 + (Vector2(40, -30) - view.centre) * view.k
			check("it goes on the island page where it is", drawn.size() == 1 and (drawn[0][1] as Vector2).distance_to(want) < 0.5
				and Rect2(Vector2.ZERO, view.frame.size).has_point(drawn[0][1]))
			MM.clear("quest")
			check("clearing takes it off", not MM.has("quest") and MM.marks.is_empty())
			return TK.done(fails)
	step += 1
	return false
