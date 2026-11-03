extends SceneTree
## Wall Jump (Acrobatics, 1.30): in mid-air against a wall, jump kicks you up and out off it (once before you land; Wall
## Kick twice) and teaches Acrobatics; without the node a jump at a wall is nothing. Spring Heels kicks harder. Wall
## Cling: pushing into the wall on the way down holds you there a second.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var x0 := 0
var vy0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 10.0, 8.0)
	cs.shape = box
	wall.add_child(cs)
	wall.position = Vector3(1.3, stage.GROUND_Y + 5.0, 0)
	stage.add_child(wall)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func xp() -> int:
	return int(pr.mastery_of("acrobatics")["xp"])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			TK.press("move_right")
			TK.act("jump")
			until = TK.wait_ticks(14)
		1:
			TK.act("jump")
			until = TK.wait_ticks(3)
		2:
			check("no Wall Jump: a jump at the wall does nothing (%s, vx %.1f)" % [p.body_model.current_action(), p.velocity.x], p.body_model.current_action() != "wall_kick")
			until = TK.wait_secs(1.2)
		3:
			pr.owned["ac_walljump"] = true
			pr._dirty()
			TK.act("jump")
			until = TK.wait_ticks(14)
		4:
			x0 = xp()
			TK.act("jump")
			until = TK.wait_ticks(3)
		5:
			check("Wall Jump: kicked off the wall, up and away (%s, v %s)" % [p.body_model.current_action(), str(p.velocity)],
				p.body_model.current_action() == "wall_kick" and p.velocity.x < -4.0 and p.velocity.y > 5.0)
			check("...teaches Acrobatics (+%d)" % (xp() - x0), xp() - x0 == pr.ACRO_XP["wall_jump"])
			vy0 = p.velocity.y
			until = TK.wait_ticks(14)
		6:
			TK.act("jump")
			until = TK.wait_ticks(3)
		7:
			check("once before you land (%d)" % int(p.air_uses.get("wall_jump", 0)), int(p.air_uses.get("wall_jump", 0)) == 1)
			until = TK.wait_secs(1.5)
		8:
			check("landed", p.is_on_floor())
			pr.owned["ac_springheels"] = true
			pr.owned["ac_wallcling"] = true
			pr._dirty()
			TK.act("jump")
			until = TK.wait_ticks(14)
		9:
			TK.act("jump")
			until = TK.wait_ticks(3)
		10:
			check("Spring Heels: a harder kick (%.1f > %.1f)" % [p.velocity.y, vy0], p.velocity.y > vy0 + 0.5)
			until = TK.wait_secs(3.5)
		11:
			TK.act("jump")
			until = TK.wait_secs(0.75)
		12:
			check("Wall Cling: pushing into the wall on the way down holds you (%s, %s, vy %.2f)" % [p.body_model.current_action(), p.current_state_name(), p.velocity.y],
				p.body_model.current_action() == "wall_cling" and absf(p.velocity.y) < 0.6 and not p.is_on_floor())
			TK.release("move_right")
			until = TK.wait_secs(1.5)
		13:
			check("...let go: down you come", p.is_on_floor() and p.body_model.current_action() != "wall_cling")
			return TK.done(fails)
	step += 1
	return false
