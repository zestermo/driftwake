class_name SkillTrees
extends RefCounted
## The skill trees of the v1.18.2 redesign (docs/progression_plan.md "Redesign"), grouped in sections:
##   captain    the Captain (levels 1-40)
##   combat     a tree per weapon (mastery 1-30, earned only with that weapon in hand)
##   adventure  Acrobatics (1-30), Defense, Sailing, Swimming, Cooking, Fishing, Stealth, Tinkering (levels 1-20)
##   fruit      the Driftfruit you ate (levels 1-20)
## A tree grows up from its root in three branches. Every node past the root is bought (1.18.4, docs/v1_18_4_plan.md):
## weapon and fruit trees from the Combat pool (Captain levels), Adventure trees from the Adventure pool (their levels);
## the tree's level only gates it (price: PRICE by kind, or a node's own "cost"). Small stat "steps" (x/3, x/5) are
## bought a step at a time. A variant is two versions of one node: both owned once bought, one active (switched at the
## ship's bunk). The Captain's nodes and a fruit's level-1 powers still come by themselves. Progression reads the
## effects (same keys as SkillTree's, so the game's readers don't change).
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
	"polearm": ["Polearm", "combat", Color(1.0, 0.9, 0.4), 30],
	"hammer": ["Hammer", "combat", Color(0.88, 0.74, 0.54), 30],
	"dual_axe": ["Twin Axes", "combat", Color(0.8, 0.88, 1.0), 30],
	"greatsword": ["Greatsword", "combat", Color(0.72, 0.95, 0.84), 30],
	"corsair": ["Corsair", "combat", Color(1.0, 0.5, 0.42), 30],
	"pistol": ["Pistol", "combat", Color(0.95, 0.75, 0.4), 30],
	"unarmed": ["Unarmed", "combat", Color(1.0, 0.85, 0.6), 30],
	"black_leg": ["Black Leg", "combat", Color(1.0, 0.45, 0.35), 30],
	"acrobatics": ["Acrobatics", "adventure", Color(0.61, 0.88, 0.54), 30],
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
const LEFT := [Vector2(-120, -78), Vector2(-192, -162), Vector2(-252, -248), Vector2(-300, -336), Vector2(-336, -420), Vector2(-362, -500), Vector2(-380, -580), Vector2(-392, -660)]
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
	"polearm": ["pl", "Rolling Thunder", "Storm Bearer", "lightning: bolts crackling off the head and a thunderclap on the big blows"],
	"hammer": ["hm", "Rumbling Earth", "Mountain's Weight", "earth: rock thrown up off every blow, the shockwaves in sandstone and stone spikes heaving up out of the ground"],
	"dual_axe": ["dx", "Hoarfrost", "Winter's Bite", "frost: rime and ice chips cracking off every chop, a cold mist, and Fimbulwinter heaves ice up out of the ground under your foes"],
	"greatsword": ["gs", "Gale Edge", "Tempest Blade", "wind: gusts torn off every swing, crescents of air flung off the big ones in jade, and a cyclone round you when the big turns and Skysplitter land"],
	"pistol": ["g", "Golden Powder", "Gilded Gun", "gold flashes and powder smoke"],
	"unarmed": ["u", "Rushing Wind", "Gale Fists", "rushing wind and rings of air"],
	"black_leg": ["bl", "Searing Heel", "Red-Hot Leg", "heat: the kicking leg glows red-hot, crimson flames burst off the big kicks and white-hot sparks off every one, and Last Course sets the ground burning"],
}

## What every Captain level past the first adds by itself (the old Captain tree's stat nodes, folded in).
const GROWTH := {"max_hp": 5.5, "damage_pct": 0.02, "max_stamina": 0.6, "max_energy": 0.6, "defense": 0.5}
## Will milestones: id -> [the boss that teaches it (Progression.boss_kind), the Wills it needs first].
const WILL := {"h_arm": ["morrow", []], "h_coat": ["ape", ["h_arm"]], "h_obs": ["queen", ["h_arm"]], "h_fore": ["arena", ["h_arm"]],
	"h_conq": ["sea_king", ["h_arm", "h_coat", "h_obs", "h_fore"]]}

## A node's price by kind, plus a point for every 10 levels of its gate (a step: 1 a step); Adventure's are cheaper.
## Nodes that became others (an old save's purchase is bought back as the new one, same gate and price): the fists'
## wrestling moves went in 1.18.4.
const RENAMED := {"u_suplex": "u_cannon", "u_swing": "u_meteor_fist"}
const PRICE := {"move": 2, "mech": 2, "tech": 3, "passive": 3, "variant": 4, "elem": 5, "ult": 8}
const PRICE_ADVENTURE := {"move": 1, "mech": 1, "tech": 2, "passive": 2, "variant": 2, "elem": 3, "ult": 4}

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


## The points a tree's nodes are bought with: "combat" (weapons and the fruit), "adventure", "" (the Captain).
static func pool_of(tree: String) -> String:
	match section_of(tree):
		"combat", "fruit":
			return "combat"
		"adventure":
			return "adventure"
	return ""


## A node's price in its pool's points (a step's is per step); 0 for one that isn't bought.
static func price(id: String) -> int:
	var n := node_def(id)
	if n.has("cost"):
		return int(n["cost"])
	if n["kind"] == "step":
		return 1
	var base: Dictionary = PRICE_ADVENTURE if section_of(str(n["tree"])) == "adventure" else PRICE
	if not base.has(n["kind"]) or pool_of(str(n["tree"])) == "":
		return 0
	return int(base[n["kind"]]) + int(n["level"]) / 10


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
	_build_captain()
	_build_acrobatics()
	_build_defense()
	_build_sailing()
	_build_swimming()
	_build_cooking()
	_build_fishing()
	_build_stealth()
	_build_tinkering()
	_build_cutlass()
	_build_katana()
	_build_dual()
	_build_axe()
	_build_dagger()
	_build_dual_dagger()
	_build_polearm()
	_build_hammer()
	_build_dual_axe()
	_build_greatsword()
	_build_corsair()
	_build_pistol()
	_build_unarmed()
	_build_black_leg()
	_build_ember()
	_build_wolf()
	_build_vine()


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
static func _variant(id: String, name_: String, branch: int, versions: Array, desc: String = "") -> Dictionary:
	var lv := 99
	for v in versions:
		lv = mini(lv, int(v[2]))
	var n := _big(id, name_, "variant", branch, lv, {}, desc)
	for v in versions:
		var sk: String = v[5] if v.size() > 5 else ""
		var vn := _node(v[0], v[1], "version", branch, int(v[2]), v[3], str(v[4]), sk, [id], n["pos"])
		vn["parent"] = id
		n["versions"].append({"id": v[0], "name": v[1], "desc": vn["desc"], "level": int(v[2]), "effects": v[3], "skill": sk})
	return n


