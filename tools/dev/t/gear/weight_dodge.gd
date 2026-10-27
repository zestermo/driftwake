extends SceneTree
## What you wear sets the dodge (1.24): plain leather (medium) dashes as before, all cloth rolls further, heavy armour
## is a short hop; from the guard, heavy armour hops with the guard kept up. Weight slows swimming.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var gear
var gs
var start := Vector3.ZERO
var dist := {}
var swim := {}
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func wear(kit: String) -> void:
	p.equipment.clear()
	match kit:
		"medium":
			p.equipment.equip(gear.make("feet", "boots", {"feet": "boots"}, "", 0))
		"heavy":
			for e in [["head", "morion", {"hat": "morion"}], ["vest", "mail", {"vest": "mail"}], ["coat", "greatcoat", {"coat": "greatcoat"}],
					["hands", "gauntlets", {"gloves": true, "gauntlets": true}], ["feet", "greaves", {"feet": "greaves"}]]:
				p.equipment.equip(gear.make(e[0], e[1], e[2], "", 0))
	p.refresh_look()
	swim[kit] = p.progression.stat("swim_pct")


func dodge_from(kit: String) -> void:
	wear(kit)
	start = p.global_position
	TK.act("dodge")


func moved() -> float:
	var d: Vector3 = p.global_position - start
	d.y = 0.0
	return d.length()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gear = load("res://scripts/loot/gear.gd")
			gs = load("res://scripts/items/gear_stats.gd")
			until = TK.wait_secs(0.3)
		1:
			dodge_from("medium")
			check("leather boots and cloth: a medium load", p.gear_load() == gs.MEDIUM)
			until = TK.wait_ticks(4)
		2:
			check("medium: the dash (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dash")
			until = TK.wait_secs(0.9)
		3:
			dist["medium"] = moved()
			dodge_from("light")
			check("all cloth: light", p.gear_load() == gs.LIGHT)
			until = TK.wait_ticks(4)
		4:
			check("light: a roll (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dodge_roll")
			until = TK.wait_secs(1.0)
		5:
			dist["light"] = moved()
			dodge_from("heavy")
			check("mail and plate: heavy", p.gear_load() == gs.HEAVY)
			until = TK.wait_ticks(4)
		6:
			check("heavy: a hop (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sidestep")
			until = TK.wait_secs(0.9)
		7:
			dist["heavy"] = moved()
			print("   light %.2f m, medium %.2f m, heavy %.2f m" % [dist["light"], dist["medium"], dist["heavy"]])
			check("the light roll goes further than the dash", dist["light"] > dist["medium"] + 0.5)
			check("the heavy hop is short", dist["heavy"] < dist["medium"] * 0.75 and dist["heavy"] > 0.8)
			check("weight swims worse (light %.2f, medium %.2f, heavy %.2f)" % [swim["light"], swim["medium"], swim["heavy"]],
				swim["light"] > swim["medium"] and swim["medium"] > swim["heavy"])
			TK.press("parry")
			until = TK.wait_secs(0.6)
		8:
			check("guard up", p.current_state_name() == "Block")
			start = p.global_position
			TK.act("dodge")
			until = TK.wait_ticks(8)
		9:
			check("heavy: the hop from the guard keeps it up (%s)" % p.current_state_name(), p.current_state_name() == "Block" and p.is_blocking)
			until = TK.wait_secs(0.6)
		10:
			check("...and moves (%.2f m)" % moved(), moved() > 0.6)
			check("...still guarding after", p.current_state_name() == "Block")
			TK.release("parry")
			return TK.done(fails)
	step += 1
	return false
