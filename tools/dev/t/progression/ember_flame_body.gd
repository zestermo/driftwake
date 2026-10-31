extends SceneTree
## Ember's Flame Body by its form (1.27, FruitForms, Player._flame_body): Active, Flicker cast, blows pass through while
## it lasts; Reflex (150 Flickers, mastery 12), a hit passes now and then, at most once every 6 s; Nature (400, 24), shot
## always passes; another fruit's captain is hit as ever.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
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


func _hit(ranged: bool) -> float:
	var p = stage.player
	var hc = p.health_component
	hc.current_health = hc.max_health
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 5.0
	hd.knockback_force = 0.0
	hd.ranged = ranged
	p._on_hit_received(hd, null)
	return hc.max_health - hc.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	match step:
		0:
			p.power.fruit = "wolf"
			check("another fruit's captain: hit as ever", _hit(false) > 0.0)
			p.power.fruit = "ember"
			check("Ember, fresh: hit as ever", _hit(false) > 0.0)
			p.power.loadout[0] = "flicker"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			p.state_machine.force_state("Idle", {})
			var why: String = p.power.can_cast(0)
			check("Flicker cast (%s)" % why, p.power.try_cast(0))
			check("...blows pass through the flames", _hit(false) == 0.0 and _hit(true) == 0.0)
			p.power.buffs.clear()
			pr.uses["flicker"] = 150
			pr.mastery["ember"] = {"lv": 12, "xp": 0}
			var passed := 0
			for i in range(40):
				if _hit(false) == 0.0:
					passed += 1
			check("Reflex: a hit passes now and then, once in 6 s at most (%d of 40)" % passed, passed == 1)
			pr.uses["flicker"] = 400
			pr.mastery["ember"] = {"lv": 24, "xp": 0}
			var shots := 0
			for i in range(10):
				if _hit(true) == 0.0:
					shots += 1
			check("Nature: shot always passes (%d of 10)" % shots, shots == 10)
			# Cinder Fist's forms: at Reflex a dodge's end throws one by itself, once in 4 s
			pr.uses["fire_fist"] = 0
			check("Cinder Fist at Active: no dodge throw", not p.ember_dodge_reflex())
			pr.uses["fire_fist"] = 150
			check("...at Reflex: a dodge's end throws one", p.ember_dodge_reflex())
			check("...not twice in 4 s", not p.ember_dodge_reflex())
			# Blazing Ring's Reflex: a real landing rings by itself (not a hop, not twice in 5 s)
			pr.uses["fire_ring"] = 150
			# the awakening: Sunborn, 30 s of the aura and the flames
			pr.uses["flicker"] = 0
			p.power.loadout[4] = "sunborn"
			p.power.ult = p.power.ULT_MAX
			p.state_machine.force_state("Idle", {})
			check("Sunborn cast: awakened (%s)" % p.power.can_cast(4), p.power.try_cast(4) and p.power.buff("awakened"))
			var sh := 0
			for i in range(6):
				if _hit(true) == 0.0:
					sh += 1
			check("...shot passes through the sun (%d of 6)" % sh, sh == 6)
			check("Blazing Ring at Reflex: a hop doesn't ring, a real landing does, not twice in 5 s", not p.ember_landing_ring(2.0) and p.ember_landing_ring(9.0) and not p.ember_landing_ring(9.0))
			return TK.done(fails)
	step += 1
	return false
