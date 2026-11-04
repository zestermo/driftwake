extends SceneTree
## The Scouring's look and threat (1.30, ScouringFX): the smoke darkens the sky once the shells fall and clears once the
## crew's out of the ring; a shell is telegraphed (its warning, its flight from the ring, its whistle queued) and
## hurts only when it lands, less at its edge; shells land on what's there (a hall's roof, the sea).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var sc
var hp0 := 0.0
var lands := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var gm = root.get_node("GameManager")
	var wx = root.get_node("Weather")
	var P = load("res://scripts/island/stronghold_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			sc = isl.city.get_node("Scouring")
			var c0: Vector3 = isl.city_global(P.LAND_C, 0.0)
			get_first_node_in_group("ship").place(Vector3(c0.x + 220.0, 0.0, c0.z), 0.0)
			check("no smoke before the Commodore falls (%.2f)" % wx.smoke, wx.smoke < 0.01)
			# (shells land on what's there: the Mess Hall's roof, the open sea)
			var roof: Array = sc._from_sky(isl.city_global(Vector2(-30.0, 1.0), 0.0))
			check("a shell over the Mess Hall bursts on its roof (y %.1f)" % (roof[0] as Vector3).y, not roof[2] and (roof[0] as Vector3).y > 21.0)
			var sea: Array = sc._from_sky(isl.city_global(Vector2(0.0, 240.0), 0.0))
			check("a shell out at sea lands in the water", sea[2])
			sc.grace = 1.0
			sc.count = 1.0
			gm.world_flags["sh_seal_keep"] = true
			# (our captain just out of the ring while the smoke comes in: no shell is aimed there)
			p.global_position = c0 + Vector3(-sc.RING_R - 40.0, 2.0, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(11.0)
		3:
			check("the shells fall (%s, %d fired)" % [sc.state, sc._next], sc.state == "barrage" and sc._next >= 5)
			check("the sky goes dark with smoke (%.2f)" % wx.smoke, wx.smoke > 0.8)
			# one shell aimed at our captain, by hand: telegraphed, in flight from the ring, its whistle queued, no harm yet
			# (the barrage held off and its burning patches put out, so only this shell can touch them)
			sc._next = 1 << 30
			sc._pending.clear()
			sc.fires.clear()
			p.global_position = isl.city_global(Vector2(0, 16), 12.4)
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			lands = sc._clock() + sc.WARN
			sc._fire(p.global_position + Vector3(1.0, 0, 0), Vector3.UP, false, lands, 100000)
			check("the shell's in flight from the ring", sc.fx.flights.any(func(f): return is_equal_approx(float(f[3]), lands) and (f[0] as Vector3).distance_to(p.global_position) > 150.0))
			check("...and its whistle is queued", sc.fx._whistles.any(func(e): return is_equal_approx(float(e[1]), lands - sc.fx.WHISTLE)))
			until = TK.wait_secs(sc.WARN * 0.5)
		4:
			check("no harm before it lands (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health >= hp0 - 0.01)
			until = TK.wait_secs(sc.WARN * 0.5 + 0.4)
		5:
			var lost: float = hp0 - p.health_component.current_health
			check("it lands and hurts (%.0f lost)" % lost, lost >= sc.SHELL_DMG * 0.45)
			var ship = get_first_node_in_group("ship")
			var c: Vector3 = isl.city_global(P.LAND_C, 0.0)
			ship.place(c + Vector3(sc.RING_R + 20.0, 0, 0), 0.0)
			until = TK.wait_secs(2.0)
		6:
			check("out of the ring: escaped", sc.state == "escaped")
			until = TK.wait_secs(sc.fx.SMOKE_OUT + 2.0)
		7:
			check("the smoke clears (%.2f)" % wx.smoke, wx.smoke < 0.02)
			return TK.done(fails)
	step += 1
	return false
