extends SceneTree
## The coral atoll's boss, the giant hermit crab (atoll_hermit.gd): its shell takes the blows (the crab barely hurt)
## until it cracks off; then the soft body takes more than the blow; hurt enough bare, it scuttles to one of the spare
## shells on its flat, backs in and hides (nothing reaches it), then bursts out wearing it, the spare gone from the flat.
const TK := preload("res://tools/dev/test_kit.gd")
const D := preload("res://scripts/island/themes/atoll_data.gd")
var stage
var p
var crab
var step := 0
var until := 0
var fails := 0
var waited := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _blow(dmg: float):
	var h = load("res://scripts/combat/hit_data.gd").new()
	h.damage = dmg
	h.poise = 0.0
	crab._on_hit(h, p)


func _process(d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.get_node("HealthComponent").max_health = 99999.0
			p.get_node("HealthComponent").current_health = 99999.0
			var th = load("res://scripts/island/themes/island_themes.gd").of("atoll")
			check("the atoll's boss is the hermit crab", th.bosses == ["hermit_crab"] and str(th.beasts["hermit_crab"]["script"]).contains("atoll_hermit"))
			var at: Vector3 = p.global_position + Vector3(0, 0, -16.0)
			crab = load(th.beasts["hermit_crab"]["script"]).new()
			crab.setup({"post": at, "yaw": 0.0, "level": 6, "variant": 0, "name": "The Shell King"})
			stage.add_child(crab)
			crab.global_position = at
			until = TK.wait_ticks(10)
		1:
			var spares: Array = stage.get_children().filter(func(n): return str(n.name).contains("Spare"))
			check("it wears its shell, three spares lying round its flat (%d)" % spares.size(), crab.shell_on and crab.get_node("Model/Body/Shell").visible and spares.size() == 3)
			crab.alert()
			var hp0: float = crab.health.current_health
			_blow(100.0)
			var lost: float = hp0 - crab.health.current_health
			check("a blow on its shell barely reaches it (%.0f of 100)" % lost, lost > 0.0 and lost < 50.0 and crab.shell_on)
			var n := 0
			while crab.shell_on and n < 30:
				_blow(100.0)
				n += 1
			check("chipped away, the shell cracks off (%d more blows)" % n, not crab.shell_on and n >= 5)
			hp0 = crab.health.current_health
			_blow(100.0)
			lost = hp0 - crab.health.current_health
			check("bare, its soft body takes more than the blow (%.0f of 100)" % lost, lost > 100.0)
			n = 0
			while not crab._want_hide() and n < 20:
				_blow(100.0)
				n += 1
			check("hurt enough bare, it wants a new shell", crab._want_hide())
			step = 2
			return false
		2:
			waited += d
			if crab.move != "hide" and waited < 14.0:
				return false
			var dist: float = Vector2(crab.global_position.x - crab.spare_at(0).x, crab.global_position.z - crab.spare_at(0).z).length()
			check("it scuttles off to a spare (%.1f m from it after %.1f s) and hides in it" % [dist, waited], crab.move == "hide" and crab.hidden and crab.spares_used == 1 and crab.shell_on and dist < 1.0 and waited < 7.0)
			var hp0: float = crab.health.current_health
			_blow(200.0)
			check("hidden, nothing reaches it", crab.health.current_health == hp0)
			until = TK.wait_secs(D.HERMIT_HIDE_S + 1.0)
		3:
			var spare = stage.get_children().filter(func(n): return str(n.name).contains("Spare0"))[0]
			check("it bursts out wearing the new shell, the spare gone from the flat", not crab.hidden and crab.shell_on and not spare.visible)
			return TK.done(fails)
	step += 1
	return false
