extends SceneTree
## Stealth is learned by sneaking near foes: crouch-walking a few metres with a grunt about teaches it (and finds
## the tree); Soft Step (bought at Stealth 2) sneaks faster; with Ambush (Stealth 4) a blow struck straight out of a sneak
## lands harder (an extra share on the foe) and teaches more; a second blow isn't a sneak attack.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var step := 0
var until := 0
var fails := 0
var x0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -16), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func xp() -> int:
	return int(pr.mastery_of("stealth")["xp"])


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = p.get_tree().get_nodes_in_group("enemies")[0]
			p.state_machine.force_state("Crouch", {})
			x0 = p.global_position.x
			TK.press("move_right")
			until = TK.wait_secs(2.5)
		1:
			TK.release("move_right")
			var walked: float = p.global_position.x - x0
			print("   sneaked %.1f m (%s): stealth xp %d" % [walked, p.current_state_name(), xp()])
			check("sneaking near a foe teaches Stealth and finds its tree", xp() > 0 and "stealth" in pr.visible_trees("adventure"))
			pr.add_life("stealth", pr.mastery_to_next(pr.mastery_level("stealth")) - int(pr.mastery_of("stealth")["xp"]))
			check("Stealth 2: Soft Step bought, a faster sneak", pr.buy("st_soft") and is_equal_approx(pr.stat("sneak_pct"), 0.25))
			while pr.mastery_level("stealth") < 4:
				pr.add_life("stealth", pr.mastery_to_next(pr.mastery_level("stealth")))
			check("Stealth 4: Ambush bought", pr.buy("st_ambush"))
			var hp0: float = g.health.current_health
			var x1 := xp()
			var hit := HitData.new()
			hit.damage = 20.0
			pr.sneak(0.0)
			pr.on_hit(g, hit)
			print("   ambush: %.0f -> %.0f" % [hp0, g.health.current_health])
			check("a blow out of a sneak: Ambush's extra share lands (%.0f)" % (hp0 - g.health.current_health), g.health.current_health < hp0)
			check("...and teaches more Stealth", xp() > x1)
			var hp1: float = g.health.current_health
			pr.on_hit(g, hit)
			check("a second blow is no sneak attack", g.health.current_health == hp1)
			return TK.done(fails)
	step += 1
	return false
