extends SceneTree
## Eating mid-fight is one tap: E tapped during a swing waits for the swing to end and then drinks from the tonic flask (1.25.2: the quick item)
## (the tap isn't lost); tapped again on the shared cooldown, it's refused at once (the bar flashes).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var refused := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "cutlass", "hud": false})


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
			p.quick_refused.connect(func(): refused += 1)
			p.health_component.current_health = 30.0
			TK.act("light_attack")
			until = TK.wait_ticks(3)
		1:
			check("swinging (%s)" % p.current_state_name(), p.current_state_name() == "LightAttack")
			TK.act("quick_item")
			until = TK.wait_ticks(2)
		2:
			check("no drink mid-swing", not p.is_using_item() and p.inventory_component.count("tonic_flask") == 3)
			until = TK.wait_secs(0.8)
		3:
			check("the swing over, the tonic flask comes out (%s)" % p.body_model.current_action(), p.is_using_item() and p.body_model.current_action() == "tonic" and p.inventory_component.count("tonic_flask") == 2)
			until = TK.wait_secs(1.2)
		4:
			TK.act("quick_item")
			until = TK.wait_ticks(2)
		5:
			check("on the shared cooldown: refused at once", refused == 1 and not p.is_using_item() and p.inventory_component.count("tonic_flask") == 2)
			return TK.done(fails)
	step += 1
	return false
