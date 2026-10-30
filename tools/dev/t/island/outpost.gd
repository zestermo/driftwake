extends SceneTree
## 1.23 Marine outposts (MarineOutpost): guards at the door, the armoury locked, the prisoner behind bars. A blade drawn
## in the village gets a warning; kept out, the alarm rings and a squad turns out (guards gone); the squad beaten, the
## outpost is raided (a world flag): the armoury opens, the bars are gone, and the prisoner, let out, pays you.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var o
var gold0 := 0
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


func killer() -> HitData:
	var h := HitData.new()
	h.damage = 99999.0
	h.unblockable = true
	h.impact = "slice"
	return h


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var hc = p.get_node("HealthComponent")
			hc.max_health = 99999.0
			hc.current_health = 99999.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var lp: Vector3 = stage.to_local(p.global_position)
			o = load("res://scripts/island/marine_outpost.gd").make(stage, Vector2(lp.x, lp.z), 30.0, "t_outpost", 1, 2, rng)
			o.global_position = p.global_position + Vector3(0, 0, -22.0)
			check("guards at the door, the armoury locked, the prisoner behind bars",
				o._guards.size() == 2 and not o._chest.interactable.enabled and o._cell_bars.visible)
			TK.act("ready_weapon")
			until = TK.wait_secs(1.2)
		1:
			check("a blade out in the village: a warning, not the alarm yet (armed %s)" % p.armed, p.armed and o._warned.size() == 1 and not o.alarmed)
			until = TK.wait_secs(o.WARN_HOLD + 1.0)
		2:
			check("kept out: the alarm, a squad turns out (%d), the guards gone" % (o._camp.grunts.size() if o._camp else -1),
				o.alarmed and o._camp != null and o._camp.grunts.size() >= o.SQUAD and o._guards.is_empty())
			for g in o._camp.grunts:
				g._on_hit(killer(), p)
			until = TK.wait_secs(2.0)
		3:
			check("the squad beaten: raided (a world flag), the armoury open, the bars gone",
				o.raided and root.get_node("GameManager").world_flags.has("t_outpost") and o._chest.interactable.enabled and not o._cell_bars.visible)
			check("...its orders captured: the Admiralty's stronghold known (1.27)", root.get_node("GameManager").world_flags.has("stronghold_known"))
			gold0 = p.inventory_component.count("gold")
			o._free_prisoner(p)
			until = TK.wait_ticks(3)
		4:
			check("the prisoner let out pays you (%d gold)" % (p.inventory_component.count("gold") - gold0), p.inventory_component.count("gold") > gold0)
			return TK.done(fails)
	step += 1
	return false
