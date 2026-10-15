extends SceneTree
## A blow sounds like what landed: a cutlass slices, a finisher slices heavy, an axe chops, a fist punches, a
## grunt's cutlass and ball on the captain slice and thud; a parry with a blade clashes, bare-handed it knocks.
## The impact rides HitData over the wire; menus open and close and their buttons confirm / go back on UIStyle.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var cm
var ui
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -6), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Our blow on the grunt (caught idle, so it can't guard); the sound it made.
func strike(kind: String = "") -> String:
	g._enter_idle()
	var h = p.melee_hit(10.0, kind)
	h.damage = 1.0
	cm.last_impact = ""
	g.hurtbox.take_hit(h, p)
	return cm.last_impact


## The grunt's blow on the captain.
func struck(h) -> String:
	p.state_machine.force_state("Idle", {})
	cm.last_impact = ""
	p.hurtbox.take_hit(h, g)
	return cm.last_impact


func parry_guard() -> String:
	p.state_machine.force_state("Parry", {})
	cm.last_guard = ""
	p.hurtbox.take_hit(g._hit_light, g)
	return cm.last_guard


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			g = stage.camp.grunts[0]
			cm = root.get_node("CombatManager")
			ui = load("res://scripts/ui/ui_style.gd")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			until = TK.wait_secs(0.6)
		1:
			check("a cutlass blow slices (%s)" % cm.impact_sound(p.melee_hit(10.0)), strike() == "slice")
			check("a cutlass finisher slices heavy", strike("finisher") == "slice_heavy")
			var h = p.melee_hit(10.0)
			h.knockdown = true
			check("a blow that floors them slices heavy", cm.impact_sound(h) == "slice_heavy")
			var net = root.get_node("Net")
			check("the impact rides the hit over the wire", net.hit_unpack(net.hit_pack(p.melee_hit(10.0))).impact == "slice")
			check("a grunt's cutlass slices the captain", struck(g._hit_light) == "slice")
			var shot = g._hit_light.duplicate()
			shot.ranged = true
			shot.impact = "shot"
			check("a grunt's ball thuds into the captain", struck(shot) == "shot_hit")
			until = TK.wait_ticks(30)
		2:
			check("parrying a cutlass with a cutlass clashes", parry_guard() == "clash")
			p.state_machine.force_state("Idle", {})
			p.equip_weapon(load("res://scripts/loot/item_db.gd").get_item("boarding_axe"), false)
			check("an axe chops (style %s)" % p.style(), strike() == "chop")
			p.unequip_weapon()
			check("a fist punches (style %s)" % p.style(), strike() == "punch")
			check("a fist finisher punches heavy", strike("finisher") == "punch_heavy")
			until = TK.wait_ticks(30)
		3:
			check("parrying a cutlass bare-handed knocks", parry_guard() == "block")
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(30)
		4:
			ui.played.clear()
			TK.act("inventory")
			until = TK.wait_ticks(6)
		5:
			check("opening the inventory plays open (%s)" % str(ui.played), ui.played.has("open"))
			TK.act("inventory")
			until = TK.wait_ticks(6)
		6:
			check("closing it plays close (%s)" % str(ui.played), not ui.played.is_empty() and ui.played.back() == "close")
			ui.played.clear()
			var ok = ui.button("Sail")
			root.add_child(ok)
			ok.pressed.emit()
			ok.queue_free()
			until = TK.wait_ticks(2)
		7:
			var back = ui.button("Back")
			root.add_child(back)
			back.pressed.emit()
			back.queue_free()
			until = TK.wait_ticks(2)
		8:
			check("a button confirms, a Back button goes back (%s)" % str(ui.played), ui.played == ["confirm", "back"])
			return TK.done(fails)
	step += 1
	return false
