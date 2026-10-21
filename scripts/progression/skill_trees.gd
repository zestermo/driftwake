class_name SkillTrees
extends RefCounted
## The skill trees of the v1.18.2 redesign (docs/progression_plan.md "Redesign"), grouped in sections:
##   captain    the Captain (levels 1-40)
##   combat     a tree per weapon (mastery 1-30, earned only with that weapon in hand)
##   adventure  Acrobatics, Defense, Sailing, Swimming, Cooking, Fishing, Stealth, Tinkering (levels 1-20)
##   fruit      the Driftfruit you ate (levels 1-20)
## A tree grows up from its root in three branches. Big nodes (moves, techniques, mechanics, passives, the element,
## the ultimate) come by themselves at their level; small stat "steps" (x/3, x/5) are bought with the tree's points
## (one a level) in any order. A variant is two versions of one node: both owned once reached, one active (switched
## at the ship's bunk). Progression reads the effects (same keys as SkillTree's, so the game's readers don't change).
##
## tree_def: {id, name, section, color, max_level, root, branches: [{name, nodes: [ids, big nodes then steps]}]}
## node_def: {id, name, kind, tree, branch (index, -1 the root), level, pos (tree space, y up is -), links, skill,
##   desc, max_steps, versions: [{id, name, desc, level, effects, skill}], effects (a step's are per step)}
##   kind: root | move | tech | mech | passive | elem | ult | step | variant | auto | talent | will | version
##   (a version is its own node too, owned while it's the active one; "passive" counts only in a passive slot)
## Trees not converted yet have a header and no branches (their nodes are still SkillTree's).

const SECTIONS := ["captain", "combat", "adventure", "fruit"]
## id -> [name, section, color, max level], in the order the menu lists them.
const HEADERS := {
	"captain": ["Captain", "captain", Color(0.95, 0.77, 0.37), 40],
	"sword": ["Cutlass", "combat", Color(0.85, 0.85, 0.95), 30],
	"katana": ["Katana", "combat", Color(0.7, 0.85, 1.0), 30],
	"dual": ["Dual Wield", "combat", Color(0.55, 0.85, 1.0), 30],
	"axe": ["Axe", "combat", Color(1.0, 0.7, 0.45), 30],
	"dagger": ["Dagger", "combat", Color(1.0, 0.45, 0.58), 30],
	"dual_dagger": ["Twin Daggers", "combat", Color(0.6, 1.0, 0.45), 30],
	"corsair": ["Corsair", "combat", Color(1.0, 0.5, 0.42), 30],
	"pistol": ["Pistol", "combat", Color(0.95, 0.75, 0.4), 30],
	"unarmed": ["Unarmed", "combat", Color(1.0, 0.85, 0.6), 30],
	"acrobatics": ["Acrobatics", "adventure", Color(0.61, 0.88, 0.54), 20],
	"defense": ["Defense", "adventure", Color(0.91, 0.84, 0.68), 20],
	"sea": ["Sailing", "adventure", Color(0.45, 0.8, 0.85), 20],
	"swim": ["Swimming", "adventure", Color(0.4, 0.7, 1.0), 20],
	"cook": ["Cooking", "adventure", Color(1.0, 0.72, 0.4), 20],
	"fish": ["Fishing", "adventure", Color(0.55, 0.9, 0.75), 20],
	"stealth": ["Stealth", "adventure", Color(0.63, 0.55, 0.85), 20],
	"tinker": ["Tinkering", "adventure", Color(0.85, 0.66, 0.37), 20],
	"ember": ["Ember Fruit", "fruit", Color(1.0, 0.5, 0.15), 20],
	"wolf": ["Wolf Fruit", "fruit", Color(0.75, 0.68, 0.55), 20],
	"vine": ["Vine Fruit", "fruit", Color(0.45, 0.85, 0.3), 20],
}

## Where a branch's big nodes sit (tree space, the root at 0,0): the left and right branches lean out, the middle
## one goes straight up. A step sits off the node it hangs on.
const LEFT := [Vector2(-120, -78), Vector2(-192, -162), Vector2(-252, -248), Vector2(-300, -336), Vector2(-336, -420), Vector2(-362, -500)]
const MID_STEP := 84.0
const STEP_OFF := {0: [Vector2(-84, -28), Vector2(-64, 40)], 1: [Vector2(76, -30), Vector2(-76, -30)], 2: [Vector2(84, -28), Vector2(64, 40)],
	-1: [Vector2(72, -18), Vector2(-72, -18), Vector2(104, 34), Vector2(-104, 34)]}

## Each weapon's element (its two element nodes at 16 and 25): [prefix, name 1, name 2, what it looks like].
const ELEMENTS := {
	"sword": ["s", "Call of the Tide", "Tidewalker", "the sea: spray and foam, and Kraken's Wake raises the deep under your foes"],
	"katana": ["k", "Falling Petals", "Blossom Path", "pale steel light and falling petals"],
	"axe": ["a", "Ember Heart", "Living Fire", "embers and splintered stone"],
	"dual": ["d", "Twin Currents", "Crossing Storm", "twin currents of light, cyan and violet, crossing in an X"],
	"corsair": ["cs", "Black Powder", "Powder Keg", "black powder: scarlet flashes, gold sparks and dark smoke, and Broadside's cannon fire burns"],
	"dagger": ["dg", "Nightfall", "Blood Moon", "shadow: black wisps off the blade and crimson sparks, and Red Eclipse's wounds open in the dark"],
	"dual_dagger": ["dd", "Viper's Kiss", "Serpent's Coil", "venom: green motes and poison bubbling off every wound"],
	"pistol": ["g", "Golden Powder", "Gilded Gun", "gold flashes and powder smoke"],
	"unarmed": ["u", "Rushing Wind", "Gale Fists", "rushing wind and rings of air"],
}

