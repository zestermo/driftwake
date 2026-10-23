extends SceneTree
## Cartwheel Crescent's hands on the ground: through each plant (BlackLegMoves.WHEEL_PLANTS, the hand fully down) the
## planted hand sits on the floor, not floating over it (or sunk into it), measured every frame.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hi := -9.0
var lo := 9.0
var seen := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 2 and p.body_model.current_action() == "bl_wheel":
		var b = p.body_model
		var u: float = float(b._action["t"]) / maxf(float(b._action["dur"]), 0.001)
		for w in load("res://scripts/npc/black_leg_moves.gd").WHEEL_PLANTS:
			var m := (float(w[1]) - float(w[0])) * 0.3
			if u < float(w[0]) + m or u > float(w[1]) - m:
				continue
			var hand: Node3D = b.hand_r if str(w[2]) == "r" else b.hand_l
			var y: float = hand.global_position.y - p.global_position.y
			hi = maxf(hi, y)
			lo = minf(lo, y)
			seen += 1
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "cartwheel_crescent", "slot": 0})
			until = TK.wait_secs(1.6)
		2:
			print("hands planted: %d frames, %.3f..%.3f m over the floor" % [seen, lo, hi])
			check("frames measured with a hand down (%d)" % seen, seen > 6)
			check("the planted hands sit on the floor, not floating (highest %.3f m)" % hi, hi < 0.14)
			check("...nor sunk into it (lowest %.3f m)" % lo, lo > -0.05)
			return TK.done(fails)
	step += 1
	return false
