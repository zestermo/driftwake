extends SceneTree
## 1.23 poise (docs/v1_23_previews.md section 3): a grunt (30 poise) goes down from one kick move, takes one heavy on
## its feet and goes down to the second, and once its poise has broken it can't be floored again for 4 s.
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
			check("a kick move floors a grunt", a.state == G.S.DOWN)
			hit(b, blow(20.0, 25.0))
			check("one heavy: the grunt reels but stays up (state %d)" % b.state, b.state != G.S.DOWN)
			until = TK.wait_secs(0.4)
		2:
			hit(b, blow(20.0, 25.0))
			check("the second heavy floors it", b.state == G.S.DOWN)
			until = TK.wait_secs(0.2)
		3:
			# (a: lights empty a fresh grunt's poise into a hard stagger, standing; b is down)
			if a.state in [G.S.DOWN, G.S.GETUP]:
				return false
			until = TK.wait_secs(4.5)
		4:
			for i in range(5):
				hit(a, blow(9.0, 6.0))
			check("five lights break its poise: it reels hard on its feet (state %d)" % a.state, a.state == G.S.STAGGER)
			until = TK.wait_secs(1.5)
		5:
			hit(a, blow(16.0, 30.0, true))
			check("a kick move inside 4 s of a break doesn't floor it", a.state != G.S.DOWN)
			until = TK.wait_secs(3.0)
		6:
			hit(a, blow(16.0, 30.0, true))
			check("past 4 s it floors it again", a.state == G.S.DOWN)
			return TK.done(fails)
	step += 1
	return false
