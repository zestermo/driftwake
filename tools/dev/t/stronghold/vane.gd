extends SceneTree
## Commodore Aurel Vane in the Command Hall (1.27, StrongholdBoss, the end): walk in and he's there (a captain-style
## AI, katana and pistol, a boss's health) behind the grate; at 65% the fortress answers (marines pour in, the hall's
## quarters flare in turn); at 30% the Verdict (a second blade, enraged); beaten, "sh_seal_keep" and the grate rises.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var bnode
var vane
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
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
			bnode = isl.city.get_node("Boss_vane")
			p.global_position = bnode.to_global(Vector3(0.0, 0.6, 18.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		3:
			vane = isl.city.get_node_or_null("BossVane")
			check("walk in: Commodore Vane is there", vane != null and vane.is_ai and str(vane.net_profile.get("name", "")) == "Commodore Aurel Vane")
			if vane == null:
				return TK.done(fails)
			check("...a boss's health (%.0f), the grate down" % vane.health_component.max_health, vane.health_component.max_health >= 1100.0 and bnode.grate_shut())
			vane.get_node("Brain").order = "hold"
			vane.health_component.take_damage(vane.health_component.max_health * 0.4)
			until = TK.wait_secs(5.0)
		4:
			var adds = isl.city.get_node_or_null("Encounter_adds_vane")
			check("at 65%% the fortress answers: phase %d, marines pour in (%d)" % [bnode.phase(), adds.alive_count() if adds else -1], bnode.phase() == 2 and adds != null and adds.alive_count() == 5)
			check("...and the hall's quarters flare in turn (%d zones)" % bnode.zones().size(), bnode.zones().size() == 4 and bnode._strips.size() == 4)
			vane.health_component.take_damage(vane.health_component.max_health * 0.4)
			until = TK.wait_secs(1.0)
		5:
			check("at 30%% the Verdict: phase %d, enraged (skill %.1f, ultimate %.0f)" % [bnode.phase(), vane.get_node("Brain").skill, vane.power.ult],
				bnode.phase() == 3 and vane.get_node("Brain").skill >= 1.0 and vane.power.ult > 0.0)
			vane.health_component.take_damage(vane.health_component.max_health * 2.0)
			until = TK.wait_secs(1.0)
		6:
			check("beaten: the keep is the crew's, the grate up", bnode.beaten() and root.get_node("GameManager").world_flags.has("sh_seal_keep") and not bnode.grate_shut())
			return TK.done(fails)
	step += 1
	return false
