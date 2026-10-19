extends SceneTree
## Each food plays its own action: stew slurped from a bowl (heals at the end), a biscuit bitten (you walk slower
## while eating).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id)


func start(id: String) -> void:
	p.state_machine.force_state("Idle", {})
	p.heal_cd = 0.0
	p.health_component.current_health = 20.0
	hp0 = p.health_component.current_health
	p.use_item(item(id))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			for id in ["stew", "biscuit"]:
				p.inventory_component.add_item(item(id), 3)
			start("stew")
			check("stew: slurped from a bowl", p.body_model.current_action() == "slurp" and str(p.body_model._left_prop.mesh.get_meta("model")) == "bowl")
			until = TK.wait_secs(1.2)
		1:
			check("stew heals at the end", p.health_component.current_health > hp0 + 40.0)
			start("biscuit")
			check("biscuit: a bite of food", p.body_model.current_action() == "bite" and str(p.body_model._left_prop.mesh.get_meta("model")) == "food")
			Input.action_press("move_forward")
			until = TK.wait_secs(0.3)
		2:
			var v := Vector2(p.velocity.x, p.velocity.z).length()
			check("walking while eating is slower (%.2f m/s)" % v, v > 0.5 and v < p.move_speed * 0.6)
			Input.action_release("move_forward")
			return TK.done(fails)
	step += 1
	return false
