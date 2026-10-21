extends SceneTree
## One skill bar across the loadouts: with a katana in hand (loadout 1) and a pistol in loadout 2, a pistol skill
## goes on the bar; pressing its key switches to loadout 2 and the skill runs (Smoke Bomb: you vanish), and the
## snapshot a crewmate's screen gets shows the pistol in hand with the cast. A katana skill switches back. Knocked
## down, the switch can't happen, so the cast is refused (Busy) and the hands stay as they are.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "katana", "crew": [{"name": "Mate", "at": Vector3(3, 0, 0)}]})


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
	var hs = load("res://scripts/net/humanoid_sync.gd")
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			learn("smoke_bomb")
			learn("iai_counter")
			p.inventory_component.add_item(ItemDB.get_item("pistol"), 1)
			p.loadouts[1] = ["pistol", ""]
			check("katana in hand, loadout 1 (%s)" % p.style(), p.style() == "katana" and p.loadout_at == 0)
			check("the pistol's Smoke Bomb goes on the bar with a katana in hand", p.power.equip("smoke_bomb", 0) and p.power.loadout[0] == "smoke_bomb")
			check("...and the katana's Iai Counter beside it", p.power.equip("iai_counter", 1))
			p.power.energy = p.power.max_energy()
			TK.act("skill_1")
			until = TK.wait_ticks(3)
		1:
			check("1 switches to loadout 2 (%d, %s)" % [p.loadout_at, p.style()], p.loadout_at == 1 and p.style() == "pistol")
			check("...and Smoke Bomb runs (%s)" % p.current_state_name(), p.current_state_name() == "Technique" and p.power.cooldown_left(0) > 0.0)
			var snap: Array = p.net_pack()
			hs.apply(mate.body_model, snap[9], snap[9], 1.0)
			check("a crewmate's screen: the pistol in hand with the cast (%s, %s)" % [hs.model_of(mate.body_model.weapon), snap[5]],
				hs.model_of(mate.body_model.weapon) == hs.model_of(p.body_model.weapon) and hs.model_of(p.body_model.weapon) != "" and snap[5] == "Technique")
			until = TK.wait_secs(0.35)
		2:
			check("Smoke Bomb: you vanish", p.vanished())
			until = TK.wait_secs(1.8)
		3:
			check("free again (%s)" % p.current_state_name(), p.is_free())
			p.power.energy = p.power.max_energy()
			TK.act("skill_2")
			until = TK.wait_ticks(3)
		4:
			check("2 switches back to the katana for Iai Counter (%d, %s, %s)" % [p.loadout_at, p.style(), p.current_state_name()],
				p.loadout_at == 0 and p.style() == "katana" and p.current_state_name() == "Technique")
			until = TK.wait_secs(1.8)
		5:
			p.power.cooldowns.clear()
			p.power.energy = p.power.max_energy()
			p.knock_down(Vector3.UP * 2.0)
			until = TK.wait_ticks(2)
		6:
			check("knocked down: the switch can't happen, so the cast is refused (%s)" % p.power.can_cast(0), p.power.can_cast(0) == "Busy")
			p.power.try_cast(0)
			check("...and the katana stays in hand", p.loadout_at == 0 and p.style() == "katana")
			return TK.done(fails)
	step += 1
	return false
