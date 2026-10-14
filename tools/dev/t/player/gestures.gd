extends SceneTree
## Gestures: a villager talks with their hands and the captain with theirs, the coin goes over when you trade, F on a
## chest reaches in with both hands, and every gesture plays.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var npc
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"npc": {"name": "Harbormaster Odile", "dialogue": "odile"}, "chest": [["treasure", 1]]})


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
			npc = stage.npc
			p.global_position = npc.global_position + Vector3(1.2, 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		1:
			npc._on_interacted(p)
			until = TK.wait_ticks(4)
		2:
			var dlg = root.get_node("Dialogue")
			check("talking: %s gestures with their line (%s)" % [npc.npc_name, npc.humanoid.current_action()], p.current_state_name() == "Talk" and npc.humanoid.current_action().begins_with("gesture_talk"))
			dlg.line_shown.emit(dlg.PLAYER_SPEAKER, "Aye.")
			check("...and the captain with theirs (%s)" % p.body_model.current_action(), p.body_model.current_action().begins_with("gesture_talk"))
			dlg.dialogue_event.emit("shop:nessa")
			check("...hands over the coin when they trade (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gesture_hand")
			dlg._close()
			until = TK.wait_ticks(10)
		3:
			root.get_node("GameMenu").close()
			p.state_machine.force_state("Idle", {})
			p.global_position = stage.chest.global_position + Vector3(-0.9, 0.05, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		4:
			var ic = p.interaction_component
			check("next to a chest, F offers it (%s)" % (ic.current_interactable.prompt_text if ic.current_interactable else "nothing"), ic.current_interactable == stage.chest.interactable)
			var ev := InputEventAction.new()
			ev.action = "interact"
			ev.pressed = true
			ic._unhandled_input(ev)
			check("...and F reaches in with both hands (%s)" % p.body_model.current_action(), p.body_model.current_action() == "gesture_open")
			p.body_model.stop_action()
			var missing := []
			for g in ["talk_a", "talk_b", "talk_c", "nod", "open", "pickup", "lever", "push", "reach", "hand"]:
				p.gesture(g)
				if p.body_model.current_action() != "gesture_" + g:
					missing.append(g)
			check("every gesture plays (not: %s)" % str(missing), missing.is_empty())
			return TK.done(fails)
	step += 1
	return false
