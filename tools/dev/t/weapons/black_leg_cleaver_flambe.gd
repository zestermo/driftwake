extends SceneTree
## Black-leg's Cleaver Kick and Flambe Dash (the tree mastered, so with the heat): Cleaver Kick's blade of air cuts
## the dummy 10 m down the line and leaves it burning; Flambe Dash streaks through the dummy (it doesn't stop you: you
## land past it), kicks it and leaves it burning, and the enemies' collision is back on after.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var start := Vector3.ZERO
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -10.0)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cast(id: String, gap: float) -> void:
	p.global_position = stage.dummy.global_position + Vector3(0, 0.05, gap)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.power.energy = 999.0
	p.power.cooldowns.clear()
	start = p.global_position
	taken = 0.0
	p.state_machine.force_state("Technique", {"id": id, "slot": 0})


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(hd, _a): taken += hd.damage)
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			p.hurtbox.monitorable = false
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			cast("cleaver_kick", 10.0)
			until = TK.wait_secs(0.95)
		2:
			check("Cleaver Kick's blade cuts the dummy 10 m off (%.0f damage)" % taken, taken > 0.0)
			check("...and leaves it burning", stage.dummy.get_node_or_null("Burn") != null)
			until = TK.wait_secs(3.5)
		3:
			if not p.is_free():
				return false
			cast("flambe_dash", 4.0)
			until = TK.wait_secs(1.1)
		4:
			var past: float = (start - p.global_position).dot(Vector3(0, 0, 1))
			check("Flambe Dash kicks the dummy (%.0f damage)" % taken, taken > 0.0)
			check("...streaks through it, landing past it (%.1f m on, the dummy at 4)" % past, past > 6.0)
			check("...and leaves it burning", stage.dummy.get_node_or_null("Burn") != null)
			check("enemies stop you again after it", p.get_collision_mask_value(12))
			return TK.done(fails)
	step += 1
	return false
