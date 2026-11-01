extends SceneTree
## The lantern bomb (1.28): thrown at a foe it bursts and burns on where it lands in a real light the tier's radius
## wide; the foes its light falls on are marked on the compass (not one out of it); at most three burn at once (a
## fourth puts the oldest out).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g: Array = []
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -9), "role": "sword", "seed": 71},
		{"post": Vector3(-30, 0, -9), "role": "sword", "seed": 72}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var Z = load("res://scripts/gadgets/gadget_zone.gd")
	var M = load("res://scripts/gadgets/gadget_marks.gd")
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts
			for x in g:
				TK.calm(x, Vector3.BACK)
			p.gadgets.give("lantern_bomb", 1)
			TK.act("gadget_fire")
			until = TK.wait_secs(1.6)
		1:
			var z = Z.lanterns[0] if Z.lanterns.size() == 1 else null
			check("a lantern burns where it landed (%d)" % Z.lanterns.size(), z != null and z.inside(g[0].global_position))
			check("...a real light the tier's radius wide", z != null and z._light != null and is_equal_approx(z._light.omni_range, GadgetData.tier_val("lantern_bomb", "light", 1)))
			check("the foe in its light is marked", M.is_marked(g[0]))
			check("...not the one out of it", not M.is_marked(g[1]))
			for i in range(3):
				Z.spawn(self, "lantern_bomb", 0, p.global_position + Vector3(i * 4.0 + 4.0, 0, 6.0), p)
			until = TK.wait_ticks(3)
		2:
			check("three burn at most: the oldest goes out (%d)" % Z.lanterns.size(), Z.lanterns.size() == 3 and not Z.lanterns.any(func(l): return l.inside(g[0].global_position)))
			return TK.done(fails)
	step += 1
	return false
