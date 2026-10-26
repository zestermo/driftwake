extends SceneTree
## Black-leg is learned, not found: before it's taught empty hands are fists and nothing switches them; Gus at the
## Salted Gull sends you to Hana Teal at the teahouse (1.23), whose pupil's test ("master:black_leg") teaches it; taught, the
## Black Leg tree shows and empty hands kick; a weapon in hand puts the kicks away, and a loadout keeps them (X swaps
## straight to them; its techniques fit the bar); the bag's empty hand slot switches fists and kicks; the choice
## survives a save; with Nonchalance the guard is hands in the pockets (and puppets are told).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var save
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
			p.unequip_weapon()
			p.set_kicks(true)
			check("not taught yet: empty hands are fists, nothing switches them (%s)" % p.style(), p.style() == "fist" and not p.knows_black_leg())
			check("...and a black-leg loadout can't be taken up", p.loadout_style(1) == "" or p.loadouts[1].is_empty())
			var gus: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/gus.json"))
			var offer := false
			for c in gus["nodes"]["menu"]["choices"]:
				offer = offer or (c.get("next", "") == "legs" and c.get("hide_if", "") == "gus_black_leg" and c.get("after", "") == "vey_skills")
			var hana: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/hana.json"))
			check("Gus (the Salted Gull's cook) tells you about it, once (after Vey's training), and sends you to Hana's teahouse",
				offer and str(gus["nodes"]["legs_taught"]["text"]).contains("Hana"))
			check("...where Hana's pupil tests you ('master:black_leg')", hana["nodes"]["legs_test"].get("event", "") == "master:black_leg")
			root.get_node("/root/Dialogue").dialogue_event.emit("learn_black_leg")
			check("taught by him: the Black Leg tree shows in Combat", p.progression.visible_trees("combat").has("black_leg"))
			check("empty hands kick (%s), and the loadout in use keeps it (%s)" % [p.style(), str(p.loadouts[p.loadout_at])],
				p.style() == "black_leg" and p.loadouts[p.loadout_at] == ["black_leg", ""])
			p.equip_weapon(ItemDB.get_item("cutlass"), false)
			check("a cutlass in hand: the cutlass (%s)" % p.style(), p.style() == "sword" and not p.kicks)
			p.loadouts[1] = ["black_leg", ""]
			check("a loadout of kicks counts as black-leg (%s)" % p.loadout_style(1), p.loadout_style(1) == "black_leg" and p.loadout_carried(1))
			var PC = load("res://scripts/powers/power_component.gd")
			var mule: Dictionary = load("res://scripts/progression/skills.gd").get_skill("rising_heel")
			check("its techniques fit that loadout (the bar takes them)", PC.fits(mule, "black_leg") and PC.loadout_for(mule, p.power.loadout_styles(), 0) == 1)
			TK.act("loadout")
			until = TK.wait_secs(0.4)
		1:
			check("a tap of X swaps straight to the kicks (%s, loadout %d)" % [p.style(), p.loadout_at], p.style() == "black_leg" and p.loadout_at == 1
				and p.equipped_weapon == null)
			p.set_kicks(false)
			check("the empty hand slot switches to fists (%s)" % p.style(), p.style() == "fist" and p.loadouts[1] == ["", ""])
			p.set_kicks(true)
			check("...and back to kicks", p.style() == "black_leg" and p.loadouts[1] == ["black_leg", ""])
			save = load("res://scripts/game/save_game.gd")
			save.use_test_file("user://t_black_leg_learn_%d.dat" % OS.get_process_id())
			check("saved", save.save(p))
			p.kicks = false
			p.loadouts = [[], [], []]
			check("loaded", save.load_into(p))
			check("still kicking after a load (%s, %s)" % [p.style(), str(p.loadouts)], p.style() == "black_leg" and p.loadouts[1] == ["black_leg", ""])
			save.delete()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		2:
			var b = p.body_model
			var hy: float = b.hand_r.global_position.y - p.global_position.y
			check("before Nonchalance the hands are up loose (%.2f m)" % hy, not b.kick_pockets and hy > 0.85)
			p.progression.master_all()
			p._recalc_stats()
			until = TK.wait_secs(0.5)
		3:
			var b = p.body_model
			var hr: Vector3 = b.hand_r.global_position - p.global_position
			var hl: Vector3 = b.hand_l.global_position - p.global_position
			check("mastered (Nonchalance, Guard 10): hands in the pockets at the hips (%.2f / %.2f m)" % [hr.y, hl.y],
				b.kick_pockets and load("res://scripts/progression/skill_trees.gd").node_def("bl_pockets")["level"] == 10 and hr.y < 0.95 and hl.y < 0.95 and hr.y > 0.6)
			var fields: Array = load("res://scripts/net/humanoid_sync.gd").FIELDS
			check("puppets are told (HumanoidSync)", fields.has("kick_pockets") and fields.has("stance"))
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		4:
			var b = p.body_model
			var hy: float = b.hand_r.global_position.y - p.global_position.y
			check("a kick brings the hands straight out (%s, right hand %.2f m)" % [b.current_action(), hy], b.current_action() == "bl_1" and hy > 0.95)
			return TK.done(fails)
	step += 1
	return false
