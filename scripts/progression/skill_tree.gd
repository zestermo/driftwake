class_name SkillTree
extends RefCounted
## The old skill-tree registry's readers, over SkillTrees (the v1.18.2 redesign): every tree's nodes are SkillTrees',
## shown here in the old shape ("new": true, "req" {}, "cost" 0, "region" the tree's name) so `nodes()`,
## `get_node_def()`, `node_for_skill()` and the old skill map keep working. Also the fighting style -> weapon tree map.
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

## The old skill map's tabs (kind: shared, weapon, life, tab, fruit).
const TREES := {
	"base": {"name": "Captain", "tab": "CAPTAIN", "kind": "shared"},
	"unarmed": {"name": "Unarmed", "tab": "UNARMED", "kind": "weapon"},
	"black_leg": {"name": "Black Leg", "tab": "BLACK LEG", "kind": "weapon"},
	"sword": {"name": "Cutlass", "tab": "CUTLASS", "kind": "weapon"},
	"katana": {"name": "Katana", "tab": "KATANA", "kind": "weapon"},
	"axe": {"name": "Axe", "tab": "AXE", "kind": "weapon"},
	"dagger": {"name": "Dagger", "tab": "DAGGER", "kind": "weapon"},
	"dual": {"name": "Dual Wield", "tab": "DUAL", "kind": "weapon"},
	"dual_dagger": {"name": "Twin Daggers", "tab": "2 DAGGERS", "kind": "weapon"},
	"polearm": {"name": "Polearm", "tab": "POLEARM", "kind": "weapon"},
	"hammer": {"name": "Hammer", "tab": "HAMMER", "kind": "weapon"},
	"dual_axe": {"name": "Twin Axes", "tab": "2 AXES", "kind": "weapon"},
	"greatsword": {"name": "Greatsword", "tab": "GREATSWORD", "kind": "weapon"},
	"corsair": {"name": "Corsair", "tab": "CORSAIR", "kind": "weapon"},
	"pistol": {"name": "Pistol", "tab": "PISTOL", "kind": "weapon"},
	"long_gun": {"name": "Long Gun", "tab": "LONG GUN", "kind": "weapon"},
	"life": {"name": "Life Skills", "tab": "LIFE", "kind": "tab"},
	"swim": {"name": "Swimming", "tab": "LIFE", "kind": "life"},
	"sea": {"name": "Sailing", "tab": "LIFE", "kind": "life"},
	"cook": {"name": "Cooking", "tab": "LIFE", "kind": "life"},
	"fish": {"name": "Fishing", "tab": "LIFE", "kind": "life"},
	"fruit": {"name": "Driftfruit", "tab": "FRUIT", "kind": "fruit"},
}
const TAB_ORDER := ["base", "unarmed", "black_leg", "sword", "katana", "axe", "dagger", "dual", "dual_dagger", "polearm", "hammer", "dual_axe", "greatsword", "corsair", "pistol", "long_gun", "life", "fruit"]
const LIFE_SKILLS := ["swim", "sea", "cook", "fish"]

## Fighting style (Player.style()) -> the weapon tree it builds mastery in.
const STYLE_TREE := {"fist": "unarmed", "sword": "sword", "katana": "katana", "axe": "axe", "dagger": "dagger",
	"dual_sword": "dual", "dual_dagger": "dual_dagger", "sword_pistol": "corsair", "pistol": "pistol", "dual_pistol": "pistol", "polearm": "polearm",
	"hammer": "hammer", "dual_axe": "dual_axe", "greatsword": "greatsword", "black_leg": "black_leg", "long_gun": "long_gun"}

const REGION_COLORS := {
	"Core": Color(0.85, 0.78, 0.6), "Mobility": Color(0.45, 0.85, 0.95), "Survival": Color(0.5, 0.9, 0.45),
	"Armament": Color(0.6, 0.45, 0.85), "Observation": Color(0.95, 0.5, 0.75), "Conqueror": Color(0.95, 0.3, 0.3),
	"Seafarer": Color(0.4, 0.75, 0.95),
	"Unarmed": Color(1.0, 0.85, 0.6), "Black Leg": Color(1.0, 0.45, 0.35), "Cutlass": Color(0.85, 0.85, 0.95), "Katana": Color(0.7, 0.85, 1.0),
	"Axe": Color(1.0, 0.7, 0.45), "Dual Wield": Color(0.55, 0.85, 1.0), "Dagger": Color(1.0, 0.45, 0.58), "Twin Daggers": Color(0.6, 1.0, 0.45), "Polearm": Color(1.0, 0.9, 0.4), "Hammer": Color(0.88, 0.74, 0.54), "Twin Axes": Color(0.8, 0.88, 1.0), "Greatsword": Color(0.72, 0.95, 0.84), "Corsair": Color(1.0, 0.5, 0.42), "Pistol": Color(0.95, 0.75, 0.4), "Long Gun": Color(0.74, 0.84, 1.0),
	"Ember": Color(1.0, 0.5, 0.15), "Wolf": Color(0.7, 0.62, 0.5), "Vine": Color(0.45, 0.85, 0.3),
	"Seamanship": Color(0.45, 0.8, 0.9), "Swimming": Color(0.4, 0.7, 1.0), "Cooking": Color(1.0, 0.72, 0.4), "Fishing": Color(0.55, 0.9, 0.75),
}

## Direction (degrees, screen space: 90 = down) each old base-tree region grew in (the old map still draws them).
const REGION_ANGLE := {"Mobility": -135.0, "Survival": -45.0, "Observation": 45.0, "Armament": 135.0, "Conqueror": 90.0, "Seafarer": 180.0}

static var _nodes: Dictionary = {}


static func nodes() -> Dictionary:
	if _nodes.is_empty():
		var st := SkillTrees.nodes()
		for k in st.keys():
			var n: Dictionary = st[k].duplicate()
			n["region"] = str(SkillTrees.tree_def(str(n["tree"]))["name"])
			n["req"] = {}
			n["cost"] = 0
			n["new"] = true
			_nodes[k] = n
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


## Owned from the start: every weapon and life skill's root (Progression adds the other trees' roots).
static func starting_nodes() -> Array:
	var out: Array = []
	for k in nodes().keys():
		var n: Dictionary = nodes()[k]
		if n["kind"] == "root" and is_mastery_tree(str(n["tree"])):
			out.append(k)
	return out


## No milestone perks since 1.18.2 (a life skill's nodes come at their level); the old skill map still asks.
static func perks_of(_tree_id: String) -> Array:
	return []


static func root_of(tree: String) -> String:
	return str(SkillTrees.tree_def("captain" if tree == "base" else tree).get("root", ""))


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
	return SkillTrees.node_for_skill(skill_id)
