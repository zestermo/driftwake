extends SceneTree
## A rum is a swig with the bottle in hand, taken from the bag at the start, healing only at the end; the shared
## cooldown then refuses the next heal (a tonic, or a biscuit as the quick item).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hp0 := 0.0
var n0 := 0
var refused := 0
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


func hp() -> float:
	return p.health_component.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			for id in ["rum", "tonic", "biscuit"]:
				p.inventory_component.add_item(item(id), 3)
			p.quick_refused.connect(func(): refused += 1)
			p.heal_cd = 0.0
			p.health_component.current_health = 20.0
			# (mid-fight: no out-of-combat regen muddling the heal)
			p._since_hit = 0.0
			hp0 = hp()
			n0 = p.inventory_component.count("rum")
			p.use_item(item("rum"))
			check("rum: the swig plays with a bottle in hand", p.is_using_item() and p.body_model.current_action() == "swig"
				and p.body_model._left_prop != null and str(p.body_model._left_prop.mesh.get_meta("model")) == "bottle")
			check("rum: taken from the bag at the start", p.inventory_component.count("rum") == n0 - 1)
			until = TK.wait_secs(0.4)
		1:
			check("rum: no heal mid-swig", hp() == hp0 and p.is_using_item())
			until = TK.wait_secs(0.4)
		2:
			var want: float = item("rum").heal_amount * (1.0 + p.progression.stat("potion_pct"))
			check("rum: heals %d at the end of the swig (%.1f)" % [int(want), hp() - hp0], absf(hp() - hp0 - want) < 0.5)
			check("the shared cooldown is running", p.heal_cd > 0.0 and p.heal_cd < p.HEAL_CD)
			var n: int = p.inventory_component.count("tonic")
			p.use_item(item("tonic"))
			check("the shared cooldown refuses a tonic", not p.is_using_item() and p.inventory_component.count("tonic") == n and refused == 1)
			p.inventory_component.select_quick("biscuit")
			var nb: int = p.inventory_component.count("biscuit")
			p.use_quick()
			check("...and the quick item (a biscuit)", not p.is_using_item() and p.inventory_component.count("biscuit") == nb and refused == 2)
			return TK.done(fails)
	step += 1
	return false
