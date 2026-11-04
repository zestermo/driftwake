extends SceneTree
## 1.30 enemy health bars: a calm grunt far off has none; hit, it gets the bar and the red marker over its head, its
## fill its health; out of the fight the bar fades and goes ~5 s later; aggro'd (in a fight) it comes back; the
## townsfolk beside you never get one; with a menu open, none show.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var bars
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"grunts": [{"post": Vector3(0.0, 0, -26.0), "role": "sword", "seed": 71}],
		"npc": {"name": "Fishwife Ada", "at": Vector3(-2, 0, -3)}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _calm() -> void:
	g.state = g.S.IDLE
	g._player = null
	g.process_mode = Node.PROCESS_MODE_DISABLED


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			g = stage.camp.grunts[0]
			bars = stage.hud._enemy_bars
			until = TK.wait_secs(1.0)
		1:
			_calm()
			until = TK.wait_secs(0.6)
		2:
			check("a calm grunt 26 m off: no bar", bars.shown.is_empty())
			g.health.current_health = g.health.max_health * 0.5
			until = TK.wait_secs(0.6)
		3:
			check("hit: the bar over it", bars.shown.has(g.get_instance_id()))
			var e: Dictionary = bars.shown.get(g.get_instance_id(), {})
			var want: int = Levels.REF - stage.player.progression.level
			check("...its level badge: a level-0 grunt reads %d, gap %d (%s)" % [Levels.REF, want, e],
				int(e.get("lv", -1)) == Levels.REF and int(e.get("gap", -99)) == want)
			check("...the townsfolk beside you get none", bars.shown.size() == 1 and not bars.shown.values().any(func(e): return e["n"] == stage.npc))
			until = TK.wait_secs(4.6)
		4:
			check("4.5 s out of the fight: fading (%.2f)" % bars.alpha(float(bars.shown.get(g.get_instance_id(), {"t": 99.0})["t"])),
				bars.shown.has(g.get_instance_id()) and bars.alpha(float(bars.shown[g.get_instance_id()]["t"])) < 1.0)
			until = TK.wait_secs(1.5)
		5:
			check("...and gone after ~5 s", bars.shown.is_empty())
			g.state = g.S.CHASE
			until = TK.wait_secs(0.6)
		6:
			check("aggro'd (in a fight): the bar again", bars.shown.has(g.get_instance_id()))
			stage.hud.set_menu_open(true)
			check("a menu open: none show", not bars.visible)
			stage.hud.set_menu_open(false)
			return TK.done(fails)
	step += 1
	return false
