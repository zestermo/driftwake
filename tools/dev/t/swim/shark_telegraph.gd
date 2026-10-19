extends SceneTree
## A shark telegraphs before it bites: it notices a swimmer with its fin out of the water, circles for a few
## seconds without touching them, turns square on for its tell, then charges and bites. Out of the water
## it leaves you be.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var shark
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var t := 0.0
var seen := {}
var fin_out := false
var hurt_before_tell := false
var notice_t := -1.0
var tell_t := -1.0
var attack_t := -1.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(delta: float) -> bool:
	if shark == null or not is_instance_valid(shark) or step < 2:
		return false
	t += delta
	var st: int = shark.state
	var S = shark.S
	if not seen.has(st):
		seen[st] = t
	if st == S.NOTICE and notice_t < 0.0:
		notice_t = t
	if st == S.TELL and tell_t < 0.0:
		tell_t = t
	if st == S.ATTACK and attack_t < 0.0:
		attack_t = t
	if st == S.NOTICE and t - notice_t > 1.5:
		# the dorsal fin's top (0.5 m body + 0.75 m fin) out of the water
		var top: float = shark.global_position.y + 1.2
		if top > float(p.water_surface(shark.global_position)):
			fin_out = true
	if tell_t < 0.0 and p.health_component.current_health < hp0:
		hurt_before_tell = true
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.global_position = Vector3(stage.SHORE_X + 12.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			shark = load("res://scripts/enemies/sea/shark.gd").new()
			shark.name = "Shark"
			var home := Vector3(stage.SHORE_X + 28.0, -4.0, 0)
			shark.setup(home)
			stage.add_child(shark)
			shark.global_position = home
			until = TK.wait_secs(0.5)
		1:
			hp0 = p.health_component.current_health
			until = TK.wait_secs(14.0)
		2:
			var S = shark.S
			print("   notice ", snappedf(notice_t, 0.01), " tell ", snappedf(tell_t, 0.01), " attack ", snappedf(attack_t, 0.01), " hp ", hp0, " -> ", p.health_component.current_health)
			check("the shark noticed the swimmer", notice_t >= 0.0)
			check("...its fin came up out of the water", fin_out)
			check("...it circled a good while before its tell (%.1f s)" % (tell_t - notice_t), tell_t - notice_t > 3.5)
			check("...the tell held before the charge (%.2f s)" % (attack_t - tell_t), attack_t - tell_t >= shark.TELL - 0.05)
			check("...nothing hurt the swimmer before the tell", not hurt_before_tell)
			check("...then the charge bit (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health < hp0)
			check("...and it swam off after (state %d)" % shark.state, seen.has(S.FLEE))
			# out of the water: it gives up
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(5.0)
		3:
			var S = shark.S
			check("a captain ashore is left alone: back on patrol (state %d)" % shark.state, shark.state in [S.WANDER, S.IDLE])
			return TK.done(fails)
	step += 1
	return false
