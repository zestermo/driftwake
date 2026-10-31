extends SceneTree
## The tell language (1.28): a beast's close blow (a move table's "cone") puts a fan on the ground over where it
## lands as it winds up, and every move starts with a glint (white: parry it, red: you can't).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var beast
var step := 0
var until := 0
var fails := 0
var glints: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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
			var th = load("res://scripts/island/themes/island_themes.gd").of("snow")
			beast = load(th.beasts["rimeback"]["script"]).new()
			var at: Vector3 = p.global_position + Vector3(0, 0, -6.0)
			beast.setup({"post": at, "yaw": 0.0, "level": 6, "name": "Test"})
			stage.add_child(beast)
			beast.global_position = at
			until = TK.wait_ticks(5)
		1:
			TK.calm(beast, Vector3.ZERO)
			var table: Dictionary = beast._table()
			beast._table_begin("sweep", table["sweep"])
			var fans: Array = root.find_children("ArcWarn*", "", true, false)
			check("a sweep (a cone) lays a fan on the ground as it winds up (%d)" % fans.size(), fans.size() >= 1)
			check("parryable and unparryable glints differ", beast.GLINT_PARRY != beast.GLINT_PERIL)
			check("the sweep is parryable, so it glints white", bool(table["sweep"].get("parry", false)))
			until = TK.wait_secs(1.5)
		2:
			var fans: Array = root.find_children("ArcWarn*", "", true, false)
			check("the fan is gone after the tell (%d left)" % fans.size(), fans.is_empty())
			return TK.done(fails)
	step += 1
	return false
