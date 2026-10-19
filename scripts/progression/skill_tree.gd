class_name SkillTree
extends RefCounted
## The skill trees, one tab each on the skill map:
##   base     the Captain (shared by every weapon, paid with level skill points): the body's
##            stats in a ring round the middle; Mobility, Survival, the Seafarer (gated on
##            the life skills), Armament and Observation Haki (level 10+) and Conqueror's
##            Haki (level 18+) grow out of it
##   unarmed, sword (cutlass), katana, axe, dagger, dual, dual_dagger, corsair (sword and pistol), pistol
##            weapon trees, paid for with that weapon's mastery points (earned by fighting
##            with it or a weapon of its family); a few big nodes each: its moveset
##            ("move" nodes), its skills and ultimate, and passives that change how it fights
##   life     the life skills side by side (swim, sea = Seamanship, cook, fish): learned by doing,
##            their perks come by themselves at mastery milestones
##   fruit    your Devil Fruit (only once you've eaten one)
## You can learn any node linked to one you own (if you meet its requirements).
##
## Node: {id, name, kind, tree, region, pos, links, cost, effects, skill, req, desc}
##   kind: origin | root | stat | passive | move | active | ult | perk
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

## kind: shared (paid with level skill points), weapon (paid with its own mastery points, earned by fighting
## with it), life (learned by doing: its perks come by themselves at mastery milestones), fruit (skill points),
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

## Weapon families: mastery earned with one weapon also builds the others of its family
## (Progression.FAMILY_SHARE of it). The Corsair is a cutlass and a pistol, so it's in both.
const FAMILIES := {
	"blades": ["sword", "katana", "dual", "dagger", "dual_dagger", "corsair"],
	"heavy": ["axe"],
	"guns": ["pistol", "corsair"],
	"fists": ["unarmed"],
}

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


## The other weapon trees that share a family with `tree`.
static func kin_of(tree: String) -> Array:
	var out: Array = []
	for f in FAMILIES.keys():
		if tree in FAMILIES[f]:
			for t in FAMILIES[f]:
				if t != tree and not (t in out):
					out.append(t)
	return out


static func families_of(tree: String) -> Array:
	return FAMILIES.keys().filter(func(f): return tree in FAMILIES[f])


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


## Weapon trees sit on a grid growing up from the root: column (100 apart),
## row (72 apart). Skills keep the spot under their name clear.
static func _g(col: float, row: float) -> Vector2:
	return Vector2(col * 100.0, -row * 72.0)


## Costs (unless given): a move 1, a stat or passive 2, an active 2, an ultimate 4 (a Devil Fruit's
## tree keeps its own: 1, 2, 3).
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
	_build_unarmed()
	_build_cutlass()
	_build_katana()
	_build_axe()
	_build_dual()
	_build_dagger()
	_build_dual_dagger()
	_build_corsair()
	_build_pistol()
	_build_life()
	_build_mastery()
	_build_fruits()


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
## Cooking and fishing keys (meal_time_pct, meal_power_pct, fish_bite_pct, fish_reel_pct, fish_rare_pct,
## fish_double) are read by those systems once they exist.
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
	_perk("sw_child", "Child of the Sea", "Swimming", 15, 5, "sw_wind", {"swim_pct": 0.15, "max_stamina": 15.0, "breath_pct": 0.5},
		"You swim another 15% faster, hold your breath longer still, and +15 max stamina.")

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
	_perk("fs_hands", "Steady Hands", "Fishing", 5, 2, "fs_patient", {"fish_reel_pct": 0.25}, "Reeling in is 25% easier.")
	_perk("fs_lore", "Sea Lore", "Fishing", 10, 3, "fs_hands", {"fish_rare_pct": 0.15}, "Rare catches come 15% more often.")
	_perk("fs_salt", "Old Salt", "Fishing", 15, 4, "fs_lore", {"fish_double": 0.15}, "15% of your catches come up two at once.")


