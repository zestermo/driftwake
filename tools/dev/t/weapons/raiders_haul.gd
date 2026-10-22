extends SceneTree
## Raider's Haul (DualAxeArts `_haul`): the grunt in front is hooked and carried once round you at arm's length
## (seen behind you mid-swing, never inside you), battering the grunt standing at your side flat, then flung
## unblockably well down the line, where the grunt standing on it is bowled over; a boss in front is circled
## instead (you end up round its far side) and chopped three times, the last through its guard.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g0
var g1
var g2
var g3
var hits := {}
var from := Vector3.ZERO
var start := Vector3.ZERO
var behind := false
var closest := 99.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "reavers_axe", "grunts": [
		{"post": Vector3(0, 0, -2.0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"},
		{"post": Vector3(1.9, 0, 0.3), "yaw": 0.0, "mode": "stand", "seed": 38, "role": "sword"},
		{"post": Vector3(0.3, 0, -8.0), "yaw": 0.0, "mode": "stand", "seed": 39, "role": "sword"},
		{"post": Vector3(16.0, 0, -3.0), "yaw": 0.0, "mode": "stand", "seed": 40, "role": "sword"}]})


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
			p.inventory_component.add_item(ItemDB.get_item("tomahawk"), 1)
			p.set_offhand(ItemDB.get_item("tomahawk"))
			stage.camera_rig.rotation.y = 0.0
			g0 = stage.camp.grunts[0]
			g1 = stage.camp.grunts[1]
			g2 = stage.camp.grunts[2]
			g3 = stage.camp.grunts[3]
			for g in [g0, g1, g2, g3]:
				hits[g] = []
				g.health.max_health = 9999.0
				g.health.current_health = 9999.0
				g.hurtbox.hit_received.connect(func(h, _a): hits[g].append(h))
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			for g in [g0, g1, g2]:
				g._enter_idle()
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "raiders_haul", "slot": 0})
			until = TK.wait_secs(0.3)
		2:
			# (sampled through the swing: where the carried grunt is against you)
			var rel: Vector3 = g0.global_position - p.global_position
			rel.y = 0.0
			closest = minf(closest, rel.length())
			behind = behind or rel.z > 1.0
			if p.current_state_name() == "Technique" and float(p.state_machine.current_state.t) < 0.98:
				return false
			from = g0.humanoid.hips.global_position
			until = TK.wait_secs(1.2)
		3:
			check("carried round behind you mid-swing", behind)
			check("never hauled inside you (closest %.2f m)" % closest, closest > 1.2)
			check("the grunt at your side is battered flat (%d hits)" % hits[g1].size(), hits[g1].any(func(h): return h.knockdown))
			check("the one swung takes an unblockable fling", hits[g0].any(func(h): return h.unblockable and h.breaker))
			var flown: float = Vector2(g0.humanoid.hips.global_position.x - from.x, g0.humanoid.hips.global_position.z - from.z).length()
			check("flung well down the line (%.1f m)" % flown, flown >= 5.0)
			check("the grunt on the line is bowled over (%d hits)" % hits[g2].size(), hits[g2].any(func(h): return h.knockdown))
			until = TK.wait_secs(0.5)
		4:
			if not p.is_free():
				return false
			g3.add_to_group("bosses")
			g3._enter_idle()
			p.global_position = g3.global_position + Vector3(0, 0.1, 2.0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			start = p.global_position - g3.global_position
			from = g3.humanoid.hips.global_position
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "raiders_haul", "slot": 0})
			until = TK.wait_secs(0.85)
		5:
			var now: Vector3 = p.global_position - g3.global_position
			check("you run round the boss (%.0f deg round)" % rad_to_deg(Vector2(start.x, start.z).angle_to(Vector2(now.x, now.z))),
				absf(Vector2(start.x, start.z).angle_to(Vector2(now.x, now.z))) > 1.2)
			until = TK.wait_secs(1.0)
		6:
			# (the first hit is the hook's)
			var chops: Array = hits[g3].slice(1)
			check("three chops land on the boss (%d)" % chops.size(), chops.size() == 3)
			check("the last through its guard, the hardest", chops.size() == 3 and chops[2].unblockable and chops[2].breaker and chops[2].damage > chops[0].damage)
			var moved: float = Vector2(g3.humanoid.hips.global_position.x - from.x, g3.humanoid.hips.global_position.z - from.z).length()
			check("the boss isn't flung (%.1f m)" % moved, moved < 3.0)
			check("the technique is over", p.current_state_name() != "Technique")
			return TK.done(fails)
	step += 1
	return false
