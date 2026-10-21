extends SceneTree
## The pistol's guard is a low ready (the gun hand well under the shoulder, the barrel angled down), and a shot from
## it goes off on the press with the arm up at the target within a few ticks: the low ready never delays a shot.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var pressed_at := 0
var fired_at := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "pistol"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## How far the gun hand sits under its shoulder (m).
func drop() -> float:
	return b.arm_r.global_position.y - b.hand_r.global_position.y


func _on_tick() -> void:
	if step == 3 and fired_at < 0 and b.current_action() == "shoot_r":
		fired_at = Engine.get_physics_frames()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.5)
		1:
			check("the pistol's drawn", p.armed and b.weapon_in_hand and b.stance == "pistol")
			until = TK.wait_secs(0.5)
		2:
			check("low ready: the gun hand %.2f m under the shoulder" % drop(), drop() > 0.3)
			physics_frame.connect(_on_tick)
			pressed_at = Engine.get_physics_frames()
			TK.act("light_attack")
		3:
			if fired_at < 0 and Engine.get_physics_frames() < pressed_at + 30:
				return false
			check("the shot goes off on the press (%d ticks)" % (fired_at - pressed_at), fired_at >= 0 and fired_at - pressed_at <= 2)
			until = fired_at + 4
		4:
			check("...the arm up at the target 4 ticks after it (%.2f m under the shoulder)" % drop(), drop() < 0.1)
			return TK.done(fails)
	step += 1
	return false
