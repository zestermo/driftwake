extends SceneTree
## 1.23 beast pass: the Bear King. Phase 1 mauls, charges and swats (no Body Slam yet); phase 2 adds the Body Slam and
## the Fish-scoop, phase 3 the Frenzy and the Avalanche Roar (icicles crash down on the captain); each phase change is a
## moment. Its claws broken: the Frenzy is two swipes, not four, and a claw drops; its hide torn: blows there do double.
## Its poise broken: it reels on its feet with double damage, never knocked down.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hp() -> float:
	return p.get_node("HealthComponent").current_health


func _drop_has(id: String) -> bool:
	for n in current_scene.get_children():
		if str(n.name).begins_with("Drop_") and n.contents.any(func(s): return s.item.id == id):
			return true
	return false


func blow(dmg: float, poise: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = poise
	h.impact = "punch"
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var th = load("res://scripts/island/themes/island_themes.gd").of("snow")
			var at: Vector3 = p.global_position + Vector3(0, 0, -7.0)
			b = load(th.beasts["great_bear"]["script"]).new()
			b.setup({"post": at, "yaw": 0.0, "level": 6, "name": "The Bear King"})
			stage.add_child(b)
			b.global_position = at
			until = TK.wait_ticks(10)
		1:
			var m: Array = b.bp.moves()
			check("phase 1: maul, charge, swat, no slam yet (%s)" % str(m), m.size() == 3 and "maul" in m and not "slam" in m)
			b.alert()
			check("woken it rears and roars", b.move == "roar")
			until = TK.wait_secs(2.0)
		2:
			b.health.current_health = b.health.max_health * 0.55
			b._phase_check()
			check("below 60%: phase 2 and its moment", b.phase == 2 and b.move == "moment")
			until = TK.wait_secs(2.8)
		3:
			var m: Array = b.bp.moves()
			check("phase 2 adds the Body Slam and the Fish-scoop (%s)" % str(m), "slam" in m and "scoop" in m and not "frenzy" in m)
			b.health.current_health = b.health.max_health * 0.25
			b._phase_check()
			until = TK.wait_secs(2.8)
		4:
			var m: Array = b.bp.moves()
			check("phase 3 adds the Frenzy and the Avalanche Roar (%s)" % str(m), "frenzy" in m and "avalanche" in m)
			check("...foaming, eyes red", b._foam != null and b._eye_mi.material_override != null)
			# (filmed on its own: no chain carrying on after it)
			b.end_move()
			b.bp.chain_over()
			b.film("frenzy")
			until = TK.wait_secs(2.3)
		5:
			check("the Frenzy: four swipes (%d)" % b._n, b._n == 4)
			b.part_hit("claws", 99999.0)
			b.end_move()
			b._set_state(1)
			b.bp.chain_over()
			b.film("frenzy")
			until = TK.wait_secs(2.0)
		6:
			check("claws broken: two swipes (%d), claws gone" % b._n, b._n == 2 and not b.rig["ClawsFL"].visible)
			check("...and a Bear King Claw drops", _drop_has("bear_claw"))
			b.end_move()
			hp0 = _hp()
			p.global_position = b.global_position + b._fwd() * 6.0
			p.reset_physics_interpolation()
			b.film("avalanche")
			until = TK.wait_secs(2.8)
		7:
			check("the Avalanche Roar's icicles come down on the captain (%.0f)" % (hp0 - _hp()), _hp() < hp0)
			b.part_hit("hide", 99999.0)
			# (a blow from behind, at its haunches)
			p.global_position = b.global_position - b._fwd() * 3.2
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
		8:
			check("hide torn: a raw patch, double damage there (x%.1f)" % b._taken_k(p), b.rig["Patch"].visible and absf(b._taken_k(p) - 2.0) < 0.01)
			b.end_move()
			b._set_state(1)
			until = TK.wait_secs(4.5)
		9:
			p.global_position = b.global_position + b._fwd() * 3.0
			p.reset_physics_interpolation()
			b.end_move()
			b.mv_t = 0.0
			for i in range(12):
				b._on_hit(blow(5.0, 60.0), p)
			check("heavy blows break its poise: it reels on its feet (state %d)" % b.state, b.state == 2 and b.bp.vulnerable())
			var hp: float = b.health.current_health
			b._on_hit(blow(10.0, 6.0), p)
			check("...double damage (%.0f)" % (hp - b.health.current_health), absf(hp - b.health.current_health - 20.0) < 0.5)
			return TK.done(fails)
	step += 1
	return false
