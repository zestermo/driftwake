extends SceneTree
## v1.11 moves: the take-offs (standing, running, sprinting) and their landings, the double jump,
## the log pose raised, each weapon kind's draw and sheathe with its own sound.
const TK := preload("res://tools/dev/test_kit.gd")
## item, draw style (DrawMoves.kind), its draw sound, its sheathe sound
const KINDS := [["cutlass", "blade", "draw_blade", "sheathe_blade"], ["katana", "katana", "draw_katana", "sheathe_katana"],
	["boarding_axe", "axe", "draw_axe", "sheathe_axe"], ["war_axe", "great", "draw_great", "sheathe_great"],
	["dagger", "dagger", "draw_dagger", "sheathe_dagger"], ["pistol", "pistol", "draw_pistol", "holster"]]
var step := 0
var until := 0
var p
var fails := 0
var seen := {}
var heard: Array = []
var wi := 0


func _initialize() -> void:
	TK.seed_of(self)
	node_added.connect(func(n): if n is AudioStreamPlayer3D: heard.append(n.stream))
	change_scene_to_file("res://scenes/world/world.tscn")


func was_heard(sound: String) -> bool:
	return heard.has(root.get_node("FX")._streams[sound])


func press(a: String, on := true) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = on
	Input.parse_input_event(e)


func tap(a: String) -> void:
	press(a)
	press(a, false)


func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if not c:
		fails += 1


func body():
	return p.body_model


## Records every action the body plays (and the landing kind) while a step waits.
func watch() -> void:
	var a: String = body().current_action()
	if a != "":
		seen[a] = true
	if body()._land > 0.0:
		seen["land:" + body()._land_kind] = true


func to_village() -> void:
	var isl = root.get_node("World/Islands/Brinehollow")
	var v = isl.VILLAGE + Vector2(0, 6)
	p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if p != null:
		watch()
	if TK.ticking(until):
		return false
	match step:
		0:
			until = TK.wait_secs(1.0)
		1:
			p = root.get_tree().get_first_node_in_group("player")
			to_village()
			until = TK.wait_secs(0.6)
		2:
			seen.clear()
			tap("jump")
			until = TK.wait_secs(1.1)
		3:
			check("standing still: the standing take-off (%s)" % [seen.keys()], seen.has("jump_stand"))
			check("...and a two-footed landing", seen.has("land:stand"))
			to_village()
			press("move_forward")
			until = TK.wait_secs(0.5)
		4:
			seen.clear()
			tap("jump")
			until = TK.wait_secs(1.0)
		5:
			check("on the move: the running take-off (%s)" % [seen.keys()], seen.has("jump_run") and not seen.has("jump_stand"))
			check("...landing in stride (the staggered landing)", seen.has("land:run"))
			press("move_forward", false)
			to_village()
			press("move_forward")
			press("sprint")
			until = TK.wait_secs(0.8)
		6:
			seen.clear()
			check("sprinting before the jump (%.1f m/s)" % Vector2(p.velocity.x, p.velocity.z).length(), p.sprinting)
			tap("jump")
			until = TK.wait_secs(1.0)
		7:
			check("sprinting: the long bound (%s)" % [seen.keys()], seen.has("jump_sprint"))
			check("...and a running landing", seen.has("land:sprint"))
			press("sprint", false)
			press("move_forward", false)
			to_village()
			p.set_ability("double_jump", true)
			until = TK.wait_secs(0.6)
		8:
			seen.clear()
			tap("jump")
			until = TK.wait_secs(0.25)
		9:
			tap("jump")
			until = TK.wait_ticks(3)
		10:
			check("the double jump is its own move (%s)" % body().current_action(), body().current_action() == "double_jump")
			until = TK.wait_secs(0.2)
		11:
			check("mid-somersault the body is tipped well over (%.2f)" % body().pivot.rotation.x, absf(wrapf(body().pivot.rotation.x, -PI, PI)) > 1.0)
			until = TK.wait_secs(1.2)
		12:
			check("a double jump comes down in the kneeling landing (%s)" % [seen.keys()], seen.has("land:double"))
			check("the somersault is undone after (%.2f)" % body().pivot.rotation.x, absf(body().pivot.rotation.x) < 0.1)
			p.give_log_pose()
			Input.action_press("log_pose")
			until = TK.wait_secs(0.6)
		13:
			var lp: Node3D = body().fore_l.get_node("LogPose")
			var ball: Vector3 = lp.get_node("Ball").global_position
			var face: Vector3 = (-lp.global_basis.orthonormalized().z).normalized()
			var to_eyes: Vector3 = (body().head.global_position - ball).normalized()
			var front: float = (ball - body().torso.global_position).dot(-body().global_basis.orthonormalized().z)
			print("   log pose: ball %.2f m below the head, %.2f m out in front, facing the eyes %.2f" % [body().head.global_position.y - ball.y, front, face.dot(to_eyes)])
			check("holding L raises the wrist (%s)" % body().current_action(), body().current_action() == "log_pose")
			check("...the ball up in front of the chest, below the chin", front > 0.15 and body().head.global_position.y - ball.y > 0.05 and body().head.global_position.y - ball.y < 0.5)
			check("...its face turned to the eyes", face.dot(to_eyes) > 0.4)
			Input.action_release("log_pose")
			until = TK.wait_secs(0.4)
		14:
			# each weapon kind: put on sheathed, drawn (R), put away (R)
			var k: Array = KINDS[wi]
			var it = ItemDB.get_item(k[0])
			p.inventory_component.add_item(it, 1)
			p.equip_weapon(it, false)
			until = TK.wait_secs(0.4)
		15:
			var k: Array = KINDS[wi]
			if k[1] in ["axe", "great"]:
				check("%s: sheathed on the back" % k[0], body().weapon.get_parent().name == "BackSocket")
			heard.clear()
			tap("ready_weapon")
			until = TK.wait_ticks(4)
		16:
			var k: Array = KINDS[wi]
			check("%s: drawn its own way (%s / %s)" % [k[0], body().current_action(), DrawMoves.kind(body())], body().current_action() == "draw" and DrawMoves.kind(body()) == k[1])
			until = TK.wait_secs(0.6)
		17:
			var k: Array = KINDS[wi]
			check("%s: in hand, with its sound (%s)" % [k[0], k[2]], body().weapon_in_hand and was_heard(k[2]))
			heard.clear()
			tap("ready_weapon")
			until = TK.wait_secs(0.7)
		18:
			var k: Array = KINDS[wi]
			check("%s: put away, with its sound (%s)" % [k[0], k[3]], not body().weapon_in_hand and was_heard(k[3]))
			if k[0] == "pistol":
				check("...spun before it's holstered", was_heard("gun_spin"))
			wi += 1
			if wi < KINDS.size():
				step = 14
				return false
			print("RESULT fails=", fails)
			quit()
	step += 1
	return false
