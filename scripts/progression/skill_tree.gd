class_name SkillTree
extends RefCounted
## The old skill-tree registry, kept while its last trees move to SkillTrees (the v1.18.2 redesign):
##   life    the life skills side by side (swim, sea = Seamanship, cook, fish): learned by doing,
##            their perks come by themselves at mastery milestones
##   fruit    your Devil Fruit (only once you've eaten one)
## The Captain and weapon trees are SkillTrees' now; `nodes()` merges SkillTrees' nodes in this shape ("new": true), so a
## reader of either sees every node.
##
## Node: {id, name, kind, tree, region, pos, links, cost, effects, skill, req, desc}
##   kind: origin | root | stat | passive | move | active | ult | perk (and SkillTrees' kinds)
##   effects: stat bonuses / flags summed by Progression.stat(); a move node
##     carries a flag "mv_<move>" (Progression.has_move)
##   req: {"level": n}, {"fruit": id}, {"node": id}, {"life": tree, "life_lv": n} (a life skill's
##     mastery), {"mastery": n} (a perk: reached at that level of its own life skill)
##
## Weapon-tree effect keys (<t> = the tree id, read with Progression.style_stat for
## the weapon in hand): dmg_ damage, stam_ attack stamina, flow_ energy per hit,
## crit_ chance of a x1.5 hit, heavy_ / finisher_ / skill_ damage of heavies,
## combo finishers and techniques, leech_ share of damage healed, exec_ extra
## damage to targets left under 30% health, parry_ parry window (s), parryshot_
## a parry also cuts gunshots, deflect_ cuts them by itself (deflect_cd_ shortens
## its 4 s wait), return_ sends cut shots back, unblock_ heavies can't be blocked, armor_ no flinching mid-attack,
## def_ defense, cdr_ cooldown cut for that tree's skills, bleed_ chance a hit opens a
## bleeding wound, backstab_ extra share of a hit landed from behind, evade_ chance a blow
## is slipped (the daggers).

## kind: shared (paid with level skill points), weapon (a SkillTrees weapon tree: mastery by fighting with it),
## life (learned by doing: its perks come by themselves at mastery milestones), fruit (skill points),
## tab (a tab that shows other trees: the life skills side by side).
const TREES := {
	"base": {"name": "Captain", "tab": "CAPTAIN", "kind": "shared"},
	"unarmed": {"name": "Unarmed", "tab": "UNARMED", "kind": "weapon"},
	"sword": {"name": "Cutlass", "tab": "CUTLASS", "kind": "weapon"},
	"katana": {"name": "Katana", "tab": "KATANA", "kind": "weapon"},
	"axe": {"name": "Axe", "tab": "AXE", "kind": "weapon"},
	"dagger": {"name": "Dagger", "tab": "DAGGER", "kind": "weapon"},
	"dual": {"name": "Dual Wield", "tab": "DUAL", "kind": "weapon"},
	"dual_dagger": {"name": "Twin Daggers", "tab": "2 DAGGERS", "kind": "weapon"},
	"corsair": {"name": "Corsair", "tab": "CORSAIR", "kind": "weapon"},
	"pistol": {"name": "Pistol", "tab": "PISTOL", "kind": "weapon"},
	"life": {"name": "Life Skills", "tab": "LIFE", "kind": "tab"},
	"swim": {"name": "Swimming", "tab": "LIFE", "kind": "life"},
	"sea": {"name": "Seamanship", "tab": "LIFE", "kind": "life"},
	"cook": {"name": "Cooking", "tab": "LIFE", "kind": "life"},
	"fish": {"name": "Fishing", "tab": "LIFE", "kind": "life"},
	"fruit": {"name": "Devil Fruit", "tab": "FRUIT", "kind": "fruit"},
}
const TAB_ORDER := ["base", "unarmed", "sword", "katana", "axe", "dagger", "dual", "dual_dagger", "corsair", "pistol", "life", "fruit"]
const LIFE_SKILLS := ["swim", "sea", "cook", "fish"]

## Fighting style (Player.style()) -> the weapon tree it builds mastery in.
const STYLE_TREE := {"fist": "unarmed", "sword": "sword", "katana": "katana", "axe": "axe", "dagger": "dagger",
	"dual_sword": "dual", "dual_dagger": "dual_dagger", "sword_pistol": "corsair", "pistol": "pistol", "dual_pistol": "pistol"}

