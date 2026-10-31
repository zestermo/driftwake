extends SceneTree
## The Iron Fruit (1.27): its item, its fruit and its tree are there; Iron Guard by its form (FruitForms,
## Player._iron_guard): Active, cast, blows do half damage; Reflex (150 uses, mastery 12), a heavy blow meets iron by
## itself, at most once every 8 s, a light one doesn't; Nature (400, 24), anything short of a technique; Iron Fist casts.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _hd(dmg: float, heavy: bool):
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = dmg
	hd.knockback_force = 0.0
	hd.knockdown = heavy
	return hd


func _taken(hd) -> float:
	var hc = stage.player.health_component
	hc.current_health = hc.max_health
	stage.player.state_machine.force_state("Idle", {})
	stage.player._on_hit_received(hd, null)
	return hc.max_health - hc.current_health


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var pr = p.progression
	check("the Iron Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("iron_fruit") != null
		and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("iron") and load("res://scripts/progression/skill_trees.gd").nodes().has("i_guard"))
	p.power.fruit = "iron"
	var full := _taken(_hd(20.0, false))
	p.power.loadout[0] = "iron_guard"
	p.power.loadout[1] = "iron_fist"
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()
	p.state_machine.force_state("Idle", {})
	check("Iron Guard cast", p.power.try_cast(0))
	var guarded := _taken(_hd(20.0, false))
	check("...blows do half damage (%.1f, was %.1f)" % [guarded, full], guarded > 0.0 and guarded <= full * 0.55)
	p.power.buffs.clear()
	pr.uses["iron_guard"] = 150
	pr.mastery["iron"] = {"lv": 12, "xp": 0}
	check("Reflex: a light blow isn't met by iron", _taken(_hd(20.0, false)) >= full * 0.9)
	check("...a heavy one is (once in 8 s)", _taken(_hd(20.0, true)) <= full * 0.55 and _taken(_hd(20.0, true)) >= full * 0.9)
	pr.uses["iron_guard"] = 400
	pr.mastery["iron"] = {"lv": 24, "xp": 0}
	check("Nature: anything short of a technique meets iron", _taken(_hd(20.0, true)) <= full * 0.55)
	p.state_machine.force_state("Idle", {})
	p.power.energy = p.power.max_energy()
	check("Iron Fist casts", p.power.try_cast(1))
	return TK.done(fails)
