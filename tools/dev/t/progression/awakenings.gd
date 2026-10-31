extends SceneTree
## The awakenings (1.27, fruit mastery 30): each fruit's (Stormborn, Skyborn... Sunborn's sisters) casts from the
## ultimate slot and awakens it for 30 s: every power of that fruit at its Nature (FruitForms.form), half the energy,
## cooldowns back twice as fast; another fruit's powers aren't touched; it wears off.
const TK := preload("res://tools/dev/test_kit.gd")
const AW := {"storm": ["stormborn", "chain_lightning"], "gust": ["skyborn", "gust_cone"], "wolf": ["moonborn", "pounce"],
	"bear": ["mountainborn", "bear_roar"], "vine": ["rootborn", "vine_snare"], "iron": ["ironborn", "iron_guard"],
	"bubble": ["foamborn", "bubble_shield"], "clockwork": ["timeborn", "time_stop"], "echo": ["soundborn", "shatter_note"]}
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	var FF = load("res://scripts/progression/fruit_forms.gd")
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			for fr in AW:
				var aw: String = AW[fr][0]
				var pw: String = AW[fr][1]
				p.power.fruit = fr
				p.power.buffs.clear()
				check("%s: %s at Active before" % [fr, pw], FF.form(pr, pw, fr) == FF.ACTIVE)
				p.power.loadout[p.power.ULT] = aw
				p.power.ult = p.power.ULT_MAX
				p.power._ult_lock = 0.0
				p.power.cooldowns.clear()
				p.state_machine.force_state("Idle", {})
				check("...%s casts" % aw, p.power.try_cast(p.power.ULT))
				check("...%s at its Nature while awakened, Ember's untouched" % pw, FF.form(pr, pw, fr) == FF.NATURE and FF.form(pr, "fire_fist", "ember") == FF.ACTIVE)
			# half the energy: the last fruit (echo) casting Shatter Note
			p.power.loadout[0] = "shatter_note"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			var e0: float = p.power.energy
			p.state_machine.force_state("Idle", {})
			p.power.try_cast(0)
			check("half the energy while awakened (%.0f spent of 28)" % (e0 - p.power.energy), absf((e0 - p.power.energy) - 14.0) < 0.6)
			p.power.cooldowns["sonar"] = 10.0
			until = TK.wait_secs(2.0)
		2:
			check("cooldowns back twice as fast (10 s -> %.1f s after 2 s)" % float(p.power.cooldowns.get("sonar", 0.0)), float(p.power.cooldowns.get("sonar", 0.0)) < 6.5)
			p.power.buffs["awakened"] = 0.5
			until = TK.wait_secs(1.0)
		3:
			check("it wears off: Shatter Note back to Active", FF.form(pr, "shatter_note", "echo") == FF.ACTIVE)
			return TK.done(fails)
	step += 1
	return false