## The picture a node without a skill shows on the tree (Skills.icon(icon): gen_psx_textures.py "moves").
static func _icon(id: String, icon: String) -> void:
	_nodes[id]["icon"] = icon
	if _nodes[id].has("parent"):
		for v in _nodes[_nodes[id]["parent"]]["versions"]:
			if v["id"] == id:
				v["icon"] = icon


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
# The Captain: growth by level, milestones, talents, Will
# --------------------------------------------------------------------------
static func _build_captain() -> void:
	_tree("captain", ["Milestones", "Talents", "Will"])
	_root("c_root", "Captain", {},
		"Every level makes you a little stronger by itself: +5.5 health, +2% damage, +0.6 stamina and energy, +0.5 defense. Milestones come at their level; every 5 levels you pick one of two talents; Will comes from the bosses you beat.")
	_big("m_soru", "Soru", "auto", 0, 8, {}, "", "soru")
	_big("c_quarter", "Quartermaster", "auto", 0, 10, {"loadout_slots": 1}, "A third weapon loadout on the loadout wheel (X): three setups to swap between mid-fight.")
	_big("v_tekkai", "Tekkai", "auto", 0, 14, {}, "", "tekkai")
	_big("c_slot4", "Fourth Slot", "auto", 0, 25, {}, "A fourth passive slot.")
	_talent(5, ["v_mend", "Mend", {"regen_hp": 2.5}, "Out of combat (no damage for 5 s) you heal 2.5 health a second."],
		["v_stomach", "Iron Stomach", {"potion_pct": 0.4}, "Food and drink heal you 40% more."])
	_talent(10, ["t_hands", "Quick Hands", {"use_speed_pct": 0.35}, "You eat and drink 35% faster."],
		["t_seadog", "Sea Dog", {"sea_dog": 1}, "Aboard a ship your stamina refills twice as fast."])
	_talent(15, ["v_adren", "Adrenaline", {"adrenaline": 0.25}, "Below 35% health you hit 25% harder."],
		["t_wind", "Second Wind", {"second_wind": 1}, "Once a fight, dropping below 30% health refills your stamina and energy."])
	_talent(20, ["c_focus", "Focus", {"ult_charge_pct": 0.15, "xp_pct": 0.1}, "Your ultimate charges 15% faster, and you win 10% more experience from every fight."],
		["t_bounty", "Bounty Hunter", {"bounty_pct": 0.15}, "+15% damage to elites and bosses."])
	_talent(25, ["t_rally", "Rallying Cry", {"revive_pct": 0.5, "rally": 0.25}, "You get a crewmate up 50% faster, and both of you heal a quarter of your health."],
		["t_treasure", "Treasure Sense", {"treasure_sense": 60.0}, "Closed chests within 60 m show on your compass."])
	_talent(30, ["v_last", "Last Stand", {"last_stand": 1}, "Once a minute, a blow that would kill you leaves you at 1 health instead."],
		["t_presence", "Captain's Presence", {"presence": 0.25}, "Common foes' blows hit you 25% softer (not elites or bosses)."])
	_talent(35, ["t_learner", "Quick Learner", {"xp_pct": 0.15, "mastery_pct": 0.15}, "15% more experience, and every tree learns 15% faster."],
		["t_hide", "Thick Hide", {"defense": 10.0, "max_hp": 30.0}, "+10 defense and +30 max health."])
	_talent(40, ["t_warlord", "Warlord", {"damage_pct": 0.12, "crit_all": 0.06}, "+12% damage with everything, and 6% of your hits land 50% harder."],
		["t_legend", "Living Legend", {"max_hp": 60.0, "defense": 8.0, "stamina_regen_pct": 0.2}, "+60 max health, +8 defense, and stamina refills 20% faster."])
	_will("h_arm", "Iron Will", {"armament": 1, "damage_pct": 0.08}, "", "Beat Captain Morrow. Will made armor: +8% damage, and your heavy attacks can't be blocked.",
		["h_harden", "Hardening", {"defense": 8.0, "energy_regen_pct": 0.2}, "Passive (a slot). Will under the skin: +8 defense, and energy refills 20% faster."])
	_will("h_coat", "Iron Will: Coat", {}, "armament_coat", "Beat a great ape. Coat your weapon or fists in Will.",
		["h_black", "Black Fists", {"dmg_unarmed": 0.15}, "Passive (a slot). Your bare fists are iron: +15% unarmed damage."])
	_will("h_obs", "Sense", {"observation": 1}, "", "Beat the Brood Queen. Sense intent: enemies flash red the moment they start an attack, and your parry window is a little wider.",
		["h_instinct", "Instinct", {"evade_chance": 0.08, "parry_all": 0.04}, "Passive (a slot). 8% of the blows that would hit you are sidestepped on instinct, and your parry window is wider still."])
	_will("h_fore", "Foresight", {}, "foresight", "Beat a great beast in its arena. Sense what's coming before it comes.",
		["h_weak", "Weak Points", {"crit_all": 0.06}, "Passive (a slot). You see where to strike: 6% more of your hits land 50% harder."])
	_will("h_conq", "Captain's Will", {}, "conquerors_haki", "Beat a Sea King, with every other Will yours. A will that bends others.",
		["h_will", "King's Will", {"damage_pct": 0.06, "max_hp": 20.0}, "Passive (a slot). +6% damage, +20 max health."])


## A talent: one of two versions at `lv`, picked (not given); each [id, name, effects, desc].
static func _talent(lv: int, a: Array, b: Array) -> void:
	var id := "talent_%d" % lv
	var n := _big(id, "Talent %d" % lv, "talent", 1, lv)
	for v in [a, b]:
		var vn := _node(v[0], v[1], "version", 1, lv, v[2], v[3], "", [id], n["pos"])
		vn["parent"] = id
		n["versions"].append({"id": v[0], "name": v[1], "desc": v[3], "level": lv, "effects": v[2], "skill": ""})


## A Will milestone (its boss beaten, not a level) and the Will passive that comes with it ([id, name, effects, desc]).
static func _will(id: String, name_: String, effects: Dictionary, skill: String, desc: String, passive: Array) -> void:
	var n := _big(id, name_, "will", 2, 1, effects, desc, skill)
	n["boss"] = WILL[id][0]
	n["needs"] = WILL[id][1]
	var p := _node(passive[0], passive[1], "passive", 2, 1, passive[2], passive[3], "", [id], n["pos"] + Vector2(84, -28))
	p["will"] = id
	_trees[_t]["branches"][2]["nodes"].append(passive[0])


# --------------------------------------------------------------------------
# Adventure: learned by doing (levels 1-20)
# --------------------------------------------------------------------------
static func _build_acrobatics() -> void:
	_tree("acrobatics", ["Air", "Dodge", "Stride"])
	_root("ac_root", "Acrobatics", {}, "Jump, dodge and sprint to build it: air jumps and dodges count most.")
	_big("m_geppo", "Geppo", "mech", 0, 2, {"air_jumps": 1}, "Kick off the air itself: a second jump in mid-air.")
	_big("m_skywalk", "Sky Walk", "mech", 0, 9, {"air_jumps": 1}, "One more jump in mid-air (three in all).")
	_big("ac_breakfall", "Breakfall", "move", 0, 12, {"breakfall": 1},
		"Knocked flying by a heavy blow, or tumbling from a long fall: press jump in the air to right yourself and come down on your feet.")
	# (the landing variant keeps Featherfall's old id, so a save that bought it owns the variant)
	_variant("ac_feather", "Landing", 0, [
		["ac_featherfall", "Featherfall", 15, {"featherfall": 1}, "Falls hurt a quarter as much, with no stumble on landing."],
		["ac_crash", "Crash Landing", 15, {"crash_landing": 1},
			"Come down hard from a long drop and you land on one knee and a fist: the ground cracks and the foes round you are thrown off their feet. The fall hurts you half as much, with no stumble."]],
		"Two ways to come down. Both are yours; pick the one you carry at the ship's bunk.")
	_big("ac_skydash", "Skyward Dash", "move", 0, 18, {"skyward_dash": 1},
		"Righted in mid-air (Breakfall, or an air step out of a tumble): dodge for an air dash, and two more air steps. Enough to get back aboard after a blow throws you off the ship.")
	_big("ac_moonstep", "Moonstep", "move", 0, 20, {"moonstep": 1},
		"In mid-air, dodge to stamp both feet down on the air itself and burst straight up, far higher than an air step (once a jump, 18 stamina).")
	_icon("ac_featherfall", "move_featherfall")
	_icon("ac_crash", "move_crash")
	_icon("ac_moonstep", "move_moonstep")
	_big("ac_skyleap", "Sky Leap", "move", 0, 22, {"sky_leap": 1},
		"Stand still and hold jump: Will hardens your legs, then let go to leap 25 m into the sky (40 stamina; a shorter hold, a shorter leap). You land in a crater, unhurt, with your air steps still to use.")
	_big("ac_heavenward", "Heavenward", "move", 0, 28, {"heavenward": 1},
		"Sky Leap's full charge carries you 20 m higher and 4 m further (50 stamina): 60 m with Haki Legs.")
	_big("m_swift", "Swift Step", "mech", 1, 4, {"dodge_cost_pct": 0.4, "dodge_dist_pct": 0.3, "dodge_iframe_pct": 0.5},
		"Your dodge costs 40% less stamina, carries you 30% further and leaves you untouchable 50% longer.")
	_variant("ac_dodge", "Dodge Style", 1, [
		["ac_roll", "Roll", 7, {"dodge_roll": 1}, "Your dodge is a tumbling roll: you turn into it and go under the blow, further and untouchable longer, a beat slower to come up."],
		["ac_sidestep", "Sidestep", 7, {"dodge_sidestep": 1},
			"Your dodge is a short, sharp slip aside: cheaper and quicker to strike out of, and slipping a blow as it lands makes your next hit land 50% harder."]],
		"Two ways to get out of the way. Both are yours; pick the one you carry at the ship's bunk.")
	_big("ac_fleet", "Fleetfoot", "mech", 1, 12, {"move_pct": 0.06, "sprint_pct": 0.08}, "+6% movement speed, +8% sprint speed.")
	_big("ac_afterimage", "Afterimage", "move", 1, 18, {"afterimage": 1},
		"Your dodge leaves a copy of you standing where you were, and the foes coming for you swing at it instead (once every 6 s).")
	_icon("ac_roll", "move_roll")
	_icon("ac_sidestep", "move_sidestep")
	_icon("ac_afterimage", "move_afterimage")
	_big("m_sprinter", "Long Stride", "mech", 2, 3, {"sprint_cost_pct": 0.35, "sprint_pct": 0.1}, "Sprinting burns 35% less stamina and you sprint 10% faster.")
	_big("ac_bound", "Sprint Jump", "mech", 2, 6, {"sprint_jump_pct": 0.5}, "A sprint's long bound costs half the stamina.")
	_big("ac_sure", "Sure Footing", "mech", 2, 10, {"stamina_regen_pct": 0.1}, "Stamina refills 10% faster.")
	_big("ac_monkey", "Rigging Monkey", "mech", 2, 16, {"climb_pct": 0.4}, "You climb ladders and the rigging 40% faster.")
	_step("ac_light", "Light Step", "ac_root", 5, {"dodge_cost_pct": 0.04}, "Your dodge costs 4% less stamina a step.")
	_step("ac_quick", "Quick Feet", "m_swift", 5, {"move_pct": 0.01, "sprint_pct": 0.015}, "+1% movement and +1.5% sprint speed a step.")
	_step("ac_hang", "Hang Time", "m_skywalk", 3, {"dodge_iframe_pct": 0.08}, "Untouchable 8% longer in a dodge, a step.")
	_step("ac_spring", "Spring", "m_sprinter", 3, {"sprint_cost_pct": 0.05}, "Sprinting burns 5% less stamina a step.")
	_step("ac_wind", "Wind", "ac_bound", 3, {"max_stamina": 4.0}, "+4 max stamina a step.")
	_step("ac_hakilegs", "Haki Legs", "ac_skyleap", 3, {"sky_leap_steps": 1}, "Sky Leap goes 5 m higher and 2 m further a step.")
	_nodes["ac_hakilegs"]["level"] = 23


