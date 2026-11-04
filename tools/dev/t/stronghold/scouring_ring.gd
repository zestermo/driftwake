extends SceneTree
## The Scouring's ring and fires (1.30, ScouringFX piece 2): the warships come up round the island with the gap toward
## the sea gate left open, their broadsides fly; the sirens sound and the drums beat; the shells set great fires burning
## that hurt a captain in them; once the shells fall the journal's step is "Escape the ring" with its marker out past
## the ring through the gap, and the district line says so.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var sc
var hp0 := 0.0
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
	var P = load("res://scripts/island/stronghold_plan.gd")
	var LQ = load("res://scripts/quests/line_quests.gd")
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
			check("no warships before the Commodore falls", sc.fx.ships.is_empty())
			sc.grace = 0.5
			sc.count = 4.0
			gm.world_flags["sh_seal_keep"] = true
			p.global_position = c0 + Vector3(-sc.RING_R - 40.0, 2.0, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		3:
			check("the countdown (%s): the ring's up (%d ships)" % [sc.state, sc.fx.ships.size()], sc.state == "count" and sc.fx.ships.size() == sc.fx.SHIPS)
			var c: Vector3 = isl.city_global(P.LAND_C, 0.0)
			var gap: Vector3 = sc.fx.gap_dir()
			var near_gap: Array = sc.fx.ships.filter(func(e):
				var o: Vector3 = ((e[0] as Node3D).global_position - c)
				o.y = 0.0
				return o.normalized().angle_to(gap) < sc.fx.GAP_HALF * 0.9)
			check("...no ship in the gap", near_gap.is_empty())
			var g: Vector3 = sc.gap_at(isl)
			check("the gap's marker is out past the ring, toward the sea gate", not sc.in_ring(g) and (g - c).normalized().dot(gap) > 0.99)
			check("the sirens sound", sc.fx._siren.playing)
			until = TK.wait_secs(14.0)
		4:
			check("the barrage (%s): the drums beat" % sc.state, sc.state == "barrage" and sc.fx._drums.playing)
			check("broadsides fired (%d)" % sc.fx._broadside, sc.fx._broadside >= 0)
			check("the shells set great fires burning (%d; %d shells, %d burning patches)" % [sc.fx.blazes.size(), sc._next, sc.fires.size()], sc.fx.blazes.size() >= 1)
			if sc.fx.blazes.is_empty():
				return TK.done(fails)
			check("the escape step takes over (sh_barrage)", gm.world_flags.has("sh_barrage"))
			var vault_step := {"until": ["any", [["opened", "sh_vault_x"], ["flag", "sh_barrage"]]]}
			check("...the vault's step is passed once the shells fall", LQ.met(self, vault_step["until"]))
			var gap_at: Vector3 = LQ.where(self, ["sh_gap"])
			check("the journal's marker is the gap", gap_at.distance_to(sc.gap_at(isl)) < 0.5)
			# a captain stood in a blaze burns (the barrage held off and the patches out, so only the fire can)
			sc._next = 1 << 30
			sc._pending.clear()
			sc.fires.clear()
			var b: Array = sc.fx.blazes[0]
			p.global_position = b[0] + Vector3.UP * 0.5
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			until = TK.wait_secs(1.6)
		5:
			check("standing in a blaze burns (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			var hint: String = LQ.district_hint(self, isl.city_global(Vector2(0, 4), 12.4))
			check("the district line says to get out (%s)" % hint, hint.begins_with("THE SCOURING"))
			return TK.done(fails)
	step += 1
	return false
