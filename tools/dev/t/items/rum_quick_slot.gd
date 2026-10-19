extends SceneTree
## A tap of the quick-item key (E) drinks the selected rum, and the rum heals.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "cutlass"})


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
			p.health_component.take_damage(50)
			TK.act("quick_item")
			until = TK.wait_secs(0.2)
		1:
			check("a tap of E drinks the rum (%s)" % p.body_model.current_action(), p.body_model.current_action() == "swig" and p.inventory_component.count("rum") == 2)
			until = TK.wait_secs(1.0)
		2:
			print("   hp ", p.health_component.current_health)
			check("rum healed (%.0f hp)" % p.health_component.current_health, p.health_component.current_health >= 50.0 + load("res://resources/items/rum.tres").heal_amount - 0.5)
			return TK.done(fails)
	step += 1
	return false
