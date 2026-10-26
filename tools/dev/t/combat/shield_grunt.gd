extends SceneTree
## 1.23 the shield grunt: a shield on the off hand; from the front it stops every light blow and shot, a heavy breaks
## its guard (it reels, the guard down a while: the next light lands), and from behind it's hit like anyone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var G
var step := 0
var until := 0
var fails := 0
var stopped := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0.0, 0, -3.0), "role": "sword", "seed": 82, "shield": true}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(poise: float, ranged: bool = false) -> HitData:
	var h := HitData.new()
	h.damage = 6.0
	h.poise = poise
	h.ranged = ranged
	h.knockback_force = 1.0
	h.impact = "shot" if ranged else "slice"
	return h


func face(front: bool) -> void:
	var pl: Node3D = stage.player
	var to: Vector3 = pl.global_position - g.global_position
	g.facing.rotation.y = atan2(-to.x, -to.z) + (0.0 if front else PI)


func hit(h: HitData, front: bool) -> bool:
	face(front)
	var hp: float = g.health.current_health
	g._on_hit(h, stage.player)
	return g.health.current_health < hp


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			g = stage.camp.grunts[0]
			stage.player.hurtbox.monitorable = false
			check("it carries a shield", g.shield and g.humanoid.offhand != null)
			g.alert()
			until = TK.wait_secs(1.0)
		1:
			for i in 6:
				g._set_state(G.S.CIRCLE)
				if not hit(blow(6.0), true):
					stopped += 1
			if not hit(blow(4.0, true), true):
				stopped += 1
			check("from the front it stops every light blow and a shot (%d of 7)" % stopped, stopped == 7)
			g._set_state(G.S.CIRCLE)
			check("a heavy breaks its guard", hit(blow(25.0), true) and g.state == G.S.STAGGER)
			until = TK.wait_secs(0.3)
		2:
			check("with the guard down a light lands", hit(blow(6.0), true))
			until = TK.wait_secs(5.0)
		3:
			g._set_state(G.S.CIRCLE)
			check("the guard's back up after a while", not hit(blow(6.0), true))
			g._set_state(G.S.CIRCLE)
			check("from behind it's hit", hit(blow(6.0), false))
			return TK.done(fails)
	step += 1
	return false
