extends SceneTree
## Readying and dropping the fists is one symmetric chamber (fists_up, fists_down): both hands thrown out ahead and a
## little down, mirrored, then up into the guard (or down to the sides); and a standing jump with the fists up moves
## the arms as the plain jump does (no hand left up in the guard).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var plain := []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## The hands in the body's frame (x right, y up from the feet, -z ahead).
func _hands() -> Array:
	var b = p.body_model
	var inv: Transform3D = p.player_model.global_transform.affine_inverse()
	return [inv * b.hand_l.global_position, inv * b.hand_r.global_position]


func _mirrored(h: Array, tol: float) -> bool:
	var l: Vector3 = h[0]
	var r: Vector3 = h[1]
	return absf(l.y - r.y) < tol and absf(l.z - r.z) < tol and absf(l.x + r.x) < tol


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.unequip_weapon()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.19)
		1:
			var h := _hands()
			check("readied: %s" % p.body_model.current_action(), p.body_model.current_action() == "fists_up")
			check("the chamber: both hands out ahead, mirrored (%s / %s)" % [str(h[0]), str(h[1])], _mirrored(h, 0.1) and h[0].z < -0.3)
			check("...wide and below the shoulders (%.2f m apart, %.2f m up)" % [h[1].x - h[0].x, h[0].y], h[1].x - h[0].x > 0.6 and h[0].y < 1.35 and h[0].y > 0.8)
			until = TK.wait_secs(0.6)
		2:
			var h := _hands()
			check("then the guard: fists up by the face (%.2f / %.2f m)" % [h[0].y, h[1].y], h[0].y > 1.3 and h[1].y > 1.3)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.17)
		3:
			var h := _hands()
			check("put away: %s" % p.body_model.current_action(), p.body_model.current_action() == "fists_down" and not p.armed)
			check("the same chamber, mirrored (%s / %s)" % [str(h[0]), str(h[1])], _mirrored(h, 0.12) and h[0].z < -0.25)
			until = TK.wait_secs(0.7)
		4:
			var h := _hands()
			check("then the hands down by the sides (%.2f / %.2f m)" % [h[0].y, h[1].y], h[0].y < 1.0 and h[1].y < 1.0 and _mirrored(h, 0.12))
			TK.act("jump")
			until = TK.wait_secs(0.3)
		5:
			plain = _hands()
			until = TK.wait_secs(1.5)
		6:
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		7:
			check("fists up again", p.armed and p.style() == "fist" and p.is_on_floor())
			TK.act("jump")
			until = TK.wait_secs(0.3)
		8:
			var h := _hands()
			check("a standing jump in the stance: both hands swing as one (%.2f / %.2f m)" % [h[0].y, h[1].y], absf(h[0].y - h[1].y) < 0.15)
			check("...like the plain jump's (%.2f / %.2f vs %.2f / %.2f m)" % [h[0].y, h[1].y, plain[0].y, plain[1].y],
				absf(h[0].y - plain[0].y) < 0.2 and absf(h[1].y - plain[1].y) < 0.2)
			return TK.done(fails)
	step += 1
	return false