static func _build_defense() -> void:
	_tree("defense", ["Parry", "Guard", "Grit"])
	_root("df_root", "Defense", {}, "Parry and block real blows to build it: a parry counts most.")
	_big("df_clean", "Clean Parry", "mech", 0, 2, {"parry_all": 0.03, "parry_stamina": 10.0, "clean_parry": 1},
		"A wider parry window, and a parry gives you 10 stamina back. A perfect parry (caught the moment the guard goes up) staggers them longer and wide open.")
	_big("v_iron", "Iron Body", "mech", 0, 8, {"defense": 10.0}, "+10 defense.")
	_big("df_instinct", "Battle Instinct", "mech", 0, 12, {"evade_chance": 0.04, "parry_all": 0.02},
		"4% of the blows that would hit you are slipped by instinct, and your parry window is wider still.")
	_variant("df_perfect", "Perfect Parry", 0, [
		["df_disarm", "Disarm", 16, {"parry_disarm": 1}, "A perfect parry twists the weapon out of their hand: it goes flying, and they can't attack or guard until they find another (7 s)."],
		["df_shove", "Shove", 16, {"parry_shove": 1}, "A perfect parry turns into a shove that throws them off their feet."]],
		"Two answers to a perfect parry (with Clean Parry). Both are yours; pick the one you carry at the ship's bunk.")
	_big("df_brace", "Brace", "mech", 1, 3, {"block_cost_pct": 0.3}, "Blocking a blow costs 30% less stamina.")
	_variant("df_guard", "Guard Style", 1, [
		["df_rolling", "Rolling Guard", 7, {"rolling_guard": 1}, "Dodge behind your guard and you roll with it still up: blows from the front glance off mid-roll, and you come up guarding."],
		["df_planted", "Planted", 7, {"guard_planted": 1}, "Your guard sinks into a wide, rooted stance: blows don't push you back and cost 30% less to block, but you shuffle slower behind it."]],
		"Two ways to hold a guard. Both are yours; pick the one you carry at the ship's bunk.")
	_icon("df_disarm", "move_disarm")
	_icon("df_shove", "move_shove")
	_icon("df_rolling", "move_rolling_guard")
	_icon("df_planted", "move_planted")
	_big("df_hold", "Hold the Line", "mech", 1, 11, {"block_move_pct": 0.5}, "Behind your guard you shuffle half again as fast.")
	_big("df_wall", "Iron Wall", "mech", 1, 20, {"block_cost_pct": 0.3}, "Blocking costs another 30% less stamina.")
	_big("v_steadfast", "Steadfast", "mech", 2, 4, {"steadfast": 1}, "Light hits no longer make you flinch.")
	_big("df_unshaken", "Unshaken", "mech", 2, 9, {"max_hp": 25.0}, "+25 max health.")
	_big("df_skin", "Second Skin", "mech", 2, 14, {"defense": 6.0}, "+6 defense.")
	_big("df_unbreak", "Unbreakable", "mech", 2, 18, {"max_hp": 40.0, "defense": 4.0}, "+40 max health and +4 defense.")
	_step("df_timing", "Timing", "df_root", 5, {"parry_all": 0.008}, "A slightly wider parry window a step.")
	_step("df_sturdy", "Sturdy Guard", "df_brace", 5, {"block_cost_pct": 0.03}, "Blocking costs 3% less stamina a step.")
	_step("df_thick", "Thick Skin", "v_steadfast", 5, {"defense": 1.5}, "+1.5 defense a step.")
	_step("df_recover", "Recovery", "v_iron", 3, {"regen_hp": 0.5}, "Out of a fight you heal 0.5 health a second more, a step.")
	_step("df_calm", "Composure", "df_hold", 3, {"stamina_regen_pct": 0.03}, "Stamina refills 3% faster a step.")


## Sailing (Seamanship, scripts/ship/seamanship.gd): its keys count at the station you man (helm_speed / helm_turn /
## helm_flood steering, gun_reload / gun_dmg a gun you man, repair, pump, capstan; lookout m on the compass aboard;
## crew: half again while a crewmate mans another station).
static func _build_sailing() -> void:
	_tree("sea", ["Helm", "Guns", "Deck"])
	_root("sea_root", "Sailing", {}, "Sail her, fight her guns and keep her afloat to build it. Its nodes count at the station you're manning: the helm, a gun, the pump, a hole or a fire.")
	_big("sea_hand", "Sea Hand", "mech", 0, 2, {"helm_speed": 0.04, "repair": 0.3}, "At the helm she sails 4% faster, and you patch holes and beat out fires 30% faster.")
	_big("f_helm", "Helmsman", "mech", 0, 5, {"helm_speed": 0.06, "helm_turn": 0.1}, "At the helm she sails 6% faster and turns 10% sharper.")
	_big("sea_storm", "Storm Sailing", "mech", 0, 10, {"helm_flood": 0.4, "lookout": 200.0},
		"At the helm water in her costs 40% less of her speed, and aboard, sails and salvage within 200 m show on your compass.")
	_big("sea_gunner", "Gun Captain", "mech", 1, 4, {"gun_reload": 0.15, "gun_dmg": 0.1}, "A gun you man reloads 15% faster, and its balls hit 10% harder.")
	_big("sea_broad", "Broadside Master", "mech", 1, 15, {"gun_reload": 0.15, "gun_dmg": 0.15, "helm_speed": 0.05},
		"Another 15% faster reload, balls 15% harder, and she sails another 5% faster for you.")
	_big("sea_turn", "Hard Over", "mech", 2, 7, {"helm_turn": 0.08, "pump": 0.4, "capstan": 1.0}, "At the helm she turns 8% sharper; you bail 40% more and work the capstan twice as fast.")
	_big("sea_crew", "Bosun", "mech", 2, 20, {"crew": 0.5, "repair": 0.3, "pump": 0.3},
		"Your station bonuses count half again while a crewmate mans another station, and you mend and bail faster still.")
	_step("sea_steady", "Steady Helm", "sea_root", 5, {"helm_speed": 0.01}, "At the helm she sails 1% faster a step.")
	_step("sea_gunnery", "Gunnery", "sea_gunner", 5, {"gun_reload": 0.03}, "A gun you man reloads 3% faster a step.")
	_step("sea_carpenter", "Carpenter", "sea_hand", 3, {"repair": 0.1}, "You patch and douse 10% faster a step.")
	_step("sea_bilge", "Bilge Rat", "sea_turn", 3, {"pump": 0.1}, "You bail 10% more a step.")
	_step("sea_lookout", "Lookout", "sea_storm", 3, {"lookout": 40.0}, "Aboard, sails and salvage show 40 m further a step.")


static func _build_swimming() -> void:
	_tree("swim", ["Stroke", "Breath", "Sea"])
	_root("swim_root", "Swimming", {}, "Swim to build it: every stretch of open water you cross counts.")
	_big("sw_strokes", "Strong Strokes", "mech", 0, 2, {"swim_pct": 0.1}, "You swim 10% faster.")
	_big("sw_born", "Sea Born", "mech", 0, 7, {"swim_pct": 0.15}, "You swim another 15% faster.")
	_variant("sw_sprint", "Surface Sprint", 0, [
		["sw_dolphin", "Dolphin Kick", 12, {"dolphin_kick": 1}, "Sprinting at the surface becomes the butterfly: 30% faster, with a surge of spray every half second, for 30% more stamina."],
		["sw_glide", "Long Glide", 12, {"long_glide": 1}, "Sprinting at the surface is a stroke and a long streamlined glide: a touch faster, for half the stamina."]],
		"Two ways to sprint on top of the water. Both are yours; pick the one you carry at the ship's bunk.")
	_icon("sw_dolphin", "move_dolphin")
	_icon("sw_glide", "move_glide")
	_big("sw_lungs", "Deep Lungs", "mech", 1, 4, {"max_stamina": 10.0, "breath_pct": 0.5}, "You hold your breath half as long again on a dive, and +10 max stamina.")
	_big("sw_wind", "Catch Your Breath", "mech", 1, 10, {"stamina_regen_pct": 0.1, "breath_refill_pct": 1.0},
		"Stamina refills 10% faster, and your breath comes back twice as fast at the surface.")
	_big("sw_diver", "Deep Diver", "mech", 1, 14, {"breath_pct": 0.5}, "You hold your breath half as long again.")
	_big("sw_current", "Current Reader", "mech", 2, 8, {"sea_resist": 0.25}, "Currents, surf, swell and cold have a quarter less hold on you.")
	_big("sw_child", "Child of the Sea", "mech", 2, 15, {"swim_pct": 0.15, "max_stamina": 15.0, "breath_pct": 0.5, "sea_resist": 0.25},
		"You swim another 15% faster, hold your breath longer still, +15 max stamina, and the sea's hold on you weakens again.")
	_big("sw_salt", "Old Salt Lungs", "mech", 2, 20, {"breath_pct": 0.5, "breath_refill_pct": 0.5}, "Your breath lasts longer still and comes back faster.")
	_step("sw_long", "Long Strokes", "swim_root", 5, {"swim_pct": 0.03}, "You swim 3% faster a step.")
	_step("sw_big", "Big Lungs", "sw_lungs", 5, {"breath_pct": 0.08}, "You hold your breath 8% longer a step.")
	_step("sw_tireless", "Tireless", "sw_born", 5, {"max_stamina": 3.0}, "+3 max stamina a step.")
	_step("sw_cold", "Cold Blood", "sw_current", 5, {"sea_resist": 0.05}, "The sea's hold on you 5% weaker a step.")


