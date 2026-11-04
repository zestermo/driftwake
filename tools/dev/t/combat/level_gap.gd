extends SceneTree
## (1.30) The level gap (docs/v1_30_plan.md "round 5"): g = the foe's level minus the captain's. A gap -4 foe takes
## x1.24 and deals x0.52, its poise x0.52; a +5 foe takes x0.7, deals x1.6, poise x1.6; gap 0 is unchanged; a level-0
## foe counts as its curves' ref; the overkill a throw needs moves with it (and the other way for a captain thrown).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var got: HitData
var SP


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -6.0), "yaw": PI, "mode": "stand", "seed": 3}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(dmg: float, poise: float = 6.0, knockdown: bool = false, gap: int = 0) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.poise = poise
	h.knockdown = knockdown
	h.gap = gap
	return h


func _near(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if absf(float(a[i]) - float(b[i])) > 0.001:
			return false
	return a.size() == b.size()


func _grab(h: HitData, _a: Node) -> void:
	got = h


func _out(g, p, foe_lv: int, cap_lv: int) -> HitData:
	g.level = foe_lv
	p.progression.level = cap_lv
	got = null
	g.hurtbox.take_hit(blow(10.0), p)
	return got


func _in(g, p, foe_lv: int, cap_lv: int) -> HitData:
	g.level = foe_lv
	p.progression.level = cap_lv
	got = null
	p.hurtbox.take_hit(blow(10.0), g)
	return got


func _poise_drop(gap: int) -> float:
	var po := Poise.make("grunt")
	po.take(blow(0.0, 10.0, false, gap))
	return po.full - po.value


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.is_empty():
				return false
			SP = load("res://scripts/combat/splat.gd")
			var out := [-6, -4, -2, 0, 2, 3, 5].map(func(g): return snappedf(Levels.gap_dmg_out(g), 0.01))
			var inn := [-6, -4, -2, 0, 2, 3, 5].map(func(g): return snappedf(Levels.gap_dmg_in(g), 0.01))
			var spl := [-6, -4, -2, 0, 2, 3, 5].map(func(g): return snappedf(Levels.gap_splat(g), 0.01))
			check("damage out by gap %s" % [out], _near(out, [1.36, 1.24, 1.12, 1.0, 0.88, 0.82, 0.7]))
			check("damage in by gap %s" % [inn], _near(inn, [0.4, 0.52, 0.76, 1.0, 1.24, 1.36, 1.6]))
			check("splat line by gap %s" % [spl], _near(spl, [0.1, 0.4, 0.7, 1.0, 1.3, 1.45, 1.75]))
			check("the badge: grey at -5, white at -4 and +2, red at +3", Levels.badge(-5) == Levels.BADGE_GREY
				and Levels.badge(-4) == Levels.BADGE_WHITE and Levels.badge(2) == Levels.BADGE_WHITE and Levels.badge(3) == Levels.BADGE_RED)
			var g = stage.camp.grunts[0]
			var p = stage.player
			g.set_physics_process(false)
			g.hurtbox.hit_received.connect(_grab)
			p.hurtbox.hit_received.connect(_grab)
			var h := _out(g, p, 7, 11)
			check("a gap -4 foe takes x1.24 (%.2f, gap %d)" % [h.damage, h.gap], is_equal_approx(h.damage, 12.4) and h.gap == -4)
			h = _in(g, p, 7, 11)
			check("...and deals x0.52 (%.2f)" % h.damage, is_equal_approx(h.damage, 5.2) and h.gap == -4)
			h = _out(g, p, 16, 11)
			check("a gap +5 foe takes x0.7 (%.2f)" % h.damage, is_equal_approx(h.damage, 7.0) and h.gap == 5)
			h = _in(g, p, 16, 11)
			check("...and deals x1.6 (%.2f)" % h.damage, is_equal_approx(h.damage, 16.0))
			h = _out(g, p, 11, 11)
			var h2 := _in(g, p, 11, 11)
			check("gap 0 is today's balance (%.2f, %.2f)" % [h.damage, h2.damage], is_equal_approx(h.damage, 10.0)
				and is_equal_approx(h2.damage, 10.0) and h.gap == 0)
			h = _out(g, p, 0, 3)
			check("a level-0 foe counts as level %d (%.2f vs a level-3 captain)" % [Levels.foe_level(g), h.damage],
				Levels.foe_level(g) == Levels.REF and is_equal_approx(h.damage, 10.0))
			check("its poise x0.52 at -4, x1.6 at +5, x1 at 0 (%.2f %.2f %.2f)" % [_poise_drop(-4), _poise_drop(5), _poise_drop(0)],
				is_equal_approx(_poise_drop(-4), 10.0 / 0.52) and is_equal_approx(_poise_drop(5), 10.0 / 1.6) and is_equal_approx(_poise_drop(0), 10.0))
			check("an overkill of 45%% throws a gap -4 foe, not a gap 0 one", SP.wants(blow(45.0, 6.0, false, -4), 0.0, 100.0)
				and not SP.wants(blow(45.0, 6.0, false, 0), 0.0, 100.0))
			check("60%% doesn't throw a gap +5 foe (needs 87.5%%), 90%% does", not SP.wants(blow(60.0, 6.0, false, 5), 0.0, 100.0)
				and SP.wants(blow(90.0, 6.0, false, 5), 0.0, 100.0))
			check("a strong blow: 20%% over throws gap 0, not gap +5 (needs 26%%)", SP.wants(blow(20.0, 6.0, true, 0), 0.0, 100.0)
				and not SP.wants(blow(20.0, 6.0, true, 5), 0.0, 100.0))
			check("a +5 foe throws a captain with 10%% (the line x0.25); a level foe needs 30%%",
				SP.flattens(blow(10.0, 30.0, true, 5), 10.0, 100.0, g) and not SP.flattens(blow(10.0, 30.0, true, 0), 10.0, 100.0, g))
			return TK.done(fails)
	step += 1
	return false
