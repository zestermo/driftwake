extends SceneTree
## Pincer (dagger): alone, Marked Prey marks the foe ahead and your next three hits on it each land a crit with them;
## with a crewmate, both of you are marked on it: the first one's hit adds a crit, the second's a bigger one.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "dagger", "dummy": Vector3(0, 0, -4)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## The extra a 10-damage blow by `who` on the dummy adds (the blow itself isn't dealt here).
func extra(who) -> float:
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 10.0
	var h0: float = stage.dummy.health_component.current_health
	who.power.on_sword_hit(stage.dummy, hd)
	return h0 - stage.dummy.health_component.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("/root/Net")
	match step:
		0:
			p = stage.player
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			check("alone: Marked Prey (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_ticks(3)
		1:
			check("the foe ahead is marked", p.crew_tech.marked("pincer") and str(p.crew_tech.marks["pincer"]["by"]) == net.key_of(stage.dummy))
			check("three hits crit (%.0f %.0f %.0f)" % [extra(p), extra(p), extra(p)], not p.crew_tech.marked("pincer"))
			check("and the fourth doesn't", extra(p) == 0.0)
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.8)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "pincer", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(4)
		3:
			check("you're both marked on it", p.crew_tech.marked("pincer") and mate.crew_tech.marked("pincer"))
			var first := extra(mate)
			var second := extra(p)
			check("their hit adds a crit (%.0f), yours after it a bigger one (%.0f)" % [first, second], first >= 7.0 and second >= 14.0)
			check("both marks spent", not p.crew_tech.marked("pincer") and not mate.crew_tech.marked("pincer"))
			check("a quick one: 60 s", is_equal_approx(p.crew_tech.cooldown_len, 60.0))
			return TK.done(fails)
	step += 1
	return false