## Weapon trees share a shape on the grid: the root at the bottom with the moveset either side of it
## (row 0), defence and grapples up the left (col -2), the stat node and the skills up the middle to the
## top stat and the ultimate, the passives that shape the style up the right (col 2), the element's two
## mastery nodes just left of the skill and the top stat they hang off (col -1).
static func _build_unarmed() -> void:
	_tree = "unarmed"
	var R := "Unarmed"
	_add("u_root", "Unarmed", "root", R, _g(0, 0), [], {},
		"Bare-handed brawling: jab, cross, hook and a flying kick. Fight with your fists to build unarmed mastery.")
	_add("u_round", "Roundhouse", "move", R, _g(-2, 0), ["u_root"], {"mv_roundhouse": 1},
		"Adds a fourth hit to your punch combo: a spinning roundhouse kick.")
	_add("u_meteor", "Meteor Kick", "move", R, _g(2, 0), ["u_root"], {"mv_meteor_kick": 1},
		"Attack in the air: a dive kick at the enemy you're looking at that knocks them flat and bounces you back up for another (three in a row); a miss slams the ground.", {"level": 3})
	_add("u_knuckles", "Iron Knuckles", "stat", R, _g(0, 1), ["u_root"], {"dmg_unarmed": 0.12, "stam_unarmed": 0.2},
		"+12% unarmed damage, and unarmed attacks cost 20% less stamina.")
	# grapples
	_add("u_hip", "Shoulder Throw", "active", R, _g(-2, 1), ["u_round"], {}, "", {}, "hip_toss")
	_add("u_landing", "Heavy Landing", "passive", R, _g(-2, 2), ["u_hip"], {"throw_splash": 1, "skill_unarmed": 0.25},
		"Anyone you throw lands like a cannonball: everyone near where they land is knocked flat and hurt. Your grapples and martial arts hit 25% harder.")
	_add("u_suplex", "Suplex", "active", R, _g(-2, 3), ["u_landing"], {}, "", {}, "suplex")
	_add("u_swing", "Giant Swing", "active", R, _g(-2, 4), ["u_suplex"], {}, "", {"level": 6}, "giant_swing")
	# martial arts
	_add("u_palm", "Shockwave Palm", "active", R, _g(0, 2), ["u_knuckles"], {}, "", {}, "palm_strike")
	_add("u_dragon", "Rising Dragon", "active", R, _g(0, 3), ["u_palm"], {}, "", {}, "rising_dragon")
	_add("u_hundred", "Hundred Fists", "active", R, _g(0, 4), ["u_dragon"], {}, "", {"level": 4}, "hundred_fists")
	_add("u_thousand", "Thousand Fists", "stat", R, _g(0, 5), ["u_hundred", "u_finish"], {"dmg_unarmed": 0.18, "crit_unarmed": 0.12},
		"+18% unarmed damage, and 12% of your unarmed hits land 50% harder.", {"level": 10}, "", 3)
	_add("u_seaking", "Sea King Fist", "ult", R, _g(0, 6), ["u_thousand"], {}, "", {"level": 12}, "sea_king_fist")
	# body
	_add("u_ironbody", "Iron Body", "passive", R, _g(2, 1), ["u_meteor", "u_knuckles"], {"def_unarmed": 8.0, "parry_unarmed": 0.06},
		"Fighting bare-handed: +8 defense and a wider parry window.")
	_add("u_chi", "Chi", "passive", R, _g(2, 2), ["u_ironbody"], {"flow_unarmed": 0.5, "leech_unarmed": 0.06},
		"Unarmed hits give 50% more energy and heal you for 6% of their damage.")
	_add("u_finish", "Finishing Blow", "passive", R, _g(2, 3), ["u_chi"], {"finisher_unarmed": 0.4, "cdr_unarmed": 0.2},
		"The last hit of your combo lands 40% harder, and unarmed techniques come back 20% sooner.")


## Each weapon's element, awakened by two mastery passives: the first shows it
## on the tree's skills and ultimate, the second on every blow. Each sits just
## left of the node it hangs off: the first by a skill, the second by the top stat.
## tree: [prefix, region, link 1, link 2, name 1, name 2, element (for the text)]
const MASTERY := {
	"sword": ["s", "Cutlass", "s_flying", "s_captain", "Call of the Tide", "Tidewalker", "the sea: spray and foam, and Kraken's Wake raises the deep under your foes"],
	"katana": ["k", "Katana", "k_tiger", "k_saint", "Falling Petals", "Blossom Path", "pale steel light and falling petals"],
	"axe": ["a", "Axe", "a_overhead", "a_warlord", "Ember Heart", "Living Fire", "embers and splintered stone"],
	"dual": ["d", "Dual Wield", "d_dance", "d_master", "Twin Currents", "Crossing Storm", "twin currents of light, cyan and violet, crossing in an X"],
	"corsair": ["cs", "Corsair", "cs_grape", "cs_captain", "Black Powder", "Powder Keg", "black powder: scarlet flashes, gold sparks and dark smoke, and Broadside's cannon fire burns"],
	"dagger": ["dg", "Dagger", "dg_fan", "dg_night", "Nightfall", "Blood Moon", "shadow: black wisps off the blade and crimson sparks, and Red Eclipse's wounds open in the dark"],
	"dual_dagger": ["dd", "Twin Daggers", "dd_viper", "dd_master", "Viper's Kiss", "Serpent's Coil", "venom: green motes and poison bubbling off every wound"],
	"pistol": ["g", "Pistol", "g_storm", "g_legend", "Golden Powder", "Gilded Gun", "gold flashes and powder smoke"],
	"unarmed": ["u", "Unarmed", "u_palm", "u_thousand", "Rushing Wind", "Gale Fists", "rushing wind and rings of air"],
}

