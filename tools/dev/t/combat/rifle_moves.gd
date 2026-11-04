extends SceneTree
## 1.30 riflemen, less predictable: up close a quick hip shot (a short aim) instead of the long one; rushed, a bayonet
## thrust or the butt stroke; now and then a kneeling aimed shot (a long aim, the kneel the tell) that hits harder; a
## dodge roll out of a heavy's way; and two riflemen never fire in the same moment.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var a
var b
var G
var step := 0
var until := 0
var fails := 0
var seen := {}
var fired_at := {}
var together := 0
var kneel_aim := 0.0
var hip_aim := 0.0
var rolled := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "grunts": [
		{"post": Vector3(-3, 0, -12.0), "role": "rifle", "seed": 81},
		{"post": Vector3(3, 0, -12.0), "role": "rifle", "seed": 82}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if a and G:
		for g in [a, b]:
			if not is_instance_valid(g):
				continue
			if g.state == G.S.AIM:
				seen[g._gun] = true
				if g._gun == "kneel":
					kneel_aim = g._aim_len
					if g.humanoid.current_action() != "fo_kneel_aim":
						seen["kneel_no_pose"] = true
				if g._gun == "hip":
					hip_aim = g._aim_len
				if g._fired and not fired_at.has(g):
					fired_at[g] = Engine.get_physics_frames()
			elif fired_at.has(g):
				fired_at.erase(g)
			if g.state == G.S.SHOVE:
				seen["jab" if g._jab else "butt"] = true
			if g.state == G.S.DASH and g.humanoid.current_action().begins_with("fo_roll"):
				rolled = true
		if fired_at.size() == 2 and absi(int(fired_at[a]) - int(fired_at[b])) < 6:
			together += 1
			fired_at.clear()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 2:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			a = stage.camp.grunts[0]
			b = stage.camp.grunts[1]
			stage.player.hurtbox.monitorable = false
			a.alert()
			until = TK.wait_secs(1.0)
		1:
			# long range: their shots, kneeling now and then, never in the same moment
			for g in [a, b]:
				g._kneel_odds = 0.5
			until = TK.wait_secs(26.0)
		2:
			check("a kneeling aimed shot (%.1f s aim)" % kneel_aim, seen.has("kneel") and kneel_aim >= 1.8)
			check("kneeling while it aims", not seen.has("kneel_no_pose"))
			check("the pair never fire in the same moment (%d)" % together, together == 0)
			# close in: a hip shot at a few metres
			b.queue_free()
			a._kneel_odds = 0.0
			a.global_position = stage.player.global_position + Vector3(0, 0.2, -4.5)
			a.reset_physics_interpolation()
			a._set_state(G.S.KEEP)
			a._shot_cd = 99.0
			a._hip_cd = 0.0
			a._shove_cd = 99.0
			a._roll_cd = 99.0
			until = TK.wait_secs(3.0)
		3:
			check("a hip shot up close (%.2f s aim)" % hip_aim, seen.has("hip") and hip_aim < 0.7)
			# rushed: the bayonet or the butt
			seen.erase("jab")
			seen.erase("butt")
			a._shove_cd = 0.0
			a._hip_cd = 99.0
			a.global_position = stage.player.global_position + Vector3(0, 0.2, -2.2)
			a.reset_physics_interpolation()
			until = TK.wait_secs(2.5)
		4:
			check("rushed, it strikes with the rifle (%s)" % str(seen.keys()), seen.has("jab") or seen.has("butt"))
			# a heavy coming: it rolls clear
			a._roll_cd = 0.0
			a._shove_cd = 99.0
			a._set_state(G.S.KEEP)
			a._roll_odds = 1.0
			a.global_position = stage.player.global_position + Vector3(0, 0.2, -3.5)
			a.reset_physics_interpolation()
			stage.player.player_model.rotation.y = 0.0
			TK.act("heavy_attack")
			until = TK.wait_secs(1.5)
		5:
			check("it rolls out of a heavy's way", rolled)
			return TK.done(fails)
	step += 1
	return false