const REGION_COLORS := {
	"Core": Color(0.85, 0.78, 0.6), "Mobility": Color(0.45, 0.85, 0.95), "Survival": Color(0.5, 0.9, 0.45),
	"Armament": Color(0.6, 0.45, 0.85), "Observation": Color(0.95, 0.5, 0.75), "Conqueror": Color(0.95, 0.3, 0.3),
	"Seafarer": Color(0.4, 0.75, 0.95),
	"Unarmed": Color(1.0, 0.85, 0.6), "Cutlass": Color(0.85, 0.85, 0.95), "Katana": Color(0.7, 0.85, 1.0),
	"Axe": Color(1.0, 0.7, 0.45), "Dual Wield": Color(0.55, 0.85, 1.0), "Dagger": Color(1.0, 0.45, 0.58), "Twin Daggers": Color(0.6, 1.0, 0.45), "Corsair": Color(1.0, 0.5, 0.42), "Pistol": Color(0.95, 0.75, 0.4),
	"Ember": Color(1.0, 0.5, 0.15), "Wolf": Color(0.7, 0.62, 0.5), "Vine": Color(0.45, 0.85, 0.3),
	"Seamanship": Color(0.45, 0.8, 0.9), "Swimming": Color(0.4, 0.7, 1.0), "Cooking": Color(1.0, 0.72, 0.4), "Fishing": Color(0.55, 0.9, 0.75),
}

## Direction (degrees, screen space: 90 = down) each base-tree region grows in.
const REGION_ANGLE := {"Mobility": -135.0, "Survival": -45.0, "Observation": 45.0, "Armament": 135.0, "Conqueror": 90.0, "Seafarer": 180.0}

static var _nodes: Dictionary = {}
static var _tree: String = "base"


static func nodes() -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _nodes


static func get_node_def(id: String) -> Dictionary:
	return nodes().get(id, {})


static func style_tree(style: String) -> String:
	return str(STYLE_TREE.get(style, ""))


static func kind_of(tree: String) -> String:
	return str(TREES.get(tree, {}).get("kind", ""))


## A tree with a mastery track (a weapon or a life skill).
static func is_mastery_tree(tree: String) -> bool:
	return kind_of(tree) in ["weapon", "life"]


static func is_weapon_tree(tree: String) -> bool:
	return kind_of(tree) == "weapon"


static func is_life_tree(tree: String) -> bool:
	return kind_of(tree) == "life"


## The tab a tree's nodes show on.
static func tab_of(tree: String) -> String:
	return "life" if is_life_tree(tree) else tree


## The trees a tab shows.
static func tab_trees(tab: String) -> Array:
	return LIFE_SKILLS if tab == "life" else [tab]


## No weapon families since 1.18.2 (no carry-over); the old skill map still asks.
static func kin_of(_tree_id: String) -> Array:
	return []


static func families_of(_tree_id: String) -> Array:
	return []


## Owned from the start: the Origin and every weapon and life skill's root.
static func starting_nodes() -> Array:
	var out: Array = []
	for k in nodes().keys():
		var n: Dictionary = nodes()[k]
		if n["kind"] == "origin" or (n["kind"] == "root" and is_mastery_tree(str(n["tree"]))):
			out.append(k)
	return out


## A life skill's milestone perks in mastery order: [[level, node id], ...].
static func perks_of(tree: String) -> Array:
	var out: Array = []
	for k in nodes().keys():
		var n: Dictionary = nodes()[k]
		if n["tree"] == tree and n["kind"] == "perk":
			out.append([int(n["req"]["mastery"]), k])
	out.sort()
	return out


static func root_of(tree: String) -> String:
	for k in nodes().keys():
		var n: Dictionary = nodes()[k]
		if n["tree"] == tree and n["kind"] in ["origin", "root"] and tree != "fruit":
			return k
	return ""


static func _p(angle_deg: float, r: float, off_deg: float = 0.0) -> Vector2:
	var a := deg_to_rad(angle_deg + off_deg)
	return Vector2(cos(a), sin(a)) * r


