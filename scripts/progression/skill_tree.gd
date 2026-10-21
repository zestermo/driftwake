class_name SkillTree
extends RefCounted
## The old skill-tree registry, kept while its last trees move to SkillTrees (the v1.18.2 redesign):
##   base     the Captain (paid with level skill points): the body's stats in a ring round the middle; Mobility,
##            Survival, the Seafarer (gated on the life skills), Armament and Observation Haki (level 10+) and
##            Conqueror's Haki (level 18+) grow out of it
##   life     the life skills side by side (swim, sea = Seamanship, cook, fish): learned by doing,
##            their perks come by themselves at mastery milestones
##   fruit    your Devil Fruit (only once you've eaten one)
## The weapon trees are SkillTrees' now; `nodes()` merges SkillTrees' nodes in this shape ("new": true), so a
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
	_build_base()
	_build_life()
	_build_fruits()
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


static func _build_base() -> void:
	_tree = "base"
	_add("origin", "Pirate's Spirit", "origin", "Core", Vector2.ZERO, [], {}, "Where every captain starts. Learn the nodes linked to the ones you own.")
	# ---- the body: a ring of eight round the middle, each opening a region ----
	var ring := [
		[-135.0, "c_agility", "Agility", {"move_pct": 0.06, "sprint_pct": 0.08}, "+6% movement speed, +8% sprint speed."],
		[-90.0, "c_endurance", "Endurance", {"max_stamina": 25.0, "stamina_regen_pct": 0.1}, "+25 max stamina, and it refills 10% faster."],
		[-45.0, "c_vitality", "Vitality", {"max_hp": 35.0}, "+35 max health."],
		[0.0, "c_focus", "Focus", {"ult_charge_pct": 0.15, "xp_pct": 0.1}, "Your ultimate charges 15% faster, and you win 10% more experience from every fight."],
		[45.0, "c_toughness", "Toughness", {"defense": 6.0}, "+6 defense."],
		[90.0, "c_strength", "Strength", {"damage_pct": 0.1}, "+10% damage with everything."],
		[135.0, "c_spirit", "Spirit", {"max_energy": 25.0, "energy_regen_pct": 0.12}, "+25 max energy, and it refills 12% faster."],
		[180.0, "c_legs", "Sea Legs", {"stamina_regen_pct": 0.1, "swim_pct": 0.1}, "Stamina refills 10% faster and you swim 10% faster. Opens the Seafarer's nodes, which grow with your life skills."],
	]
	for d in ring:
		_add(d[1], d[2], "stat", "Core", _p(d[0], 90.0), ["origin"], d[3], d[4])
	_add("c_quarter", "Quartermaster", "passive", "Core", _p(0.0, 175.0), ["c_focus"], {"loadout_slots": 1},
		"A third weapon loadout on the loadout wheel (X): three setups to swap between mid-fight.", {"level": 3})

	# ---- Mobility ----
	var A: float = REGION_ANGLE["Mobility"]
	_add("m_geppo", "Geppo", "passive", "Mobility", _p(A, 175.0), ["c_agility"], {"air_jumps": 1},
		"Kick off the air itself: a second jump in mid-air.")
	_add("m_soru", "Soru", "active", "Mobility", _p(A, 255.0, -12.0), ["m_geppo"], {}, "", {}, "soru")
	_add("m_swift", "Swift Step", "passive", "Mobility", _p(A, 255.0, 12.0), ["m_geppo"], {"dodge_cost_pct": 0.4, "dodge_dist_pct": 0.3, "dodge_iframe_pct": 0.5},
		"Your dodge costs 40% less stamina, carries you 30% further and leaves you untouchable 50% longer.", {"level": 4})
	_add("m_skywalk", "Sky Walk", "passive", "Mobility", _p(A, 335.0, -10.0), ["m_soru"], {"air_jumps": 1, "featherfall": 1},
		"One more jump in mid-air (three in all), and falls hurt a quarter as much with no stumble on landing.", {"level": 4})
	_add("m_sprinter", "Long Stride", "passive", "Mobility", _p(A, 335.0, 10.0), ["m_swift"], {"sprint_cost_pct": 0.35, "sprint_pct": 0.1},
		"Sprinting burns 35% less stamina and you sprint 10% faster.")

	# ---- Survival ----
	A = REGION_ANGLE["Survival"]
	_add("v_hardy", "Hardy", "stat", "Survival", _p(A, 175.0), ["c_vitality"], {"max_hp": 25.0, "defense": 4.0}, "+25 max health, +4 defense.")
	_add("v_tekkai", "Tekkai", "active", "Survival", _p(A, 255.0, -12.0), ["v_hardy"], {}, "", {}, "tekkai")
	_add("v_steadfast", "Steadfast", "passive", "Survival", _p(A, 255.0, 12.0), ["v_hardy"], {"steadfast": 1},
		"Light hits no longer make you flinch.")
	_add("v_iron", "Iron Hide", "stat", "Survival", _p(A, 335.0, -12.0), ["v_tekkai"], {"defense": 10.0}, "+10 defense.", {"level": 5})
	_add("v_mend", "Mend", "passive", "Survival", _p(A, 335.0, 12.0), ["v_steadfast"], {"regen_hp": 2.5},
		"Out of combat (no damage for 5 s) you heal 2.5 health a second.")
	_add("v_adren", "Adrenaline", "passive", "Survival", _p(A, 415.0, -17.0), ["v_iron"], {"adrenaline": 0.25},
		"Below 35% health you hit 25% harder.", {"level": 5})
	_add("v_stomach", "Iron Stomach", "passive", "Survival", _p(A, 415.0, 17.0), ["v_mend"], {"potion_pct": 0.4},
		"Food and drink heal you 40% more.")
	_add("v_last", "Last Stand", "passive", "Survival", _p(A, 415.0), ["v_adren", "v_stomach"], {"last_stand": 1},
		"Once a minute, a blow that would kill you leaves you at 1 health instead.", {"level": 6}, "", 3)

	# ---- the Seafarer (each node needs a life skill) ----
	A = REGION_ANGLE["Seafarer"]
	_add("f_swim", "Sea Born", "passive", "Seafarer", _p(A, 175.0, -14.0), ["c_legs"], {"swim_pct": 0.25},
		"You swim 25% faster.", {"life": "swim", "life_lv": 4})
	_add("f_helm", "Helmsman", "passive", "Seafarer", _p(A, 175.0, 14.0), ["c_legs"], {"helm_speed": 0.06, "helm_turn": 0.1},
		"At the helm she sails 6% faster and turns 10% sharper.", {"life": "sea", "life_lv": 5})

	# ---- Haki (level-gated) ----
	A = REGION_ANGLE["Armament"]
	_add("h_arm", "Armament Haki", "passive", "Armament", _p(A, 175.0), ["c_spirit"], {"armament": 1, "damage_pct": 0.08},
		"Will made armor: +8% damage, and your heavy attacks can't be blocked.", {"level": 10})
	_add("h_coat", "Armament: Coat", "active", "Armament", _p(A, 255.0), ["h_arm"], {}, "", {"level": 12}, "armament_coat")
	_add("h_harden", "Hardening", "stat", "Armament", _p(A, 335.0, -10.0), ["h_coat"], {"defense": 8.0, "energy_regen_pct": 0.2},
		"Haki under the skin: +8 defense, and energy refills 20% faster.", {"level": 12})
	_add("h_black", "Black Fists", "stat", "Armament", _p(A, 335.0, 10.0), ["h_coat"], {"dmg_unarmed": 0.15},
		"Your bare fists are iron: +15% unarmed damage.", {"level": 14})
	A = REGION_ANGLE["Observation"]
	_add("h_obs", "Observation Haki", "passive", "Observation", _p(A, 175.0), ["c_toughness"], {"observation": 1},
		"Sense intent: enemies flash red the moment they start an attack, and your parry window is a little wider.", {"level": 10})
	_add("h_fore", "Foresight", "active", "Observation", _p(A, 255.0), ["h_obs"], {}, "", {"level": 12}, "foresight")
	_add("h_instinct", "Instinct", "passive", "Observation", _p(A, 335.0, -10.0), ["h_fore"], {"evade_chance": 0.08, "parry_all": 0.04},
		"8% of the blows that would hit you are sidestepped on instinct, and your parry window is wider still.", {"level": 12})
	_add("h_weak", "Weak Points", "passive", "Observation", _p(A, 335.0, 10.0), ["h_fore"], {"crit_all": 0.06},
		"You see where to strike: 6% more of your hits land 50% harder.", {"level": 14})
	A = REGION_ANGLE["Conqueror"]
	_add("h_will", "King's Will", "passive", "Conqueror", _p(A, 195.0), ["c_strength"], {"damage_pct": 0.06, "max_hp": 20.0},
		"A will that bends others: +6% damage, +20 max health.", {"level": 18})
	_add("h_conq", "Conqueror's Haki", "ult", "Conqueror", _p(A, 285.0), ["h_will"], {}, "", {"level": 20}, "conquerors_haki")


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


