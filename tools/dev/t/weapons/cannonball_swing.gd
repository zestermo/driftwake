extends SceneTree
## Cannonball Swing (HammerArts `_drive`): the grunt in front takes an unblockable blow and is launched flying well
## down the line, the grunt standing behind it on the line is knocked flat; a boss in front is only staggered long,
## not launched.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g0
var g1
var g2
var hits := {}
var from := Vector3.ZERO
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "warhammer", "grunts": [
		{"post": Vector3(0, 0, -3.0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"},
		{"post": Vector3(0.3, 0, -9.0), "yaw": 0.0, "mode": "stand", "seed": 38, "role": "sword"},
		{"post": Vector3(14.0, 0, -3.0), "yaw": 0.0, "mode": "stand", "seed": 39, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			stage.camera_rig.rotation.y = 0.0
			g0 = stage.camp.grunts[0]
			g1 = stage.camp.grunts[1]
			g2 = stage.camp.grunts[2]
			for g in [g0, g1, g2]:
				hits[g] = []
				g.health.max_health = 9999.0
				g.health.current_health = 9999.0
				g.hurtbox.hit_received.connect(func(h, _a): hits[g].append(h))
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			for g in [g0, g1]:
				g._enter_idle()
			from = g0.humanoid.hips.global_position
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "cannonball_swing", "slot": 0})
			until = TK.wait_secs(1.6)
		2:
			var h0: Array = hits[g0]
			check("the one in front takes an unblockable blow (%d hits)" % h0.size(), h0.size() >= 1 and h0[0].unblockable and h0[0].damage >= 20.0)
			var flown: float = Vector2(g0.humanoid.hips.global_position.x - from.x, g0.humanoid.hips.global_position.z - from.z).length()
			check("it was launched flying down the line (%.1f m)" % flown, flown >= 6.0)
			check("the grunt behind it on the line is knocked flat (%d hits)" % hits[g1].size(), hits[g1].any(func(h): return h.knockdown))
			until = TK.wait_secs(0.5)
		3:
			if not p.is_free():
				return false
			g2.add_to_group("bosses")
			g2._enter_idle()
			p.global_position = g2.global_position + Vector3(0, 0.1, 2.6)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			from = g2.humanoid.hips.global_position
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "cannonball_swing", "slot": 0})
			until = TK.wait_secs(1.2)
		4:
			var h2: Array = hits[g2]
			check("a boss takes the blow as a long stagger (%d hits)" % h2.size(), h2.size() >= 1 and h2[0].stagger_duration >= 2.0 and not h2[0].knockdown)
			var moved: float = Vector2(g2.humanoid.hips.global_position.x - from.x, g2.humanoid.hips.global_position.z - from.z).length()
			check("and isn't launched (%.1f m)" % moved, moved < 3.0)
			check("the technique is over", p.current_state_name() != "Technique")
			return TK.done(fails)
	step += 1
	return false
