extends SceneTree
## (1.31) Screen feel on this captain's screen (camera_rig._screen_feel -> PSX.set_feel): low health draws the red
## vignette, a knockdown blinks the screen dim, flying fast smears it and widens the view, "Screen effects" 0 turns
## it all off.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var psx
var step := 0
var until := 0
var fails := 0
var fov0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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
			psx = root.get_node("PSX")
			check("full health: no vignette", psx._feel.x <= 0.0)
			fov0 = stage.camera_rig.camera.fov
			p.health_component.current_health = p.health_component.max_health * 0.12
			until = TK.wait_ticks(6)
		1:
			print("  feel ", psx._feel)
			check("low health draws the vignette", psx._feel.x > 0.2)
			p.health_component.current_health = p.health_component.max_health
			p.knock_down(Vector3(0, 3, 2))
			until = TK.wait_ticks(4)
		2:
			print("  feel ", psx._feel)
			check("a knockdown blinks the screen dim", psx._feel.y > 0.2)
			until = TK.wait_secs(2.5)
		3:
			check("the blink fades", psx._feel.y < 0.05)
			# launched: fast through the air
			p.global_position += Vector3(0, 30, 0)
			p.velocity = Vector3(0, 22, 0)
			until = TK.wait_ticks(10)
		4:
			print("  feel ", psx._feel, " fov ", stage.camera_rig.camera.fov)
			check("flying fast smears the screen", psx._feel.z > 0.3)
			check("and widens the view", stage.camera_rig.camera.fov > fov0 + 2.0)
			root.get_node("Settings").set_value("gameplay", "screen_fx", 0.0, false)
			p.health_component.current_health = p.health_component.max_health * 0.12
			until = TK.wait_ticks(6)
		5:
			check("Screen effects 0: no vignette, no smear", psx._feel.x <= 0.0 and psx._feel.z <= 0.0)
			root.get_node("Settings").set_value("gameplay", "screen_fx", 1.0, false)
			return TK.done(fails)
	step += 1
	return false
