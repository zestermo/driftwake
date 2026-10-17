extends SceneTree
## Brinehollow's town sound and light (BrinehollowLife's TownLife): at 10:00 the market street murmurs and the
## Gull's room is quiet, paper lanterns strung across the street unlit; at 21:00 the market's quiet, the Gull's
## room busy, the lanterns glowing, two of them and the long stair's post really lit (from the light budget, which
## isn't overspent); every new chimney has a "Chimney" marker and smokes once the camera comes near.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var isl
var life
var cam: Camera3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _at(h: float) -> void:
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(h))


func _playing(kind: String) -> bool:
	return life.beds.any(func(b): return b[1] == kind and b[0].playing)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			load("res://scripts/world/actor_sleep.gd").enabled = false
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			life = isl.get_node("TownLife")
			cam = Camera3D.new()
			root.add_child(cam)
			cam.global_position = isl.to_global(Vector3(0, 30, -80))
			cam.make_current()
			_at(10.0)
			until = TK.wait_secs(1.2)
		1:
			check("at 10:00 the market street murmurs, the Gull's room is quiet", _playing("day") and not _playing("night"))
			check("the street's paper lanterns hang unlit", life.lanterns_day.visible and not life.lanterns_night.visible
				and life.lanterns_day.mesh.get_faces().size() > 0)
			check("Haldor's hammer is on the anvil by day", life.anvil != null and life.anvil.stream.streams_count == 4)
			_at(21.0)
			until = TK.wait_secs(1.2)
		2:
			check("at 21:00 the market's quiet and the Gull's room busy", not _playing("day") and _playing("night"))
			check("the lanterns glow", life.lanterns_night.visible and not life.lanterns_day.visible)
			var lights: Array = life.find_children("*", "OmniLight3D", true, false) + life.stair_post.find_children("*", "OmniLight3D", true, false)
			check("two of the street's lanterns and the stair's post are lit (%d)" % lights.size(), lights.size() == 3 and lights.all(func(l): return l.visible))
			print("   light budget left: %d" % int(isl.kit.budget["lights"]))
			check("the light budget isn't overspent", int(isl.kit.budget["lights"]) >= 0)
			check("the new chimneys are marked (%d)" % life.chimneys.size(), life.chimneys.size() >= 3)
			var first: Node3D = life.chimneys[0][0]
			cam.global_position = first.global_position + Vector3(12, 4, 12)
			until = TK.wait_secs(1.2)
		3:
			check("a chimney smokes once the camera's near", life.chimneys[0][1] != null and life.chimneys[0][1].emitting)
			check("the far ones don't yet", life.chimneys.any(func(c): return c[1] == null))
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
