extends SceneTree
## (1.30) A smoke cloud blocks sight: a foe can't notice (Stealth.range_for 0) or pick (the grunt's target check) a
## captain standing behind one, though both are outside it; with the line clear of it, it can again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -14), "role": "sword", "seed": 31}]})


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
			g = stage.camp.grunts[0]
			TK.calm(g, Vector3.BACK)
			load("res://scripts/gadgets/gadget_zone.gd").spawn(self, "smoke", 0, g.global_position.lerp(p.global_position, 0.5))
			until = TK.wait_ticks(3)
		1:
			var eye: Vector3 = g.global_position + Vector3.UP * 1.5
			check("a cloud between them (%d)" % GadgetVeil.clouds.size(), GadgetVeil.clouds.size() == 1)
			check("the captain is outside it", not GadgetVeil.veiled(p))
			check("...but the line is blocked", GadgetVeil.blocks(eye, p.global_position))
			check("...so the foe can't notice them", Stealth.range_for(p, g.global_position, Vector3.BACK, 30.0) == 0.0)
			check("...nor pick them to fight", not g._player_ok(p) and not Stealth.sight_clear(eye, p))
			p.global_position += Vector3(12.0, 0, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(3)
		2:
			var eye: Vector3 = g.global_position + Vector3.UP * 1.5
			check("off to the side the line is clear", not GadgetVeil.blocks(eye, p.global_position))
			check("...and the foe sees them again", g._player_ok(p) and Stealth.range_for(p, g.global_position, Vector3.BACK, 30.0) > 0.0)
			return TK.done(fails)
	step += 1
	return false
