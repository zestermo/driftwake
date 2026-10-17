extends SceneTree
## Footprints (GroundLayer): on a snow island the captain's boots press prints into the snow where they
## walk and kick up one puff of powder a step; the prints fade out over their life; on a desert they press
## into the sand; at home nothing is printed (and the ground's own dust plays).
const TK := preload("res://tools/dev/test_kit.gd")
var KS
var stage
var p
var wx
var gl
var step := 0
var until := 0
var fails := 0
var start := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weather": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _zone(theme: String) -> void:
	wx._zone = [theme, 1.0 if theme != "brinehollow" else 0.0]
	wx._zone_style = KS.of(theme)
	wx._zone_t = 1e9


func _bursts() -> int:
	return stage.find_children("*", "CPUParticles3D", false, false).size()


## Prints along the way from `a` to `b`: how many 10 cm samples on either foot's line are in one.
func _printed(a: Vector3, b: Vector3) -> int:
	var n := 0
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x) * 0.12
	var steps := int(a.distance_to(b) / 0.1)
	for i in range(steps):
		var at := a + dir * (i * 0.1)
		if gl.print_at(at + side) > 0.0 or gl.print_at(at - side) > 0.0:
			n += 1
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			wx = root.get_node("Weather")
			KS = load("res://scripts/island/kit/kit_style.gd")
			gl = stage.get_node("GroundLayer")
			stage.get_node("Ground").set_meta("surface", "snow")
			_zone("snow")
			until = TK.wait_secs(0.3)
		1:
			check("on a snow island the ground layer prints in snow (%s)" % gl.kind, gl.kind == "snow")
			check("...and tells the shaders how long a print lasts", gl.shader_at.y == 70.0)
			var before := _bursts()
			var foot: Vector3 = p.global_position + Vector3(0.12, 0, 0)
			var soft: bool = load("res://scripts/world/ground_layer.gd").step(p, "snow", 0, 0.6, false)
			check("a foot coming down in snow is soft ground", soft)
			check("...it kicks up one puff (%d new)" % (_bursts() - before), _bursts() - before == 1)
			var near := maxf(gl.print_at(p.global_position + Vector3(0.12, 0, 0)), gl.print_at(p.global_position - Vector3(0.12, 0, 0)))
			check("...and leaves a print under it (%.2f)" % near, near == 1.0)
			before = _bursts()
			check("a foot on rock in the snow prints nothing", not load("res://scripts/world/ground_layer.gd").step(p, "stone", 1, 0.6, false) and _bursts() == before)
			start = p.global_position
			TK.press("move_forward")
			until = TK.wait_secs(2.5)
		2:
			TK.release("move_forward")
			var walked := start.distance_to(p.global_position)
			var n := _printed(start + (p.global_position - start).normalized() * 0.4, p.global_position)
			print("walked %.1f m, %d samples printed" % [walked, n])
			check("walking leaves a trail of prints behind the captain (%d samples over %.1f m)" % [n, walked], walked > 5.0 and n >= int(walked * 0.6))
			check("...the footsteps are snow's (%s)" % p.ground_surface(), p.ground_surface() == "snow")
			gl._clock += 70.0 * 0.8
			until = TK.wait_secs(0.25)
		3:
			var n := _printed(start + (p.global_position - start).normalized() * 0.4, p.global_position)
			var k: float = gl.print_at(start + Vector3(0.12, 0, 0))
			check("an old print is fading (%.2f, %d samples still)" % [k, n], k > 0.0 and k < 1.0)
			gl._clock += 70.0 * 0.3
			until = TK.wait_secs(0.25)
		4:
			check("...and gone after its life (%d)" % _printed(start, p.global_position), _printed(start, p.global_position) == 0)
			stage.get_node("Ground").set_meta("surface", "sand")
			_zone("desert")
			until = TK.wait_secs(0.3)
		5:
			check("on a desert it prints in sand (%s)" % gl.kind, gl.kind == "sand" and gl.shader_at.y == 45.0)
			var before := _bursts()
			check("...a foot in the sand is soft and kicks up one puff",
				load("res://scripts/world/ground_layer.gd").step(p, "sand", 0, 0.6, true) and _bursts() - before == 1 and gl.print_at(p.global_position + Vector3(0.12, 0, 0)) + gl.print_at(p.global_position - Vector3(0.12, 0, 0)) > 0.0)
			_zone("brinehollow")
			until = TK.wait_secs(0.3)
		6:
			check("at home nothing is printed", gl.kind == "" and not load("res://scripts/world/ground_layer.gd").step(p, "sand", 0, 0.6, false))
			return TK.done(fails)
	step += 1
	return false
