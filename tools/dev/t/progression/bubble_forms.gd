extends SceneTree
## The Bubble Fruit (1.27): its item, fruit and tree; Bubble Shield takes the next 3 hits and no more; Slick Floor casts;
## at Reflex (150 uses, mastery 12) a bubble forms by itself under 30% health, at most once every 20 s.
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


func _taken(hp_frac: float) -> float:
	var p = stage.player
	var hc = p.health_component
	hc.current_health = hc.max_health * hp_frac
	var before: float = hc.current_health
	p.state_machine.force_state("Idle", {})
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 5.0
	hd.knockback_force = 0.0
	p._on_hit_received(hd, null)
	return before - hc.current_health


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var p = stage.player
	var pr = p.progression
	check("the Bubble Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("bubble_fruit") != null
		and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("bubble") and load("res://scripts/progression/skill_trees.gd").nodes().has("bb_shield"))
	p.power.fruit = "bubble"
	p.power.loadout[0] = "bubble_shield"
	p.power.loadout[1] = "slick_floor"
	p.power.energy = p.power.max_energy()
	p.power.cooldowns.clear()
	p.state_machine.force_state("Idle", {})
	check("Bubble Shield casts", p.power.try_cast(0))
	var popped := 0
	for i in range(4):
		if _taken(1.0) == 0.0:
			popped += 1
	check("...takes the next 3 hits, not a 4th (%d)" % popped, popped == 3)
	p.state_machine.force_state("Idle", {})
	p.power.energy = p.power.max_energy()
	check("Slick Floor casts", p.power.try_cast(1))
	check("at Active, nothing forms when you're hurt", _taken(0.2) > 0.0)
	pr.uses["bubble_shield"] = 150
	pr.mastery["bubble"] = {"lv": 12, "xp": 0}
	check("Reflex: above 30% no bubble; under it one forms by itself, once in 20 s", _taken(0.8) > 0.0 and _taken(0.2) == 0.0 and _taken(0.2) > 0.0)
	return TK.done(fails)
