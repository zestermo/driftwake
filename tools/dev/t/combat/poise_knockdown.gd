extends SceneTree
## Poise (1.23, retuned 1.26: docs/v1_26_plan.md "Combat knockback"): a grunt has 50; a kick or a heavy rocks it, and
## a break from anything under a technique is a hard stagger on its feet; a technique or ultimate floors it; 4 s immune after.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var a
var b
var G


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(3.0, 0, -4.0), "role": "sword", "seed": 41},
		{"post": Vector3(-3.0, 0, -4.0), "role": "sword", "seed": 42}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(dmg: float, poise: float, down: bool = false) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = poise
	h.knockdown = down
	h.knockback_force = 5.0
	h.impact = "punch"
	return h


func hit(g, h: HitData) -> void:
	# (from behind: no guard in the way)
	var pl: Node3D = stage.player
	var to: Vector3 = g.global_position - pl.global_position
	g.facing.rotation.y = atan2(-to.x, -to.z)
	g._on_hit(h, pl)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 2:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			a = stage.camp.grunts[0]
			b = stage.camp.grunts[1]
			a.alert()
			b.alert()
			until = TK.wait_secs(1.0)
		1:
			hit(a, blow(16.0, 30.0, true))
			check("a kick move rocks a fresh grunt but doesn't floor it (state %d)" % a.state, a.state != G.S.DOWN)
			hit(b, blow(20.0, 25.0))
			check("one heavy: the grunt reels but stays up (state %d)" % b.state, b.state != G.S.DOWN)
			until = TK.wait_secs(0.4)
		2:
			hit(b, blow(20.0, 25.0))
			check("the second heavy breaks its poise: a hard stagger, still on its feet (state %d)" % b.state, b.state == G.S.STAGGER)
			hit(a, blow(24.0, 40.0))
			check("a technique on the kicked grunt breaks it and floors it", a.state == G.S.DOWN)
			until = TK.wait_secs(0.2)
		3:
			if a.state in [G.S.DOWN, G.S.GETUP]:
				return false
			until = TK.wait_secs(4.5)
		4:
			for i in range(9):
				hit(a, blow(1.0, 6.0))
			check("nine lights break its poise: it reels hard on its feet (state %d)" % a.state, a.state == G.S.STAGGER)
			until = TK.wait_secs(1.5)
		5:
			hit(a, blow(30.0, 120.0))
			check("an ultimate inside 4 s of a break doesn't floor it", a.state != G.S.DOWN)
			until = TK.wait_secs(3.0)
		6:
			hit(a, blow(30.0, 120.0))
			check("past 4 s an ultimate floors it", a.state == G.S.DOWN)
			return TK.done(fails)
	step += 1
	return false