## Cooking keys (meal_time_pct, meal_power_pct) are read by Food.
static func _build_cooking() -> void:
	_tree("cook", ["Hearty", "Spice", "Larder"])
	_root("cook_root", "Cooking", {}, "Cook at a galley to build it.")
	_big("ck_hand", "Galley Hand", "mech", 0, 2, {"potion_pct": 0.1}, "Food and drink heal you 10% more.")
	_big("ck_stomach", "Iron Gut", "mech", 0, 10, {"potion_pct": 0.2}, "Food and drink heal you another 20% more.")
	_big("ck_ship", "Ship's Cook", "mech", 1, 5, {"meal_time_pct": 0.25}, "Galley meals last 25% longer.")
	_big("ck_chef", "Master Chef", "mech", 1, 15, {"meal_power_pct": 0.2}, "Galley meals' buffs are 20% stronger.")
	_big("ck_feast", "Long Feast", "mech", 2, 8, {"meal_time_pct": 0.25}, "Galley meals last another 25% longer.")
	_big("ck_banquet", "Captain's Table", "mech", 2, 20, {"meal_power_pct": 0.15, "potion_pct": 0.15}, "Meals' buffs 15% stronger again, and food heals 15% more.")
	_step("ck_season", "Seasoning", "cook_root", 5, {"meal_power_pct": 0.03}, "Galley meals' buffs 3% stronger a step.")
	_step("ck_simmer", "Slow Simmer", "ck_ship", 5, {"meal_time_pct": 0.04}, "Galley meals last 4% longer a step.")
	_step("ck_taster", "Taster", "ck_hand", 5, {"potion_pct": 0.03}, "Food and drink heal you 3% more a step.")
	_step("ck_stock", "Good Stock", "ck_feast", 5, {"regen_pct": 0.05}, "Out of a fight you mend 5% faster a step.")


## Fishing keys (fish_bite_pct, fish_reel_pct, fish_bait_save, fish_rare_pct, fish_double, fish_legend) are read by Fishing.
static func _build_fishing() -> void:
	_tree("fish", ["Line", "Bait", "Lore"])
	_root("fish_root", "Fishing", {}, "Fish to build it.")
	_big("fs_patient", "Patient Line", "mech", 0, 2, {"fish_bite_pct": 0.2}, "Fish bite 20% sooner.")
	_big("fs_hands", "Steady Hands", "mech", 0, 5, {"fish_reel_pct": 0.25}, "The float stays down 25% longer: more time to reel in a bite.")
	_big("fs_master", "Master Angler", "mech", 0, 20, {"fish_legend": 1.0, "fish_reel_pct": 0.15}, "Legendary fish come twice as often, and the float stays down another 15% longer.")
	_big("fs_saver", "Bait Saver", "mech", 1, 8, {"fish_bait_save": 0.3}, "30% of your catches leave the bait on the hook.")
	_big("fs_salt", "Old Salt", "mech", 1, 15, {"fish_double": 0.15}, "15% of your catches come up two at once.")
	_big("fs_lore", "Sea Lore", "mech", 2, 10, {"fish_rare_pct": 0.2}, "Rarer fish bite 20% more often.")
	_step("fs_bite", "Quick Bite", "fish_root", 5, {"fish_bite_pct": 0.04}, "Fish bite 4% sooner a step.")
	_step("fs_reel", "Strong Reel", "fs_hands", 5, {"fish_reel_pct": 0.04}, "The float stays down 4% longer a step.")
	_step("fs_luck", "Lucky Cast", "fs_lore", 5, {"fish_rare_pct": 0.03}, "Rarer fish bite 3% more often a step.")
	_step("fs_thrift", "Thrifty", "fs_saver", 5, {"fish_bait_save": 0.03}, "3% more catches leave the bait on the hook, a step.")


## Stealth: everything on the sneaking captain's own machine (sneak_pct: CrouchState's speed; ambush_pct: a blow
## struck within moments of sneaking, Progression.on_hit; the dodge's keys).
static func _build_stealth() -> void:
	_tree("stealth", ["Sneak", "Ambush", "Shadow"])
	_root("st_root", "Stealth", {}, "Sneak (C) near foes and strike from hiding to build it.")
	_big("st_soft", "Soft Step", "mech", 0, 2, {"sneak_pct": 0.25}, "You sneak 25% faster.")
	_big("st_ghost", "Ghost", "mech", 0, 12, {"sneak_pct": 0.25}, "You sneak another 25% faster.")
	_big("st_ambush", "Ambush", "mech", 1, 4, {"ambush_pct": 0.3}, "A blow struck from a sneak lands 30% harder.")
	_big("st_assassin", "Assassin", "mech", 1, 15, {"ambush_pct": 0.4}, "A blow struck from a sneak lands another 40% harder.")
	_big("st_vanish", "Slip Away", "mech", 2, 8, {"dodge_cost_pct": 0.1, "dodge_iframe_pct": 0.15}, "Your dodge costs 10% less and leaves you untouchable 15% longer.")
	_big("st_shadow", "Shadow", "mech", 2, 20, {"ambush_pct": 0.3, "sneak_pct": 0.15}, "Sneak attacks 30% harder again, and you sneak 15% faster.")
	_step("st_quiet", "Quiet Feet", "st_root", 5, {"sneak_pct": 0.04}, "You sneak 4% faster a step.")
	_step("st_knife", "Knife Work", "st_ambush", 5, {"ambush_pct": 0.05}, "A blow from a sneak lands 5% harder a step.")
	_step("st_patience", "Patience", "st_soft", 5, {"stamina_regen_pct": 0.02}, "Stamina refills 2% faster a step.")
	_step("st_nimble", "Nimble", "st_vanish", 5, {"dodge_cost_pct": 0.02}, "Your dodge costs 2% less a step.")


