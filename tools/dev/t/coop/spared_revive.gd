extends SceneTree
## A captain-style AI (the Commodore, an officer) beats a co-op captain: Duel.beaten spares them (downed, not dead) and
## nothing stood them up, so they lay there for good. Now a crewmate standing means they're down and revivable, they
## get up alone if nobody comes, and with the whole crew down they lie for the wipe's brig (which stands them up).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rival
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Mate", "at": Vector3(3, 0, 0)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _kill() -> void:
	var hd := HitData.new()
	hd.damage = 9999.0
	p.hurtbox.take_hit(hd, rival)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var gm = root.get_node("GameManager")
	match step:
		0:
			p = stage.player
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			rival = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(0, 0.1, -5), 0.0, Node.new(), "BossVane")
			until = TK.wait_secs(0.6)
		1:
			var net = root.get_node("Net")
			net.active = true
			net.roster = {1: {}, 2: {}}
			net.players = {1: p, 2: stage.crew[0]}
			net.local_player = p
			check("co-op (%s)" % net.coop(), net.coop() and net.others_standing())
			check("a rival about", rival.is_in_group("rivals"))
			_kill()
			until = TK.wait_ticks(3)
		2:
			check("beaten by the AI: down, held, at 0 (%s)" % p.current_state_name(), p.current_state_name() == "Downed" and p.health_component.current_health == 0.0)
			check("...a crewmate can get us up: bleeding, no grave", p.is_bleeding() and gm.grave == null)
			p.revive()
			until = TK.wait_secs(1.0)
		3:
			check("revived: health back (%.0f)" % p.health_component.current_health, p.health_component.current_health > 0.0 and not p.is_bleeding())
			until = TK.wait_secs(2.5)
		4:
			check("...and on our feet (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"])
			_kill()
			until = TK.wait_ticks(3)
		5:
			check("beaten again: down and bleeding", p.current_state_name() == "Downed" and p.is_bleeding())
			until = TK.wait_secs(p.BLEED_TIME + 1.0)
		6:
			check("nobody came: we got up on our own (%.0f hp)" % p.health_component.current_health, p.health_component.current_health > 0.0 and not p.is_bleeding() and gm.grave == null)
			until = TK.wait_secs(2.5)
		7:
			check("...on our feet (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"])
			_kill()
			until = TK.wait_ticks(3)
		8:
			stage.crew[0].health_component.current_health = 0.0
			until = TK.wait_ticks(4)
		9:
			check("the whole crew down: we lie for the wipe, not bleeding", p.current_state_name() == "Downed" and not p.is_bleeding() and p.health_component.current_health == 0.0)
			Duel.stand_up(p, 50.0, 0.0)
			until = TK.wait_secs(2.5)
		10:
			check("the brig's stand-up gets us up (%s)" % p.current_state_name(), p.health_component.current_health > 0.0 and p.current_state_name() in ["Idle", "Move"])
			return TK.done(fails)
	step += 1
	return false
