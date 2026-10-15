extends SceneTree
## Duels that don't happen or don't finish: a rival (a stand-in) declines ours; we decline theirs (N); one left
## unanswered lapses after 15 s; mid-duel nobody else can challenge either of us; the rival walking 35 m off
## the ring makes it a draw, and we're as we were.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rival
var other
var duel
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Rival", "at": Vector3(0, 0, -2)}, {"name": "Other", "at": Vector3(3, 0, 0)}]})


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
			other = stage.crew[1]
			duel = Duel.inst
			duel.challenge(rival.net_id)
			duel._answer(rival.net_id, false, rival.global_position)
			until = TK.wait_ticks(2)
		1:
			check("the rival declines ours: no duel, told so (%s)" % stage.hud.toast.text, duel.duel_of(1).is_empty() and duel.state["asks"].is_empty()
				and stage.hud.toast.text == "Rival declined the duel")
			duel._challenge(rival.net_id, 1)
			until = TK.wait_ticks(3)
		2:
			check("theirs: our prompt", duel.hud.asking())
			var ev := InputEventKey.new()
			ev.physical_keycode = KEY_N
			ev.pressed = true
			duel.hud._input(ev)
			until = TK.wait_ticks(2)
		3:
			check("N declines: no duel, the prompt's gone", duel.duel_of(1).is_empty() and duel.state["asks"].is_empty() and not duel.hud.asking())
			duel._challenge(rival.net_id, 1)
			until = TK.wait_secs(Duel.ANSWER_TIME - 1.0)
		4:
			check("unanswered: still asking at 14 s", duel.hud.asking() and duel.asker_of(1) == rival.net_id)
			until = TK.wait_secs(1.2)
		5:
			check("...lapsed at 15 s, no duel", not duel.hud.asking() and duel.state["asks"].is_empty() and duel.duel_of(1).is_empty())
			duel.challenge(rival.net_id)
			duel._answer(rival.net_id, true, rival.global_position)
			until = TK.wait_ticks(2)
		6:
			check("a duel with the rival", not duel.duel_of(1).is_empty())
			duel._challenge(other.net_id, 1)
			duel._challenge(other.net_id, rival.net_id)
			check("...nobody can challenge either of us meanwhile", duel.state["asks"].is_empty())
			duel.challenge(other.net_id)
			check("...nor can we challenge anyone (%s)" % stage.hud.toast.text, duel.state["asks"].is_empty() and stage.hud.toast.text == "You're already in a duel")
			until = TK.wait_secs(Duel.COUNTDOWN + 0.2)
		7:
			check("fighting", duel.fighting(duel.duel_of(1)))
			rival.global_position = p.global_position + Vector3(0, 0, -(Duel.RING + 3.0))
			until = TK.wait_ticks(3)
		8:
			var d: Dictionary = duel.duel_of(1)
			check("the rival walks off the ring: a draw (%s)" % duel.hud.banner_text(), not d.is_empty() and int(d["winner"]) == 0 and duel.hud.banner_text() == "Draw")
			check("...nobody's hittable", rival.hurtbox.collision_layer & Duel.ENEMY_LAYER == 0)
			until = TK.wait_secs(Duel.REVIVE_AFTER + 0.7)
		9:
			check("...over, and we're on our feet at full health", duel.state["duels"].is_empty() and p.current_state_name() == "Idle"
				and p.health_component.current_health == p.health_component.max_health)
			return TK.done(fails)
	step += 1
	return false
