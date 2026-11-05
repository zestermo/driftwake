extends SceneTree
## The fists' stationary techniques (1.30.2 polish): Shockwave Palm, Rising Dragon and Hundred Fists each play their
## pose and land on a dummy in front, and none leaves the captain stuck in it.
const TK := preload("res://tools/dev/test_kit.gd")
const IDS := ["palm_strike", "rising_dragon", "hundred_fists"]
var stage
var p
var taken := 0.0
var saw := {}
var i := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -1.8)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p != null:
		saw[p.body_model.current_action()] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.player_model.rotation.y = 0.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 0, 1.8)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.player_model.rotation.y = 0.0
			taken = 0.0
			saw = {}
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": IDS[i], "slot": 0})
			until = TK.wait_secs(2.2)
		2:
			check("%s plays its pose (%s)" % [IDS[i], str(saw.keys())], saw.has(IDS[i]))
			check("%s lands on the dummy (%.0f)" % [IDS[i], taken], taken > 0.0)
			check("%s hands back control (%s)" % [IDS[i], p.current_state_name()], p.current_state_name() in ["Idle", "Move", "Fall"])
			i += 1
			if i < IDS.size():
				step = 1
				until = TK.wait_secs(0.5)
				return false
			return TK.done(fails)
	step += 1
	return false
