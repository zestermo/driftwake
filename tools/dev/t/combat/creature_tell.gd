extends SceneTree
## Every creature's wind-up reads (1.26, docs/v1_26_plan.md "Enemy wind-ups and knockback"): as a creature starts its
## tell (Creature S.TELL: a wolf's crouch before the lunge), its body glows red (Creature._tell_glow, on every screen
## by the "tell" event), so a blow is never without warning.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var wolves: Array = []
var tells := 0
var glowed := 0
var _seen := {}
var S: Dictionary


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (every frame: a wolf entering its tell, and whether it glows red within its first few frames)
	for w in wolves:
		if not is_instance_valid(w):
			continue
		if w.state == S.TELL:
			if not _seen.has(w):
				_seen[w] = 0
				tells += 1
			_seen[w] += 1
			var t = w._hit_mat.get_shader_parameter("tint_mul") if w._hit_mat else null
			var r := float(t.r) if t is Color else (float(t.x) if (t is Vector3 or t is Vector4) else 1.0)
			if _seen[w] <= 12 and r > 1.4:
				glowed += 1
				_seen[w] = 100
		elif _seen.has(w):
			_seen.erase(w)
	if TK.ticking(until):
		return false
	var ground := Vector3(0, stage.GROUND_Y, 0)
	match step:
		0:
			S = load("res://scripts/enemies/fauna/creature.gd").S
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			for i in range(3):
				var w = load("res://scripts/enemies/fauna/wolf.gd").new()
				w.name = "wolf_%d" % i
				w.setup(ground + Vector3(-1.5 + i * 1.5, 0, -8.0), {"pack": 7, "lead": i == 0})
				w.position = ground + Vector3(-1.5 + i * 1.5, 0, -8.0)
				stage.add_child(w)
				wolves.append(w)
			until = TK.wait_secs(20.0)
		1:
			check("the wolves wound up to lunge (%d tells)" % tells, tells >= 2)
			check("...and every tell glowed red as it began (%d of %d)" % [glowed, tells], glowed >= tells - 1 and glowed >= 2)
			return TK.done(fails)
	step += 1
	return false
