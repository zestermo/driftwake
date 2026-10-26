extends SceneTree
## 1.23 beast pass: the Silverback's parts. Blows to its face wear its tusks down; broken, they're stumps, it can't
## Grab any more and they drop Silverback Ivory for the captain. Its knuckles are in reach only while its fists are in
## the ground after a slam; cracked, the slam's ring shrinks and they drop a knuckle bone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ape
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(dmg: float) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = 0.0
	h.impact = "punch"
	return h


func _drop_has(id: String) -> bool:
	for n in current_scene.get_children():
		if str(n.name).begins_with("Drop_") and n.contents.any(func(s): return s.item.id == id):
			return true
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var at: Vector3 = p.global_position + Vector3(0, 0, -6.0)
			ape = load("res://scripts/enemies/jungle_ape.gd").new()
			ape.setup({"post": at, "mode": "stand", "seed": 3})
			ape.level = 6
			stage.add_child(ape)
			ape.global_position = at + Vector3.UP * 0.3
			until = TK.wait_ticks(10)
		1:
			ape.alert()
			until = TK.wait_secs(2.5)
		2:
			ape._special = ""
			ape._set_state(2)
			ape.health.current_health = ape.health.max_health * 0.25
			ape._phase_check()
			until = TK.wait_secs(2.8)
		3:
			check("phase 3: it can Grab", "grab" in ape.moves())
			# a blow from right in front of its face
			var head: Vector3 = ape.humanoid.head.global_position
			p.global_position = Vector3(head.x, ape.global_position.y, head.z) + ape._fwd() * 0.6
			p.reset_physics_interpolation()
			var whole: float = ape.parts.parts["tusks"][0]
			ape._on_hit(blow(30.0), p)
			check("a blow to its face wears the tusks (%.0f -> %.0f)" % [whole, ape.parts.parts["tusks"][0]], ape.parts.parts["tusks"][0] < whole)
			check("its knuckles are out of reach with its fists up", ape.parts.parts["fists"][0] == ape.parts.parts["fists"][6])
			for i in range(20):
				if not ape.parts.broken("tusks"):
					ape._part_hit("tusks", 30.0)
			until = TK.wait_secs(0.5)
		4:
			check("the tusks break: stumps where they were", ape.parts.broken("tusks") and not ape.humanoid.head.get_node("Tusks").visible and ape.humanoid.head.get_node("TusksBroken").visible)
			check("...no more Grab (%s)" % str(ape.moves()), not "grab" in ape.moves())
			check("...and Silverback Ivory drops", _drop_has("ivory"))
			var r0: float = ape._slam_r()
			ape._last_pick = "slam"
			ape._recover(1.4)
			ape._part_hit(ape.parts.near(ape.humanoid.hand_r.global_position), 9999.0)
			check("struck while its fists are down after a slam, the knuckles crack", ape.parts.broken("fists") and not ape.humanoid.hand_r.get_node("Knuckles").visible)
			check("...the slam's ring shrinks (%.1f -> %.1f m)" % [r0, ape._slam_r()], ape._slam_r() < r0 * 0.7)
			until = TK.wait_secs(0.5)
		5:
			check("...and a knuckle bone drops", _drop_has("knuckle"))
			ape.reset_fight()
			check("a reset mends them", not ape.parts.broken("tusks") and not ape.parts.broken("fists") and ape.humanoid.head.get_node("Tusks").visible)
			return TK.done(fails)
	step += 1
	return false
