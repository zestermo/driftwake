extends SceneTree
## A rival crew walks in (1.26, docs/v1_26_plan.md "Bounty hunters"): they turn up well off (RivalEncounter.WALK_FROM,
## their landing's side), weapons away, and walk up to the captain; the meeting starts once they're close. They fight
## slower (CaptainBrain.pace) and carry more health (HP_K) than before.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var e
var d0 := 0.0
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
	var RE = load("res://scripts/ai/rival_encounter.gd")
	match step:
		0:
			p = stage.player
			root.get_node("GameManager").rivals.clear()
			RE.walk_in = true
			# their landing off to the east
			e = RE.start(p, "brine_wolves", p.global_position + Vector3(80, 0, 0))
			until = TK.wait_ticks(3)
		1:
			var cap = e.rivals[-1]
			d0 = cap.global_position.distance_to(p.global_position)
			check("they turn up well off, not on top of the captain (%.0f m)" % d0, d0 > 30.0)
			check("...from their landing's side", (cap.global_position - p.global_position).x > 20.0)
			check("...walking in, not yet met (%s)" % e.phase, e.phase == "come" and e.rivals.all(func(r): return r.get_node("Brain").order == "come"))
			check("...slower fighters than a duel's (pace %.1f)" % cap.get_node("Brain").pace, cap.get_node("Brain").pace >= RE.PACE - 0.01)
			check("...and tougher (health x%.2f)" % cap.hp_k, cap.hp_k >= RE.HP_K * 1.8 - 0.01)
			until = TK.wait_secs(RE.COME_GIVE_UP + 2.0)
		2:
			var cap = e.rivals[-1]
			var d: float = cap.global_position.distance_to(p.global_position)
			check("they walked up (%.0f m -> %.0f m)" % [d0, d], d < d0 - 15.0)
			check("...and the meeting began (%s)" % e.phase, e.phase != "come")
			return TK.done(fails)
	step += 1
	return false