## Tinkering (Downtime's tinker): kit_time_pct (the tuned kit wears off slower), kit_per_pct (each spell tunes longer).
static func _build_tinkering() -> void:
	_tree("tinker", ["Kit", "Powder", "Hands"])
	_root("tk_root", "Tinkering", {}, "Tinker with your kit (the action wheel, aboard or at camp) to build it.")
	_big("tk_tight", "Tight Fit", "mech", 0, 2, {"kit_time_pct": 0.25}, "A tuned kit stays tuned 25% longer.")
	_big("tk_spring", "Fine Springs", "mech", 0, 10, {"kit_time_pct": 0.5}, "Another 50% longer.")
	_big("tk_powder", "Dry Powder", "mech", 1, 5, {"reload_pct": 0.1}, "You reload 10% faster, always.")
	_big("tk_horn", "Powder Horn", "mech", 1, 15, {"extra_shots": 1}, "Every pistol holds one more shot, always.")
	_big("tk_hands", "Clever Hands", "mech", 2, 8, {"kit_per_pct": 0.5}, "Each spell of tinkering tunes the kit half again as long.")
	_big("tk_whet", "Field Whetstone", "mech", 2, 20, {"damage_pct": 0.04}, "+4% damage with everything, always.")
	_step("tk_oil", "Oil", "tk_root", 5, {"kit_time_pct": 0.05}, "A tuned kit stays tuned 5% longer a step.")
	_step("tk_ram", "Ramrod", "tk_powder", 5, {"reload_pct": 0.02}, "You reload 2% faster a step.")
	_step("tk_file", "File", "tk_hands", 5, {"kit_per_pct": 0.05}, "Each spell of tinkering tunes 5% longer a step.")
	_step("tk_patch", "Patchwork", "tk_tight", 5, {"repair": 0.05}, "You patch and douse 5% faster a step.")


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
	_big("s_guard2", "Easy Guard", "mech", 0, 15, {"guard2_sword": 1},
		"A second guard: stood tall and easy, the blade hanging loose out at your side, a thumb in your sash. Double-tap block to switch between it and the swashbuckler's guard; your cuts come out of either.")
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
	# (Iai Counter, Wind Severer and the air attack became variants in 1.18.4: the first version is the old node, kept
	# owned and active in old saves; the price stays the old node's)
	_variant("k_counter", "Iai Counter", 0, [
		["k_drawcut", "Draw Cut", 8, {}, "", "iai_counter"],
		["k_sidestep", "Side Step", 8, {}, "", "side_step"]],
		"Two ways to meet a blow from the scabbard. Both are yours; pick the one you carry at the ship's bunk.")["cost"] = 3
	_big("k_phantom", "Phantom Step", "tech", 0, 14, {}, "", "phantom_step")
	_big("k_guard2", "Waki Guard", "mech", 0, 15, {"guard2_katana": 1},
		"A second guard: side on and low, the blade held back behind the right hip, its length hidden from the foe. Double-tap block to switch between it and the middle guard; your cuts come out of either.")
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
	_variant("k_wind", "Wind Severer", 2, [
		["k_tower", "Towering Wave", 5, {}, "", "wind_sever"],
		["k_twin", "Twin Waves", 18, {}, "", "twin_waves"]],
		"Two ways to send the wind. Both are yours (Twin Waves from mastery 18); pick the one you carry at the ship's bunk.")["cost"] = 3
	_variant("k_arc", "Air Cut", 2, [
		["k_crescent", "Crescent Arc", 7, {"mv_air_slash": 1}, "Attack in the air: a little lift and one big arc swept down under you (once per jump)."],
		["k_moon", "Falling Moon", 15, {"mv_falling_moon": 1}, "Attack in the air: the blade raised, one turn over forward with it held out (the point draws a full moon), a dive, and a crescent run out along the ground ahead that knocks everyone on it flat (once per jump)."]],
		"Two ways to cut from the air. Both are yours (Falling Moon from mastery 15); pick the one you carry at the ship's bunk.")["cost"] = 2
	_icon("k_moon", "falling_moon")
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
	_big("d_guard2", "Wings", "mech", 0, 15, {"guard2_dual": 1},
		"A second guard: pitched down and forward over a deep crouch, both arms swept back with the blades like half-folded wings. Double-tap block to switch between it and the paired guard; your cuts come out of either.")
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
	_big("a_guard2", "Bearded Guard", "mech", 0, 15, {"guard2_axe": 1},
		"A second guard: choked up two-handed across the front, the head up by the left shoulder, and a block on the haft in both hands. Double-tap block to switch between it and the brawler's guard; your combo comes out of either.")
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
	_big("dg_guard2", "Hidden Knife", "mech", 0, 15, {"guard2_dagger": 1},
		"A second guard: stood easy, the dagger held low at the back of your hip, the free hand out open. Double-tap block to switch between it and the knife fighter's crouch; your cuts come out of either.")
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


## Polearms (spear, trident, naginata, bisento, halberd, pitchfork): reach and sweeps, lightning as the element.
static func _build_polearm() -> void:
	_tree("polearm", ["Guard", "Storm", "Reach"])
	_root("pl_root", "Polearm", {},
		"Two hands on a long shaft: thrusts that hit from three paces off, wide sweeps that clear a crowd, and on right-click a lunge that skewers the whole line. Keep them at the point. Fight with a polearm in hand to build its mastery.")
	_big("pl_deflect", "Turn the Shot", "mech", 0, 3, {"parryshot_polearm": 1, "parry_polearm": 0.06},
		"Parry with a polearm and you knock gunshots aside on the shaft too (without it, a parry only stops blades), and your parry window is wider.")
	_big("pl_vstrike", "Vaulting Strike", "tech", 0, 8, {}, "", "vault_strike")
	_big("pl_bearing", "Emperor's Bearing", "mech", 0, 10, {"plant_polearm": 1},
		"A master's ease: stand still with a polearm drawn and nothing happening for a few seconds, and you plant its butt on the ground beside you, the pole upright in one hand, chest out. Anything you do comes straight out of it.")
	_big("pl_windmill", "Windmill Guard", "tech", 0, 14, {}, "", "windmill_guard")
	_big("pl_return", "Spear Wall", "mech", 0, 20, {"deflect_polearm": 1, "return_polearm": 1, "deflect_cd_polearm": 1.0},
		"With a polearm drawn, a shot from the front is knocked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.")
	_big("pl_thrusts", "Hundred Thrusts", "tech", 1, 5, {}, "", "hundred_thrusts")
	_big("pl_dragon", "Dragon Sweep", "tech", 1, 10, {}, "", "dragon_sweep")
	_elem(1)
	_elem(2)
	_big("pl_wheel_ult", "Raijin's Wheel", "ult", 1, 30, {}, "", "raijin_wheel")
	_big("pl_wheel", "Wheel Sweep", "move", 2, 2, {"mv_wheel_sweep": 1}, "Adds a fourth hit to your combo: the spear laid out at the waist and swung round once all about you.")
	_big("pl_vault", "Pole Vault", "move", 2, 4, {"mv_pole_vault": 1},
		"Jump at a sprint with a polearm drawn: plant the point and vault, half again as high and far as a running bound.")
	_big("pl_legs", "Leg Sweep", "move", 2, 6, {"mv_leg_sweep": 1},
		"Attack at a sprint: drop into a kneeling slide and sweep the head through their shins. It breaks their wind-up and puts them on the ground.")
	_big("pl_fall", "Falling Spear", "move", 2, 9, {"mv_falling_spear": 1},
		"Attack in the air: the spear raised overhead, point down, then a straight drop onto it and a ring off the landing that knocks everyone close flat (once per jump).")
	_big("pl_javelin", "Thunder Javelin", "tech", 2, 12, {}, "", "thunder_javelin")
	_big("pl_long", "Long Reach", "passive", 2, 13, {"finisher_polearm": 0.3, "heavy_polearm": 0.25},
		"Passive (a slot). The last blow of your combo lands 30% harder, and your Skewer (right-click) 25%.")
	_variant("pl_way", "Lancer's Way", 2, [
		["pl_keep", "Keep Away", 22, {"leech_polearm": 0.06, "cdr_polearm": 0.2}, "Polearm hits heal you for 6% of their damage, and polearm techniques come back 20% sooner."],
		["pl_skewer", "Skewer", 22, {"exec_polearm": 0.5, "crit_polearm": 0.06}, "A hit that leaves them under 30% health deals 50% more on top, and 6% more of your hits are crits."]],
		"Two ways to hold the line. Both are yours; pick the one you carry at the ship's bunk.")
	_step("pl_shaft", "Long Shaft", "pl_root", 5, {"dmg_polearm": 0.05}, "+5% polearm damage a step.")
	_step("pl_nerves", "Steady Shaft", "pl_deflect", 3, {"parry_polearm": 0.02}, "A polearm parry's window a little wider a step.")
	_step("pl_point", "Spearpoint", "pl_elem", 5, {"crit_polearm": 0.03}, "3% more of your polearm hits land 50% harder, a step.")
	_step("pl_sweeping", "Sweeping", "pl_dragon", 5, {"finisher_polearm": 0.06}, "The last blow of your combo lands 6% harder a step.")
	_step("pl_feet", "Light Feet", "pl_wheel", 3, {"stam_polearm": 0.05}, "Polearm attacks cost 5% less stamina a step.")
	_step("pl_lunge", "Lunge", "pl_legs", 3, {"heavy_polearm": 0.08}, "Your Skewer (right-click) hits 8% harder a step.")
	_step("pl_flow", "Flow", "pl_thrusts", 3, {"flow_polearm": 0.15}, "Polearm hits give 15% more energy a step.")
	_step("pl_recover", "Recovery", "pl_long", 3, {"cdr_polearm": 0.05}, "Polearm techniques come back 5% sooner a step.")


