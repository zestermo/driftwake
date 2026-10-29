extends SceneTree
## The tonic flask (1.26, docs/v1_26_plan.md "Healing"): every captain's, three draughts (its stack), each mending 40%
## of max health on the quick-slot cooldown; resting at an inn tops it up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


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
			p.refill_flask()
			check("a full flask, three draughts, among the quick slot's choices (%d)" % p.inventory_component.count(p.FLASK),
				p.inventory_component.count(p.FLASK) == 3 and p.inventory_component.quick_choices().has(ItemDB.get_item(p.FLASK)))
			p.health_component.current_health = p.health_component.max_health * 0.3
			hp0 = p.health_component.current_health
			p.use_item(ItemDB.get_item(p.FLASK))
			until = TK.wait_secs(1.5)
		1:
			var got: float = (p.health_component.current_health - hp0) / p.health_component.max_health
			check("a draught mends about 40%% of your health (%.0f%%)" % (got * 100.0), got > 0.36 and got < 0.48)
			check("...and spends one (%d left)" % p.inventory_component.count(p.FLASK), p.inventory_component.count(p.FLASK) == 2)
			var said: String = root.get_node("GameManager").rest(p)
			check("resting tops it up (%d, '%s')" % [p.inventory_component.count(p.FLASK), said], p.inventory_component.count(p.FLASK) == 3 and "flask" in said)
			return TK.done(fails)
	step += 1
	return false
