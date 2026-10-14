extends SceneTree
## Quick-slot healing: the heal lands at the end of the action, a hit spills it (item gone, no heal,
## a short retry cooldown), the shared cooldown refuses a second use, each item plays its own action.
const TK := preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var until := 0
var p
var fails := 0
var saw := {}
var foe: Node3D


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id)


func hp() -> float:
	return p.health_component.current_health


func start(id: String) -> void:
	p.state_machine.force_state("Idle", {})
	p.heal_cd = 0.0
	p.health_component.current_health = 20.0
	saw["hp"] = hp()
	saw["n"] = p.inventory_component.count(id)
	p.use_item(item(id))


func _process(d: float) -> bool:
	t += d
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 1.5:
				return false
			p = root.get_tree().get_first_node_in_group("player")
			for id in ["rum", "tonic", "stew", "biscuit"]:
				p.inventory_component.add_item(item(id), 3)
			p.quick_refused.connect(func(): saw["refused"] = int(saw.get("refused", 0)) + 1)
			foe = Node3D.new()
			root.add_child(foe)
			foe.global_position = p.global_position + Vector3(0, 0, -1.5)
			start("rum")
			check("rum: the swig plays with a bottle in hand", p.is_using_item() and p.body_model.current_action() == "swig"
				and p.body_model._left_prop != null and str(p.body_model._left_prop.mesh.get_meta("model")) == "bottle")
			check("rum: taken from the bag at the start", p.inventory_component.count("rum") == int(saw["n"]) - 1)
			until = TK.wait_secs(0.4)
			step += 1
		1:
			check("rum: no heal mid-swig", hp() == float(saw["hp"]) and p.is_using_item())
			until = TK.wait_secs(0.4)
			step += 1
		2:
			var want: float = item("rum").heal_amount * (1.0 + p.progression.stat("potion_pct"))
			check("rum: heals %d at the end of the swig (%.1f)" % [int(want), hp() - float(saw["hp"])], absf(hp() - float(saw["hp"]) - want) < 0.5)
			check("the shared cooldown is running", p.heal_cd > 0.0 and p.heal_cd < p.HEAL_CD)
			var n: int = p.inventory_component.count("tonic")
			p.use_item(item("tonic"))
			check("the shared cooldown refuses a tonic", not p.is_using_item() and p.inventory_component.count("tonic") == n and int(saw.get("refused", 0)) == 1)
			p.inventory_component.assign_hotbar(1, "biscuit")
			var nb: int = p.inventory_component.count("biscuit")
			p.activate_hotbar(1)
			check("...and quick slot 6 (biscuit)", not p.is_using_item() and p.inventory_component.count("biscuit") == nb and int(saw.get("refused", 0)) == 2)
			until = TK.wait_secs(0.3)
			step += 1
		3:
			# --- a hit spills a tonic
			start("tonic")
			check("tonic: uncork and drink with a flask", p.body_model.current_action() == "tonic" and str(p.body_model._left_prop.mesh.get_meta("model")) == "flask")
			until = TK.wait_secs(0.3)
			step += 1
		4:
			var hd := HitData.new()
			hd.damage = 6.0
			p.hurtbox.take_hit(hd, foe)
			saw["hit_hp"] = hp()
			check("a hit mid-drink spills it", not p.is_using_item() and p.body_model.current_action() != "tonic")
			check("...the tonic's gone", p.inventory_component.count("tonic") == int(saw["n"]) - 1)
			check("...and the cooldown drops to the retry (%.2f)" % p.heal_cd, p.heal_cd <= p.HEAL_RETRY)
			until = TK.wait_secs(1.2)
			step += 1
		5:
			check("...and its heal never lands (%.1f -> %.1f)" % [float(saw["hit_hp"]), hp()], hp() < float(saw["hit_hp"]) + 2.0)
			check("the bottle's out of the hand", p.body_model._left_prop == null)
			until = TK.wait_secs(0.6)
			step += 1
		6:
			start("stew")
			check("stew: slurped from a bowl", p.body_model.current_action() == "slurp" and str(p.body_model._left_prop.mesh.get_meta("model")) == "bowl")
			until = TK.wait_secs(1.2)
			step += 1
		7:
			check("stew heals at the end", hp() > float(saw["hp"]) + 40.0)
			start("biscuit")
			check("biscuit: a bite of food", p.body_model.current_action() == "bite" and str(p.body_model._left_prop.mesh.get_meta("model")) == "food")
			Input.action_press("move_forward")
			until = TK.wait_secs(0.3)
			step += 1
		8:
			var v := Vector2(p.velocity.x, p.velocity.z).length()
			check("walking while eating is slower (%.2f m/s)" % v, v > 0.5 and v < p.move_speed * 0.6)
			Input.action_release("move_forward")
			until = TK.wait_secs(0.8)
			step += 1
		9:
			p.inventory_component.assign_hotbar(2, "tonic")
			check("the galley doesn't brew tonics", not str(root.get_node("GameManager").restock(p)).contains("Sea Tonic"))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
