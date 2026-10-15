extends SceneTree
## The rig doesn't drift: with the body squashed or scaled off 1.0, the IK callers (reach_hand, an instrument, a sword
## swing), a knockdown and get-up, and a swim in and out leave every joint's local scale and position where a fresh
## body has them (the animator sets only rotations, so a stray scale would stay until the body was rebuilt).
const TK := preload("res://tools/dev/test_kit.gd")
const JOINT_NAMES := ["hips", "torso", "neck", "head", "arm_l", "fore_l", "hand_l", "arm_r", "fore_r", "hand_r", "leg_l", "shin_l", "leg_r", "shin_r"]
var stage
var p
var b
var base := {}
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func snap() -> Dictionary:
	var d := {}
	for n in JOINT_NAMES:
		var j: Node3D = b.get(n)
		if j:
			d[n] = [j.basis.get_scale(), j.position]
	return d


func no_drift(after: String) -> void:
	var worst := ""
	for n in base.keys():
		var j: Node3D = b.get(n)
		var s: Vector3 = j.basis.get_scale()
		var pos: Vector3 = j.position
		if not s.is_equal_approx(base[n][0]) or pos.distance_to(base[n][1]) > 0.002:
			worst = "%s scale %s pos %s (was %s, %s)" % [n, s, pos, base[n][0], base[n][1]]
			break
	check("no joint drifted after %s%s" % [after, "" if worst == "" else ": " + worst], worst == "")


func reach_all() -> void:
	var tg: Vector3 = b.torso.global_position
	b.reach_hand(true, tg + Vector3(0.1, 0.1, -0.35), b.global_basis * Vector3(1, -1, 0.3))
	b.reach_hand(false, tg + Vector3(-0.1, 0.05, -0.3), b.global_basis * Vector3(-1, -1, 0.3))
	b.reach_hand(true, tg + Vector3(0.3, -0.2, 0.1), b.global_basis * Vector3(1, -1, 0.3))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			until = TK.wait_secs(0.5)
		1:
			base = snap()
			check("a fresh captain has joints to watch (%d)" % base.size(), base.size() >= 10)
			b.scale = Vector3(1.12, 0.86, 1.05)
			until = TK.wait_ticks(3)
		2:
			reach_all()
			no_drift("reach_hand with the body squashed")
			b.scale = Vector3.ONE
			until = TK.wait_ticks(3)
		3:
			no_drift("the squash is gone")
			b.scale = Vector3(0.9, 1.1, 0.9)
			var it = ItemDB.get_item("concertina")
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("concertina"))
			until = TK.wait_ticks(4)
		4:
			p.state_machine.force_state("Idle", {})
			p.velocity = Vector3.ZERO
			p.jam.start()
			until = TK.wait_secs(1.0)
		5:
			check("playing", p.jam.playing)
			no_drift("playing an instrument, body scaled")
			p.jam.stop()
			b.scale = Vector3(1.1, 0.9, 1.0)
			TK.act("light_attack")
			until = TK.wait_secs(0.25)
		6:
			no_drift("a sword swing, body scaled")
			until = TK.wait_secs(0.6)
		7:
			b.scale = Vector3.ONE
			b.start_ragdoll(Vector3(2, 3, 0))
			until = TK.wait_secs(1.5)
		8:
			var info: Dictionary = b.ragdoll_rest_info()
			b.begin_getup(bool(info["face_up"]), 1.0, info["hips_xform"])
			until = TK.wait_secs(1.5)
		9:
			no_drift("a knockdown and get-up")
			b.start_ragdoll(Vector3(-2, 4, 1))
			until = TK.wait_secs(1.0)
		10:
			var info: Dictionary = b.ragdoll_rest_info()
			b.begin_getup(bool(info["face_up"]), 1.0, info["hips_xform"])
			until = TK.wait_secs(1.5)
		11:
			no_drift("a second knockdown")
			p.global_position = Vector3(stage.SHORE_X + 6.0, 1.0, 0)
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.5)
		12:
			check("swimming (%s)" % p.current_state_name(), p.current_state_name() == "Swim")
			b.start_ragdoll(Vector3(1, 2, 0))
			until = TK.wait_secs(1.5)
		13:
			var info: Dictionary = b.ragdoll_rest_info()
			b.begin_getup(bool(info["face_up"]), 1.0, info["hips_xform"])
			until = TK.wait_secs(1.5)
		14:
			no_drift("a knockdown in the water")
			p.global_position = Vector3(stage.SHORE_X - 4.0, stage.GROUND_Y + 0.05, 0)
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Idle", {})
			until = TK.wait_secs(1.0)
		15:
			no_drift("climbing out of the water")
			return TK.done(fails)
	step += 1
	return false
