extends SceneTree
## 1.23 beast pass: a beast boss's poise (Poise "beast_boss", 400). Lights barely dent it; a planned chain of heavy
## blows breaks it, and then it reels in the stagger pose on its feet (never knocked down, never juggled, even by a
## launcher) and takes double damage for 3 s; a launcher on its own doesn't throw it up either.
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


func blow(dmg: float, poise: float, launch: float = 0.0) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = poise
	h.launch = launch
	h.knockdown = launch > 0.0
	h.impact = "punch"
	return h


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
			# (from behind: no part in reach)
			p.global_position = ape.global_position - ape._fwd() * 3.0
			p.reset_physics_interpolation()
			for i in range(10):
				ape._on_hit(blow(8.0, 6.0), p)
			check("ten lights don't break it (state %d)" % ape.state, ape.state != 9)
			ape._on_hit(blow(20.0, 30.0, 9.0), p)
			check("a launcher doesn't throw it up", not ape.is_in_group("juggled") and ape.state != 22 and ape.state != 11)
			for i in range(8):
				ape._on_hit(blow(25.0, 40.0), p)
			check("a chain of heavy blows breaks it: the stagger pose (state %d, %s)" % [ape.state, ape.humanoid.current_action()],
				ape.state == 9 and ape.humanoid.current_action() == "ape_reel")
			check("...double damage now", ape.vulnerable())
			var hp: float = ape.health.current_health
			ape._on_hit(blow(20.0, 6.0), p)
			check("...a 20 blow takes %.0f" % (hp - ape.health.current_health), absf(hp - ape.health.current_health - 40.0) < 0.5)
			until = TK.wait_secs(1.0)
		3:
			check("it reels on its feet, not knocked down nor in the air", ape.state == 9 and ape.humanoid.ragdoll == null and ape.is_on_floor() and not ape.is_in_group("juggled"))
			until = TK.wait_secs(2.6)
		4:
			check("the double damage is over after 3 s", not ape.vulnerable())
			check("...and it's back in the fight (state %d)" % ape.state, ape.state != 9)
			return TK.done(fails)
	step += 1
	return false
