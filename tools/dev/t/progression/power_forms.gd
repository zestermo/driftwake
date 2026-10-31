extends SceneTree
## The forms of each fruit's powers 3-5 (1.27, PowerComponent.AUTO): at Active nothing fires by itself; at Reflex (150
## uses, mastery 12) a power fires at its moment if it's on a bar, not again for 12 s; at Nature (400, mastery 24) it
## fires off the bar too, every 6 s. The moments come from play: a blow on you (Bubble Trap), surrounded (Iron Slam),
## a dodge (Thunder Spear), a kill (Bubble Bath).
const TK := preload("res://tools/dev/test_kit.gd")
const Y := 3.05
var stage
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(2, 0, -2), "role": "sword", "seed": 11}, {"post": Vector3(-2, 0, -2), "role": "sword", "seed": 12},
		{"post": Vector3(0, 0, 2), "role": "sword", "seed": 13}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func form_to(pr, id: String, fruit: String, uses: int, lv: int) -> void:
	pr.uses[id] = uses
	pr.mastery[fruit] = {"lv": lv, "xp": 0}


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	var gs: Array = stage.camp.grunts
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			for g in gs:
				g.set_physics_process(false)
			# Bubble Trap on the "hurt" moment
			p.power.fruit = "bubble"
			for i in range(p.power.loadout.size()):
				p.power.loadout[i] = ""
			for i in range(p.power.other_loadout.size()):
				p.power.other_loadout[i] = ""
			p.power.loadout[1] = "bubble_trap"
			p.power._auto_at.clear()
			check("at Active nothing fires", p.power.auto_moment("hurt", gs[0]).is_empty())
			form_to(pr, "bubble_trap", "bubble", 150, 12)
			check("Reflex, on the bar: Bubble Trap fires at the blow", p.power.auto_moment("hurt", gs[0]) == ["bubble_trap"])
			check("...not again inside 12 s", p.power.auto_moment("hurt", gs[0]).is_empty())
			p.power._auto_at.clear()
			p.power.loadout[1] = ""
			check("Reflex, off every bar: it doesn't", p.power.auto_moment("hurt", gs[0]).is_empty())
			form_to(pr, "bubble_trap", "bubble", 400, 24)
			check("Nature: it fires off the bar too", p.power.auto_moment("hurt", gs[0]) == ["bubble_trap"])
			# a real blow brings the moment: the trap answers it
			p.power._auto_at.clear()
			gs[1].health.current_health = gs[1].health.max_health
			var hd := HitData.new()
			hd.damage = 5.0
			hd.unblockable = true
			p.hurtbox.take_hit(hd, gs[1])
			until = TK.wait_ticks(3)
		2:
			check("a real blow on you: whoever struck is bubbled (state %d)" % int(gs[1].state), int(gs[1].state) == int(gs[1].S.STAGGER))
			# Iron Slam when surrounded (the three grunts close round you)
			p.power.fruit = "iron"
			p.power._auto_at.clear()
			form_to(pr, "iron_slam", "iron", 400, 24)
			for i in range(gs.size()):
				gs[i].set_physics_process(true)
				gs[i].poise._immune_until = -1
				gs[i].global_position = p.global_position + Vector3(cos(TAU * i / 3.0), 0, sin(TAU * i / 3.0)) * 2.0
			until = TK.wait_secs(1.6)
		3:
			var down: int = gs.filter(func(g): return int(g.state) == int(g.S.DOWN)).size()
			check("surrounded: Iron Slam by itself (%d of 3 floored)" % down, down >= 2)
			# Thunder Spear at a dodge's end
			p.power.fruit = "storm"
			form_to(pr, "thunder_spear", "storm", 400, 24)
			check("a dodge's end: Thunder Spear", "thunder_spear" in p.power.auto_moment("dodge"))
			# Bubble Bath on a kill
			p.power.fruit = "bubble"
			form_to(pr, "bubble_bath", "bubble", 400, 24)
			p.health_component.current_health = p.health_component.max_health * 0.5
			hp0 = p.health_component.current_health
			var g = gs[0]
			g.health.current_health = 1.0
			var kill := HitData.new()
			kill.damage = 50.0
			kill.unblockable = true
			g.hurtbox.take_hit(kill, p)
			p.power.on_sword_hit(g, kill)
			until = TK.wait_ticks(3)
		4:
			check("a kill: Bubble Bath heals you (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health > hp0)
			return TK.done(fails)
	step += 1
	return false
