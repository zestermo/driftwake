extends SceneTree
## Health mends slowly out of a fight only: none for CALM_S after a blow taken, then about REGEN_PCT of max
## health a second; a hit you land stops it again; a meal with regen_pct (Fisherman's Stew) speeds it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func hp() -> float:
	return p.health_component.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.current_health = 40.0
			p._since_hit = 0.0
			hp0 = hp()
			until = TK.wait_secs(5.0)
		1:
			check("no regen within %d s of a blow (%.1f -> %.1f)" % [int(p.CALM_S), hp0, hp()], is_equal_approx(hp(), hp0) and p.in_fight())
			until = TK.wait_secs(4.0)
		2:
			check("out of the fight", not p.in_fight())
			hp0 = hp()
			until = TK.wait_secs(2.0)
		3:
			var rate: float = (hp() - hp0) / 2.0
			var want: float = p.health_component.max_health * p.REGEN_PCT
			check("then it mends at ~%.1f a second (%.2f)" % [want, rate], rate > want * 0.8 and rate < want * 1.25)
			p.fought()
			hp0 = hp()
			until = TK.wait_secs(2.0)
		4:
			check("a hit you land stops it", is_equal_approx(hp(), hp0))
			p.progression.eat_meal("fish_stew")
			p._since_fight = 100.0
			hp0 = hp()
			until = TK.wait_secs(2.0)
		5:
			var rate: float = (hp() - hp0) / 2.0
			var want: float = p.health_component.max_health * p.REGEN_PCT * 1.5
			check("Fisherman's Stew mends half again faster (~%.1f a second: %.2f)" % [want, rate], rate > want * 0.8 and rate < want * 1.25)
			return TK.done(fails)
	step += 1
	return false
