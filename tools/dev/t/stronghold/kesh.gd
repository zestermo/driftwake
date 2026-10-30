extends SceneTree
## Lieutenant Varro Kesh in the Casting Hall (1.27, StrongholdBoss): nobody until a captain walks in; then he's there
## (a captain-style AI with a boss's health, under his name) and the grate drops; at half health the sluices open
## (phase 2) and the molten channels run in turn, burning a captain who stands in the live one; beaten, the Arsenal's
## seal is the crew's and the grate rises.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var bnode
var kesh
var step := 0
var until := 0
var fails := 0
var tries := 0


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
			bnode = isl.city.get_node("Boss_kesh")
			check("the Casting Hall: nobody yet, its grate up", isl.city.get_node_or_null("BossKesh") == null and not bnode.grate_shut())
			var r: Rect2 = bnode.rm[2]
			p.global_position = isl.city.to_global(Vector3(r.get_center().x - 10.0, float(bnode.rm[3]) + 0.4, r.get_center().y - 4.5))
			p.reset_physics_interpolation()
			until = TK.wait_secs(2.0)
		3:
			kesh = isl.city.get_node_or_null("BossKesh")
			check("walk in: Lieutenant Kesh is there", kesh != null and kesh.is_ai and str(kesh.net_profile.get("name", "")) == "Lieutenant Varro Kesh")
			if kesh == null:
				return TK.done(fails)
			check("...with a boss's health (%.0f)" % kesh.health_component.max_health, kesh.health_component.max_health >= 400.0)
			check("...the grate down behind you", bnode.grate_shut() and bnode._grate.collision_layer == 1)
			# (he stands still for the test: we're timing the floor, not dodging him)
			kesh.get_node("Brain").order = "hold"
			kesh.health_component.take_damage(kesh.health_component.max_health * 0.55)
			until = TK.wait_secs(1.0)
		4:
			if tries == 0:
				check("at half health the sluices open (phase %d)" % bnode.phase(), bnode.phase() == 2)
			# wait for a channel to burn
			var now: Array = bnode.channel_now()
			tries += 1
			if str(now[1]) != "burn" and tries < 400:
				return false
			check("...the molten channels run in turn (channel %d burning)" % int(now[0]), int(now[0]) >= 0 and str(now[1]) == "burn")
			var r: Rect2 = bnode.rm[2]
			p.global_position = bnode.to_global(Vector3(-4.0, 0.4, float(bnode.CHANNELS[int(now[0])])))
			p.reset_physics_interpolation()
			bnode._hurt = 0.0
			until = TK.wait_secs(0.6)
		5:
			check("...and burn a captain standing in the live one", bnode._hurt > 0.0)
			kesh.health_component.take_damage(kesh.health_component.max_health * 2.0)
			until = TK.wait_secs(1.0)
		6:
			check("beaten: the Arsenal's seal is the crew's, the grate up", bnode.beaten() and not bnode.grate_shut() and bnode._grate.collision_layer == 0)
			return TK.done(fails)
	step += 1
	return false
