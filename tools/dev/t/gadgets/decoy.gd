extends SceneTree
## The decoy (1.28): thrown short ahead, a straw captain springs up; grunts within its lure reach go for it (one idle at
## his post is roused), swing at it without breaking it, and once its time's up it falls apart and they turn back to
## the captain. A Mk III goes off when it does, hurting the foes round it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g: Array = []
var d
var hp := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(3, 0, -11), "role": "sword", "seed": 51},
		{"post": Vector3(-4, 0, -12), "role": "sword", "seed": 52}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts
			p.gadgets.give("decoy", 0)
			TK.act("gadget_fire")
			until = TK.wait_secs(1.5)
		1:
			var ds: Array = get_nodes_in_group("decoys")
			d = ds[0] if ds.size() == 1 else null
			check("a straw captain stands where it landed (%d)" % ds.size(), d != null and d.get_script() == load("res://scripts/gadgets/gadget_decoy.gd"))
			check("...short of the foes, between them and the captain", d != null and d.spot.distance_to(p.global_position) < 7.0)
			check("...a charge spent", p.gadgets.charges("decoy") == 1)
			check("both grunts go for it (%s, %s)" % [g[0]._lure, g[1]._lure], d != null and g[0]._lure == d and g[1]._lure == d)
			check("...the idle ones roused", g[0].in_combat() and g[1].in_combat())
			until = TK.wait_secs(GadgetData.tier_val("decoy", "secs", 0) - 1.5 - 0.3)
		2:
			check("they swing at it, and it stands (%.1f)" % d._last_hit, is_instance_valid(d) and d._last_hit >= 0.0 and d.alive())
			check("...the captain left alone (%.0f hp)" % p.health_component.current_health, p.health_component.current_health >= p.health_component.max_health)
			# (it landed ~0.75 s after the throw)
			until = TK.wait_secs(1.5)
		3:
			check("its time up, it falls apart", not is_instance_valid(d) or not d.is_inside_tree())
			check("...and they turn back to the captain", g.all(func(x): return x._lure == null))
			for x in g:
				TK.calm(x)
			hp = g[0].health.current_health
			d = load("res://scripts/gadgets/gadget_decoy.gd").landed(self, 2, g[0].global_position + Vector3(1.0, 0, 0), p)
			d.life = 0.4
			until = TK.wait_secs(1.0)
		4:
			check("a Mk III goes off when it falls apart (%.0f -> %.0f)" % [hp, g[0].health.current_health], g[0].health.current_health < hp)
			return TK.done(fails)
	step += 1
	return false
