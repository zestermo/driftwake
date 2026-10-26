extends SceneTree
## 1.23 masters: Hana Teal's test ("master:black_leg", from her dialogue): her pupil Tomo steps up in front of you,
## bare-handed and kicking; put him down and you've learned black leg (the tree shows, Dialogue flag "master_black_leg");
## nothing paid, he leaves.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var bout
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
	match step:
		0:
			p = stage.player
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			check("(not taught yet)", not p.knows_black_leg())
			root.get_node("Net").request_arena("master:black_leg", 0)
			until = TK.wait_secs(0.5)
		1:
			var bouts := get_nodes_in_group("arena_bouts")
			bout = bouts[0] if not bouts.is_empty() else null
			check("the test starts: Tomo steps up", bout != null and is_instance_valid(bout.rival))
			if bout:
				check("...bare-handed, kicking (%s)" % bout.rival.style(), bout.rival.equipped_weapon == null and bout.rival.style() == "black_leg")
				check("...in front of you (%.1f m)" % bout.rival.global_position.distance_to(p.global_position), bout.rival.global_position.distance_to(p.global_position) < 12.0)
				bout.rival.health_component.current_health = 1.0
			until = TK.wait_secs(0.5)
		2:
			check("put him down: black leg learned", p.knows_black_leg() and p.progression.visible_trees("combat").has("black_leg"))
			check("...remembered (Hana won't offer again)", root.get_node("Dialogue").has_flag("master_black_leg"))
			return TK.done(fails)
	step += 1
	return false