## Devil Fruits (only the one you've eaten shows; its root comes with the fruit).
static func _build_fruits() -> void:
	_tree = "fruit"
	var A := 90.0
	var root := _p(A, 190.0)
	# Ember (Logia)
	_add("e_root", "Ember Fruit (Logia)", "root", "Ember", root, [], {},
		"Logia: your body is fire. Your dodge turns you to flame - fully untouchable, passing straight through enemies and gunfire.", {"fruit": "ember"})
	_add("e_fist", "Fire Fist", "active", "Ember", _p(A, 265.0, -16.0), ["e_root"], {}, "", {"fruit": "ember"}, "fire_fist", 0)
	_add("e_ring", "Blazing Ring", "active", "Ember", _p(A, 265.0, 16.0), ["e_root"], {}, "", {"fruit": "ember"}, "fire_ring", 0)
	_add("e_kindled", "Kindled Blade", "passive", "Ember", _p(A, 330.0, -26.0), ["e_fist"], {"kindled_blade": 1},
		"Every melee hit sears: the target burns for a moment.", {"fruit": "ember"})
	_add("e_dash", "Flame Dash", "active", "Ember", _p(A, 345.0, -9.0), ["e_fist"], {}, "", {"fruit": "ember", "level": 3}, "flame_dash")
	_add("e_field", "Ember Field", "active", "Ember", _p(A, 345.0, 9.0), ["e_ring"], {}, "", {"fruit": "ember", "level": 3}, "ember_field")
	_add("e_smolder", "Smoldering Body", "passive", "Ember", _p(A, 330.0, 26.0), ["e_ring"], {"smoldering": 1},
		"Your flame-form dodge leaves burning embers behind.", {"fruit": "ember"})
	_add("e_heat", "Searing Heat", "stat", "Ember", _p(A, 420.0, -8.0), ["e_dash", "e_field"], {"fire_pct": 0.15},
		"+15% fire damage.", {"fruit": "ember"})
	_add("e_inferno", "Great Inferno", "ult", "Ember", _p(A, 495.0), ["e_heat"], {}, "", {"fruit": "ember", "level": 8}, "inferno", 3)
	# Wolf (Zoan)
	_add("z_root", "Wolf Fruit (Zoan)", "root", "Wolf", root, [], {},
		"Zoan: press V to shift between your human and hybrid wolf form. Hybrid: claws instead of weapons, 25% more damage and 15% faster.", {"fruit": "wolf"})
	_add("z_fang", "Rending Fang", "active", "Wolf", _p(A, 265.0, -16.0), ["z_root"], {}, "", {"fruit": "wolf"}, "rending_fang", 0)
	_add("z_pounce", "Pounce", "active", "Wolf", _p(A, 265.0, 16.0), ["z_root"], {}, "", {"fruit": "wolf"}, "pounce", 0)
	_add("z_pelt", "Thick Pelt", "passive", "Wolf", _p(A, 345.0, -10.0), ["z_fang"], {"hybrid_defense": 8.0},
		"+8 defense in hybrid form.", {"fruit": "wolf"})
	_add("z_hunt", "Predator", "passive", "Wolf", _p(A, 345.0, 10.0), ["z_pounce"], {"hybrid_speed_pct": 0.1},
		"Hybrid form is another 10% faster.", {"fruit": "wolf"})
	_add("z_howl", "Alpha Howl", "active", "Wolf", _p(A, 420.0), ["z_pelt", "z_hunt"], {}, "", {"fruit": "wolf", "level": 4}, "howl")
	# Vine (Paramecia)
	_add("p_root", "Vine Fruit (Paramecia)", "root", "Vine", root, [], {},
		"Paramecia: Photosynthesis - out of combat you slowly heal and regain energy while on land.", {"fruit": "vine"})
	_add("p_snare", "Vine Snare", "active", "Vine", _p(A, 265.0, -16.0), ["p_root"], {}, "", {"fruit": "vine"}, "vine_snare", 0)
	_add("p_swing", "Vine Swing", "active", "Vine", _p(A, 265.0, 16.0), ["p_root"], {}, "", {"fruit": "vine"}, "vine_swing", 0)
	_add("p_roots", "Deep Roots", "passive", "Vine", _p(A, 345.0, -10.0), ["p_snare"], {"photo_mult": 1.0},
		"Photosynthesis works twice as fast.", {"fruit": "vine"})
	_add("p_thorns", "Thorn Hide", "passive", "Vine", _p(A, 345.0, 10.0), ["p_swing"], {"thorn_hide": 6.0},
		"Enemies that hit you in melee take 6 damage from your thorns.", {"fruit": "vine"})
	_add("p_whip", "Thorn Whip", "active", "Vine", _p(A, 420.0), ["p_roots", "p_thorns"], {}, "", {"fruit": "vine", "level": 4}, "thorn_whip")


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
