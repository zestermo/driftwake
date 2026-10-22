extends SceneTree
## The twin axes' hook (DualAxeArts.hook -> vine_yank(to, dmg, wrap = false)) from a guest: vine_yank is a host call,
## its three arguments come through the wire whole (the point, the damage, and `wrap` still a false bool, so the host
## draws no vines), and the host applying the decoded call hauls the grunt in; the spins' hook (`stand`) leaves the
## grunt that far from you, clear of your body.
const TK := preload("res://tools/dev/test_kit.gd")
var DA
var stage
var p
var g
var net
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "reavers_axe", "grunts": [
		{"post": Vector3(0, 0, -6.0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _dist() -> float:
	var d: Vector3 = g.global_position - p.global_position
	d.y = 0.0
	return d.length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			stage.camera_rig.rotation.y = 0.0
			g = stage.camp.grunts[0]
			g.health.max_health = 9999.0
			g.health.current_health = 9999.0
			net = root.get_node("Net")
			DA = load("res://scripts/player_states/dual_axe_arts.gd")
			until = TK.wait_secs(0.5)
		1:
			check("vine_yank is a host call", "vine_yank" in net.HOST_CALLS)
			var to: Vector3 = p.global_position + Vector3(0, 0, -0.2)
			var a = net._dec(net._enc([to, 4.0, false]))
			check("its three arguments come through the wire", a is Array and a.size() == 3 and a[0] is Vector3 and (a[0] as Vector3).is_equal_approx(to)
				and is_equal_approx(float(a[1]), 4.0))
			check("`wrap` arrives a false bool (no vines on the host)", a is Array and a.size() == 3 and typeof(a[2]) == TYPE_BOOL and a[2] == false)
			g._enter_idle()
			g.callv("vine_yank", a)
			until = TK.wait_secs(1.0)
		2:
			check("the host's decoded call hauls the grunt in (%.1f m)" % _dist(), _dist() < 3.0)
			until = TK.wait_secs(2.0)
		3:
			g.global_position = p.global_position + Vector3(4.5, 0, -4.5)
			g.reset_physics_interpolation()
			g._enter_idle()
			until = TK.wait_secs(0.3)
		4:
			check("the spins' hook takes a light grunt", DA.hook(p, g, 2.0, DA.HOOK_STAND))
			until = TK.wait_secs(1.0)
		5:
			check("and leaves it clear of your body, about %.1f m off (%.2f m)" % [DA.HOOK_STAND, _dist()], _dist() > 1.6 and _dist() < 3.2)
			return TK.done(fails)
	step += 1
	return false
