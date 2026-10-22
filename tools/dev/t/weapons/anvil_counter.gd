extends SceneTree
## Anvil Counter (HammerArts `_anvil`): braced, a blow rings off (no damage), and the head ripped up throws the
## attacker down with a blow nothing blocks, a grunt close by caught by the shockwave at your feet; the guard is down
## after. Braced with nothing coming: half the energy back at the end of the brace.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hc
var hits: Array = []
var near: Array = []
var e1 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "warhammer",
		"grunts": [{"post": Vector3(-2.0, 0, -0.5), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow() -> HitData:
	var h := HitData.new()
	h.damage = 15.0
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			hc = p.health_component
			stage.camera_rig.rotation.y = 0.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): hits.append(h))
			var g = stage.camp.grunts[0]
			g.health.max_health = 9999.0
			g.health.current_health = 9999.0
			g.hurtbox.hit_received.connect(func(h, _a): near.append(h))
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			stage.camp.grunts[0]._enter_idle()
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "anvil_counter", "slot": 0})
			until = TK.wait_secs(0.3)
		2:
			check("braced: the guard is up", p.is_parrying)
			var hp: float = hc.current_health
			p._on_hit_received(blow(), stage.dummy)
			check("the blow rings off (no damage)", is_equal_approx(hc.current_health, hp))
			until = TK.wait_secs(0.35)
		3:
			check("the head ripped up into them: knocked down, unblockable (%d hits)" % hits.size(),
				hits.any(func(h): return h.unblockable and h.knockdown and h.damage >= 20.0))
			check("the shockwave at your feet throws the grunt close by down (%d hits)" % near.size(), near.any(func(h): return h.knockdown))
			check("the guard is down once it's answered", not p.is_parrying)
			until = TK.wait_secs(0.5)
		4:
			check("the technique is over", p.current_state_name() != "Technique")
			if not p.is_free():
				return false
			hits.clear()
			p.power.energy = 50.0
			p.state_machine.force_state("Technique", {"id": "anvil_counter", "slot": 0})
			until = TK.wait_secs(0.94)
		5:
			e1 = p.power.energy
			check("still braced near the end of the second", p.is_parrying)
			until = TK.wait_secs(0.12)
		6:
			check("nothing came: half the energy back (%.1f -> %.1f)" % [e1, p.power.energy], p.power.energy - e1 >= 7.5)
			check("the guard is down after the brace", not p.is_parrying)
			check("nothing was struck", hits.is_empty())
			return TK.done(fails)
	step += 1
	return false
