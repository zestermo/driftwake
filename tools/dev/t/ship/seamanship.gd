extends SceneTree
## Seamanship: a tab of its own on the skill map, a mastery tree owned from its root; sailing at the helm and
## a ship sunk nearby earn its mastery; its bonuses count at the station you man: the helm (faster, sharper,
## and on the ship's snapshot for the other screens), a gun (reloads faster, balls hit harder), deck jobs
## (patching faster); and it's saved with the captain.
const TK := preload("res://tools/dev/test_kit.gd")
var ST
var stage
var p
var pr
var ship
var gun
var step := 0
var until := 0
var fails := 0
var xp0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func sea_xp() -> int:
	var m: Dictionary = pr.mastery_of("sea")
	var total := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		total += pr.mastery_to_next(lv)
	return total


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			ST = load("res://scripts/progression/skill_tree.gd")
			p = stage.player
			pr = p.progression
			ship = stage.ship
			check("Seamanship has its tab, a mastery tree", ST.TAB_ORDER.has("sea") and ST.is_mastery_tree("sea"))
			check("...its root owned from the start, 15 nodes", pr.owns("sea_root") and ST.nodes().keys().filter(func(k): return ST.nodes()[k]["tree"] == "sea").size() == 15)
			# sailing at the helm
			xp0 = sea_xp()
			ship.is_player_steering = true
			ship.sail = 1.0
			ship.speed = 10.0
			until = TK.wait_secs(4.0)
		1:
			print("   sea xp %d -> %d" % [xp0, sea_xp()])
			check("sailing at the helm earns Seamanship", sea_xp() > xp0)
			check("...no bonus at the helm without the tree", ship._helm_k == Vector3.ONE)
			pr.mastery_of("sea")["pts"] = 20
			for id in ["sea_trim", "sea_turn", "sea_load", "sea_gunner", "sea_carp"]:
				pr.learn(id)
			check("learned with mastery points", pr.owns("sea_trim") and pr.owns("sea_carp") and int(pr.mastery_of("sea")["pts"]) == 15)
			until = TK.wait_ticks(3)
		2:
			check("at the helm: 4%% faster, 8%% sharper (%s)" % str(ship._helm_k), is_equal_approx(ship._helm_k.x, 1.04) and is_equal_approx(ship._helm_k.y, 1.08))
			var pack: Array = ship.net_pack()
			check("...on her snapshot for the other screens", is_equal_approx(float(pack[15]), 1.04) and bool(pack[18]))
			ship.is_player_steering = false
			ship.speed = 0.0
			ship.sail = 0.0
			until = TK.wait_ticks(3)
		3:
			check("...and only while you steer", ship._helm_k == Vector3.ONE)
			check("a patch takes 30%% less long (%.2f s)" % ship.job_time("patch"), is_equal_approx(ship.job_time("patch"), ship.PATCH_TIME / 1.3))
			gun = ship.cannons[0]
			gun.aiming_locally = true
			gun.cool = 1.0
			until = TK.wait_ticks(30)
		4:
			print("   cool after 0.5 s manned: %.3f" % gun.cool)
			check("a gun you man reloads 15% faster", gun.cool < 0.5 - 0.06 and gun.cool > 0.3)
			gun.cool = 0.0
			gun.fire(p)
			var balls := get_nodes_in_group("cannonballs")
			var ball = balls.back() if not balls.is_empty() else null
			check("balls you fire hit 10%% harder (%.1f)" % (ball.hull_damage if ball else 0.0), ball != null and is_equal_approx(ball.hull_damage, 33.0))
			gun.aiming_locally = false
			# a brig sunk close by
			xp0 = sea_xp()
			var es = load("res://scripts/ship/enemy_ship.gd").new().setup(Vector3(95, 0, 30), 20.0, 0.0, 99, "brig")
			es.position = Vector3(95, 0, 30)
			stage.add_child(es)
			es.call_deferred("_start_sink")
			until = TK.wait_ticks(10)
		5:
			check("a brig sunk close by: +60 Seamanship (%d)" % (sea_xp() - xp0), sea_xp() - xp0 == 60)
			var d: Dictionary = pr.to_dict()
			pr.from_dict({})
			check("...forgotten on a blank load", not pr.owns("sea_trim"))
			pr.from_dict(d)
			check("Seamanship is saved with the captain", pr.owns("sea_trim") and pr.mastery_of("sea") == d["mastery"]["sea"])
			return TK.done(fails)
	step += 1
	return false