## Hammers (warhammer, kanabo, mallet, maul, anchor hammer): weight, stagger and shockwaves, earth as the element.
static func _build_hammer() -> void:
	_tree("hammer", ["Iron", "Quake", "Weight"])
	_root("hm_root", "Hammer", {},
		"Two hands on a heavy head: slow swings that shove them back and stagger them, a flat swing that breaks a guard, and on right-click the hammer slammed into the ground with a shockwave that knocks everyone round it flat. Fight with a hammer in hand to build its mastery.")
	_big("hm_deflect", "Iron Wall", "mech", 0, 3, {"parryshot_hammer": 1, "parry_hammer": 0.06},
		"Parry with a hammer and you swat gunshots aside with the head too (without it, a parry only stops blades), and your parry window is wider.")
	_big("hm_skull", "Skullcracker", "tech", 0, 8, {}, "", "skullcracker")
	_big("hm_anvil_c", "Anvil Counter", "tech", 0, 14, {}, "", "anvil_counter")
	_big("hm_unstop", "Immovable", "mech", 0, 20, {"armor_hammer": 1, "def_hammer": 6.0},
		"Mid-swing with a hammer, blows don't make you flinch or knock you off your feet, and you have 6 more defense with one in hand.")
	_big("hm_quakes", "Rolling Quake", "tech", 1, 5, {}, "", "rolling_quake")
	_big("hm_cyclone", "Cyclone Crusher", "tech", 1, 10, {}, "", "cyclone_crusher")
	_elem(1)
	_elem(2)
	_big("hm_titan", "Titan's Fall", "ult", 1, 30, {}, "", "titans_fall")
	_big("hm_spin", "Wrecking Spin", "move", 2, 2, {"mv_wrecking_spin": 1},
		"Adds a fourth blow to your combo: the hammer let out at arm's length, the whole body turned round once behind it, and the head brought down at the end. It hits everyone about you and puts them on the ground.")
	_big("hm_rush", "Rising Crush", "move", 2, 4, {"mv_rising_crush": 1},
		"Attack at a sprint: drag the head low behind you, then swing it up off the ground through them. It breaks their wind-up and throws them down.")
	_big("hm_fall", "Hammerfall", "move", 2, 6, {"mv_hammerfall": 1},
		"Attack in the air: heave the hammer up overhead and drop with it; landing drives it into the ground in a shockwave that knocks everyone close flat (once per jump).")
	_big("hm_drive", "Cannonball Swing", "tech", 2, 12, {}, "", "cannonball_swing")
	_big("hm_after", "Aftershock", "passive", 2, 13, {"finisher_hammer": 0.3, "heavy_hammer": 0.25},
		"Passive (a slot). The last blow of your combo lands 30% harder, and your Earthquake (right-click) 25%.")
	_variant("hm_way", "Smith's Way", 2, [
		["hm_bones", "Bonebreaker", 22, {"exec_hammer": 0.5, "crit_hammer": 0.06}, "A hit that leaves them under 30% health deals 50% more on top, and 6% more of your hits are crits."],
		["hm_anvil", "Anvil", 22, {"leech_hammer": 0.06, "cdr_hammer": 0.2}, "Hammer hits heal you for 6% of their damage, and hammer techniques come back 20% sooner."]],
		"Two ways to swing it. Both are yours; pick the one you carry at the ship's bunk.")
	_step("hm_heft", "Heft", "hm_root", 5, {"dmg_hammer": 0.05}, "+5% hammer damage a step.")
	_step("hm_hide", "Iron Hide", "hm_deflect", 3, {"def_hammer": 3.0}, "+3 defense with a hammer in hand a step.")
	_step("hm_crush", "Crushing", "hm_elem", 5, {"crit_hammer": 0.03}, "3% more of your hammer hits land 50% harder, a step.")
	_step("hm_momentum", "Momentum", "hm_cyclone", 5, {"finisher_hammer": 0.06}, "The last blow of your combo lands 6% harder a step.")
	_step("hm_back", "Strong Back", "hm_spin", 3, {"stam_hammer": 0.05}, "Hammer attacks cost 5% less stamina a step.")
	_step("hm_overhead", "Overhead", "hm_rush", 3, {"heavy_hammer": 0.08}, "Your Earthquake (right-click) hits 8% harder a step.")
	_step("hm_flow", "Flow", "hm_quakes", 3, {"flow_hammer": 0.15}, "Hammer hits give 15% more energy a step.")
	_step("hm_recover", "Recovery", "hm_after", 3, {"cdr_hammer": 0.05}, "Hammer techniques come back 5% sooner a step.")


## Twin axes (an axe in each hand, any two designs): a berserker's rhythm of chops, hooks that haul them in, frost as
## the element.
static func _build_dual_axe() -> void:
	_tree("dual_axe", ["Hook", "Frenzy", "Reaver"])
	_root("dx_root", "Twin Axes", {},
		"An axe in each hand: quick chops trading hands, a hook on the third that hauls them in, and on right-click a frenzy of chops ending in both crashed down crossed. A parry catches the blow in the crossed axes and hooks them in a step. Fight with two axes in hand to build its mastery.")
	_big("dx_deflect", "Hooked Guard", "mech", 0, 3, {"parryshot_dual_axe": 1, "parry_dual_axe": 0.06},
		"Parry with two axes and you knock gunshots aside with the heads too (without it, a parry only stops blades), and your parry window is wider.")
	_big("dx_gallows", "Gallows Hook", "tech", 0, 8, {}, "", "gallows_hook")
	_big("dx_haul", "Raider's Haul", "tech", 0, 14, {}, "", "raiders_haul")
	_big("dx_rage", "Bloodrage", "mech", 0, 20, {"armor_dual_axe": 1, "def_dual_axe": 4.0},
		"Mid-swing with twin axes, blows don't make you flinch or knock you off your feet, and you have 4 more defense with them in hand.")
	_big("dx_frenzy", "Hewing Frenzy", "tech", 1, 5, {}, "", "hewing_frenzy")
	_big("dx_storm", "Axestorm", "tech", 1, 10, {}, "", "axestorm")
	_elem(1)
	_elem(2)
	_big("dx_winter", "Fimbulwinter", "ult", 1, 30, {}, "", "fimbulwinter")
	_big("dx_whirl", "Reaping Whirl", "move", 2, 2, {"mv_reaping_whirl": 1},
		"Adds a fourth blow to your combo: both axes flung out level and two turns behind them. It hits everyone about you and puts them on the ground.")
	_big("dx_leap", "Raider's Leap", "move", 2, 4, {"mv_raiders_leap": 1},
		"Attack at a sprint: leap with both axes raised and crash them down crossed into the one in front. It breaks their wind-up and throws them down.")
	_big("dx_saw", "Buzzsaw", "move", 2, 6, {"mv_buzzsaw": 1},
		"Attack in the air: tuck up with both axes out and drop turning over and over like a saw blade, cutting everything under you, then bite both into the ground in a ring that knocks them flat (once per jump).")
	_big("dx_ravens", "Ravens' Return", "tech", 2, 12, {}, "", "ravens_return")
	_big("dx_blood", "Red Rhythm", "passive", 2, 13, {"flow_dual_axe": 0.3, "finisher_dual_axe": 0.3},
		"Passive (a slot). Twin-axe hits give 30% more energy, and the last blow of your combo lands 30% harder.")
	_variant("dx_way", "Reaver's Way", 2, [
		["dx_berserk", "Berserker", 22, {"crit_dual_axe": 0.08, "leech_dual_axe": 0.06}, "8% more of your hits are crits, and twin-axe hits heal you for 6% of their damage."],
		["dx_raider", "Raider", 22, {"cdr_dual_axe": 0.2, "exec_dual_axe": 0.4}, "Twin-axe techniques come back 20% sooner, and a hit that leaves them under 30% health deals 40% more on top."]],
		"Two ways to run a raid. Both are yours; pick the one you carry at the ship's bunk.")
	_step("dx_keen", "Keen Bits", "dx_root", 5, {"dmg_dual_axe": 0.05}, "+5% twin-axe damage a step.")
	_step("dx_hide", "Iron Hide", "dx_deflect", 3, {"def_dual_axe": 3.0}, "+3 defense with twin axes in hand a step.")
	_step("dx_bite", "Biting Cold", "dx_elem", 5, {"crit_dual_axe": 0.03}, "3% more of your twin-axe hits land 50% harder, a step.")
	_step("dx_pace", "Relentless", "dx_storm", 5, {"finisher_dual_axe": 0.06}, "The last blow of your combo lands 6% harder a step.")
	_step("dx_feet", "Light Feet", "dx_whirl", 3, {"stam_dual_axe": 0.05}, "Twin-axe attacks cost 5% less stamina a step.")
	_step("dx_heave", "Heave", "dx_leap", 3, {"heavy_dual_axe": 0.08}, "Your Berserker Frenzy (right-click) hits 8% harder a step.")
	_step("dx_flow", "Flow", "dx_frenzy", 3, {"flow_dual_axe": 0.15}, "Twin-axe hits give 15% more energy a step.")
	_step("dx_recover", "Recovery", "dx_blood", 3, {"cdr_dual_axe": 0.05}, "Twin-axe techniques come back 5% sooner a step.")


