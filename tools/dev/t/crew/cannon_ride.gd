extends SceneTree
## Cannon Ride (cannon): your crewmate climbs onto the barrel and rides the shot far along your aim, landing in a slam;
## alone, Recoil Jump fires into the ground and rides the blast up.
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
	stage = TK.stage(self, {"weapon": "hand_cannon"})


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
			check("a cannon's crew technique is Cannon Ride", p.crew_tech.id() == "cannon_ride")
			check("alone: Recoil Jump (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.6)
		1:
			check("you rode the blast up (%.1f m)" % (top - y0), top - y0 > 3.0)
			p.global_position = Vector3(0, y0, 10)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "cannon_ride", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(6)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate is up on the barrel (%.2f up)" % d.y, mate.current_state_name() == "CrewTechnique" and d.y > 1.2)
			until = TK.wait_secs(0.35)
		4:
			var h := Vector2(mate.velocity.x, mate.velocity.z).length()
			check("fired off along your aim (%.1f m/s on, %.1f up)" % [h, mate.velocity.y], h > 12.0 and mate.velocity.y > 3.0)
			return TK.done(fails)
	step += 1
	return false
