extends SceneTree
## The sea chart draws a standing island we've charted with its real coast (its land where the island
## is, the size it is, no circle for it); one not charted yet isn't drawn that way.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var page
var step := 0
var until := 0
var fails := 0


## The bits of the world the chart reads (Brinehollow's sea, nothing charted at sea).
class ChartWorld extends Node:
	var starter_center := Vector2.ZERO
	var island_infos: Array = []
	var redtide = null


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
			gm = root.get_node("GameManager")
			var cw := ChartWorld.new()
			cw.name = "Islands"
			stage.add_child(cw)
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(9, 110.0)
			isle.position = Vector3(500, 0, -200)
			isle.add_to(self)
			p.get_node("MapHold").preview(true)
			page = p.get_node("MapHold").page
			page.show_isle(false)
			until = TK.wait_ticks(3)
		1:
			var land = page.get_node_or_null("Land_isle9")
			check("not charted: no coast for it on the chart", land == null or not land.visible)
			gm.charted["island:Stubrock"] = true
			until = TK.wait_ticks(3)
		2:
			var land = page.get_node_or_null("Land_isle9")
			check("charted: its coast is on the chart", land != null and land.visible and page._landed.has("Stubrock"))
			var d: Dictionary = load("res://scripts/map/map_isles.gd").at(self, Vector2(500, -200))
			var r: Rect2 = d["rect"]
			var want: Vector2 = page.SIZE * 0.5 + (Vector2(500, -200) + r.position - page._centre) * page._k
			check("...where the island is, its size", land != null and land.position.distance_to(want) < 1.0 and land.size.distance_to(r.size * page._k) < 1.0)
			check("...drawn behind the chart's ink", land != null and land.show_behind_parent)
			p.global_position = Vector3(500, p.global_position.y, -200)
			p.reset_physics_interpolation()
			page.on_open()
			until = TK.wait_ticks(2)
		3:
			check("on the island's own page it's not drawn", page.on_isle and not page.get_node("Land_isle9").visible)
			p.get_node("MapHold").preview(false)
			return TK.done(fails)
	step += 1
	return false
