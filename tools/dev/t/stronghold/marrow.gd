extends SceneTree
## Captain Ilse Marrow in the prison's yard (1.27, StrongholdBoss, an open arena): nobody until a captain comes into
## the yard; then she's there (a captain-style AI, a greatsword, a boss's health, under her name); at half health the
## cell block opens and its brutes come out (elite, berserk prisoners); beaten, the prison's seal is the crew's.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var bnode
var marrow
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
			bnode = isl.city.get_node("Boss_marrow")
			check("the prison's yard: nobody yet", isl.city.get_node_or_null("BossMarrow") == null)
			p.global_position = bnode.to_global(Vector3(6.0, 0.6, 0.0))
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		3:
			marrow = isl.city.get_node_or_null("BossMarrow")
			check("come into the yard: Captain Marrow is there", marrow != null and marrow.is_ai and str(marrow.net_profile.get("name", "")) == "Captain Ilse Marrow")
			if marrow == null:
				return TK.done(fails)
			check("...a greatsword in her hands, a boss's health (%.0f)" % marrow.health_component.max_health, marrow.health_component.max_health >= 700.0 and marrow.equipment != null)
			marrow.get_node("Brain").order = "hold"
			marrow.health_component.take_damage(marrow.health_component.max_health * 0.55)
			until = TK.wait_secs(5.0)
		4:
			var cells = isl.city.get_node_or_null("Encounter_cells_marrow")
			check("at half health (phase %d) the cell block opens: its brutes come out (%d)" % [bnode.phase(), cells.alive_count() if cells else -1],
				bnode.phase() == 2 and cells != null and cells.alive_count() == 4)
			if cells:
				check("...berserk prisoners, not marines", cells.grunts.all(func(g): return bool(g.elite_rank)))
			marrow.health_component.take_damage(marrow.health_component.max_health * 2.0)
			until = TK.wait_secs(1.0)
		5:
			check("beaten: the prison's seal is the crew's", bnode.beaten())
			var sg = isl.city.get_node("SealGate")
			check("...the keep's gate still shut: the Arsenal's seal is missing", not sg.open() and sg._grate.collision_layer == 1)
			root.get_node("GameManager").world_flags["sh_seal_arsenal"] = true
			until = TK.wait_ticks(3)
		6:
			var sg = isl.city.get_node("SealGate")
			check("both seals: the keep's gate opens", sg.open() and sg._grate.collision_layer == 0)
			return TK.done(fails)
	step += 1
	return false