static func _build_mastery() -> void:
	for tr in MASTERY.keys():
		var m: Array = MASTERY[tr]
		_tree = tr
		var p: String = m[0]
		var left := Vector2(-100.0, 0.0)
		_add(p + "_elem", m[4], "passive", m[1], _nodes[m[2]]["pos"] + left, [m[2]], {"elem_" + tr: 1},
			"Mastery. Your %s skills awaken: %s." % [str(m[1]).to_lower(), m[6]], {"level": 8}, "", 2)
		_add(p + "_elem2", m[5], "passive", m[1], _nodes[m[3]]["pos"] + left, [m[3]], {"elem2_" + tr: 1},
			"Mastery. The element follows every blow: your %s combo and heavy attack carry it too." % str(m[1]).to_lower(),
			{"level": 16, "node": p + "_elem"}, "", 3)


static func _build_cutlass() -> void:
	_tree = "sword"
	var R := "Cutlass"
	_add("s_root", "Cutlass", "root", R, _g(0, 0), [], {},
		"The pirate's blade: quick cuts and a lunging thrust. Fight with a cutlass (or any blade, a little) to build its mastery.")
	_add("s_dash", "Running Cut", "move", R, _g(-2, 0), ["s_root"], {"mv_dash_cut": 1},
		"Attack at a sprint: one low cut driving through the target, breaking its wind-up.")
	_add("s_dive", "Boarding Dive", "move", R, _g(2, 0), ["s_root"], {"mv_boarding_dive": 1},
		"Attack in the air: the blade drawn back, then a point-first dive at the enemy you're looking at and a backflip off them (once per jump).", {"level": 3})
	_add("s_edge", "Keen Edge", "stat", R, _g(0, 1), ["s_root"], {"dmg_sword": 0.14, "stam_sword": 0.15},
		"+14% cutlass damage, and cutlass attacks cost 15% less stamina.")
	# defence
	_add("s_deflect", "Arrow Cutting", "passive", R, _g(-2, 1), ["s_dash"], {"parryshot_sword": 1, "parry_sword": 0.06},
		"Parry with a cutlass and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_add("s_riposte", "Riposte", "active", R, _g(-2, 2), ["s_deflect"], {}, "", {}, "riposte")
	_add("s_return", "Return to Sender", "passive", R, _g(-2, 3), ["s_riposte"], {"deflect_sword": 1, "return_sword": 1, "deflect_cd_sword": 1.0},
		"Mastered: with a cutlass drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# skills
	_add("s_flying", "Flying Slash", "active", R, _g(0, 2), ["s_edge"], {}, "", {}, "flying_slash")
	_add("s_swordfish", "Swordfish Flurry", "active", R, _g(0, 3), ["s_flying"], {}, "", {}, "swordfish")
	_add("s_captain", "Captain's Blade", "stat", R, _g(0, 4), ["s_swordfish", "s_swash"], {"dmg_sword": 0.22, "crit_sword": 0.1},
		"+22% cutlass damage, and 10% of your cutlass hits land 50% harder.", {"level": 10}, "", 3)
	_add("s_kraken", "Kraken's Wake", "ult", R, _g(0, 5), ["s_captain"], {}, "", {"level": 12}, "kraken_wake")
	# style
	_add("s_flourish", "Flourish", "passive", R, _g(2, 1), ["s_dive", "s_edge"], {"finisher_sword": 0.3, "heavy_sword": 0.25},
		"The last cut of your combo lands 30% harder, and your lunging thrust 25%.")
	_add("s_plunder", "Plunder", "passive", R, _g(2, 2), ["s_flourish"], {"leech_sword": 0.06, "exec_sword": 0.5},
		"Cutlass hits heal you for 6% of their damage, and a hit that leaves them under 30% health deals 50% more on top.")
	_add("s_swash", "Swashbuckler", "passive", R, _g(2, 3), ["s_plunder"], {"cdr_sword": 0.2, "flow_sword": 0.4},
		"Cutlass techniques come back 20% sooner, and cutlass hits give 40% more energy.")


static func _build_katana() -> void:
	_tree = "katana"
	var R := "Katana"
	_add("k_root", "Katana", "root", R, _g(0, 0), [], {},
		"Two hands, slow wide cuts, and iaijutsu on heavy: hold to charge, attack to draw. Fight with a katana (or any blade, a little) to build its mastery.")
	_add("k_draw", "Quick Draw", "move", R, _g(-2, 0), ["k_root"], {"mv_quick_draw": 1},
		"Attack at a sprint: a quick cut straight out of the scabbard that breaks wind-ups.")
	_add("k_folded", "Folded Steel", "stat", R, _g(2, 0), ["k_root"], {"dmg_katana": 0.12, "stam_katana": 0.15},
		"+12% katana damage, and katana attacks cost 15% less stamina.")
	_add("k_full", "Full Draw", "move", R, _g(0, 1), ["k_root"], {"mv_iai_full": 1},
		"Your iai charges to its second level: a gold glint, a longer dash, and everything you cut through crumples.", {}, "", 2)
	_add("k_eye", "Mind's Eye", "passive", R, _g(-1, 1), ["k_draw", "k_full"], {"iai_speed": 0.3},
		"Your iai charges 30% faster.")
	# movement and defence
	_add("k_deflect", "Cut the Shot", "passive", R, _g(-2, 1), ["k_draw"], {"parryshot_katana": 1, "parry_katana": 0.06},
		"Parry with a katana and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_add("k_counter", "Iai Counter", "active", R, _g(-2, 2), ["k_deflect"], {}, "", {}, "iai_counter")
	_add("k_arc", "Crescent Arc", "move", R, _g(-2, 3), ["k_counter"], {"mv_air_slash": 1},
		"Attack in the air: a little lift and one big arc swept down under you (once per jump).")
	_add("k_phantom", "Phantom Step", "active", R, _g(-2, 4), ["k_arc"], {}, "", {}, "phantom_step")
	_add("k_return", "Bullet Return", "passive", R, _g(-2, 5), ["k_phantom"], {"deflect_katana": 1, "return_katana": 1, "deflect_cd_katana": 1.0},
		"Mastered: with a katana drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# skills
	_add("k_tiger", "Tiger Rush", "active", R, _g(0, 2), ["k_full"], {}, "", {"level": 4}, "tiger_rush")
	_add("k_wind", "Wind Severer", "active", R, _g(0, 3), ["k_tiger"], {}, "", {}, "wind_sever")
	_add("k_saint", "Sword Saint", "stat", R, _g(0, 4), ["k_wind", "k_through"], {"dmg_katana": 0.16, "crit_katana": 0.15},
		"+16% katana damage, and 15% of your katana hits land 50% harder.", {"level": 10}, "", 3)
	_add("k_petals", "Thousand Petals", "ult", R, _g(0, 5), ["k_saint"], {}, "", {"level": 12}, "petal_storm")
	# style
	_add("k_clean", "Clean Line", "passive", R, _g(2, 1), ["k_folded"], {"heavy_katana": 0.3, "exec_katana": 0.5},
		"Your iai cuts 30% deeper, and a cut that leaves them under 30% health deals 50% more on top.")
	_add("k_calm", "Empty Mind", "passive", R, _g(2, 2), ["k_clean"], {"cdr_katana": 0.25},
		"Katana techniques come back 25% sooner.")
	_add("k_through", "Through the Guard", "passive", R, _g(2, 3), ["k_calm"], {"unblock_katana": 1},
		"Your iai can't be blocked.", {"level": 8})


static func _build_axe() -> void:
	_tree = "axe"
	var R := "Axe"
	_add("a_root", "Axe", "root", R, _g(0, 0), [], {},
		"Heavy, deliberate hacks and a whirlwind on heavy. Fight with an axe to build its mastery.")
	_add("a_sky", "Skybreaker", "move", R, _g(-2, 0), ["a_root"], {"mv_skybreaker": 1},
		"Attack in the air: spring into a somersault and split the ground in a line ahead, knocking everyone on it flat.")
	_add("a_heft", "Heft", "stat", R, _g(0, 1), ["a_root"], {"dmg_axe": 0.14, "stam_axe": 0.15},
		"+14% axe damage, and axe attacks cost 15% less stamina.")
	# brute force
	_add("a_throw", "Hatchet Throw", "active", R, _g(-2, 1), ["a_sky"], {}, "", {}, "axe_throw")
	_add("a_split", "Earthsplitter", "active", R, _g(-2, 2), ["a_throw"], {}, "", {}, "earthsplitter")
	_add("a_frenzy", "Frenzy", "passive", R, _g(-2, 3), ["a_split"], {"crit_axe": 0.1, "cdr_axe": 0.2},
		"10% of your axe hits land 50% harder, and axe techniques come back 20% sooner.")
	# fury
	_add("a_overhead", "Overhead", "passive", R, _g(0, 2), ["a_heft"], {"heavy_axe": 0.3}, "Your whirlwind hits 30% harder.")
	_add("a_unstop", "Unstoppable", "passive", R, _g(0, 3), ["a_overhead"], {"armor_axe": 1},
		"Mid-swing with an axe, blows don't make you flinch or knock you off your feet.", {"level": 4})
	_add("a_berserk", "Berserk", "active", R, _g(0, 4), ["a_unstop", "a_exec"], {}, "", {}, "berserk")
	_add("a_warlord", "Warlord", "stat", R, _g(0, 5), ["a_berserk"], {"dmg_axe": 0.22, "def_axe": 8.0},
		"+22% axe damage, and +8 defense with an axe in hand.", {"level": 10}, "", 3)
	_add("a_maelstrom", "Maelstrom", "ult", R, _g(0, 6), ["a_warlord"], {}, "", {"level": 12}, "maelstrom")
	# blood
	_add("a_blood", "Bloodlust", "passive", R, _g(2, 1), ["a_root", "a_heft"], {"flow_axe": 0.4, "leech_axe": 0.08},
		"Axe hits give 40% more energy and heal you for 8% of their damage.")
	_add("a_sunder", "Sunder", "passive", R, _g(2, 2), ["a_blood"], {"unblock_axe": 1}, "Your heavy attacks can't be blocked.")
	_add("a_exec", "Executioner", "passive", R, _g(2, 3), ["a_sunder"], {"exec_axe": 0.5},
		"A hit that leaves them under 30% health deals 50% more on top.")


static func _build_dual() -> void:
	_tree = "dual"
	var R := "Dual Wield"
	_add("d_root", "Dual Wield", "root", R, _g(0, 0), [], {},
		"A blade in each hand: fast cuts trading hands and a crashing double overhead. A cutlass with a second sword, an axe or a dagger: an off-hand axe hacks harder but slower, a dagger stabs lighter and quicker. Fight with two blades (or any blade, a little) to build dual-wield mastery.")
	_add("d_spin", "Twin Spin", "move", R, _g(-2, 0), ["d_root"], {"mv_twin_spin": 1},
		"Adds a fourth hit to your combo: both blades whirled round in a spin.")
	_add("d_cyclone", "Twin Cyclone", "move", R, _g(2, 0), ["d_root"], {"mv_twin_cyclone": 1},
		"Attack in the air: blades crossed, then a drill of turns down and forward cutting everyone close on every turn, and a burst on landing that knocks them flat.", {"level": 3})
	_add("d_twin", "Twin Blades", "stat", R, _g(0, 1), ["d_root"], {"dmg_dual": 0.16, "stam_dual": 0.15},
		"+16% damage while dual wielding, and dual-wield attacks cost 15% less stamina.")
	# guard
	_add("d_deflect", "Twin Deflect", "passive", R, _g(-2, 1), ["d_spin"], {"parryshot_dual": 1, "parry_dual": 0.06},
		"Parry with two blades and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_add("d_counter", "Crossed Counter", "active", R, _g(-2, 2), ["d_deflect"], {}, "", {}, "cross_counter")
	_add("d_return", "Ricochet Steel", "passive", R, _g(-2, 3), ["d_counter"], {"deflect_dual": 1, "return_dual": 1, "deflect_cd_dual": 1.0},
		"Mastered: with both blades drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# dance
	_add("d_dance", "Blade Dance", "active", R, _g(0, 2), ["d_twin"], {}, "", {}, "blade_dance")
	_add("d_cross", "Cross Fang", "active", R, _g(0, 3), ["d_dance"], {}, "", {}, "cross_fang")
	_add("d_master", "Twin Master", "stat", R, _g(0, 4), ["d_cross", "d_exec"], {"dmg_dual": 0.26, "crit_dual": 0.12},
		"+26% damage while dual wielding, and 12% of your dual-wield hits land 50% harder.", {"level": 10}, "", 3)
	_add("d_tempest", "Tempest of Steel", "ult", R, _g(0, 5), ["d_master"], {}, "", {"level": 12}, "steel_tempest")
	# edge
	_add("d_whirl", "Whirling Steel", "passive", R, _g(2, 1), ["d_cyclone", "d_twin"], {"flow_dual": 0.4, "finisher_dual": 0.35},
		"Dual-wield hits give 40% more energy, and the last cut of your combo lands 35% harder.")
	_add("d_tech", "Dancer", "passive", R, _g(2, 2), ["d_whirl"], {"cdr_dual": 0.2, "leech_dual": 0.06},
		"Dual-wield techniques come back 20% sooner, and hits heal you for 6% of their damage.")
	_add("d_exec", "Thousand Cuts", "passive", R, _g(2, 3), ["d_tech"], {"exec_dual": 0.4},
		"A cut that leaves them under 30% health deals 40% more on top.")


## One dagger: the root brings its nature (crits, wounds that bleed, a blade in the back).
static func _build_dagger() -> void:
	_tree = "dagger"
	var R := "Dagger"
	_add("dg_root", "Dagger", "root", R, _g(0, 0), [], {"crit_dagger": 0.1, "bleed_dagger": 0.15, "backstab_dagger": 0.5},
		"A short blade for close work: quick stabs and cuts, and on right-click you're gone and out from behind the one in front. 10% of your hits are crits, 15% open a wound that bleeds, and a blade in the back deals half again. Fight with a dagger (or any blade, a little) to build its mastery.")
	_add("dg_gut", "Gutting Strike", "move", R, _g(-2, 0), ["dg_root"], {"mv_gut_strike": 1},
		"Adds a fourth hit to your combo: a turn on the heel, the off hand seizes them and the blade goes in low. It bleeds.")
	_add("dg_fang", "Fang Dive", "move", R, _g(2, 0), ["dg_root"], {"mv_fang_dive": 1},
		"Attack in the air: knees tucked and the blade drawn back, then a dive at the enemy you're looking at that always finds the gap (a sure crit that bleeds) and a backflip off them (once per jump).", {"level": 3})
	_add("dg_edge", "Whetstone", "stat", R, _g(0, 1), ["dg_root"], {"dmg_dagger": 0.14, "stam_dagger": 0.15},
		"+14% dagger damage, and dagger attacks cost 15% less stamina.")
	# guard
	_add("dg_deflect", "Flick the Shot", "passive", R, _g(-2, 1), ["dg_gut"], {"parryshot_dagger": 1, "evade_dagger": 0.08},
		"Parry with a dagger and you flick gunshots aside too (without it, a parry only stops blades), and 8% of the blows that would hit you are slipped by instinct.")
	_add("dg_slip", "Slip", "active", R, _g(-2, 2), ["dg_deflect"], {}, "", {}, "slip")
	_add("dg_return", "Knife in the Dark", "passive", R, _g(-2, 3), ["dg_slip"], {"deflect_dagger": 1, "return_dagger": 1, "deflect_cd_dagger": 1.0},
		"Mastered: with a dagger drawn, a shot from the front is flicked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# skills
	_add("dg_fan", "Knife Fan", "active", R, _g(0, 2), ["dg_edge"], {}, "", {}, "knife_fan")
	_add("dg_cut", "Cutthroat", "active", R, _g(0, 3), ["dg_fan"], {}, "", {"level": 4}, "cutthroat")
	_add("dg_night", "Night Blade", "stat", R, _g(0, 4), ["dg_cut", "dg_open"], {"dmg_dagger": 0.22, "crit_dagger": 0.1},
		"+22% dagger damage, and another 10% of your dagger hits land 50% harder.", {"level": 10}, "", 3)
	_add("dg_eclipse", "Red Eclipse", "ult", R, _g(0, 5), ["dg_night"], {}, "", {"level": 12}, "red_eclipse")
	# blood
	_add("dg_deep", "Deep Cuts", "passive", R, _g(2, 1), ["dg_fang", "dg_edge"], {"bleed_dagger": 0.15, "flow_dagger": 0.4},
		"Another 15% of your dagger hits open a wound that bleeds, and dagger hits give 40% more energy.")
	_add("dg_back", "In the Back", "passive", R, _g(2, 2), ["dg_deep"], {"backstab_dagger": 0.3, "heavy_dagger": 0.3},
		"A blade in the back deals another 30% on top, and your Shadow Lunge (right-click) hits 30% harder.")
	_add("dg_open", "Open Vein", "passive", R, _g(2, 3), ["dg_back"], {"exec_dagger": 0.5, "leech_dagger": 0.06},
		"A hit that leaves them under 30% health deals 50% more on top, and dagger hits heal you for 6% of their damage.")


## Two daggers: a set of their own (not the dual-wield tree), venom and speed.
static func _build_dual_dagger() -> void:
	_tree = "dual_dagger"
	var R := "Twin Daggers"
	_add("dd_root", "Twin Daggers", "root", R, _g(0, 0), [], {"crit_dual_dagger": 0.08, "bleed_dual_dagger": 0.2, "backstab_dual_dagger": 0.35},
		"A dagger in each hand: the fastest blows you can throw, a scissor rip on right-click. 8% of your hits are crits, 20% open a wound that bleeds, and a blade in the back deals a third again. Fight with two daggers (or any blade, a little) to build their mastery.")
	_add("dd_whirl", "Fang Whirl", "move", R, _g(-2, 0), ["dd_root"], {"mv_fang_whirl": 1},
		"Adds a fourth hit to your combo: a whirl with both blades out, then both driven in together. It bleeds.")
	_add("dd_knives", "Knife Rain", "move", R, _g(2, 0), ["dd_root"], {"mv_knife_rain": 1},
		"Attack in the air: hang a beat and fling a fistful of knives down at up to four enemies below and ahead; every one cut bleeds (once per jump).", {"level": 3})
	_add("dd_twin", "Paired Fangs", "stat", R, _g(0, 1), ["dd_root"], {"dmg_dual_dagger": 0.14, "stam_dual_dagger": 0.15},
		"+14% damage with two daggers, and twin-dagger attacks cost 15% less stamina.")
	# guard and tricks
	_add("dd_deflect", "Crossed Knives", "passive", R, _g(-2, 1), ["dd_whirl"], {"parryshot_dual_dagger": 1, "evade_dual_dagger": 0.08},
		"Parry with two daggers and you knock gunshots aside too (without it, a parry only stops blades), and 8% of the blows that would hit you are slipped by instinct.")
	_add("dd_edge", "Bleeding Edge", "active", R, _g(-2, 2), ["dd_deflect"], {}, "", {}, "bleeding_edge")
	_add("dd_return", "Knives Back", "passive", R, _g(-2, 3), ["dd_edge"], {"deflect_dual_dagger": 1, "return_dual_dagger": 1, "deflect_cd_dual_dagger": 1.0},
		"Mastered: with both daggers drawn, a shot from the front is knocked aside by itself (once every 3 s), and every shot you stop flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# fangs
	_add("dd_viper", "Viper Flurry", "active", R, _g(0, 2), ["dd_twin"], {}, "", {}, "viper_flurry")
	_add("dd_leap", "Scissor Leap", "active", R, _g(0, 3), ["dd_viper"], {}, "", {"level": 4}, "scissor_leap")
	_add("dd_master", "Viper King", "stat", R, _g(0, 4), ["dd_leap", "dd_exec"], {"dmg_dual_dagger": 0.24, "crit_dual_dagger": 0.1},
		"+24% damage with two daggers, and another 10% of your hits land 50% harder.", {"level": 10}, "", 3)
	_add("dd_fangs", "Hundred Fangs", "ult", R, _g(0, 5), ["dd_master"], {}, "", {"level": 12}, "hundred_fangs")
	# venom
	_add("dd_deep", "Open Wounds", "passive", R, _g(2, 1), ["dd_knives", "dd_twin"], {"bleed_dual_dagger": 0.15, "flow_dual_dagger": 0.4},
		"Another 15% of your twin-dagger hits open a wound that bleeds, and they give 40% more energy.")
	_add("dd_back", "Two in the Back", "passive", R, _g(2, 2), ["dd_deep"], {"backstab_dual_dagger": 0.25, "heavy_dual_dagger": 0.3},
		"A blade in the back deals another 25% on top, and your Scissor Rip (right-click) hits 30% harder.")
	_add("dd_exec", "Death by Cuts", "passive", R, _g(2, 3), ["dd_back"], {"exec_dual_dagger": 0.4, "leech_dual_dagger": 0.06},
		"A hit that leaves them under 30% health deals 40% more on top, and twin-dagger hits heal you for 6% of their damage.")


static func _build_corsair() -> void:
	_tree = "corsair"
	var R := "Corsair"
	_add("cs_root", "Corsair", "root", R, _g(0, 0), [], {},
		"A cutlass in your hand and a pistol in the other: cuts and point-blank shots, a lunge that ends in a shot on right-click. The pistol holds two balls and reloads itself as you fight. Fight this way (or with any blade or gun, a little) to build Corsair mastery.")
	_add("cs_finale", "Powder Finale", "move", R, _g(-2, 0), ["cs_root"], {"mv_powder_finale": 1},
		"Adds a fourth hit to your combo: a full turn with the blade out, then a shot point-blank that knocks them flat.")
	_add("cs_drop", "Dead Man's Drop", "move", R, _g(2, 0), ["cs_root"], {"mv_deadmans_drop": 1},
		"Attack in the air: lean over the enemy you're looking at and fire down into them (it pins them), then dive through them point first; the landing knocks everyone close flat (once per jump).", {"level": 3})
	_add("cs_steel", "Boarding Steel", "stat", R, _g(0, 1), ["cs_root"], {"dmg_corsair": 0.12, "stam_corsair": 0.15},
		"+12% damage with sword and pistol, and their attacks cost 15% less stamina.")
	# guard
	_add("cs_deflect", "Steel and Shot", "passive", R, _g(-2, 1), ["cs_finale"], {"parryshot_corsair": 1, "parry_corsair": 0.06},
		"Parry with the cutlass and you cut gunshots out of the air too (without it, a parry only stops blades), and your parry window is wider.")
	_add("cs_parley", "Parley", "active", R, _g(-2, 2), ["cs_deflect"], {}, "", {}, "parley")
	_add("cs_return", "Return Fire", "passive", R, _g(-2, 3), ["cs_parley"], {"deflect_corsair": 1, "return_corsair": 1, "deflect_cd_corsair": 1.0},
		"Mastered: with the cutlass drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4}, "", 3)
	# skills
	_add("cs_bandolier", "Bandolier", "passive", R, _g(-1, 1), ["cs_steel", "cs_finale"], {"shots_corsair": 1, "reload_corsair": 0.35},
		"The off-hand pistol holds one more ball and reloads 35% faster.")
	_add("cs_grape", "Grapeshot", "active", R, _g(0, 2), ["cs_steel"], {}, "", {}, "grapeshot")
	_add("cs_cross", "Crossfire", "active", R, _g(0, 3), ["cs_grape"], {}, "", {"level": 4}, "crossfire")
	_add("cs_captain", "Dread Captain", "stat", R, _g(0, 4), ["cs_cross", "cs_noquarter"], {"dmg_corsair": 0.16, "crit_corsair": 0.1},
		"+16% damage with sword and pistol, and 10% of your hits land 50% harder.", {"level": 10}, "", 3)
	_add("cs_broadside", "Broadside", "ult", R, _g(0, 5), ["cs_captain"], {}, "", {"level": 12}, "broadside")
	# powder
	_add("cs_rhythm", "Smoke and Steel", "passive", R, _g(2, 1), ["cs_drop", "cs_steel"], {"flow_corsair": 0.4, "heavy_corsair": 0.3},
		"Sword-and-pistol hits give 40% more energy, and your Powder Lunge (right-click) hits 30% harder, the shot too.")
	_add("cs_smoke", "Gunsmoke", "passive", R, _g(2, 2), ["cs_rhythm"], {"cdr_corsair": 0.2, "leech_corsair": 0.06},
		"Sword-and-pistol techniques come back 20% sooner, and hits heal you for 6% of their damage.")
	_add("cs_noquarter", "No Quarter", "passive", R, _g(2, 3), ["cs_smoke"], {"exec_corsair": 0.5},
		"A hit that leaves them under 30% health deals 50% more on top.")


static func _build_pistol() -> void:
	_tree = "pistol"
	var R := "Pistol"
	_add("g_root", "Pistol", "root", R, _g(0, 0), [], {},
		"Two shots, then reload. A second pistol in the off hand alternates them. Shoot (or fight as a Corsair, a little) to build pistol mastery.")
	_add("g_kata", "Gun Kata", "move", R, _g(-2, 0), ["g_root"], {"mv_gun_kata": 1},
		"Dual pistols' heavy: a hop into a double spin, arms crossed, shooting everyone close. (Without it: a pistol-whip.)")
	_add("g_hangshot", "Hang Shot", "move", R, _g(2, 0), ["g_root"], {"mv_hang_shot": 1},
		"One pistol in the air: hang a beat drawing a bead, then one heavy shot at the reticle that knocks them flat, the recoil throwing you back (once per jump, uses a shot).", {"level": 3})
	_add("g_marks", "Marksman", "stat", R, _g(0, 1), ["g_root"], {"dmg_pistol": 0.12, "reload_pct": 0.35},
		"+12% damage with pistols, and you reload 35% faster.")
	# tricks
	_add("g_rain", "Gun Rain", "move", R, _g(-2, 1), ["g_kata"], {"mv_gun_rain": 1},
		"Dual pistols in the air: fire both guns down at once, the recoil launching you forward.")
	_add("g_smoke", "Smoke Bomb", "active", R, _g(-1, 1), ["g_kata", "g_marks"], {}, "", {}, "smoke_bomb")
	_add("g_hang", "Hang Time", "passive", R, _g(-2, 2), ["g_rain"], {"gun_rain_uses": 1},
		"Gun Rain can be fired twice before you land.", {"level": 6})
	# shots
	_add("g_storm", "Bullet Storm", "active", R, _g(0, 2), ["g_marks"], {}, "", {}, "bullet_storm")
	_add("g_dead", "Deadeye", "active", R, _g(0, 3), ["g_storm", "g_smoke"], {}, "", {}, "deadeye")
	_add("g_ricochet", "Ricochet", "passive", R, _g(0, 4), ["g_dead"], {"ricochet": 1},
		"Every pistol ball that hits glances off into the nearest other enemy for 60% damage.", {"level": 6})
	_add("g_legend", "Legendary Gunman", "stat", R, _g(0, 5), ["g_ricochet", "g_exec"], {"dmg_pistol": 0.2, "crit_pistol": 0.12},
		"+20% damage with pistols, and 12% of your shots land 50% harder.", {"level": 10}, "", 3)
	_add("g_waltz", "Death's Waltz", "ult", R, _g(0, 6), ["g_legend"], {}, "", {"level": 12}, "deaths_waltz")
	# close work
	_add("g_powder", "Extra Powder", "passive", R, _g(2, 1), ["g_hangshot", "g_marks"], {"extra_shots": 1},
		"Every pistol holds one more shot.", {"level": 4})
	_add("g_point", "Point Blank", "active", R, _g(2, 2), ["g_powder"], {}, "", {}, "point_blank")
	_add("g_close", "Close Quarters", "passive", R, _g(2, 3), ["g_point"], {"pointblank_pct": 0.4, "leech_pistol": 0.05},
		"Shots from within 5 m hit 40% harder, and pistol hits heal you for 5% of their damage.")
	_add("g_exec", "Coup de Grace", "passive", R, _g(2, 4), ["g_close"], {"exec_pistol": 0.4, "cdr_pistol": 0.2},
		"A shot that leaves them under 30% health deals 40% more on top, and pistol techniques come back 20% sooner.")


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
