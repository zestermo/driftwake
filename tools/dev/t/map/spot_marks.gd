extends SceneTree
## The map's `?` marks: M on an island opens its page with a `?` near every place not found yet (camp,
## landmark, cave); walking up to the camp finds it (a toast), its `?` goes and it's marked by name.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var page
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _ids(arr: Array) -> Array:
	return arr.map(func(s): return str(s["id"]))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gm = root.get_node("GameManager")
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(4, 110.0)
			isle.add_to(self)
			page = p.get_node("MapHold").page
			TK.act("sea_chart")
			until = TK.wait_secs(0.5)
		1:
			check("the map opens on the island we're on", page.on_isle and str(page.isle.d["key"]) == "isle4")
			var q := _ids(page.isle.question_marks())
			check("a ? for the camp, the waterfall and the cave", q.has("site_camp") and q.has("place0") and q.has("inside0"))
			TK.act("sea_chart")
			until = TK.wait_secs(0.4)
		2:
			p.global_position = Vector3(55, p.global_position.y, 4)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.2)
		3:
			check("walking up to the camp finds it", load("res://scripts/map/map_fog.gd").found(gm, "isle4", "site_camp"))
			TK.act("sea_chart")
			until = TK.wait_secs(0.5)
		4:
			var q := _ids(page.isle.question_marks())
			check("the camp's ? is gone", not q.has("site_camp"))
			check("...the others are still there", q.has("place0") and q.has("inside0"))
			check("...and the camp's on the page by name", _ids(page.isle.found_spots()).has("site_camp"))
			return TK.done(fails)
	step += 1
	return false
