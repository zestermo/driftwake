extends SceneTree
## Gear stats (1.24): a piece's weight and stats from its slot and weight, its tier scaling them (not the drawbacks),
## purple and up a second stat, the same numbers from the same id (an old save's piece), a looted roll that saves and
## loads, and what's worn reaching the captain (stamina, speed, defence).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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
			var gs = load("res://scripts/items/gear_stats.gd")
			var gear = load("res://scripts/loot/gear.gd")
			var save = load("res://scripts/game/save_game.gd")
			var bandana = gear.make("head", "bandana", {"hat": "bandana"}, "", 0)
			var morion = gear.make("head", "morion", {"hat": "morion"}, "", 0)
			var mail = gear.make("vest", "mail", {"vest": "mail"}, "", 0)
			check("a bandana is light: +3% crit", gs.weight(bandana) == gs.LIGHT and gs.of(bandana) == {"crit_all": 0.03})
			check("a morion is heavy: +8 defence, -3% stamina regen", gs.weight(morion) == gs.HEAVY
				and is_equal_approx(morion.armor(), 8.0) and is_equal_approx(gs.of(morion)["stamina_regen_pct"], -0.03))
			check("mail: +16 defence, +10% poise", is_equal_approx(mail.armor(), 16.0) and is_equal_approx(gs.of(mail)["poise_pct"], 0.1))
			check("a light hat keeps its own felt (tricorn-style defence)", bandana.armor() > 0.0)
			var gold = gear.make("head", "morion", {"hat": "morion"}, "", 4)
			var gs4: Dictionary = gs.of(gold)
			check("gold scales the good numbers x1.75 (%.1f)" % gold.armor(), is_equal_approx(gold.armor(), 14.0))
			check("...not the drawback", is_equal_approx(gs4["stamina_regen_pct"], -0.03))
			check("...and a heavy hat at gold has a second stat (%s)" % str(gs4), gs4.size() == 3)
			var blue: Dictionary = gs.of(gear.make("head", "morion", {"hat": "morion"}, "", 2))
			check("blue has none", blue.size() == 2)
			var green: Dictionary = gs.of(gear.make("head", "bandana", {"hat": "bandana"}, "", 1))
			check("green x1.15 (%.4f)" % green["crit_all"], is_equal_approx(green["crit_all"], 0.035))
			var medium: Dictionary = gs.of(gear.make("vest", "jerkin", {"vest": "jerkin"}, "", 3))
			check("a purple piece with two already gets no third", medium.size() == 2 and medium.has("damage_pct"))
			var ear: Dictionary = gs.of(gear.make("accessory", "earring", {"earring": true}, "", 0))
			check("an earring: +5% gold", ear == {"gold_pct": 0.05})
			# the same id, the same stats (an old save's piece)
			gs._cache.clear()
			var again: Dictionary = gs.of(gold)
			check("the same id rolls the same second stat", again == gs4)
			# a looted purple roll saves and loads
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			var loot = gear.random_piece(rng, 3)
			var ref: Array = save.item_ref(loot)
			gs._cache.clear()
			var back = save.item_from(ref)
			check("a looted piece's roll rides in its id and save (%s)" % loot.id, loot.gear_roll != 0 and back.id == loot.id and gs.of(back) == gs.of(loot))
			var old = save.item_from(ref.slice(0, 6))
			check("a pre-1.24 ref still loads, stats from its id", old != null and old.gear_roll == 0 and gs.of(old).size() >= 1)
			# worn
			var st0: float = p.max_stamina
			var mv0: float = p.move_speed
			var def0: float = p.defense()
			p.equipment.clear()
			p.refresh_look()
			st0 = p.max_stamina
			mv0 = p.move_speed
			def0 = p.defense()
			p.equipment.equip(gear.make("torso", "shirt", {"top": "shirt"}, "", 0))
			p.equipment.equip(gear.make("coat", "greatcoat", {"coat": "greatcoat"}, "", 0))
			p.refresh_look()
			check("a shirt: +5 stamina (%.0f -> %.0f)" % [st0, p.max_stamina], is_equal_approx(p.max_stamina - st0, 5.0))
			check("a greatcoat: 5% slower (%.2f -> %.2f)" % [mv0, p.move_speed], is_equal_approx(p.move_speed, mv0 * 0.95))
			check("...and +12 defence over the shirt's felt (%.1f)" % (p.defense() - def0), p.defense() - def0 >= 12.0)
			p.equipment.clear()
			p.refresh_look()
			check("off again: back as it was", is_equal_approx(p.max_stamina, st0) and is_equal_approx(p.move_speed, mv0))
			return TK.done(fails)
	step += 1
	return false
