extends SceneTree
## The 1.25 pieces (Gear.LOOKS): each a named item in its slot with stats and an icon, sold or plundered somewhere;
## the Bulwark set (three heavy pieces) cheapens the guard and pays stamina on a parry; a full gold heavy kit with it
## still blocks no more than ~50%.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var gear = load("res://scripts/loot/gear.gd")
			var gs = load("res://scripts/items/gear_stats.gd")
			var shops = load("res://scripts/game/shops.gd")
			var placed := {}
			for e in gear.PLUNDER:
				placed[e[1]] = true
			for e in shops.RARE_GEAR:
				placed[e[1]] = true
			for id in shops.SHOPS.keys():
				for e in (shops.SHOPS[id]["stock"] as Array) + (shops.SHOPS[id].get("pool", []) as Array):
					if e.size() >= 4:
						placed[e[1]] = true
			for style in gear.LOOKS.keys():
				var it = gear.make(gear.LOOKS[style][0], style, gear.LOOKS[style][1], "", 0)
				var st: Dictionary = gs.of(it)
				check("%s: a %s piece named %s, %s" % [style, it.gear_slot, it.display_name, str(st)],
					it.gear_slot == gear.LOOKS[style][0] and gear.NAMES.has(style) and gear.DESCRIPTIONS.has(style) and not st.is_empty() and it.icon != null)
				check("%s is sold or plundered" % style, placed.has(style))
				var kept: Dictionary = gear.compose({}, {gear.LOOKS[style][0] if gear.LOOKS[style][0] != "accessory" else "acc1": it})
				var worn := true
				for k in (gear.LOOKS[style][1] as Dictionary).keys():
					worn = worn and kept.get(k) == gear.LOOKS[style][1][k]
				check("%s is worn as its garment" % style, worn)
			for s in ["bulwark_helm", "bulwark_brigandine", "bulwark_gauntlets"]:
				check("%s is heavy" % s, gs.weight(gear.make(gear.LOOKS[s][0], s, gear.LOOKS[s][1], "", 0)) == gs.HEAVY)
			# the set (the helm carries neither of its stats, so the third piece's difference is the bonus)
			p.equipment.clear()
			for s in ["bulwark_brigandine", "bulwark_gauntlets"]:
				p.equipment.equip(gear.make(gear.LOOKS[s][0], s, gear.LOOKS[s][1], "", 4))
			for e in [["coat", "greatcoat", {"coat": "greatcoat"}], ["legs", "leathers", {"legs": "leathers"}], ["feet", "sabatons", {"feet": "sabatons"}]]:
				p.equipment.equip(gear.make(e[0], e[1], e[2], "", 4))
			p.refresh_look()
			var bc0: float = p.progression.stat("block_cost_pct")
			var ps0: float = p.progression.stat("parry_stamina")
			p.equipment.equip(gear.make("head", "bulwark_helm", gear.LOOKS["bulwark_helm"][1], "", 4))
			p.refresh_look()
			check("Bulwark's third piece: +20%% block, +8 stamina a parry (%.2f, %.0f)" % [p.progression.stat("block_cost_pct") - bc0, p.progression.stat("parry_stamina") - ps0],
				is_equal_approx(p.progression.stat("block_cost_pct") - bc0, 0.2) and is_equal_approx(p.progression.stat("parry_stamina") - ps0, 8.0))
			check("a full gold heavy kit with it blocks <= ~50%% (%.2f)" % p.damage_reduction(), p.damage_reduction() <= 0.52)
			check("the set line reads", gs.bonus_text("bulwark") == "+20% block, +8 stamina on a parry")
			p.equipment.clear()
			p.refresh_look()
			return TK.done(fails)
	step += 1
	return false
