extends SceneTree
## We challenge a rival (a stand-in) from the menu (3), they accept; their finishing blow downs us, not kills:
## no death, no grave, the bag untouched, held down; Defeated; 3 s on we're up with our health from before.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rival
var duel
var menu
var step := 0
var until := 0
var fails := 0
var data := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Rival", "at": Vector3(0, 0, -2)}]})


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
			rival = stage.crew[0]
			duel = Duel.inst
			menu = p.get_node("PlayerMenu")
			p.player_model.rotation.y = 0.0
			until = TK.wait_secs(0.4)
		1:
			TK.act("interact")
			until = TK.wait_ticks(3)
		2:
			check("F: the menu", menu.is_open())
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_3
			ev.pressed = true
			menu._input(ev)
			until = TK.wait_ticks(2)
		3:
			check("3: the challenge goes to the rival, the menu closes", duel.asking(1) == rival.net_id and not menu.is_open())
			check("...the toast says so (%s)" % stage.hud.toast.text, stage.hud.toast.text == "You challenged Rival to a duel")
			TK.act("interact")
			until = TK.wait_ticks(3)
		4:
			check("...their Duel entry now says the challenge is out", menu.is_open() and menu._buttons["duel"].disabled and menu._buttons["duel"].text == "Challenge sent")
			menu.close()
			duel._answer(rival.net_id, true, rival.global_position)
			until = TK.wait_ticks(2)
		5:
			check("they accept: the duel's on", not duel.duel_of(1).is_empty())
			until = TK.wait_secs(Duel.COUNTDOWN + 0.1)
		6:
			check("...no prompt on them while we duel", rival.get_node("Meet").enabled == false and p.interaction_component.current_interactable == null)
			data["hp"] = p.health_component.current_health
			data["bag"] = p.inventory_component.items.size()
			data["rum"] = p.inventory_component.count("rum")
			var hd := HitData.new()
			hd.damage = 9999.0
			hd.knockback_force = 4.0
			p.hurtbox.take_hit(hd, rival)
			until = TK.wait_ticks(3)
		7:
			var ds = p.state_machine.current_state
			check("their finishing blow: down (%s), held down, at 0" % p.current_state_name(),
				p.current_state_name() == "Downed" and bool(ds.get("dead")) and p.health_component.current_health == 0.0)
			check("...not dead: no grave, not bleeding, the bag as it was", root.get_node("GameManager").grave == null and not p.is_bleeding()
				and p.inventory_component.items.size() == int(data["bag"]) and p.inventory_component.count("rum") == int(data["rum"]))
			var d: Dictionary = duel.duel_of(1)
			check("...the rival wins", not d.is_empty() and int(d["winner"]) == rival.net_id)
			check("...Defeated (%s)" % duel.hud.banner_text(), duel.hud.banner_text() == "Defeated")
			until = TK.wait_secs(2.0)
		8:
			check("still down a second on", p.current_state_name() == "Downed" and p.health_component.current_health == 0.0)
			until = TK.wait_secs(Duel.REVIVE_AFTER - 2.0 + 0.1)
		9:
			check("3 s on: our health from before (%.0f / %.0f)" % [p.health_component.current_health, float(data["hp"])], absf(p.health_component.current_health - float(data["hp"])) < 0.5)
			until = TK.wait_secs(3.5)
		10:
			check("...and we got up (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and root.get_node("GameManager").grave == null)
			return TK.done(fails)
	step += 1
	return false
