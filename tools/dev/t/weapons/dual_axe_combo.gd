extends SceneTree
## Two axes in hand fight as twin axes (an axe beside a cutlass or a dagger is still dual wield, one axe still the
## axe): its own stance with a head in each hand; the light combo's right chop, left chop and hook each land on
## the dummy, and the heavy (Berserker Frenzy) lands blow after blow; put away, one goes on the back and one on
## the hip.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var taken := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -1.9), "weapon": "boarding_axe"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var axe = ItemDB.get_item("boarding_axe")
			var PL = load("res://scenes/player/player.gd")
			check("one axe is the axe, an axe and a cutlass dual wield, an axe and a dagger too",
				PL.style_of(axe, null) == "axe" and PL.style_of(axe, ItemDB.get_item("cutlass")) == "dual_sword"
				and PL.style_of(ItemDB.get_item("cutlass"), axe) == "dual_sword" and PL.style_of(axe, ItemDB.get_item("dagger")) == "dual_sword")
			check("two axes (any two designs) are twin axes", PL.style_of(axe, ItemDB.get_item("hatchet")) == "dual_axe"
				and PL.style_of(ItemDB.get_item("reavers_axe"), ItemDB.get_item("tomahawk")) == "dual_axe")
			p.inventory_component.add_item(axe, 1)
			check("a second axe goes in the off hand", p.set_offhand(axe))
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.6)
		1:
			check("they fight as twin axes (%s, stance %s)" % [p.style(), p.body_model.stance], p.style() == "dual_axe" and p.body_model.stance == "dual_axe")
			var o = p.body_model.offhand
			check("an axe in each hand", o != null and o.get_parent() == p.body_model.hand_l and p.body_model.weapon.get_parent() == p.body_model.hand_r)
			var hr: Vector3 = p.body_model.hand_r.global_position - p.global_position
			var hl: Vector3 = p.body_model.hand_l.global_position - p.global_position
			check("on guard both hands up in front (%.2f / %.2f m up)" % [hr.y, hl.y], hr.y > 0.9 and hl.y > 0.8)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(5)
		2:
			check("left click chops right-handed (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_1")
			until = TK.wait_secs(0.3)
		3:
			check("the chop lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		4:
			check("it chains into the left-hand chop (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_2")
			until = TK.wait_secs(0.3)
		5:
			check("the left chop lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		6:
			check("then the hook (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_3")
			until = TK.wait_secs(0.4)
		7:
			check("the hook lands (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(1.0)
		8:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hits = 0
			taken = 0.0
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		9:
			check("right click: Berserker Frenzy (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_heavy")
			until = TK.wait_secs(1.1)
		10:
			check("blow after blow lands (%d hits, %.0f)" % [hits, taken], hits >= 4 and taken > 0.0)
			until = TK.wait_secs(0.6)
		11:
			if not p.is_free():
				return false
			TK.act("ready_weapon")
			until = TK.wait_secs(1.0)
		12:
			check("put away: one on the back, one on the hip (%s, %s)" % [p.body_model.weapon.get_parent().name, p.body_model.offhand.get_parent().name],
				p.body_model.weapon.get_parent().name == "BackSocket" and p.body_model.offhand.get_parent().name == "HipSocketL")
			return TK.done(fails)
	step += 1
	return false
