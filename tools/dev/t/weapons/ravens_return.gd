extends SceneTree
## Ravens' Return (DualAxeArts `_ravens`): both axes leave the hands (hidden there, two raven projectiles flying),
## a grunt dead ahead and one out to the front left are each cut on the way out and again on the way home, a grunt
## behind you isn't touched; then both axes are back in the hands and nothing is left flying.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g0
var g1
var g2
var hits := {}
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "reavers_axe", "grunts": [
		{"post": Vector3(0, 0, -4.0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"},
		{"post": Vector3(-3.0, 0, -5.5), "yaw": 0.0, "mode": "stand", "seed": 38, "role": "sword"},
		{"post": Vector3(0.5, 0, 3.0), "yaw": 0.0, "mode": "stand", "seed": 39, "role": "sword"}]})


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
			for g in [g0, g1, g2]:
				hits[g] = []
				g.health.max_health = 9999.0
				g.health.current_health = 9999.0
				g.hurtbox.hit_received.connect(func(h, _a): hits[g].append(h))
			until = TK.wait_secs(0.5)
		1:
			if not p.is_free():
				return false
			check("twin axes in hand (%s)" % p.style(), p.style() == "dual_axe")
			for g in [g0, g1, g2]:
				g._enter_idle()
			p.power.energy = 999.0
			p.state_machine.force_state("Technique", {"id": "ravens_return", "slot": 0})
			until = TK.wait_secs(0.7)
		2:
			var ravens := get_nodes_in_group("projectiles").filter(func(n): return str(n.kind).begins_with("raven"))
			check("two axes flying (%d)" % ravens.size(), ravens.size() == 2)
			check("both held axes hidden while they fly", not p.body_model.weapon.visible and not p.body_model.offhand.visible)
			until = TK.wait_secs(1.4)
		3:
			check("the grunt ahead is cut out and home (%d, at %s, %s)" % [hits[g0].size(), str(g0.global_position.snapped(Vector3.ONE * 0.1)), str(g0.state)], hits[g0].size() == 2)
			check("the grunt out front left too (%d)" % hits[g1].size(), hits[g1].size() == 2)
			check("the one behind you isn't touched (%d)" % hits[g2].size(), hits[g2].is_empty())
			check("the cuts are missiles, the way home lighter", hits[g0].size() == 2 and hits[g0][0].ranged and hits[g0][1].damage < hits[g0][0].damage)
			check("both axes back in the hands", p.body_model.weapon.visible and p.body_model.offhand.visible)
			var left := get_nodes_in_group("projectiles").filter(func(n): return str(n.kind).begins_with("raven") and not n.is_queued_for_deletion())
			check("nothing left flying (%d)" % left.size(), left.is_empty())
			check("the technique is over", p.current_state_name() != "Technique")
			return TK.done(fails)
	step += 1
	return false
