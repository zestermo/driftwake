extends SceneTree
## The katana tree's three variants (1.18.4): an old save's Iai Counter, Wind Severer and Crescent Arc stay the active
## versions; switched, Side Step (Iai Counter's) answers a caught blow from the dummy's side, and the cut lands; Twin
## Waves (Wind Severer's from 18) sends two waves that cross ahead and hit the dummy; Falling Moon (the air attack from
## mastery 15) turns over with the blade and its landing crescent hits the dummy. (The dummy is mended to full before
## each move: one that dies is back to full the same frame.)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var hc
var hp := 0.0
var low := 0.0
var waited := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0), "weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func waves() -> int:
	var k := 0
	for n in root.find_children("*", "", true, false):
		if n.get("kind") == "wave" and n.has_method("_turn_back") and not n.is_queued_for_deletion():
			k += 1
	return k


## (the dummy mends: the lowest it gets over `frames` frames)
func watch(frames: int) -> bool:
	low = minf(low, hc.current_health)
	waited += 1
	return waited < frames


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			hc = stage.dummy.get_node("HealthComponent")
			stage.camera_rig.rotation.y = 0.0
			pr.master_all()
			check("mastered, the first versions are active: Iai Counter, Wind Severer, Crescent Arc",
				pr.knows("iai_counter") and pr.knows("wind_sever") and pr.has_move("air_slash") and not pr.knows("side_step") and not pr.has_move("falling_moon"))
			check("Falling Moon from 15, Twin Waves from 18", SkillTrees.node_def("k_moon")["level"] == 15 and SkillTrees.node_def("k_twin")["level"] == 18)
			# (as the ship's bunk does)
			for n in ["k_arc", "k_wind", "k_counter"]:
				pr._switch(n, 1)
			check("switched: Falling Moon, Twin Waves and Side Step", pr.has_move("falling_moon") and not pr.has_move("air_slash") and pr.knows("twin_waves") and pr.knows("side_step"))
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(0.8)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 1.6)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Technique", {"id": "side_step"})
			until = TK.wait_secs(0.3)
		2:
			hc.current_health = hc.max_health
			hp = hc.current_health
			low = hp
			waited = 0
			var before: Vector3 = p.global_position
			p.state_machine.force_state("Technique", {"id": "riposte_counter", "target": stage.dummy})
			var to: Vector3 = (p.global_position - stage.dummy.global_position) * Vector3(1, 0, 1)
			var line: Vector3 = ((before - stage.dummy.global_position) * Vector3(1, 0, 1)).normalized()
			var off := (to - line * to.dot(line)).length()
			check("a caught blow: out at its side (%.2f m off the line it came along)" % off, off > 0.9)
		3:
			if watch(60):
				return false
			check("and the drawing cut lands (%.0f -> %.0f)" % [hp, low], low < hp)
		4:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.0)
		5:
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 6.5)
			p.reset_physics_interpolation()
			hc.current_health = hc.max_health
			hp = hc.current_health
			low = hp
			waited = 0
			p.state_machine.force_state("Technique", {"id": "twin_waves"})
		6:
			if waited == 50:
				check("Twin Waves: two waves out (%d)" % waves(), waves() == 2)
			if watch(150):
				return false
			check("...crossing on the dummy (%.0f -> %.0f)" % [hp, low], low < hp)
		7:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.5)
		8:
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 2.2)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hc.current_health = hc.max_health
			hp = hc.current_health
			low = hp
			waited = 0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		9:
			check("attacked in the air, Falling Moon (%s)" % p.body_model.current_action(), p.body_model.current_action() == "falling_moon")
			until = TK.wait_secs(0.25)
		10:
			check("turning over forward with the blade (pivot %.2f)" % p.body_model._cur["pivot"].x, p.body_model._cur["pivot"].x < -1.0)
		11:
			if watch(90):
				return false
			check("it lands on one knee and the crescent hits the dummy (%.0f -> %.0f)" % [hp, low], low < hp)
			return TK.done(fails)
	step += 1
	return false
