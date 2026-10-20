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
	_build_katana()


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
	var bigs := list.filter(func(k): return _nodes[k]["kind"] != "step")
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
	_big("k_elem", "Falling Petals", "elem", 1, 16, {"elem_katana": 1},
		"Mastery. Your katana skills awaken: pale steel light and falling petals.")
	_big("k_elem2", "Blossom Path", "elem", 1, 25, {"elem2_katana": 1},
		"Mastery. The element follows every blow: your katana combo and heavy attack carry it too.")
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
