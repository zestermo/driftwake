extends SceneTree
## (1.30) The pause menu's Unstuck: stuck somewhere new, it puts the captain back on the last safe ground they stood on
## (a few metres back), closes the menu, and they stay standing there; pressed again at once it waits out its cooldown.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b: Vector3
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


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(0.5)
		1:
			b = p.global_position + Vector3(-8, 0, 0)
			put(b)
			until = TK.wait_secs(0.5)
		2:
			check("standing about leaves safe spots behind (%d)" % p.unstuck.spots.size(), p.unstuck.spots.size() >= 2)
			b = p.global_position
			put(b + Vector3(16, 0, 6))
			var gm := root.get_node("GameMenu")
			gm.open("pause")
			var btn: Array = gm.find_children("*", "Button", true, false).filter(func(x): return x.text == "Unstuck" and x.is_visible_in_tree())
			check("the pause menu has Unstuck", btn.size() == 1)
			if btn.is_empty():
				return TK.done(fails)
			btn[0].pressed.emit()
			check("...pressed, the menu closes", not gm.is_open())
			check("...and the captain is back where they last stood (%.2f m off)" % flat(p.global_position).distance_to(flat(b)), flat(p.global_position).distance_to(flat(b)) < 0.5)
			until = TK.wait_secs(0.5)
		3:
			check("...standing there (%.2f over it)" % (p.global_position.y - b.y), p.is_on_floor() and absf(p.global_position.y - b.y) < 0.3)
			var at: Vector3 = p.global_position
			var said: String = p.unstuck.request(p)
			check("pressed again at once it waits (%s)" % said, said.contains("again") and p.global_position.is_equal_approx(at))
			return TK.done(fails)
	step += 1
	return false