## Costs (unless given): a stat or passive 2, an active 2, an ultimate 4 (a Devil Fruit's tree keeps its own: 1, 2, 3).
static func _add(id: String, name_: String, kind: String, region: String, pos: Vector2, links: Array,
		effects: Dictionary = {}, desc: String = "", req: Dictionary = {}, skill: String = "", cost: int = -1) -> void:
	var c := cost
	if c < 0:
		if _tree == "fruit":
			c = 2 if kind == "active" else (3 if kind == "ult" else 1)
		else:
			c = {"move": 1, "ult": 4}.get(kind, 2)
		if kind in ["origin", "root"]:
			c = 0
	_nodes[id] = {"id": id, "name": name_, "kind": kind, "tree": _tree, "region": region, "pos": pos, "links": links,
		"effects": effects, "desc": desc, "req": req, "skill": skill, "cost": c}


static func _build() -> void:
	_nodes = {}
	_build_life()
	_merge_new()


## The redesigned trees' nodes (SkillTrees), in this registry's shape too, so the readers of both see them.
static func _merge_new() -> void:
	var st := SkillTrees.nodes()
	for k in st.keys():
		var n: Dictionary = st[k].duplicate()
		n["region"] = str(SkillTrees.tree_def(str(n["tree"]))["name"])
		n["req"] = {}
		n["cost"] = 0
		n["new"] = true
		_nodes[k] = n


## Life skills, side by side on the LIFE tab: each is learned by doing (Progression.add_life) and its perks
## come by themselves at mastery milestones (a "perk" node, req {"mastery": level}), no points spent.
## Seamanship (scripts/ship/seamanship.gd): sailing at the helm, hitting ships with her guns, repairs and
## pumping, ships sunk near you. Its perks are station bonuses, each counting only while you man that
## station: helm_speed / helm_turn (her top speed and turning while you steer), helm_flood (less of
## flooding's slowdown, steering), gun_reload (a gun you man), gun_dmg (balls you fire), repair (patching,
## dousing), pump (bailing), capstan (the anchor), lookout (m: sails and salvage on your compass aboard),
## crew (the rest half again while a crewmate mans another station).
## Cooking keys (meal_time_pct, meal_power_pct) are read by Food; fishing's (fish_bite_pct, fish_reel_pct,
## fish_bait_save, fish_rare_pct, fish_double, fish_legend) by Fishing.
static func _life_root(tree: String, col: int, name_: String, region: String, desc: String) -> void:
	_tree = tree
	_add(tree + "_root", name_, "root", region, Vector2((col - 1.5) * 225.0 - 40.0, 0.0), [], {}, desc)


static func _perk(id: String, name_: String, region: String, lv: int, row: int, link: String, effects: Dictionary, desc: String) -> void:
	var root: Vector2 = _nodes[_tree + "_root"]["pos"]
	_add(id, name_, "perk", region, root + Vector2(0.0, -row * 50.0), [link], effects, desc, {"mastery": lv}, "", 0)


