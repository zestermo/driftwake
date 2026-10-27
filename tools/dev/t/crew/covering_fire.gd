extends SceneTree
## Covering Fire (pistol): a volley at the foe ahead that pins it down, then a fresh reload; while covered you (and a
## crewmate who joined) take less from blows and reload faster.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var reload0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "pistol", "dummy": Vector3(0, 0, -8)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("/root/Net")
	match step:
		0:
			p = stage.player
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			reload0 = p.reload_time()
			p.ammo[0] = 0
			check("alone: Suppress (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.3)
		1:
			var dealt: float = 10000.0 - stage.dummy.health_component.current_health
			check("the volley hit the foe ahead again and again (%.0f)" % dealt, dealt >= 40.0)
			check("a fresh reload after it (%s)" % str(p.ammo), p.ammo[0] == p.max_ammo())
			check("covered: reloads take half as long (%.2f of %.2f s)" % [p.reload_time(), reload0], p.reload_time() < reload0 * 0.6)
			check("and blows land softer", p.crew_tech.damage_k() < 0.8)
			p.crew_tech.cooldown = 0.0
			p.crew_tech.marks.clear()
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "covering_fire", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(4)
		3:
			check("your crewmate is covered", mate.crew_tech.marked("covered") and mate.crew_tech.damage_k() < 0.8)
			check("and so are you", p.crew_tech.marked("covered"))
			return TK.done(fails)
	step += 1
	return false