static var _trees: Dictionary = {}
static var _nodes: Dictionary = {}
static var _t: String = ""


static func _ensure() -> void:
	if _trees.is_empty():
		_build()


static func tree_def(id: String) -> Dictionary:
	_ensure()
	return _trees.get(id, {})


static func node_def(id: String) -> Dictionary:
	_ensure()
	return _nodes.get(id, {})


static func nodes() -> Dictionary:
	_ensure()
	return _nodes


static func has_tree(id: String) -> bool:
	return not tree_def(id).is_empty()


## A tree built in the new shape (its nodes are here, not in SkillTree).
static func converted(id: String) -> bool:
	return not tree_def(id).get("branches", []).is_empty()


static func trees_in(section: String) -> Array:
	_ensure()
	return HEADERS.keys().filter(func(t): return HEADERS[t][1] == section)


static func section_of(tree: String) -> String:
	return str(HEADERS[tree][1]) if HEADERS.has(tree) else ""


static func max_level(tree: String) -> int:
	return int(HEADERS[tree][3])


## Every node of a tree (root, big nodes, steps, versions).
static func nodes_of(tree: String) -> Array:
	_ensure()
	return _nodes.keys().filter(func(k): return _nodes[k]["tree"] == tree)


static func node_for_skill(skill_id: String) -> String:
	_ensure()
	for k in _nodes.keys():
		if _nodes[k]["skill"] == skill_id:
			return k
	return ""


# --------------------------------------------------------------------------
# Building
# --------------------------------------------------------------------------
static func _build() -> void:
	_trees = {}
	_nodes = {}
	for t in HEADERS.keys():
		var h: Array = HEADERS[t]
		_trees[t] = {"id": t, "name": h[0], "section": h[1], "color": h[2], "max_level": h[3], "root": "", "branches": []}
	_build_cutlass()
	_build_katana()
	_build_dual()
	_build_axe()
	_build_dagger()
	_build_dual_dagger()
	_build_corsair()
	_build_pistol()
	_build_unarmed()


static func _tree(id: String, branch_names: Array) -> void:
	_t = id
	for b in branch_names:
		_trees[id]["branches"].append({"name": b, "nodes": []})


static func _node(id: String, name_: String, kind: String, branch: int, level: int, effects: Dictionary, desc: String, skill: String, links: Array, pos: Vector2) -> Dictionary:
	if desc == "" and skill != "":
		desc = str(Skills.get_skill(skill).get("desc", ""))
	var n := {"id": id, "name": name_, "kind": kind, "tree": _t, "branch": branch, "level": level, "pos": pos, "links": links,
		"skill": skill, "desc": desc, "max_steps": 0, "versions": [], "effects": effects}
	_nodes[id] = n
	return n


static func _root(id: String, name_: String, effects: Dictionary, desc: String) -> void:
	_node(id, name_, "root", -1, 1, effects, desc, "", [], Vector2.ZERO)
	_trees[_t]["root"] = id


static func _big_pos(branch: int, i: int) -> Vector2:
	if branch == 1:
		return Vector2(0, -MID_STEP * (i + 1))
	var p: Vector2 = LEFT[mini(i, LEFT.size() - 1)]
	return p if branch == 0 else Vector2(-p.x, p.y)


## A big node, next up its branch (linked to the one before it, or the root).
static func _big(id: String, name_: String, kind: String, branch: int, level: int, effects: Dictionary = {}, desc: String = "", skill: String = "") -> Dictionary:
	var list: Array = _trees[_t]["branches"][branch]["nodes"]
	var bigs := list.filter(func(k): return _nodes[k]["kind"] != "step" and not _nodes[k].has("will"))
	var prev: String = bigs[-1] if not bigs.is_empty() else str(_trees[_t]["root"])
	var n := _node(id, name_, kind, branch, level, effects, desc, skill, [prev], _big_pos(branch, bigs.size()))
	list.append(id)
	return n


## A variant: two versions of one node (each [id, name, level, effects, desc, skill]), the first active by default.
static func _variant(id: String, name_: String, branch: int, versions: Array, desc: String = "") -> void:
	var lv := 99
	for v in versions:
		lv = mini(lv, int(v[2]))
	var n := _big(id, name_, "variant", branch, lv, {}, desc)
	for v in versions:
		var sk: String = v[5] if v.size() > 5 else ""
		var vn := _node(v[0], v[1], "version", branch, int(v[2]), v[3], str(v[4]), sk, [id], n["pos"])
		vn["parent"] = id
		n["versions"].append({"id": v[0], "name": v[1], "desc": vn["desc"], "level": int(v[2]), "effects": v[3], "skill": sk})


## A step node (bought a step at a time, `max_steps` of them), hanging off big node `on`; its effects are per step.
static func _step(id: String, name_: String, on: String, max_steps: int, effects: Dictionary, desc: String) -> void:
	var parent: Dictionary = _nodes[on]
	var branch := int(parent["branch"])
	var offs: Array = STEP_OFF[branch]
	var used := _nodes.keys().filter(func(k): return _nodes[k]["kind"] == "step" and on in _nodes[k]["links"]).size()
	var at: Vector2 = parent["pos"] + offs[used % offs.size()] + Vector2(0, 40.0 * int(used / offs.size()))
	# (steps off the root are listed with the middle branch)
	var n := _node(id, name_, "step", branch if branch >= 0 else 1, 1, effects, desc, "", [on], at)
	n["max_steps"] = max_steps
	_trees[_t]["branches"][int(n["branch"])]["nodes"].append(id)


