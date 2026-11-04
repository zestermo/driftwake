extends SceneTree
## 1.30 enemy toughness (docs/v1_30_plan.md "Boss scaling", "Enemy toughness"): health x(1 + 0.85 per extra captain),
## foes' poise x(1 + 0.5), their blows +10% a captain past the first; a captain's own poise never scales. Pirate crews
## (and marines) carry +30% health solo too; the drowned don't. A stronghold boss's health follows the crew mid-fight.
const TK := preload("res://tools/dev/test_kit.gd")
const NET := "res://scripts/net/network_manager.gd"
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -12.0), "yaw": PI, "mode": "stand", "seed": 3}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _near(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if not is_equal_approx(float(a[i]), float(b[i])):
			return false
	return true


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var N = load(NET)
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			var hp: Array = [1, 2, 3, 4].map(func(n): return N.hp_scale_for(n))
			var dm: Array = [1, 2, 3, 4].map(func(n): return N.dmg_scale_for(n))
			var po: Array = [1, 2, 3, 4].map(func(n): return N.poise_scale_for(n))
			check("health by crew %s" % [hp], _near(hp, [1.0, 1.85, 2.7, 3.55]))
			check("foes' damage by crew %s" % [dm], _near(dm, [1.0, 1.1, 1.2, 1.3]))
			check("foes' poise by crew %s" % [po], _near(po, [1.0, 1.5, 2.0, 2.5]))
			var g = stage.camp.grunts[0]
			var G = load("res://scripts/enemies/pirate_grunt.gd")
			var want: float = G.MAX_HP * 1.3 * Levels.hp_k(g.level, g._lv_ref())
			check("a pirate has +30%% health solo (%.0f, want %.0f)" % [g.health.max_health, want], is_equal_approx(g.health.max_health, want))
			var dr = load("res://scripts/enemies/drowned.gd").new()
			check("...the drowned don't", is_equal_approx(dr._crew_k(), 1.0))
			dr.free()
			var foe := Poise.make("grunt")
			var me := Poise.make("player")
			check("solo: a grunt's poise is its own (%.0f)" % foe.cap(), is_equal_approx(foe.cap(), 50.0))
			var net = root.get_node("Net")
			var was: Dictionary = net.roster
			net.active = true
			net.roster = {1: {}, 2: {}, 3: {}, 4: {}}
			var c4 := foe.cap()
			var d4: float = net.dmg_scale()
			var m4 := me.cap()
			var h4: float = net.hp_scale()
			net.roster = {1: {}, 2: {}}
			var c2 := foe.cap()
			net.active = false
			net.roster = was
			check("four captains: its poise x2.5 (%.0f), their blows x1.3 (%.2f), health x3.55 (%.2f)" % [c4, d4, h4],
				is_equal_approx(c4, 125.0) and is_equal_approx(d4, 1.3) and is_equal_approx(h4, 3.55))
			check("...two: poise x1.5 (%.0f)" % c2, is_equal_approx(c2, 75.0))
			check("...a captain's own poise doesn't scale (%.0f)" % m4, is_equal_approx(m4, 60.0))
			return TK.done(fails)
	step += 1
	return false
