extends SceneTree
## (1.26) The base of the t/weapons/plus_<weapon> tests (not a test itself: t/ has no group here). The tree mastered,
## its alternates switched on and its second ultimate on R; then each new move played by a dummy: the alternate sprint
## attack, right-click and aerial, the aerial heavy and the second ultimate. Each is the Technique it should be, it
## hits, and you end it back on your feet. A test extends this with WEAPON (an item id; "" for black leg) and TREE.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var WP
var moves: Array = []
var i := 0
var taken := 0.0
var deadline := 0
var step := 0
var until := 0
var fails := 0


func weapon() -> String:
	return ""


## The off hand: an item id, "same" (a copy of the main hand's), "kicks" (no weapon: black leg), "" (none).
func offhand() -> String:
	return ""


func tree_id() -> String:
	return ""


## The hands as the test asks (after the stage drew the main weapon).
func arm() -> void:
	match offhand():
		"":
			if weapon() == "":
				p.unequip_weapon()
		"kicks":
			p.unequip_weapon()
			p.learn_black_leg()
		"same":
			p.set_offhand(p.equipped_weapon.duplicate())
		_:
			var it = load("res://scripts/loot/item_db.gd").get_item(offhand())
			p.inventory_component.add_item(it, 1)
			p.set_offhand(it)


func _initialize() -> void:
	TK.seed_of(self)
	var o := {"hud": false, "dummy": Vector3(0, 0, -2.4)}
	if weapon() != "":
		o["weapon"] = weapon()
	stage = TK.stage(self, o)


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
			WP = load("res://scripts/progression/weapon_plus.gd")
			var t := tree_id()
			var pre: String = load("res://scripts/progression/skill_trees.gd").ELEMENTS[t][0]
			stage.camera_rig.rotation.y = 0.0
			stage.dummy.health_component.max_health = 100000.0
			stage.dummy.health_component.current_health = 100000.0
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			arm()
			check("the style trains the %s tree (%s)" % [t, p.style()], load("res://scripts/progression/skill_tree.gd").style_tree(p.style()) == t)
			p.progression.master_all()
			for slot in WP.ALT_SLOTS:
				p.progression.set_version("%s_alt_%s" % [pre, slot], 1)
			var d: Dictionary = WP.TREES[t]
			check("the second ultimate on R", p.power.equip(str(d["ult_b"][1]), p.power.ULT))
			moves = [["sprint", d["alts"][1]], ["heavy", d["alts"][2]], ["air", d["alts"][0]], ["air", d["air_heavy"]], ["ult", d["ult_b"][1]]]
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			if i >= moves.size():
				return TK.done(fails)
			var mv: Array = moves[i]
			var air: bool = mv[0] == "air"
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5 if air else 0.05, 1.9)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.air_uses.clear()
			p.power.cooldowns.clear()
			taken = 0.0
			if mv[0] == "ult":
				p.power.ult = p.power.ULT_MAX
				check("%s cast from R" % mv[1], p.power.try_cast(p.power.ULT))
			else:
				p.state_machine.force_state("Technique", {"id": mv[1]})
			until = TK.wait_ticks(3)
		2:
			var st = p.state_machine.current_state
			check("%s plays (%s)" % [moves[i][1], p.current_state_name()], p.current_state_name() == "Technique" and st.id == moves[i][1])
			deadline = TK.wait_secs(5.0)
			until = TK.wait_secs(0.3)
		3:
			if not p.is_free() and TK.ticking(deadline):
				return false
			check("%s hits (%.0f)" % [moves[i][1], taken], taken > 0.0)
			check("%s ends on your feet (%s)" % [moves[i][1], p.current_state_name()], p.is_free() and p.is_on_floor())
			i += 1
			step = 1
			until = TK.wait_secs(0.4)
			return false
	step += 1
	return false
