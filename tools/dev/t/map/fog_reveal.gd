extends SceneTree
## The held map's fog of war: standing on an island uncovers the ground round the captain (not far
## off), walking on uncovers more, and what's uncovered is saved and loads back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gm
var MF
var d: Dictionary
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
			gm = root.get_node("GameManager")
			MF = load("res://scripts/map/map_fog.gd")
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(3, 110.0)
			isle.add_to(self)
			d = load("res://scripts/map/map_isles.gd").at(self, Vector2.ZERO)
			check("the stage's origin is on the stub island's map", str(d.get("key", "")) == "isle3")
			check("nothing's uncovered before anyone looks", not MF.seen(gm, d, Vector2.ZERO))
			until = TK.wait_secs(1.2)
		1:
			check("the ground under the captain is uncovered", MF.seen(gm, d, Vector2.ZERO))
			check("...and 25 m off", MF.seen(gm, d, Vector2(25, 0)) and MF.seen(gm, d, Vector2(0, -25)))
			check("...but not 90 m off", not MF.seen(gm, d, Vector2(90, 0)))
			p.global_position = Vector3(90, p.global_position.y, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.2)
		2:
			check("walking on uncovers more", MF.seen(gm, d, Vector2(90, 0)))
			check("...and the way there stays uncovered", MF.seen(gm, d, Vector2.ZERO))
			check("the far side's still under fog", not MF.seen(gm, d, Vector2(-90, 0)))
			var sg = load("res://scripts/game/save_game.gd")
			sg.save(p)
			gm.fog.clear()
			check("(cleared)", not MF.seen(gm, d, Vector2(90, 0)))
			sg.load_into(p)
			check("the fog loads back from the save", MF.seen(gm, d, Vector2(90, 0)) and MF.seen(gm, d, Vector2.ZERO)
				and not MF.seen(gm, d, Vector2(-90, 0)))
			return TK.done(fails)
	step += 1
	return false
