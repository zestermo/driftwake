extends SceneTree
## Hurtboxes and interactables are found, they don't look (no monitoring: Jolt pays for every area that does), and
## still work: walking up to the chest brings up its prompt and F opens it; a swing still lands on the dummy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": true, "chest": [["treasure", 1]], "weapon": "cutlass"})


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
			var watching: Array = []
			var quiet := ["res://scenes/combat/hurtbox.gd", "res://scripts/interaction/interactable.gd", "res://scripts/interaction/seat.gd"]
			for a in root.find_children("*", "Area3D", true, false):
				if a.get_script() != null and a.get_script().resource_path in quiet and (a as Area3D).monitoring:
					watching.append(str(a.get_path()))
			check("no hurtbox or interactable monitors %s" % str(watching), watching.is_empty())
			check("...the captain's hurtbox is still found", p.hurtbox.monitorable)
			var bag_it: Array = stage.chest.find_children("*", "Area3D", true, false)
			check("...and the chest's", not bag_it.is_empty() and (bag_it[0] as Area3D).monitorable)
			check("the captain's interaction zone still looks", p.interaction_component.monitoring)
			p.global_position = stage.chest.global_position + Vector3(-1.2, 0.05, 0.0)
			p.reset_physics_interpolation()
			# (what's in it as it is: the economy's roll is t/economy's)
			stage.chest.rolled = true
			until = TK.wait_ticks(10)
		1:
			var it = p.interaction_component.current_interactable
			check("next to the chest its prompt comes up (%s)" % (it.prompt_text if it else "none"), it != null and stage.chest.is_ancestor_of(it))
			TK.act("interact")
			until = TK.wait_secs(0.5)
		2:
			check("F on the chest takes its treasure", p.inventory_component.count("treasure") == 1)
			p.global_position = stage.dummy.global_position + Vector3(1.4, 0.05, 0)
			p.reset_physics_interpolation()
			stage.camera_rig.rotation.y = PI * 0.5
			hp0 = float(stage.dummy.get_node("HealthComponent").current_health)
			until = TK.wait_secs(0.6)
		3:
			TK.act("light_attack")
			until = TK.wait_secs(0.75)
		4:
			if not p.is_free() or p.body_model.current_action() != "":
				return false
			check("a swing still lands on the dummy", float(stage.dummy.get_node("HealthComponent").current_health) < hp0)
			return TK.done(fails)
	step += 1
	return false
