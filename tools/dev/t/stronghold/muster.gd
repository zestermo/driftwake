extends SceneTree
## The stronghold's muster flags (1.27, StrongholdMuster): one in each fighting district flying the Admiralty's banner;
## F cuts it down and raises the crew's (a world flag); then the nearest raised flag is where a fallen captain gets
## back up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
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
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			var ms: Array = isl.city.find_children("Muster_*", "", false, false)
			check("a muster flag in each fighting district (%d)" % ms.size(), ms.size() == 4)
			var M = load("res://scripts/island/stronghold_muster.gd")
			check("none raised yet: no muster to get up at", M.nearest_raised(isl.city.global_position, 2000.0) == Vector3.INF)
			var ward = isl.city.get_node("Muster_ward")
			check("...the Admiralty's banner flying", ward._admiralty.visible and not ward._crew.visible)
			ward._use.interact(p)
			until = TK.wait_secs(1.0)
		3:
			var ward = isl.city.get_node("Muster_ward")
			var M = load("res://scripts/island/stronghold_muster.gd")
			check("F: the crew's flag raised (the world flag set, the banner swapped)", root.get_node("GameManager").world_flags.has("sh_muster_ward") and ward._crew.visible and not ward._admiralty.visible)
			var at: Vector3 = M.nearest_raised(ward.global_position + Vector3(20, 0, 0))
			check("...the nearest raised flag is where you'd get back up (%.1f m off it)" % at.distance_to(ward.global_position), at != Vector3.INF and at.distance_to(ward.global_position) < 4.0)
			return TK.done(fails)
	step += 1
	return false