## Greatswords (greatsword, black greatblade, claymore, sawtooth, greatcleaver, Sea King's Fang): sweeping arcs whose
## momentum carries into the next, guard breaking, the charged cleave; wind as the element.
static func _build_greatsword() -> void:
	_tree("greatsword", ["Bulwark", "Gale", "Momentum"])
	_root("gs_root", "Greatsword", {},
		"A blade as long as you are, two hands on it from a low guard: wide sweeping cuts, each flowing out of the last one's follow-through and coming faster and harder as the momentum builds, a flat backhand that breaks a guard, and on right-click the cleave: hold to raise and charge it, let go to bring it down. A full charge flings a crescent of air down the line. Fight with a greatsword in hand to build its mastery.")
	_big("gs_deflect", "Flat of the Blade", "mech", 0, 3, {"parryshot_greatsword": 1, "parry_greatsword": 0.06},
		"Parry with a greatsword and you turn gunshots aside on the flat too (without it, a parry only stops blades), and your parry window is wider.")
	_big("gs_break", "Guardbreaker", "tech", 0, 8, {}, "", "guardbreaker")
	_big("gs_gate", "Gatekeeper", "tech", 0, 14, {}, "", "gatekeeper")
	_big("gs_unyield", "Unyielding", "mech", 0, 20, {"armor_greatsword": 1, "def_greatsword": 5.0},
		"Mid-swing with a greatsword, blows don't make you flinch or knock you off your feet, and you have 5 more defense with one in hand.")
	_big("gs_crescent", "Crescent Gale", "tech", 1, 5, {}, "", "crescent_gale")
	_big("gs_tempest", "Tempest Turns", "tech", 1, 10, {}, "", "tempest_turns")
	_elem(1)
	_elem(2)
	_big("gs_sky", "Skysplitter", "ult", 1, 30, {}, "", "skysplitter")
	_big("gs_turn", "Gale Turn", "move", 2, 2, {"mv_gale_turn": 1},
		"Adds a fourth blow to your combo: the backhand's momentum let carry you on round once more with the blade out at arm's length. It hits everyone about you and puts them on the ground.")
	_big("gs_run", "Running Cleave", "move", 2, 4, {"mv_running_cleave": 1},
		"Attack at a sprint: the blade dragged behind you swung round in one flat sweep through them as you lunge. It breaks their wind-up and throws them down.")
	_big("gs_updraft", "Updraft", "tech", 2, 12, {}, "", "updraft")
	_big("gs_fall", "Falling Cleave", "move", 2, 6, {"mv_falling_cleave": 1},
		"Attack in the air: heave the blade up overhead and drop with it; landing drives it into the ground and splits a line ahead that knocks everyone on it flat (once per jump).")
	_big("gs_flow", "Unbroken Momentum", "passive", 2, 13, {"finisher_greatsword": 0.3, "heavy_greatsword": 0.25},
		"Passive (a slot). The last blow of your combo lands 30% harder, and your cleave (right-click) 25%.")
	_variant("gs_way", "Swordmaster's Way", 2, [
		["gs_head", "Headsman", 22, {"exec_greatsword": 0.5, "crit_greatsword": 0.06}, "A hit that leaves them under 30% health deals 50% more on top, and 6% more of your hits are crits."],
		["gs_tide", "Tidebreaker", 22, {"leech_greatsword": 0.06, "cdr_greatsword": 0.2}, "Greatsword hits heal you for 6% of their damage, and greatsword techniques come back 20% sooner."]],
		"Two ways to carry a blade this size. Both are yours; pick the one you carry at the ship's bunk.")
	_step("gs_edge", "Broad Edge", "gs_root", 5, {"dmg_greatsword": 0.05}, "+5% greatsword damage a step.")
	_step("gs_hide", "Iron Hide", "gs_deflect", 3, {"def_greatsword": 3.0}, "+3 defense with a greatsword in hand a step.")
	_step("gs_keen", "Keen Wind", "gs_elem", 5, {"crit_greatsword": 0.03}, "3% more of your greatsword hits land 50% harder, a step.")
	_step("gs_carry", "Carry Through", "gs_tempest", 5, {"finisher_greatsword": 0.06}, "The last blow of your combo lands 6% harder a step.")
	_step("gs_wind", "Second Wind", "gs_turn", 3, {"stam_greatsword": 0.05}, "Greatsword attacks cost 5% less stamina a step.")
	_step("gs_heft", "Heft", "gs_run", 3, {"heavy_greatsword": 0.08}, "Your cleave (right-click) hits 8% harder a step.")
	_step("gs_draw", "Draw Breath", "gs_crescent", 3, {"flow_greatsword": 0.15}, "Greatsword hits give 15% more energy a step.")
	_step("gs_recover", "Recovery", "gs_flow", 3, {"cdr_greatsword": 0.05}, "Greatsword techniques come back 5% sooner a step.")


## Two daggers: a set of their own (not the dual-wield tree), venom and speed.
static func _build_dual_dagger() -> void:
	_tree("dual_dagger", ["Guard", "Fangs", "Venom"])
	_root("dd_root", "Twin Daggers", {"crit_dual_dagger": 0.08, "bleed_dual_dagger": 0.2, "backstab_dual_dagger": 0.35},
		"A dagger in each hand: the fastest blows you can throw, a scissor rip on right-click. 8% of your hits are crits, 20% open a wound that bleeds, and a blade in the back deals a third again. Fight with two daggers to build their mastery.")
	_big("dd_deflect", "Crossed Knives", "mech", 0, 3, {"parryshot_dual_dagger": 1, "evade_dual_dagger": 0.08},
		"Parry with two daggers and you knock gunshots aside too (without it, a parry only stops blades), and 8% of the blows that would hit you are slipped by instinct.")
	_big("dd_edge", "Bleeding Edge", "tech", 0, 8, {}, "", "bleeding_edge")
	_big("dd_guard2", "Viper", "mech", 0, 15, {"guard2_dual_dagger": 1},
		"A second guard: sunk low and side on, one dagger reared up by your face with its point down at them like a fang, the other low ahead. Double-tap block to switch between it and the low cross; your cuts come out of either.")
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
	_tree("unarmed", ["Power", "Martial", "Body"])
	_root("u_root", "Unarmed", {}, "Bare-handed boxing: jab, cross and hook, each out of the last, and on right-click a huge overhand haymaker that knocks them flat. Fight with your fists to build unarmed mastery.")
	_big("u_hip", "Shoulder Throw", "tech", 0, 3, {}, "", "hip_toss")
	_big("u_landing", "Heavy Landing", "mech", 0, 9, {"throw_splash": 1, "dmg_unarmed": 0.25},
		"Anyone your haymaker or a throw knocks flat lands like a cannonball: everyone near where they come down is knocked flat and hurt. Your punches hit 25% harder.")
	_big("u_cannon", "Cannonball Fist", "tech", 0, 12, {}, "", "cannonball_fist")
	_big("u_meteor_fist", "Meteor Fist", "tech", 0, 18, {}, "", "meteor_fist")
	_big("u_palm", "Shockwave Palm", "tech", 1, 4, {}, "", "palm_strike")
	_big("u_dragon", "Rising Dragon", "tech", 1, 8, {}, "", "rising_dragon")
	_big("u_hundred", "Hundred Fists", "tech", 1, 13, {}, "", "hundred_fists")
	_elem(1)
	_elem(2)
	_big("u_seaking", "Sea King Fist", "ult", 1, 30, {}, "", "sea_king_fist")
	_big("u_round", "Uppercut", "move", 2, 2, {"mv_roundhouse": 1}, "Adds a fourth hit to your punch combo: a dipping rear uppercut that lifts them off their feet.")
	_big("u_meteor", "Diving Fist", "move", 2, 6, {"mv_meteor_kick": 1},
		"Attack in the air: dive fist-first at the enemy you're looking at, a punch that knocks them flat and bounces you back up for another (three in a row); a miss drives the fist into the ground.")
	_big("u_ironbody", "Iron Body", "passive", 2, 11, {"def_unarmed": 8.0, "parry_unarmed": 0.06}, "Passive (a slot). Fighting bare-handed: +8 defense and a wider parry window.")
	_big("u_chi", "Chi", "passive", 2, 15, {"flow_unarmed": 0.5, "leech_unarmed": 0.06}, "Passive (a slot). Unarmed hits give 50% more energy and heal you for 6% of their damage.")
	_big("u_finish", "Finishing Blow", "passive", 2, 22, {"finisher_unarmed": 0.4, "cdr_unarmed": 0.2},
		"Passive (a slot). The last hit of your combo lands 40% harder, and unarmed techniques come back 20% sooner.")
	_step("u_knuckles", "Iron Knuckles", "u_root", 5, {"dmg_unarmed": 0.05}, "+5% unarmed damage a step.")
	_step("u_grip", "Grip", "u_hip", 3, {"skill_unarmed": 0.06}, "Your fist techniques hit 6% harder a step.")
	_step("u_skin", "Stone Skin", "u_cannon", 3, {"def_unarmed": 2.0}, "+2 defense bare-handed a step.")
	_step("u_points", "Pressure Points", "u_elem", 5, {"crit_unarmed": 0.03}, "3% more of your unarmed hits land 50% harder, a step.")
	_step("u_hands", "Heavy Hands", "u_hundred", 5, {"finisher_unarmed": 0.06}, "The last hit of your combo lands 6% harder a step.")
	_step("u_feet", "Light Feet", "u_round", 3, {"stam_unarmed": 0.07}, "Unarmed attacks cost 7% less stamina a step.")
	_step("u_flow", "Flow", "u_palm", 3, {"flow_unarmed": 0.15}, "Unarmed hits give 15% more energy a step.")
	_step("u_breath", "Breath", "u_ironbody", 3, {"cdr_unarmed": 0.05}, "Unarmed techniques come back 5% sooner a step.")


