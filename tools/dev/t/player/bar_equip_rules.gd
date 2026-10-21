extends SceneTree
## What can go on the one skill bar: a weapon's skills only while that weapon is in one of your loadouts (a locked
## third loadout doesn't count), Captain skills with anything, ultimates only on R (the ultimate of any loadout's
## weapon), nothing unlearned, each refusal with a reason the menu shows. A slot whose weapon leaves your loadouts
## keeps its skill but can't be used: the cast is refused and the hands don't change.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pc
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


func learn(skill_id: String) -> void:
	var tree = load("res://scripts/progression/skill_tree.gd")
	for k in tree.nodes().keys():
		if str(tree.get_node_def(k).get("skill", "")) == skill_id:
			p.progression.owned[k] = true
			return


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pc = p.power
			for id in ["deadeye", "deaths_waltz", "kraken_wake", "soru"]:
				learn(id)
			var pistol = ItemDB.get_item("pistol")
			p.inventory_component.add_item(pistol, 1)
			p.loadouts[2] = ["pistol", ""]
			check("a pistol skill with no pistol loadout is refused (%s)" % pc.equip_why("deadeye", 0),
				pc.equip_why("deadeye", 0) == "Needs a pistol in a loadout" and not pc.equip("deadeye", 0) and pc.loadout[0] == "")
			check("...a pistol in the locked third loadout doesn't count", p.loadout_slots() == 2)
			check("a Captain skill goes on with anything", pc.equip("soru", 1))
			check("an ultimate only on R (%s)" % pc.equip_why("kraken_wake", 0), pc.equip_why("kraken_wake", 0) == "Ultimates go on R" and not pc.equip("kraken_wake", 0))
			check("...and only an ultimate on R (%s)" % pc.equip_why("soru", 4), pc.equip_why("soru", 4) == "Only an ultimate goes on R")
			check("nothing unlearned (%s)" % pc.equip_why("berserk", 0), pc.equip_why("berserk", 0) == "Not learned yet")
			p.loadouts[2] = []
			p.loadouts[1] = ["pistol", ""]
			check("pistol in loadout 2: its skill goes on with the cutlass in hand", pc.equip("deadeye", 0) and pc.loadout[0] == "deadeye")
			check("...and its ultimate on R", pc.equip("deaths_waltz", 4))
			p.inventory_component.remove_item(pistol, 1)
			pc.energy = pc.max_energy()
			pc.ult = 100.0
			check("the pistol leaves the bag: the slot keeps Deadeye", pc.loadout[0] == "deadeye")
			check("...but can't use it (%s)" % pc.can_cast(0), pc.can_cast(0) == "Needs a pistol in a loadout" and pc.can_cast(4) == "Needs a pistol in a loadout")
			check("...shown unusable", pc.loadout_for(pc.skill(0), pc.loadout_styles(), p.loadout_at) == pc.NO_LOADOUT)
			check("...the cast is refused", not pc.try_cast(0))
			check("...and the cutlass stays in hand", p.loadout_at == 0 and p.style() == "sword")
			# a boss fighting nearby locks the bar (a stand-in boss)
			var s := GDScript.new()
			s.source_code = "extends Node3D\nvar fighting := true\nfunc in_combat() -> bool:\n\treturn fighting\n"
			s.reload()
			var boss := Node3D.new()
			boss.set_script(s)
			boss.add_to_group("bosses")
			stage.add_child(boss)
			boss.global_position = p.global_position + Vector3(0, 0, -20)
			check("a boss fight locks the bar (%s)" % pc.equip_why("soru", 3), pc.equip_why("soru", 3) == "Not during a boss fight" and not pc.equip("soru", 3) and pc.loadout[1] == "soru")
			check("...clearing a slot too", not pc.equip("", 1) and pc.loadout[1] == "soru")
			learn("tekkai")
			pc.auto_equip("tekkai")
			check("...and a skill learned mid-fight waits off the bar", not ("tekkai" in pc.loadout))
			boss.fighting = false
			check("the fight over, the bar's free again", pc.equip("soru", 3) and pc.loadout[3] == "soru")
			boss.fighting = true
			boss.global_position = p.global_position + Vector3(0, 0, -80)
			check("...and a boss fighting far away doesn't lock it", pc.equip("soru", 2))
			return TK.done(fails)
	step += 1
	return false