# --------------------------------------------------------------------------
# Combat: the weapons
# --------------------------------------------------------------------------
## The element's node up the middle branch: tier 1 at 16 (on the tree's skills and ultimate), tier 2 at 25 (every blow).
static func _elem(tier: int) -> void:
	var e: Array = ELEMENTS[_t]
	var w := str(HEADERS[_t][0]).to_lower()
	if tier == 1:
		_big(e[0] + "_elem", e[1], "elem", 1, 16, {"elem_" + _t: 1}, "Mastery. Your %s skills awaken: %s." % [w, e[3]])
	else:
		_big(e[0] + "_elem2", e[2], "elem", 1, 25, {"elem2_" + _t: 1}, "Mastery. The element follows every blow: your %s combo and heavy attack carry it too." % w)


static func _build_cutlass() -> void:
	_tree("sword", ["Guard", "Tide", "Swagger"])
	_root("s_root", "Cutlass", {}, "The pirate's blade: quick cuts and a lunging thrust. Fight with a cutlass in hand to build its mastery.")
	_big("s_deflect", "Arrow Cutting", "mech", 0, 3, {"parryshot_sword": 1, "parry_sword": 0.06},
		"Parry with a cutlass and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_big("s_riposte", "Riposte", "tech", 0, 8, {}, "", "riposte")
	_big("s_return", "Return to Sender", "mech", 0, 20, {"deflect_sword": 1, "return_sword": 1, "deflect_cd_sword": 1.0},
		"With a cutlass drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.")
	_big("s_flying", "Flying Slash", "tech", 1, 4, {}, "", "flying_slash")
	_big("s_swordfish", "Swordfish Flurry", "tech", 1, 10, {}, "", "swordfish")
	_elem(1)
	_elem(2)
	_big("s_kraken", "Kraken's Wake", "ult", 1, 30, {}, "", "kraken_wake")
	_big("s_dash", "Running Cut", "move", 2, 2, {"mv_dash_cut": 1}, "Attack at a sprint: one low cut driving through the target, breaking its wind-up.")
	_big("s_dive", "Boarding Dive", "move", 2, 6, {"mv_boarding_dive": 1},
		"Attack in the air: the blade drawn back, then a point-first dive at the enemy you're looking at and a backflip off them (once per jump).")
	_big("s_flourish", "Flourish", "passive", 2, 13, {"finisher_sword": 0.3, "heavy_sword": 0.25},
		"Passive (a slot). The last cut of your combo lands 30% harder, and your lunging thrust 25%.")
	_variant("s_way", "Pirate's Way", 2, [
		["s_plunder", "Plunder", 22, {"leech_sword": 0.06, "exec_sword": 0.5}, "Cutlass hits heal you for 6% of their damage, and a hit that leaves them under 30% health deals 50% more on top."],
		["s_swash", "Swashbuckler", 22, {"cdr_sword": 0.2, "flow_sword": 0.4}, "Cutlass techniques come back 20% sooner, and cutlass hits give 40% more energy."]],
		"Two ways to fight a boarding action. Both are yours; pick the one you carry at the ship's bunk.")
	_step("s_edge", "Keen Edge", "s_root", 5, {"dmg_sword": 0.05}, "+5% cutlass damage a step.")
	_step("s_nerves", "Steady Hand", "s_deflect", 3, {"parry_sword": 0.02}, "A cutlass parry's window a little wider a step.")
	_step("s_whet", "Whetstone", "s_elem", 5, {"crit_sword": 0.03}, "3% more of your cutlass hits land 50% harder, a step.")
	_step("s_board", "Boarding Edge", "s_swordfish", 5, {"finisher_sword": 0.06}, "The last cut of your cutlass combo lands 6% harder a step.")
	_step("s_feet", "Light Feet", "s_dash", 3, {"stam_sword": 0.05}, "Cutlass attacks cost 5% less stamina a step.")
	_step("s_lunge", "Lunge", "s_dive", 3, {"heavy_sword": 0.08}, "Your lunging thrust hits 8% harder a step.")
	_step("s_flow", "Flow", "s_flying", 3, {"flow_sword": 0.15}, "Cutlass hits give 15% more energy a step.")
	_step("s_recover", "Swift Recovery", "s_flourish", 3, {"cdr_sword": 0.05}, "Cutlass techniques come back 5% sooner a step.")


static func _build_katana() -> void:
	_tree("katana", ["Guard", "Iai", "Blade"])
	_root("k_root", "Katana", {},
		"Two hands, slow wide cuts, and iaijutsu on heavy: hold to charge, attack to draw. Fight with a katana in hand to build its mastery.")
	# Guard
	_big("k_deflect", "Cut the Shot", "mech", 0, 3, {"parryshot_katana": 1, "parry_katana": 0.06},
		"Parry with a katana and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_big("k_counter", "Iai Counter", "tech", 0, 8, {}, "", "iai_counter")
	_big("k_phantom", "Phantom Step", "tech", 0, 14, {}, "", "phantom_step")
	_big("k_return", "Bullet Return", "mech", 0, 20, {"deflect_katana": 1, "return_katana": 1, "deflect_cd_katana": 1.0},
		"With a katana drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.")
	# Iai
	_big("k_full", "Full Draw", "move", 1, 6, {"mv_iai_full": 1},
		"Your iai charges to its second level: a gold glint, a longer dash, and everything you cut through crumples.")
	_big("k_tiger", "Tiger Rush", "tech", 1, 10, {}, "", "tiger_rush")
	_variant("k_iai", "Iai Upgrade", 1, [
		["k_through", "Through the Guard", 12, {"unblock_katana": 1}, "Your iai can't be blocked."],
		["k_eye", "Mind's Eye", 12, {"iai_speed": 0.3}, "Your iai charges 30% faster."]],
		"Two ways to sharpen the draw. Both are yours; pick the one you carry at the ship's bunk.")
	_elem(1)
	_elem(2)
	_big("k_petals", "Thousand Petals", "ult", 1, 30, {}, "", "petal_storm")
	# Blade
	_big("k_draw", "Quick Draw", "move", 2, 2, {"mv_quick_draw": 1},
		"Attack at a sprint: a quick cut straight out of the scabbard that breaks wind-ups.")
	_big("k_wind", "Wind Severer", "tech", 2, 5, {}, "", "wind_sever")
	_big("k_arc", "Crescent Arc", "move", 2, 7, {"mv_air_slash": 1},
		"Attack in the air: a little lift and one big arc swept down under you (once per jump).")
	_big("k_clean", "Clean Line", "passive", 2, 13, {"heavy_katana": 0.3, "exec_katana": 0.5},
		"Passive (a slot). Your iai cuts 30% deeper, and a cut that leaves them under 30% health deals 50% more on top.")
	_big("k_calm", "Empty Mind", "passive", 2, 22, {"cdr_katana": 0.25},
		"Passive (a slot). Katana techniques come back 25% sooner.")
	# steps (30 in all against the 29 points mastery gives)
	_step("k_keen", "Keen Edge", "k_root", 5, {"dmg_katana": 0.05}, "+5% katana damage a step.")
	_step("k_nerves", "Steel Nerves", "k_deflect", 3, {"parry_katana": 0.02}, "A katana parry's window a little wider a step.")
	_step("k_weight", "Counterweight", "k_phantom", 3, {"skill_katana": 0.06}, "Katana techniques and counters cut 6% deeper a step.")
	_step("k_deep", "Deep Draw", "k_iai", 5, {"heavy_katana": 0.06}, "Your iai cuts 6% deeper a step.")
	_step("k_whet", "Whetstone", "k_elem", 5, {"crit_katana": 0.03}, "3% more of your katana hits land 50% harder, a step.")
	_step("k_feet", "Light Feet", "k_draw", 3, {"stam_katana": 0.05}, "Katana attacks cost 5% less stamina a step.")
	_step("k_flow", "Flow", "k_wind", 3, {"flow_katana": 0.15}, "Katana hits give 15% more energy a step.")
	_step("k_recover", "Swift Recovery", "k_clean", 3, {"cdr_katana": 0.05}, "Katana techniques come back 5% sooner a step.")


static func _build_dual() -> void:
	_tree("dual", ["Guard", "Dance", "Edge"])
	_root("d_root", "Dual Wield", {},
		"A blade in each hand: fast cuts trading hands and a crashing double overhead. A cutlass with a second sword, an axe or a dagger: an off-hand axe hacks harder but slower, a dagger stabs lighter and quicker. Fight with two blades to build dual-wield mastery.")
	_big("d_deflect", "Twin Deflect", "mech", 0, 3, {"parryshot_dual": 1, "parry_dual": 0.06},
		"Parry with two blades and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_big("d_counter", "Crossed Counter", "tech", 0, 8, {}, "", "cross_counter")
	_big("d_return", "Ricochet Steel", "mech", 0, 20, {"deflect_dual": 1, "return_dual": 1, "deflect_cd_dual": 1.0},
		"With both blades drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.")
	_big("d_dance", "Blade Dance", "tech", 1, 5, {}, "", "blade_dance")
	_big("d_cross", "Cross Fang", "tech", 1, 10, {}, "", "cross_fang")
	_elem(1)
	_elem(2)
	_big("d_tempest", "Tempest of Steel", "ult", 1, 30, {}, "", "steel_tempest")
	_big("d_spin", "Twin Spin", "move", 2, 2, {"mv_twin_spin": 1}, "Adds a fourth hit to your combo: both blades whirled round in a spin.")
	_big("d_cyclone", "Twin Cyclone", "move", 2, 7, {"mv_twin_cyclone": 1},
		"Attack in the air: blades crossed, then a drill of turns down and forward cutting everyone close on every turn, and a burst on landing that knocks them flat.")
	_big("d_whirl", "Whirling Steel", "passive", 2, 13, {"flow_dual": 0.4, "finisher_dual": 0.35},
		"Passive (a slot). Dual-wield hits give 40% more energy, and the last cut of your combo lands 35% harder.")
	_variant("d_way", "Dancer's Way", 2, [
		["d_tech", "Dancer", 22, {"cdr_dual": 0.2, "leech_dual": 0.06}, "Dual-wield techniques come back 20% sooner, and hits heal you for 6% of their damage."],
		["d_exec", "Thousand Cuts", 22, {"exec_dual": 0.4}, "A cut that leaves them under 30% health deals 40% more on top."]],
		"Two ways to dance. Both are yours; pick the one you carry at the ship's bunk.")
	_step("d_twin", "Twin Blades", "d_root", 5, {"dmg_dual": 0.05}, "+5% damage while dual wielding a step.")
	_step("d_pair", "Steady Pair", "d_deflect", 3, {"parry_dual": 0.02}, "A two-blade parry's window a little wider a step.")
	_step("d_crossing", "Crossing Edge", "d_elem", 5, {"crit_dual": 0.03}, "3% more of your dual-wield hits land 50% harder, a step.")
	_step("d_bite", "Bite", "d_cross", 3, {"skill_dual": 0.06}, "Dual-wield techniques cut 6% deeper a step.")
	_step("d_finish", "Finisher", "d_cyclone", 5, {"finisher_dual": 0.06}, "The last cut of your combo lands 6% harder a step.")
	_step("d_feet", "Light Feet", "d_spin", 3, {"stam_dual": 0.05}, "Dual-wield attacks cost 5% less stamina a step.")
	_step("d_flow", "Flow", "d_dance", 3, {"flow_dual": 0.15}, "Dual-wield hits give 15% more energy a step.")
	_step("d_recover", "Recovery", "d_whirl", 3, {"cdr_dual": 0.05}, "Dual-wield techniques come back 5% sooner a step.")


static func _build_axe() -> void:
	_tree("axe", ["Brute", "Fury", "Blood"])
	_root("a_root", "Axe", {}, "Heavy, deliberate hacks and a whirlwind on heavy. Fight with an axe in hand to build its mastery.")
	_big("a_throw", "Hatchet Throw", "tech", 0, 3, {}, "", "axe_throw")
	_big("a_split", "Earthsplitter", "tech", 0, 9, {}, "", "earthsplitter")
	_big("a_sunder", "Sunder", "mech", 0, 14, {"unblock_axe": 1}, "Your heavy attacks can't be blocked.")
	_big("a_unstop", "Unstoppable", "mech", 1, 6, {"armor_axe": 1}, "Mid-swing with an axe, blows don't make you flinch or knock you off your feet.")
	_big("a_berserk", "Berserk", "tech", 1, 11, {}, "", "berserk")
	_elem(1)
	_elem(2)
	_big("a_maelstrom", "Maelstrom", "ult", 1, 30, {}, "", "maelstrom")
	_big("a_sky", "Skybreaker", "move", 2, 2, {"mv_skybreaker": 1},
		"Attack in the air: spring into a somersault and split the ground in a line ahead, knocking everyone on it flat.")
	_big("a_blood", "Bloodlust", "passive", 2, 12, {"flow_axe": 0.4, "leech_axe": 0.08}, "Passive (a slot). Axe hits give 40% more energy and heal you for 8% of their damage.")
	_variant("a_rage", "Rage", 2, [
		["a_frenzy", "Frenzy", 20, {"crit_axe": 0.1, "cdr_axe": 0.2}, "10% of your axe hits land 50% harder, and axe techniques come back 20% sooner."],
		["a_exec", "Executioner", 20, {"exec_axe": 0.5}, "A hit that leaves them under 30% health deals 50% more on top."]],
		"Two kinds of fury. Both are yours; pick the one you carry at the ship's bunk.")
	_step("a_heft", "Heft", "a_root", 5, {"dmg_axe": 0.05}, "+5% axe damage a step.")
	_step("a_hide", "Iron Hide", "a_split", 3, {"def_axe": 3.0}, "+3 defense with an axe in hand a step.")
	_step("a_overhead", "Overhead", "a_unstop", 5, {"heavy_axe": 0.06}, "Your whirlwind hits 6% harder a step.")
	_step("a_bite", "Keen Bite", "a_elem", 5, {"crit_axe": 0.03}, "3% more of your axe hits land 50% harder, a step.")
	_step("a_cleave", "Cleave", "a_berserk", 3, {"finisher_axe": 0.08}, "The last hack of your combo lands 8% harder a step.")
	_step("a_grip", "Light Grip", "a_sky", 3, {"stam_axe": 0.05}, "Axe attacks cost 5% less stamina a step.")
	_step("a_flow", "Flow", "a_throw", 3, {"flow_axe": 0.15}, "Axe hits give 15% more energy a step.")
	_step("a_recover", "Recovery", "a_blood", 3, {"cdr_axe": 0.05}, "Axe techniques come back 5% sooner a step.")


## One dagger: the root brings its nature (crits, wounds that bleed, a blade in the back).
static func _build_dagger() -> void:
	_tree("dagger", ["Guard", "Shadow", "Blood"])
	_root("dg_root", "Dagger", {"crit_dagger": 0.1, "bleed_dagger": 0.15, "backstab_dagger": 0.5},
		"A short blade for close work: quick stabs and cuts, and on right-click you're gone and out from behind the one in front. 10% of your hits are crits, 15% open a wound that bleeds, and a blade in the back deals half again. Fight with a dagger in hand to build its mastery.")
	_big("dg_deflect", "Flick the Shot", "mech", 0, 3, {"parryshot_dagger": 1, "evade_dagger": 0.08},
		"Parry with a dagger and you flick gunshots aside too (without it, a parry only stops blades), and 8% of the blows that would hit you are slipped by instinct.")
	_big("dg_slip", "Slip", "tech", 0, 8, {}, "", "slip")
	_big("dg_return", "Knife in the Dark", "mech", 0, 20, {"deflect_dagger": 1, "return_dagger": 1, "deflect_cd_dagger": 1.0},
		"With a dagger drawn, a shot from the front is flicked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.")
	_big("dg_fan", "Knife Fan", "tech", 1, 5, {}, "", "knife_fan")
	_big("dg_cut", "Cutthroat", "tech", 1, 10, {}, "", "cutthroat")
	_elem(1)
	_elem(2)
	_big("dg_eclipse", "Red Eclipse", "ult", 1, 30, {}, "", "red_eclipse")
	_big("dg_gut", "Gutting Strike", "move", 2, 2, {"mv_gut_strike": 1},
		"Adds a fourth hit to your combo: a turn on the heel, the off hand seizes them and the blade goes in low. It bleeds.")
	_big("dg_fang", "Fang Dive", "move", 2, 7, {"mv_fang_dive": 1},
		"Attack in the air: knees tucked and the blade drawn back, then a dive at the enemy you're looking at that always finds the gap (a sure crit that bleeds) and a backflip off them (once per jump).")
	_big("dg_deep", "Deep Cuts", "passive", 2, 13, {"bleed_dagger": 0.15, "flow_dagger": 0.4},
		"Passive (a slot). Another 15% of your dagger hits open a wound that bleeds, and dagger hits give 40% more energy.")
	_variant("dg_way", "Killer's Way", 2, [
		["dg_back", "In the Back", 22, {"backstab_dagger": 0.3, "heavy_dagger": 0.3}, "A blade in the back deals another 30% on top, and your Shadow Lunge (right-click) hits 30% harder."],
		["dg_open", "Open Vein", 22, {"exec_dagger": 0.5, "leech_dagger": 0.06}, "A hit that leaves them under 30% health deals 50% more on top, and dagger hits heal you for 6% of their damage."]],
		"Two ways to finish it. Both are yours; pick the one you carry at the ship's bunk.")
	_step("dg_edge", "Whetstone", "dg_root", 5, {"dmg_dagger": 0.05}, "+5% dagger damage a step.")
	_step("dg_slippery", "Slippery", "dg_deflect", 3, {"evade_dagger": 0.02}, "2% more of the blows that would hit you are slipped, a step.")
	_step("dg_weak", "Weak Spot", "dg_elem", 5, {"crit_dagger": 0.03}, "3% more of your dagger hits land 50% harder, a step.")
	_step("dg_lunge", "Shadow Lunge", "dg_cut", 3, {"heavy_dagger": 0.1}, "Your Shadow Lunge (right-click) hits 10% harder a step.")
	_step("dg_serrated", "Serrated", "dg_fang", 5, {"bleed_dagger": 0.03}, "3% more of your dagger hits open a wound that bleeds, a step.")
	_step("dg_feet", "Light Feet", "dg_gut", 3, {"stam_dagger": 0.05}, "Dagger attacks cost 5% less stamina a step.")
	_step("dg_flow", "Flow", "dg_fan", 3, {"flow_dagger": 0.15}, "Dagger hits give 15% more energy a step.")
	_step("dg_recover", "Recovery", "dg_deep", 3, {"cdr_dagger": 0.05}, "Dagger techniques come back 5% sooner a step.")


## Two daggers: a set of their own (not the dual-wield tree), venom and speed.
static func _build_dual_dagger() -> void:
	_tree("dual_dagger", ["Guard", "Fangs", "Venom"])
	_root("dd_root", "Twin Daggers", {"crit_dual_dagger": 0.08, "bleed_dual_dagger": 0.2, "backstab_dual_dagger": 0.35},
		"A dagger in each hand: the fastest blows you can throw, a scissor rip on right-click. 8% of your hits are crits, 20% open a wound that bleeds, and a blade in the back deals a third again. Fight with two daggers to build their mastery.")
	_big("dd_deflect", "Crossed Knives", "mech", 0, 3, {"parryshot_dual_dagger": 1, "evade_dual_dagger": 0.08},
		"Parry with two daggers and you knock gunshots aside too (without it, a parry only stops blades), and 8% of the blows that would hit you are slipped by instinct.")
	_big("dd_edge", "Bleeding Edge", "tech", 0, 8, {}, "", "bleeding_edge")
	_big("dd_return", "Knives Back", "mech", 0, 20, {"deflect_dual_dagger": 1, "return_dual_dagger": 1, "deflect_cd_dual_dagger": 1.0},
		"With both daggers drawn, a shot from the front is knocked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.")
	_big("dd_viper", "Viper Flurry", "tech", 1, 5, {}, "", "viper_flurry")
	_big("dd_leap", "Scissor Leap", "tech", 1, 10, {}, "", "scissor_leap")
	_elem(1)
	_elem(2)
	_big("dd_fangs", "Hundred Fangs", "ult", 1, 30, {}, "", "hundred_fangs")
	_big("dd_whirl", "Fang Whirl", "move", 2, 2, {"mv_fang_whirl": 1},
		"Adds a fourth hit to your combo: a whirl with both blades out, then both driven in together. It bleeds.")
	_big("dd_knives", "Knife Rain", "move", 2, 7, {"mv_knife_rain": 1},
		"Attack in the air: hang a beat and fling a fistful of knives down at up to four enemies below and ahead; every one cut bleeds (once per jump).")
	_big("dd_deep", "Open Wounds", "passive", 2, 13, {"bleed_dual_dagger": 0.15, "flow_dual_dagger": 0.4},
		"Passive (a slot). Another 15% of your twin-dagger hits open a wound that bleeds, and they give 40% more energy.")
	_variant("dd_way", "Viper's Way", 2, [
		["dd_back", "Two in the Back", 22, {"backstab_dual_dagger": 0.25, "heavy_dual_dagger": 0.3}, "A blade in the back deals another 25% on top, and your Scissor Rip (right-click) hits 30% harder."],
		["dd_exec", "Death by Cuts", 22, {"exec_dual_dagger": 0.4, "leech_dual_dagger": 0.06}, "A hit that leaves them under 30% health deals 40% more on top, and twin-dagger hits heal you for 6% of their damage."]],
		"Two ways to finish it. Both are yours; pick the one you carry at the ship's bunk.")
	_step("dd_twin", "Paired Fangs", "dd_root", 5, {"dmg_dual_dagger": 0.05}, "+5% damage with two daggers a step.")
	_step("dd_slippery", "Slippery", "dd_deflect", 3, {"evade_dual_dagger": 0.02}, "2% more of the blows that would hit you are slipped, a step.")
	_step("dd_weak", "Weak Spot", "dd_elem", 5, {"crit_dual_dagger": 0.03}, "3% more of your twin-dagger hits land 50% harder, a step.")
	_step("dd_rip", "Scissor Rip", "dd_leap", 3, {"heavy_dual_dagger": 0.1}, "Your Scissor Rip (right-click) hits 10% harder a step.")
	_step("dd_serrated", "Serrated", "dd_knives", 5, {"bleed_dual_dagger": 0.03}, "3% more of your twin-dagger hits open a wound that bleeds, a step.")
	_step("dd_feet", "Light Feet", "dd_whirl", 3, {"stam_dual_dagger": 0.05}, "Twin-dagger attacks cost 5% less stamina a step.")
	_step("dd_flow", "Flow", "dd_viper", 3, {"flow_dual_dagger": 0.15}, "Twin-dagger hits give 15% more energy a step.")
	_step("dd_recover", "Recovery", "dd_deep", 3, {"cdr_dual_dagger": 0.05}, "Twin-dagger techniques come back 5% sooner a step.")


static func _build_corsair() -> void:
	_tree("corsair", ["Guard", "Powder", "Steel"])
	_root("cs_root", "Corsair", {},
		"A cutlass in your hand and a pistol in the other: cuts and point-blank shots, a lunge that ends in a shot on right-click. The pistol holds two balls and reloads itself as you fight. Fight this way to build Corsair mastery.")
	_big("cs_deflect", "Steel and Shot", "mech", 0, 3, {"parryshot_corsair": 1, "parry_corsair": 0.06},
		"Parry with the cutlass and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_big("cs_parley", "Parley", "tech", 0, 8, {}, "", "parley")
	_big("cs_return", "Return Fire", "mech", 0, 20, {"deflect_corsair": 1, "return_corsair": 1, "deflect_cd_corsair": 1.0},
		"With the cutlass drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.")
	_big("cs_grape", "Grapeshot", "tech", 1, 5, {}, "", "grapeshot")
	_big("cs_bandolier", "Bandolier", "mech", 1, 9, {"shots_corsair": 1, "reload_corsair": 0.35}, "The off-hand pistol holds one more ball and reloads 35% faster.")
	_big("cs_cross", "Crossfire", "tech", 1, 12, {}, "", "crossfire")
	_elem(1)
	_elem(2)
	_big("cs_broadside", "Broadside", "ult", 1, 30, {}, "", "broadside")
	_big("cs_finale", "Powder Finale", "move", 2, 2, {"mv_powder_finale": 1},
		"Adds a fourth hit to your combo: a full turn with the blade out, then a shot point-blank that knocks them flat.")
	_big("cs_drop", "Dead Man's Drop", "move", 2, 7, {"mv_deadmans_drop": 1},
		"Attack in the air: lean over the enemy you're looking at and fire down into them (it pins them), then dive through them point first; the landing knocks everyone close flat (once per jump).")
	_big("cs_rhythm", "Smoke and Steel", "passive", 2, 13, {"flow_corsair": 0.4, "heavy_corsair": 0.3},
		"Passive (a slot). Sword-and-pistol hits give 40% more energy, and your Powder Lunge (right-click) hits 30% harder, the shot too.")
	_variant("cs_way", "Corsair's Way", 2, [
		["cs_smoke", "Gunsmoke", 22, {"cdr_corsair": 0.2, "leech_corsair": 0.06}, "Sword-and-pistol techniques come back 20% sooner, and hits heal you for 6% of their damage."],
		["cs_noquarter", "No Quarter", 22, {"exec_corsair": 0.5}, "A hit that leaves them under 30% health deals 50% more on top."]],
		"Two ways to take a prize. Both are yours; pick the one you carry at the ship's bunk.")
	_step("cs_steel", "Boarding Steel", "cs_root", 5, {"dmg_corsair": 0.05}, "+5% damage with sword and pistol a step.")
	_step("cs_parry", "Steady Parry", "cs_deflect", 3, {"parry_corsair": 0.02}, "The cutlass parry's window a little wider a step.")
	_step("cs_dread", "Dread", "cs_elem", 5, {"crit_corsair": 0.03}, "3% more of your sword-and-pistol hits land 50% harder, a step.")
	_step("cs_load", "Quick Load", "cs_bandolier", 3, {"reload_corsair": 0.1}, "The off-hand pistol reloads 10% faster a step.")
	_step("cs_lunge", "Powder Lunge", "cs_drop", 5, {"heavy_corsair": 0.06}, "Your Powder Lunge (right-click) hits 6% harder a step.")
	_step("cs_feet", "Light Feet", "cs_finale", 3, {"stam_corsair": 0.05}, "Sword-and-pistol attacks cost 5% less stamina a step.")
	_step("cs_flow", "Flow", "cs_grape", 3, {"flow_corsair": 0.15}, "Sword-and-pistol hits give 15% more energy a step.")
	_step("cs_recover", "Recovery", "cs_rhythm", 3, {"cdr_corsair": 0.05}, "Sword-and-pistol techniques come back 5% sooner a step.")


static func _build_pistol() -> void:
	_tree("pistol", ["Tricks", "Shots", "Close"])
	_root("g_root", "Pistol", {}, "Two shots, then reload. A second pistol in the off hand alternates them. Shoot to build pistol mastery.")
	_big("g_kata", "Gun Kata", "move", 0, 3, {"mv_gun_kata": 1},
		"Dual pistols' heavy: a hop into a double spin, arms crossed, shooting everyone close. (Without it: a pistol-whip.)")
	_big("g_smoke", "Smoke Bomb", "tech", 0, 6, {}, "", "smoke_bomb")
	_big("g_rain", "Gun Rain", "move", 0, 9, {"mv_gun_rain": 1}, "Dual pistols in the air: fire both guns down at once, the recoil launching you forward.")
	_big("g_hang", "Hang Time", "mech", 0, 14, {"gun_rain_uses": 1}, "Gun Rain can be fired twice before you land.")
	_big("g_storm", "Bullet Storm", "tech", 1, 5, {}, "", "bullet_storm")
	_big("g_dead", "Deadeye", "tech", 1, 10, {}, "", "deadeye")
	_elem(1)
	_big("g_ricochet", "Ricochet", "mech", 1, 20, {"ricochet": 1}, "Every pistol ball that hits glances off into the nearest other enemy for 60% damage.")
	_elem(2)
	_big("g_waltz", "Death's Waltz", "ult", 1, 30, {}, "", "deaths_waltz")
	_big("g_hangshot", "Hang Shot", "move", 2, 2, {"mv_hang_shot": 1},
		"One pistol in the air: hang a beat drawing a bead, then one heavy shot at the reticle that knocks them flat, the recoil throwing you back (once per jump, uses a shot).")
	_big("g_powder", "Extra Powder", "mech", 2, 7, {"extra_shots": 1}, "Every pistol holds one more shot.")
	_big("g_point", "Point Blank", "tech", 2, 11, {}, "", "point_blank")
	_big("g_close", "Close Quarters", "passive", 2, 15, {"pointblank_pct": 0.4, "leech_pistol": 0.05},
		"Passive (a slot). Shots from within 5 m hit 40% harder, and pistol hits heal you for 5% of their damage.")
	_big("g_exec", "Coup de Grace", "passive", 2, 22, {"exec_pistol": 0.4, "cdr_pistol": 0.2},
		"Passive (a slot). A shot that leaves them under 30% health deals 40% more on top, and pistol techniques come back 20% sooner.")
	_step("g_marks", "Marksman", "g_root", 5, {"dmg_pistol": 0.05}, "+5% damage with pistols a step.")
	_step("g_load", "Quick Load", "g_kata", 3, {"reload_pct": 0.12}, "You reload 12% faster a step.")
	_step("g_aim", "Steady Aim", "g_elem", 5, {"crit_pistol": 0.03}, "3% more of your shots land 50% harder, a step.")
	_step("g_hard", "Hard Shot", "g_dead", 5, {"skill_pistol": 0.06}, "Pistol techniques hit 6% harder a step.")
	_step("g_range", "Close Range", "g_powder", 3, {"pointblank_pct": 0.08}, "Shots from within 5 m hit 8% harder a step.")
	_step("g_hand", "Light Hand", "g_hangshot", 3, {"stam_pistol": 0.05}, "Pistol attacks cost 5% less stamina a step.")
	_step("g_flow", "Flow", "g_storm", 3, {"flow_pistol": 0.15}, "Pistol hits give 15% more energy a step.")
	_step("g_recover", "Recovery", "g_close", 3, {"cdr_pistol": 0.05}, "Pistol techniques come back 5% sooner a step.")


static func _build_unarmed() -> void:
	_tree("unarmed", ["Grapple", "Martial", "Body"])
	_root("u_root", "Unarmed", {}, "Bare-handed brawling: jab, cross, hook and a flying kick. Fight with your fists to build unarmed mastery.")
	_big("u_hip", "Shoulder Throw", "tech", 0, 3, {}, "", "hip_toss")
	_big("u_landing", "Heavy Landing", "mech", 0, 9, {"throw_splash": 1, "skill_unarmed": 0.25},
		"Anyone you throw lands like a cannonball: everyone near where they land is knocked flat and hurt. Your grapples and martial arts hit 25% harder.")
	_big("u_suplex", "Suplex", "tech", 0, 12, {}, "", "suplex")
	_big("u_swing", "Giant Swing", "tech", 0, 18, {}, "", "giant_swing")
	_big("u_palm", "Shockwave Palm", "tech", 1, 4, {}, "", "palm_strike")
	_big("u_dragon", "Rising Dragon", "tech", 1, 8, {}, "", "rising_dragon")
	_big("u_hundred", "Hundred Fists", "tech", 1, 13, {}, "", "hundred_fists")
	_elem(1)
	_elem(2)
	_big("u_seaking", "Sea King Fist", "ult", 1, 30, {}, "", "sea_king_fist")
	_big("u_round", "Roundhouse", "move", 2, 2, {"mv_roundhouse": 1}, "Adds a fourth hit to your punch combo: a spinning roundhouse kick.")
	_big("u_meteor", "Meteor Kick", "move", 2, 6, {"mv_meteor_kick": 1},
		"Attack in the air: a dive kick at the enemy you're looking at that knocks them flat and bounces you back up for another (three in a row); a miss slams the ground.")
	_big("u_ironbody", "Iron Body", "passive", 2, 11, {"def_unarmed": 8.0, "parry_unarmed": 0.06}, "Passive (a slot). Fighting bare-handed: +8 defense and a wider parry window.")
	_big("u_chi", "Chi", "passive", 2, 15, {"flow_unarmed": 0.5, "leech_unarmed": 0.06}, "Passive (a slot). Unarmed hits give 50% more energy and heal you for 6% of their damage.")
	_big("u_finish", "Finishing Blow", "passive", 2, 22, {"finisher_unarmed": 0.4, "cdr_unarmed": 0.2},
		"Passive (a slot). The last hit of your combo lands 40% harder, and unarmed techniques come back 20% sooner.")
	_step("u_knuckles", "Iron Knuckles", "u_root", 5, {"dmg_unarmed": 0.05}, "+5% unarmed damage a step.")
	_step("u_grip", "Grip", "u_hip", 3, {"skill_unarmed": 0.06}, "Your grapples and martial arts hit 6% harder a step.")
	_step("u_skin", "Stone Skin", "u_suplex", 3, {"def_unarmed": 2.0}, "+2 defense bare-handed a step.")
	_step("u_points", "Pressure Points", "u_elem", 5, {"crit_unarmed": 0.03}, "3% more of your unarmed hits land 50% harder, a step.")
	_step("u_hands", "Heavy Hands", "u_hundred", 5, {"finisher_unarmed": 0.06}, "The last hit of your combo lands 6% harder a step.")
	_step("u_feet", "Light Feet", "u_round", 3, {"stam_unarmed": 0.07}, "Unarmed attacks cost 7% less stamina a step.")
	_step("u_flow", "Flow", "u_palm", 3, {"flow_unarmed": 0.15}, "Unarmed hits give 15% more energy a step.")
	_step("u_breath", "Breath", "u_ironbody", 3, {"cdr_unarmed": 0.05}, "Unarmed techniques come back 5% sooner a step.")
