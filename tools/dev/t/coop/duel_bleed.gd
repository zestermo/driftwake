extends SceneTree
## In a duel, damage that names no source (a bleed or burn tick) that would finish us downs us too:
## no death, no grave, held down, the rival wins.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rival
var duel
var step := 0
var until := 0
var fails := 0


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
			until = TK.wait_secs(0.4)
		1:
			duel._challenge(1, rival.net_id)
			duel._answer(rival.net_id, true, rival.global_position)
			until = TK.wait_secs(Duel.COUNTDOWN + 0.1)
		2:
			check("the duel's on", duel.fighting(duel.duel_of(1)))
			var hd := HitData.new()
			hd.damage = 9999.0
			hd.dot = true
			p.hurtbox.take_hit(hd, null)
			until = TK.wait_ticks(3)
		3:
			var ds = p.state_machine.current_state
			check("a bleed with no source: down (%s), held down, at 0" % p.current_state_name(),
				p.current_state_name() == "Downed" and bool(ds.get("dead")) and p.health_component.current_health == 0.0)
			check("...not dead: no grave, not bleeding", root.get_node("GameManager").grave == null and not p.is_bleeding())
			var d: Dictionary = duel.duel_of(1)
			check("...the rival wins", not d.is_empty() and int(d["winner"]) == rival.net_id)
			return TK.done(fails)
	step += 1
	return false
