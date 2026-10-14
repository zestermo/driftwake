extends SceneTree
## The cutlass combo: slash_r, slash_l, the spin finisher (with a blade trail); moving cancels the recovery without
## dropping the combo; after the finisher or a long pause it starts over.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func act() -> String:
	return p.body_model.current_action()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(0.3)
		1:
			TK.act("light_attack")
			until = TK.wait_secs(0.1)
		2:
			check("hit 1 = slash_r", p.current_state_name() == "LightAttack" and act() == "slash_r")
			until = TK.wait_secs(0.35)
		3:
			TK.press("move_right")
			until = TK.wait_secs(0.25)
		4:
			check("moving cancels recovery (Move state)", p.current_state_name() == "Move")
			TK.release("move_right")
			TK.act("light_attack")
			until = TK.wait_secs(0.15)
		5:
			check("after moving, next click continues combo (hit 2 = slash_l)", act() == "slash_l")
			until = TK.wait_secs(0.55)
		6:
			TK.act("light_attack")
			until = TK.wait_secs(0.08)
		7:
			check("hit 3 = spin finisher", act() == "slash_spin")
			until = TK.wait_secs(0.2)
		8:
			var trails := 0
			for c in p.body_model.get_children():
				if c is MeshInstance3D and c.mesh is ImmediateMesh:
					trails += 1
			check("slash trail spawned", trails >= 1)
			until = TK.wait_secs(1.2)
		9:
			TK.act("light_attack")
			until = TK.wait_secs(0.08)
		10:
			check("after finisher, combo restarts at hit 1", act() == "slash_r")
			until = TK.wait_secs(2.0)
		11:
			TK.act("light_attack")
			until = TK.wait_secs(0.08)
		12:
			check("after a long pause, combo restarts", act() == "slash_r")
			return TK.done(fails)
	step += 1
	return false
