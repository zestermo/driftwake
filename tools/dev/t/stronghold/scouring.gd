extends SceneTree
## The Scouring (1.27, StrongholdScouring; grace and countdown shortened here): the Commodore's fall brings the
## broadcast and the garrison stands down; then the shells fall (telegraphed, burning patches, our captain hurt); the
## Admiral comes ashore, very tanky, and worn to 2/3 he leaves; the ship out past 500 m ends it.
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
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var gm = root.get_node("GameManager")
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
			check("nothing before the Commodore falls", sc.state == "")
			sc.grace = 1.0
			sc.count = 1.0
			sc.force_admiral = true
			gm.world_flags["sh_seal_keep"] = true
			until = TK.wait_secs(0.5)
		3:
			check("the broadcast: the grace before it (%s)" % sc.state, sc.state == "grace")
			check("...and the garrison stands down", isl.city.get_node("Garrison_ward").respawn_time > 1.0e8 and not isl.city.get_node("Officers").is_processing())
			# our captain out in the ward
			p.global_position = isl.city_global(Vector2(0, 4), 12.4)
			p.reset_physics_interpolation()
			hp0 = p.health_component.current_health
			until = TK.wait_secs(9.0)
		4:
			check("the Scouring: shells falling (%d so far, %d burning)" % [sc._next, sc.fires.size()], sc.state == "barrage" and sc._next >= 5 and sc.fires.size() >= 1)
			check("...our captain hurt by them (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			var adm = isl.city.get_node_or_null("Admiral")
			check("the Admiral comes ashore, very tanky (%.0f)" % (adm.health_component.max_health if adm else 0.0), adm != null and adm.health_component.max_health >= 2000.0)
			if adm:
				adm.health_component.take_damage(adm.health_component.max_health * 0.4)
			until = TK.wait_secs(1.0)
		5:
			check("worn to 2/3 he leaves", gm.world_flags.has("sh_admiral_gone"))
			var ship = get_first_node_in_group("ship")
			if ship == null:
				print("   (no ship on this stage: the escape check is skipped)")
				return TK.done(fails)
			var c: Vector3 = isl.city_global(load("res://scripts/island/stronghold_plan.gd").LAND_C, 0.0)
			ship.global_position = c + Vector3(620, 0, 0)
			until = TK.wait_secs(1.0)
		6:
			check("the ship out past 500 m: escaped, the Scouring over", gm.world_flags.has("sh_escaped") and sc.state == "escaped")
			return TK.done(fails)
	step += 1
	return false
