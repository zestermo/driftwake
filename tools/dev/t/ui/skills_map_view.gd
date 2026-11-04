extends SceneTree
## The skill map (1.30, docs/v1_30_previews.md section 5): every tree one map in a panel that opens centred on what you
## can buy next, zooms round the pointer (the wheel, the + / - buttons) and pans (a drag); its nodes come in three
## shapes: abilities round, passives diamonds, stat steps pips; a node past the panel's edge isn't clickable; the card
## names the shape and branch and what it waits on.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
var pr
var STD
var step := 0
var until := 0
var fails := 0
var k0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func wheel(up: bool, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = at
	sm._gui_input(e)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			STD = load("res://scripts/ui/skill_tree_draw.gd")
			check("shapes: Air Dash an ability, Hang Time a passive, Dash Distance stat pips, a Quick Hands chain pips",
				STD.shape_of("ac_airdash") == "ability" and STD.shape_of("ac_hangtime") == "passive" and STD.shape_of("ac_dashdist") == "stat" and STD.shape_of("k_qhands") == "stat")
			check("...an ultimate and a technique round, a mastery passive a diamond, Feather Fall's variant a diamond",
				STD.shape_of("k_petals") == "ability" and STD.shape_of("k_tiger") == "ability" and STD.shape_of("k_elem") == "passive" and STD.shape_of("ac_feather") == "passive")
			while pr.mastery_level("acrobatics") < 5:
				pr.add_mastery("acrobatics", pr.mastery_to_next(pr.mastery_level("acrobatics"), "acrobatics"))
			pr.buy("m_geppo")
			root.size = Vector2i(1920, 1080)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("adventure", "acrobatics")
			until = TK.wait_ticks(4)
		1:
			var want := Vector2.ZERO
			var bd := INF
			for id in SkillTrees.nodes_of("acrobatics"):
				var n: Dictionary = SkillTrees.node_def(id)
				if n["kind"] != "version" and pr.buy_why(id) == "" and (n["pos"] as Vector2).length() < bd:
					bd = (n["pos"] as Vector2).length()
					want = n["pos"]
			check("opens centred on what you can buy next (%s, want %s)" % [str(sm._map_pan), str(want)], sm._map_pan.is_equal_approx(want) and bd < INF)
			check("Air Dash (buyable) is drawn as a node you can click", sm._rect_of("n:ac_airdash").size != Vector2.ZERO)
			k0 = sm._map_k
			var c: Vector2 = sm._map_rect.get_center() + Vector2(60, 0)
			var under: Vector2 = sm._map_pan + (c - sm._map_rect.get_center()) / sm._map_k
			wheel(true, c)
			var under2: Vector2 = sm._map_pan + (c - sm._map_rect.get_center()) / sm._map_k
			check("the wheel zooms in round the pointer (%.2f -> %.2f)" % [k0, sm._map_k], sm._map_k > k0 and under.distance_to(under2) < 0.01)
			for i in 20:
				wheel(false, c)
			check("...and out, no further than its limit (%.2f)" % sm._map_k, is_equal_approx(sm._map_k, sm.MAP_ZOOMS.x))
			sm._act("map:in")
			check("the + button zooms in", sm._map_k > sm.MAP_ZOOMS.x)
			sm._map_pan = Vector2(4000, 0)
			until = TK.wait_ticks(3)
		2:
			check("panned far off: the nodes there aren't clickable", sm._hit_at(sm._map_rect.get_center()) == "" and sm._rect_of("n:ac_airdash").size == Vector2.ZERO)
			sm._act("map:next")
			sm.sel = "n:ac_airdash"
			until = TK.wait_ticks(3)
		3:
			check("N brings it back (%s)" % str(sm._map_pan), sm._rect_of("n:ac_airdash").size != Vector2.ZERO)
			check("the card says what it is and where: ABILITY · AIR", STD.SHAPE_NAME[STD.shape_of("ac_airdash")] == "Ability" and STD.branch_name("ac_airdash") == "Air")
			check("Twin Dash waits on Air Dash: its parent", pr.parent_why("ac_twindash") == "Needs Air Dash first")
			return TK.done(fails)
	step += 1
	return false