## Black-leg (learned from its trainer, not found: empty hands fight with kicks once it's chosen): kicks only, the
## hands down on the ground in the flashiest, heat as the element; Nonchalance puts the hands in the pockets.
static func _build_black_leg() -> void:
	_tree("black_leg", ["Guard", "Fire", "Flow"])
	_root("bl_root", "Black Leg", {},
		"Kicks only, the hands kept free: a low kick, a mid kick and a high kick flowing into each other, and on right-click the heel brought down from over your head through a guard. Taught, not found; choose it by clicking your empty hand in the bag (I). Fight with your kicks to build its mastery.")
	_big("bl_deflect", "Shin Guard", "mech", 0, 3, {"parryshot_black_leg": 1, "parry_black_leg": 0.06},
		"Parry with a raised shin and you kick gunshots aside too (without it, a parry only stops blades), and your parry window is wider.")
	_big("bl_mule", "Mule Kick", "tech", 0, 8, {}, "", "mule_kick")
	_big("bl_pockets", "Nonchalance", "mech", 0, 10, {"pockets_black_leg": 1},
		"A master's ease: your hands stay in your pockets on guard. They come out the moment you kick and go back in as you settle; nothing waits on them.")
	_big("bl_return", "Kick Back", "mech", 0, 20, {"deflect_black_leg": 1, "return_black_leg": 1, "deflect_cd_black_leg": 1.0},
		"Kicking, a shot from the front is kicked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.")
	_big("bl_hail", "Hailstorm Heels", "tech", 1, 5, {}, "", "hailstorm_heels")
	_big("bl_wheel", "Cartwheel Crescent", "tech", 1, 10, {}, "", "cartwheel_crescent")
	_elem(1)
	_elem(2)
	_big("bl_last", "Last Course", "ult", 1, 30, {}, "", "last_course")
	_big("bl_spin", "Handstand Spin", "move", 2, 2, {"mv_handstand_spin": 1},
		"Adds a fourth kick to your combo: down on both hands, the legs split out flat and two turns round, sweeping everyone about you off their feet.")
	_big("bl_arrow", "Arrow Kick", "move", 2, 4, {"mv_arrow_kick": 1},
		"Attack at a sprint: launch side-on and shoot one leg straight through them. It breaks their wind-up and throws them down.")
	_big("bl_cyclone", "Cyclone Heel", "move", 2, 6, {"mv_cyclone_heel": 1},
		"Attack in the air: turn flat like a top with one leg out, kicking everyone you pass, and come down on one hand in a ring that knocks them flat (once per jump).")
	_big("bl_tempo", "Galley Tempo", "passive", 2, 13, {"finisher_black_leg": 0.3, "heavy_black_leg": 0.25},
		"Passive (a slot). The last kick of your combo lands 30% harder, and your Guillotine Heel (right-click) 25%.")
	_variant("bl_way", "Cook's Way", 2, [
		["bl_chef", "Head Chef", 22, {"leech_black_leg": 0.06, "cdr_black_leg": 0.2}, "Kicks heal you for 6% of their damage, and black-leg techniques come back 20% sooner."],
		["bl_carver", "Carver", 22, {"exec_black_leg": 0.5, "crit_black_leg": 0.06}, "A kick that leaves them under 30% health deals 50% more on top, and 6% more of your kicks are crits."]],
		"Two ways to run a galley. Both are yours; pick the one you carry at the ship's bunk.")
	_step("bl_shins", "Iron Shins", "bl_root", 5, {"dmg_black_leg": 0.05}, "+5% kick damage a step.")
	_step("bl_nerves", "Light Check", "bl_deflect", 3, {"parry_black_leg": 0.02}, "A shin parry's window a little wider a step.")
	_step("bl_sear", "Searing", "bl_elem", 5, {"crit_black_leg": 0.03}, "3% more of your kicks land 50% harder, a step.")
	_step("bl_heel", "Heavy Heel", "bl_wheel", 5, {"finisher_black_leg": 0.06}, "The last kick of your combo lands 6% harder a step.")
	_step("bl_feet", "Light Feet", "bl_spin", 3, {"stam_black_leg": 0.05}, "Kicks cost 5% less stamina a step.")
	_step("bl_drop", "Guillotine", "bl_arrow", 3, {"heavy_black_leg": 0.08}, "Your Guillotine Heel (right-click) hits 8% harder a step.")
	_step("bl_flow", "Flow", "bl_hail", 3, {"flow_black_leg": 0.15}, "Kicks give 15% more energy a step.")
	_step("bl_recover", "Recovery", "bl_tempo", 3, {"cdr_black_leg": 0.05}, "Black-leg techniques come back 5% sooner a step.")


# --------------------------------------------------------------------------
# Driftfruit: the fruit you ate (levels 1-20, grown by using its powers)
# --------------------------------------------------------------------------
static func _build_ember() -> void:
	_tree("ember", ["Fist", "Body", "Blaze"])
	_root("e_root", "Ember Fruit (Logia)", {},
		"Logia: your body is fire. Your dodge turns you to flame - fully untouchable, passing straight through enemies and gunfire. Use its powers to grow it.")
	_big("e_fist", "Fire Fist", "tech", 0, 1, {}, "", "fire_fist")
	_big("e_dash", "Flame Dash", "tech", 0, 6, {}, "", "flame_dash")
	_big("e_kindled", "Kindled Blade", "mech", 1, 4, {"kindled_blade": 1}, "Every melee hit sears: the target burns for a moment.")
	_big("e_smolder", "Smoldering Body", "mech", 1, 11, {"smoldering": 1}, "Your flame-form dodge leaves burning embers behind.")
	_big("e_inferno", "Great Inferno", "ult", 1, 20, {}, "", "inferno")
	_big("e_ring", "Blazing Ring", "tech", 2, 1, {}, "", "fire_ring")
	_big("e_field", "Ember Field", "tech", 2, 8, {}, "", "ember_field")
	_step("e_heat", "Searing Heat", "e_root", 5, {"fire_pct": 0.04}, "+4% fire damage a step.")
	_step("e_fuel", "Fuel", "e_fist", 5, {"energy_regen_pct": 0.03}, "Energy refills 3% faster a step.")
	_step("e_core", "Hot Core", "e_kindled", 5, {"max_energy": 3.0}, "+3 max energy a step.")
	_step("e_quick", "Quick Flame", "e_ring", 5, {"cdr_Ember": 0.03}, "Ember powers come back 3% sooner a step.")


static func _build_wolf() -> void:
	_tree("wolf", ["Fang", "Pelt", "Pack"])
	_root("z_root", "Wolf Fruit (Zoan)", {},
		"Zoan: press V to shift between your human and hybrid wolf form. Hybrid: claws instead of weapons, 25% more damage and 15% faster. Fight in hybrid form and use its powers to grow it.")
	_big("z_fang", "Rending Fang", "tech", 0, 1, {}, "", "rending_fang")
	_big("z_hunt", "Predator", "mech", 0, 9, {"hybrid_speed_pct": 0.1}, "Hybrid form is another 10% faster.")
	_big("z_pelt", "Thick Pelt", "mech", 1, 5, {"hybrid_defense": 8.0}, "+8 defense in hybrid form.")
	_big("z_howl", "Alpha Howl", "tech", 1, 12, {}, "", "howl")
	_big("z_pounce", "Pounce", "tech", 2, 1, {}, "", "pounce")
	_step("z_claw", "Sharp Claws", "z_root", 5, {"claw_pct": 0.05}, "+5% damage in hybrid form a step.")
	_step("z_hide", "Tough Hide", "z_pelt", 5, {"hybrid_defense": 1.5}, "+1.5 defense in hybrid form a step.")
	_step("z_lope", "Lope", "z_hunt", 5, {"hybrid_speed_pct": 0.02}, "Hybrid form 2% faster a step.")
	_step("z_pack", "Pack Instinct", "z_pounce", 5, {"cdr_Wolf": 0.03}, "Wolf powers come back 3% sooner a step.")


static func _build_vine() -> void:
	_tree("vine", ["Snare", "Root", "Thorn"])
	_root("p_root", "Vine Fruit (Paramecia)", {},
		"Paramecia: Photosynthesis - out of combat you slowly heal and regain energy while on land. Use its powers to grow it.")
	_big("p_snare", "Vine Snare", "tech", 0, 1, {}, "", "vine_snare")
	_big("p_roots", "Deep Roots", "mech", 1, 5, {"photo_mult": 1.0}, "Photosynthesis works twice as fast.")
	_big("p_whip", "Thorn Whip", "tech", 1, 12, {}, "", "thorn_whip")
	_big("p_swing", "Vine Swing", "tech", 2, 1, {}, "", "vine_swing")
	_big("p_thorns", "Thorn Hide", "mech", 2, 9, {"thorn_hide": 6.0}, "Enemies that hit you in melee take 6 damage from your thorns.")
	_step("p_sun", "Sunlight", "p_root", 5, {"photo_mult": 0.15}, "Photosynthesis 15% faster a step.")
	_step("p_bark", "Bark", "p_roots", 5, {"defense": 1.5}, "+1.5 defense a step.")
	_step("p_spines", "Spines", "p_thorns", 5, {"thorn_hide": 1.5}, "Your thorns deal 1.5 more a step.")
	_step("p_growth", "Quick Growth", "p_snare", 5, {"cdr_Vine": 0.03}, "Vine powers come back 3% sooner a step.")