static func _build_life() -> void:
	_life_root("swim", 0, "Swimming", "Swimming", "Swim to build it: every stretch of open water you cross counts. Its perks come by themselves as it grows.")
	_perk("sw_strokes", "Strong Strokes", "Swimming", 2, 1, "swim_root", {"swim_pct": 0.1}, "You swim 10% faster.")
	_perk("sw_lungs", "Deep Lungs", "Swimming", 4, 2, "sw_strokes", {"max_stamina": 10.0, "breath_pct": 0.5},
		"You hold your breath half as long again on a dive, and +10 max stamina.")
	_perk("sw_born", "Sea Born", "Swimming", 7, 3, "sw_lungs", {"swim_pct": 0.15}, "You swim another 15% faster.")
	_perk("sw_wind", "Second Wind", "Swimming", 10, 4, "sw_born", {"stamina_regen_pct": 0.1, "breath_refill_pct": 1.0},
		"Stamina refills 10% faster, and your breath comes back twice as fast at the surface.")
	_perk("sw_child", "Child of the Sea", "Swimming", 15, 5, "sw_wind", {"swim_pct": 0.15, "max_stamina": 15.0, "breath_pct": 0.5, "sea_resist": 0.5},
		"You swim another 15% faster, hold your breath longer still, +15 max stamina, and currents, surf, swell and cold have half the hold on you.")

	_life_root("sea", 1, "Seamanship", "Seamanship", "Sail her, fight her guns and keep her afloat to build it. Its perks count at the station you're manning: the helm, a gun, the pump, a hole or a fire.")
	_perk("sea_hand", "Sea Hand", "Seamanship", 2, 1, "sea_root", {"helm_speed": 0.04, "repair": 0.3},
		"At the helm she sails 4% faster, and you patch holes and beat out fires 30% faster.")
	_perk("sea_gunner", "Gun Captain", "Seamanship", 4, 2, "sea_hand", {"gun_reload": 0.15, "gun_dmg": 0.1},
		"A gun you man reloads 15% faster, and its balls hit 10% harder.")
	_perk("sea_turn", "Hard Over", "Seamanship", 7, 3, "sea_gunner", {"helm_turn": 0.08, "pump": 0.4, "capstan": 1.0},
		"At the helm she turns 8% sharper; you bail 40% more and work the capstan twice as fast.")
	_perk("sea_storm", "Storm Sailing", "Seamanship", 10, 4, "sea_turn", {"helm_flood": 0.4, "lookout": 200.0},
		"At the helm water in her costs 40% less of her speed, and aboard, sails and salvage within 200 m show on your compass.")
	_perk("sea_broad", "Broadside Master", "Seamanship", 15, 5, "sea_storm", {"gun_reload": 0.15, "gun_dmg": 0.15, "helm_speed": 0.05},
		"Another 15% faster reload, balls 15% harder, and she sails another 5% faster for you.")
	_perk("sea_crew", "Bosun", "Seamanship", 20, 6, "sea_broad", {"crew": 0.5, "repair": 0.3, "pump": 0.3},
		"Your station bonuses count half again while a crewmate mans another station, and you mend and bail faster still.")

	_life_root("cook", 2, "Cooking", "Cooking", "Cook at a galley to build it. Its perks come by themselves as it grows.")
	_perk("ck_hand", "Galley Hand", "Cooking", 2, 1, "cook_root", {"potion_pct": 0.1}, "Food and drink heal you 10% more.")
	_perk("ck_ship", "Ship's Cook", "Cooking", 5, 2, "ck_hand", {"meal_time_pct": 0.25}, "Galley meals last 25% longer.")
	_perk("ck_stomach", "Iron Gut", "Cooking", 10, 3, "ck_ship", {"potion_pct": 0.2}, "Food and drink heal you another 20% more.")
	_perk("ck_chef", "Master Chef", "Cooking", 15, 4, "ck_stomach", {"meal_power_pct": 0.2}, "Galley meals' buffs are 20% stronger.")

	_life_root("fish", 3, "Fishing", "Fishing", "Fish to build it. Its perks come by themselves as it grows.")
	_perk("fs_patient", "Patient Line", "Fishing", 2, 1, "fish_root", {"fish_bite_pct": 0.2}, "Fish bite 20% sooner.")
	_perk("fs_hands", "Steady Hands", "Fishing", 5, 2, "fs_patient", {"fish_reel_pct": 0.25}, "The float stays down 25% longer: more time to reel in a bite.")
	_perk("fs_saver", "Bait Saver", "Fishing", 8, 3, "fs_hands", {"fish_bait_save": 0.3}, "30% of your catches leave the bait on the hook.")
	_perk("fs_lore", "Sea Lore", "Fishing", 10, 4, "fs_saver", {"fish_rare_pct": 0.2}, "Rarer fish bite 20% more often.")
	_perk("fs_salt", "Old Salt", "Fishing", 15, 5, "fs_lore", {"fish_double": 0.15}, "15% of your catches come up two at once.")
	_perk("fs_master", "Master Angler", "Fishing", 20, 6, "fs_salt", {"fish_legend": 1.0, "fish_reel_pct": 0.15},
		"Legendary fish come twice as often, and the float stays down another 15% longer.")


## Nodes linked to `id` (links are stored on one side; this makes them two-way).
static func neighbors(id: String) -> Array:
	var out: Array = []
	var n := get_node_def(id)
	for l in n.get("links", []):
		out.append(l)
	for k in nodes().keys():
		if id in nodes()[k]["links"] and not (k in out):
			out.append(k)
	return out


## The node that teaches a skill.
static func node_for_skill(skill_id: String) -> String:
	for k in nodes().keys():
		if nodes()[k]["skill"] == skill_id:
			return k
	return ""
