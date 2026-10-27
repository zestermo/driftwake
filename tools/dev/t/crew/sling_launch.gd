extends SceneTree
## Sling Launch (slingshot): your crewmate crouches in the pouch and is flung high over everything ahead; alone, Slingshot
## Hop flings you up and on. Long guns share the pistols' Covering Fire.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var top := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "slingshot"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 1:
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("/root/Net")
	match step:
		0:
			p = stage.player
			y0 = p.global_position.y
			check("a slingshot's crew technique is Sling Launch", p.crew_tech.id() == "sling_launch")
			check("a long gun's is Covering Fire", load("res://scripts/combat/crew_techniques.gd").of_style("long_gun") == "covering_fire")
			check("alone: Slingshot Hop (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.4)
		1:
			check("you flung yourself up (%.1f m)" % (top - y0), top - y0 > 2.5)
			p.global_position = Vector3(0, y0, 10)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "sling_launch", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(6)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate crouches in the pouch ahead (%.2f out)" % Vector2(d.x, d.z).length(), mate.current_state_name() == "CrewTechnique" and Vector2(d.x, d.z).length() < 1.3)
			until = TK.wait_secs(0.55)
		4:
			check("flung high (%.1f up)" % mate.velocity.y, mate.velocity.y > 10.0)
			return TK.done(fails)
	step += 1
	return false
