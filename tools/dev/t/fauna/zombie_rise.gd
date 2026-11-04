extends SceneTree
## A graveyard zombie (fauna/zombie.gd, 1.30) lies buried - unseen, nothing to bump into or hit - until a captain comes
## near; then it claws up out of the ground and stands. Its grab holds the captain (GrabbedState), who mashes free and
## leaves it reeling.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var z
var step := 0
var until := 0
var fails := 0
var S: Dictionary
var mash := 0
var waited := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if z and is_instance_valid(z) and z.state == S.TELL:
		# (its next blow the grab)
		z._move = 1
		z._grab_cd = 0.0
	if TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	match step:
		0:
			S = load("res://scripts/enemies/fauna/creature.gd").S
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			z = load("res://scripts/enemies/fauna/zombie.gd").new()
			z.setup(ground + Vector3(0, 0, -25), {})
			z.name = "Zombie"
			z.position = ground + Vector3(0, 0.2, -25)
			stage.add_child(z)
			until = TK.wait_secs(1.0)
		1:
			check("a zombie lies buried while nobody's near", z.state == S.HIDE and not z.model.visible and z.collision_layer == 0 and not z.hurtbox.monitorable)
			p.global_position = ground + Vector3(0, 0.1, -17)
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.6)
		2:
			check("...a captain comes near: it claws up out of the ground (%s)" % z.state, z.state == S.NOTICE and z.model.visible and z.model.position.y < -0.5)
			until = TK.wait_secs(2.2)
		3:
			check("...and stands, a body to hit (%s)" % z.state, z.state not in [S.HIDE, S.NOTICE] and z.collision_layer == 4 and z.hurtbox.monitorable and absf(z.model.position.y) < 0.05)
			until = TK.wait_ticks(10)
		4:
			waited += 1
			if str(p.current_state_name()) != "Grabbed" and waited < 60:
				until = TK.wait_ticks(10)
				return false
			check("...its grab holds the captain (%s)" % p.current_state_name(), str(p.current_state_name()) == "Grabbed")
			until = TK.wait_ticks(8)
		5:
			if mash == 0:
				check("...and it holds on (%s)" % z.state, z.state == S.SPECIAL)
			TK.act("light_attack")
			mash += 1
			if mash < 9:
				until = TK.wait_ticks(4)
				return false
			until = TK.wait_ticks(6)
		6:
			check("mashing breaks free (%s), the zombie reels (%s)" % [p.current_state_name(), z.state], str(p.current_state_name()) != "Grabbed" and z.state == S.RECOVER)
			return TK.done(fails)
	step += 1
	return false
