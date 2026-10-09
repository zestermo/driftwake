class_name SkillTree
extends RefCounted
## The skill trees, one tab each on the skill map:
##   base     Base & Haki: core stats in the middle; Mobility, Survival,
##            Armament and Observation Haki (level 10+) and Conqueror's Haki
##            (level 18+) grow out of it
##   unarmed, sword (cutlass), katana, axe, dual, pistol
##            weapon trees, paid for with that weapon's mastery points (earned
##            by fighting with it); they hold its passives, its skills, its
##            ultimate and the parts of its moveset you have to unlock ("move" nodes)
##   fruit    your Devil Fruit (only once you've eaten one)
## You can learn any node linked to one you own (if you meet its requirements).
##
## Node: {id, name, kind, tree, region, pos, links, cost, effects, skill, req, desc}
##   kind: origin | root | stat | passive | move | active | ult
##   effects: stat bonuses / flags summed by Progression.stat(); a move node
##     carries a flag "mv_<move>" (Progression.has_move)
##   req: {"level": n} and/or {"fruit": id}
##
## Weapon-tree effect keys (<t> = the tree id, read with Progression.style_stat for
## the weapon in hand): dmg_ damage, stam_ attack stamina, flow_ energy per hit,
## crit_ chance of a x1.5 hit, heavy_ / finisher_ / skill_ damage of heavies,
## combo finishers and techniques, leech_ share of damage healed, exec_ extra
## damage to targets left under 30% health, parry_ parry window (s), parryshot_
## a parry also cuts gunshots, deflect_ cuts them by itself (deflect_cd_ shortens
## its 4 s wait), return_ sends cut shots back, unblock_ heavies can't be blocked, armor_ no flinching mid-attack,
## def_ defense, cdr_ cooldown cut for that tree's skills.

const TREES := {
	"base": {"name": "Base & Haki", "tab": "BASE", "mastery": false},
	"unarmed": {"name": "Unarmed", "tab": "UNARMED", "mastery": true},
	"sword": {"name": "Cutlass", "tab": "CUTLASS", "mastery": true},
	"katana": {"name": "Katana", "tab": "KATANA", "mastery": true},
	"axe": {"name": "Axe", "tab": "AXE", "mastery": true},
	"dual": {"name": "Dual Wield", "tab": "DUAL", "mastery": true},
	"pistol": {"name": "Pistol", "tab": "PISTOL", "mastery": true},
	"fruit": {"name": "Devil Fruit", "tab": "FRUIT", "mastery": false},
}
const TAB_ORDER := ["base", "unarmed", "sword", "katana", "axe", "dual", "pistol", "fruit"]

## Fighting style (Player.style()) -> the weapon tree it builds mastery in.
const STYLE_TREE := {"fist": "unarmed", "sword": "sword", "katana": "katana", "axe": "axe",
	"dual_sword": "dual", "pistol": "pistol", "dual_pistol": "pistol"}

const REGION_COLORS := {
	"Core": Color(0.85, 0.78, 0.6), "Mobility": Color(0.45, 0.85, 0.95), "Survival": Color(0.5, 0.9, 0.45),
	"Armament": Color(0.6, 0.45, 0.85), "Observation": Color(0.95, 0.5, 0.75), "Conqueror": Color(0.95, 0.3, 0.3),
	"Unarmed": Color(1.0, 0.85, 0.6), "Cutlass": Color(0.85, 0.85, 0.95), "Katana": Color(0.7, 0.85, 1.0),
	"Axe": Color(1.0, 0.7, 0.45), "Dual Wield": Color(0.55, 0.85, 1.0), "Pistol": Color(0.95, 0.75, 0.4),
	"Ember": Color(1.0, 0.5, 0.15), "Wolf": Color(0.7, 0.62, 0.5), "Vine": Color(0.45, 0.85, 0.3),
}

## Direction (degrees, screen space: 90 = down) each base-tree region grows in.
const REGION_ANGLE := {"Mobility": -135.0, "Survival": -45.0, "Observation": 45.0, "Armament": 135.0, "Conqueror": 90.0}

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


static func is_mastery_tree(tree: String) -> bool:
	return bool(TREES.get(tree, {}).get("mastery", false))


## Owned from the start: the Origin and every weapon tree's root.
static func starting_nodes() -> Array:
	var out: Array = []
	for k in nodes().keys():
		var n: Dictionary = nodes()[k]
		if n["kind"] == "origin" or (n["kind"] == "root" and is_mastery_tree(str(n["tree"]))):
			out.append(k)
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


static func _add(id: String, name_: String, kind: String, region: String, pos: Vector2, links: Array,
		effects: Dictionary = {}, desc: String = "", req: Dictionary = {}, skill: String = "", cost: int = -1) -> void:
	var c := cost
	if c < 0:
		c = 2 if kind == "active" else (3 if kind == "ult" else 1)
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
	_build_pistol()
	_build_mastery()
	_build_fruits()


static func _build_base() -> void:
	_tree = "base"
	_add("origin", "Pirate's Spirit", "origin", "Core", Vector2.ZERO, [], {}, "Where every captain starts. Learn the nodes linked to the ones you own.")
	# ---- core stats: an inner ring of eight, a web between ----
	var inner := [
		[-135.0, "c_agility", "Agility", {"move_pct": 0.04}, "+4% movement speed."],
		[-90.0, "c_endurance", "Endurance", {"max_stamina": 12.0}, "+12 max stamina."],
		[-45.0, "c_vitality", "Vitality", {"max_hp": 15.0}, "+15 max health."],
		[0.0, "c_focus", "Focus", {"ult_charge_pct": 0.1}, "Your ultimate charges 10% faster."],
		[45.0, "c_toughness", "Toughness", {"defense": 3.0}, "+3 defense."],
		[90.0, "c_strength", "Strength", {"damage_pct": 0.05}, "+5% damage."],
		[135.0, "c_spirit", "Spirit", {"max_energy": 15.0}, "+15 max energy."],
		[180.0, "c_grit", "Grit", {"stamina_regen_pct": 0.1}, "Stamina refills 10% faster."],
	]
	for d in inner:
		_add(d[1], d[2], "stat", "Core", _p(d[0], 82.0), ["origin"], d[3], d[4])
	var web := [
		["c_end2", "Wind", {"max_stamina": 15.0}, "+15 max stamina."],
		["c_vit2", "Vigor", {"max_hp": 20.0}, "+20 max health."],
		["c_vit3", "Heart of the Sea", {"max_hp": 20.0}, "+20 max health."],
		["c_spirit2", "Inner Fire", {"energy_regen_pct": 0.12}, "Energy refills 12% faster."],
		["c_tough2", "Thick Skin", {"defense": 4.0}, "+4 defense."],
		["c_str2", "Brawn", {"damage_pct": 0.06}, "+6% damage."],
		["c_wind", "Second Wind", {"stamina_regen_pct": 0.15}, "Stamina refills 15% faster."],
		["c_legs", "Sea Legs", {"move_pct": 0.03, "sprint_pct": 0.05}, "+3% movement speed, +5% sprint speed."],
	]
	for i in range(inner.size()):
		var a: Array = inner[i]
		var b: Array = inner[(i + 1) % inner.size()]
		var a2: float = b[0]
		if a2 < a[0]:
			a2 += 360.0
		var w: Array = web[i]
		_add(w[0], w[1], "stat", "Core", _p((a[0] + a2) * 0.5, 128.0), [a[1], b[1]], w[2], w[3])
	_add("c_learner", "Quick Learner", "passive", "Core", _p(0.0, 185.0), ["c_focus"], {"xp_pct": 0.1},
		"Win 10% more experience from every fight.")

	# ---- Mobility ----
	var A: float = REGION_ANGLE["Mobility"]
	_add("m_geppo", "Geppo", "passive", "Mobility", _p(A, 185.0), ["c_agility"], {"air_jumps": 1},
		"Kick off the air itself: a second jump in mid-air.")
	_add("m_soru", "Soru", "active", "Mobility", _p(A, 265.0, -13.0), ["m_geppo"], {}, "", {}, "soru")
	_add("m_swift", "Swift Step", "passive", "Mobility", _p(A, 265.0, 13.0), ["m_geppo"], {"dodge_cost_pct": 0.3},
		"Dodging costs 30% less stamina.")
	_add("m_skywalk", "Sky Walk", "passive", "Mobility", _p(A, 345.0, -10.0), ["m_soru"], {"air_jumps": 1},
		"One more jump in mid-air (three in all).", {"level": 4})
	_add("m_fleet", "Fleet Foot", "stat", "Mobility", _p(A, 345.0, 10.0), ["m_swift"], {"sprint_pct": 0.1, "move_pct": 0.04},
		"+10% sprint speed, +4% movement speed.")
	_add("m_slip", "Slip Step", "passive", "Mobility", _p(A, 420.0), ["m_skywalk", "m_fleet"], {"dodge_iframe_pct": 0.5, "dodge_dist_pct": 0.2},
		"Your dodge carries you 20% further and you're untouchable 50% longer.", {"level": 6})
	_add("m_feather", "Featherfall", "passive", "Mobility", _p(A, 420.0, -24.0), ["m_skywalk"], {"featherfall": 1},
		"Falls hurt a quarter as much, and you never stumble on landing.", {"level": 3})
	_add("m_sprinter", "Long Stride", "passive", "Mobility", _p(A, 345.0, 30.0), ["m_fleet"], {"sprint_cost_pct": 0.35},
		"Sprinting burns 35% less stamina.")
	_add("m_swim", "Sea Born", "passive", "Mobility", _p(A, 420.0, 24.0), ["m_sprinter"], {"swim_pct": 0.3},
		"You swim 30% faster.")
	_add("m_gale", "Gale Step", "passive", "Mobility", _p(A, 495.0), ["m_slip"], {"dodge_dist_pct": 0.15, "dodge_cost_pct": 0.15},
		"Your dodge goes another 15% further and costs 15% less.", {"level": 8})

	# ---- Survival ----
	A = REGION_ANGLE["Survival"]
	_add("v_hardy", "Hardy", "stat", "Survival", _p(A, 185.0), ["c_vitality"], {"max_hp": 25.0}, "+25 max health.")
	_add("v_tekkai", "Tekkai", "active", "Survival", _p(A, 265.0, -13.0), ["v_hardy"], {}, "", {}, "tekkai")
	_add("v_steadfast", "Steadfast", "passive", "Survival", _p(A, 265.0, 13.0), ["v_hardy"], {"steadfast": 1},
		"Light hits no longer make you flinch.")
	_add("v_iron", "Iron Hide", "stat", "Survival", _p(A, 345.0, -10.0), ["v_tekkai"], {"defense": 6.0}, "+6 defense.")
	_add("v_mend", "Mend", "passive", "Survival", _p(A, 345.0, 10.0), ["v_steadfast"], {"regen_hp": 1.5},
		"Out of combat (no damage for 5 s) you heal 1.5 health a second.")
	_add("v_last", "Last Stand", "passive", "Survival", _p(A, 420.0), ["v_iron", "v_mend"], {"last_stand": 1},
		"Once a minute, a blow that would kill you leaves you at 1 health instead.", {"level": 6})
	_add("v_stomach", "Iron Stomach", "passive", "Survival", _p(A, 345.0, 30.0), ["v_mend"], {"potion_pct": 0.4},
		"Food and drink heal you 40% more.")
	_add("v_adren", "Adrenaline", "passive", "Survival", _p(A, 420.0, -24.0), ["v_iron"], {"adrenaline": 0.2},
		"Below 35% health you hit 20% harder.", {"level": 5})
	_add("v_sea_air", "Sea Air", "passive", "Survival", _p(A, 420.0, 24.0), ["v_stomach"], {"regen_hp": 1.0},
		"Out of combat you heal another 1 health a second.")
	_add("v_hide", "Weathered", "stat", "Survival", _p(A, 495.0), ["v_last"], {"defense": 8.0}, "+8 defense.", {"level": 8})

	# ---- Haki (level-gated) ----
	A = REGION_ANGLE["Armament"]
	_add("h_arm", "Armament Haki", "passive", "Armament", _p(A, 185.0), ["c_spirit"], {"armament": 1, "damage_pct": 0.08},
		"Will made armor: +8% damage, and your heavy attacks can't be blocked.", {"level": 10})
	_add("h_coat", "Armament: Coat", "active", "Armament", _p(A, 265.0), ["h_arm"], {}, "", {"level": 12}, "armament_coat")
	_add("h_harden", "Hardening", "stat", "Armament", _p(A, 345.0, -12.0), ["h_coat"], {"defense": 8.0},
		"Haki under the skin: +8 defense.", {"level": 12})
	_add("h_flow", "Haki Flow", "passive", "Armament", _p(A, 345.0, 12.0), ["h_coat"], {"energy_regen_pct": 0.2},
		"Energy refills 20% faster.", {"level": 12})
	_add("h_black", "Black Fists", "stat", "Armament", _p(A, 420.0), ["h_harden", "h_flow"], {"dmg_unarmed": 0.12},
		"Your bare fists are iron: +12% unarmed damage.", {"level": 14})
	A = REGION_ANGLE["Observation"]
	_add("h_obs", "Observation Haki", "passive", "Observation", _p(A, 185.0), ["c_toughness"], {"observation": 1},
		"Sense intent: enemies flash red the moment they start an attack, and your parry window is a little wider.", {"level": 10})
	_add("h_fore", "Foresight", "active", "Observation", _p(A, 265.0), ["h_obs"], {}, "", {"level": 12}, "foresight")
	_add("h_instinct", "Instinct", "passive", "Observation", _p(A, 345.0, -12.0), ["h_fore"], {"evade_chance": 0.08},
		"8% of the blows that would hit you are sidestepped on instinct.", {"level": 12})
	_add("h_read", "Reading Blows", "passive", "Observation", _p(A, 345.0, 12.0), ["h_fore"], {"parry_all": 0.04},
		"Your parry window is wider still.", {"level": 12})
	_add("h_weak", "Weak Points", "passive", "Observation", _p(A, 420.0), ["h_instinct", "h_read"], {"crit_all": 0.06},
		"You see where to strike: 6% more of your hits land 50% harder.", {"level": 14})
	A = REGION_ANGLE["Conqueror"]
	_add("h_will", "King's Will", "passive", "Conqueror", _p(A, 210.0), ["c_strength"], {"damage_pct": 0.06, "max_hp": 20.0},
		"A will that bends others: +6% damage, +20 max health.", {"level": 18})
	_add("h_conq", "Conqueror's Haki", "ult", "Conqueror", _p(A, 300.0), ["h_will"], {}, "", {"level": 20}, "conquerors_haki")


## Weapon trees share a shape: the root at the bottom, the moveset and defence
## (or grapples) to the left, the skills and damage up the middle (the ultimate
## at the top), crits, leech and cooldown passives to the right.
static func _build_unarmed() -> void:
	_tree = "unarmed"
	var R := "Unarmed"
	_add("u_root", "Unarmed", "root", R, _g(0, 0), [], {},
		"Bare-handed brawling: jab, cross, hook and a flying kick. Fight with your fists to build unarmed mastery.")
	_add("u_round", "Roundhouse", "move", R, _g(-2, 0), ["u_root"], {"mv_roundhouse": 1},
		"Adds a fourth hit to your punch combo: a spinning roundhouse kick.")
	_add("u_knuckles", "Iron Knuckles", "stat", R, _g(0, 1), ["u_root"], {"dmg_unarmed": 0.08}, "+8% unarmed damage.")
	_add("u_breath", "Fighter's Breath", "passive", R, _g(2, 0), ["u_root"], {"stam_unarmed": 0.2},
		"Unarmed attacks cost 20% less stamina.")
	# grapples
	_add("u_hip", "Shoulder Throw", "active", R, _g(-3, 1), ["u_round"], {}, "", {}, "hip_toss")
	_add("u_landing", "Heavy Landing", "passive", R, _g(-1.5, 1), ["u_hip", "u_knuckles"], {"throw_splash": 1},
		"Anyone you throw lands like a cannonball: everyone near where they land is knocked flat and hurt.")
	_add("u_suplex", "Suplex", "active", R, _g(-3, 3), ["u_hip"], {}, "", {}, "suplex")
	_add("u_grip", "Iron Grip", "passive", R, _g(-2, 4), ["u_suplex"], {"skill_unarmed": 0.25},
		"Your grapples and martial arts techniques hit 25% harder.")
	_add("u_swing", "Giant Swing", "active", R, _g(-3, 5), ["u_grip"], {}, "", {"level": 6}, "giant_swing")
	# martial arts
	_add("u_palm", "Shockwave Palm", "active", R, _g(0, 2), ["u_knuckles"], {}, "", {}, "palm_strike")
	_add("u_dragon", "Rising Dragon", "active", R, _g(-1, 3), ["u_palm", "u_landing"], {}, "", {}, "rising_dragon")
	_add("u_hundred", "Hundred Fists", "active", R, _g(0, 4), ["u_dragon"], {}, "", {"level": 4}, "hundred_fists")
	_add("u_thousand", "Thousand Fists", "stat", R, _g(0, 5), ["u_hundred", "u_tempo"], {"dmg_unarmed": 0.12},
		"+12% unarmed damage.", {"level": 10})
	_add("u_seaking", "Sea King Fist", "ult", R, _g(0, 6), ["u_thousand"], {}, "", {"level": 12}, "sea_king_fist")
	# body
	_add("u_flow", "Flow of Combat", "passive", R, _g(1.5, 1), ["u_knuckles", "u_breath"], {"flow_unarmed": 0.5},
		"Unarmed hits give 50% more energy.")
	_add("u_stone", "Stone Fists", "stat", R, _g(3, 1), ["u_flow"], {"dmg_unarmed": 0.1}, "+10% unarmed damage.")
	_add("u_ironbody", "Iron Body", "stat", R, _g(1.5, 2), ["u_flow"], {"def_unarmed": 8.0}, "+8 defense while fighting bare-handed.")
	_add("u_counter", "Counter Guard", "passive", R, _g(3, 2), ["u_stone"], {"parry_unarmed": 0.06},
		"Your bare-handed parry window is wider.")
	_add("u_points", "Pressure Points", "passive", R, _g(1.5, 3), ["u_ironbody"], {"crit_unarmed": 0.12},
		"12% of your unarmed hits land 50% harder.")
	_add("u_chi", "Chi", "passive", R, _g(3, 3), ["u_counter"], {"leech_unarmed": 0.06}, "Unarmed hits heal you for 6% of their damage.")
	_add("u_finish", "Finishing Blow", "passive", R, _g(1.5, 4), ["u_points"], {"finisher_unarmed": 0.4},
		"The last hit of your combo lands 40% harder.")
	_add("u_tempo", "Fighting Rhythm", "passive", R, _g(3, 4), ["u_chi"], {"cdr_unarmed": 0.2},
		"Unarmed techniques come back 20% sooner.")


## Each weapon's element, awakened by two mastery passives: the first shows it
## on the tree's skills and ultimate, the second on every blow. Placed the same
## on every grid: the first beside the middle skill, the second under the top stat.
## tree: [prefix, region, link 1, link 2, name 1, name 2, element (for the text)]
const MASTERY := {
	"sword": ["s", "Cutlass", "s_flying", "s_captain", "Call of the Tide", "Tidewalker", "the sea: spray and foam, and Kraken's Wake raises the deep under your foes"],
	"katana": ["k", "Katana", "k_tiger", "k_saint", "Falling Petals", "Blossom Path", "pale steel light and falling petals"],
	"axe": ["a", "Axe", "a_overhead", "a_warlord", "Ember Heart", "Living Fire", "embers and splintered stone"],
	"dual": ["d", "Dual Wield", "d_dance", "d_master", "Twin Currents", "Crossing Storm", "twin currents of light, cyan and violet"],
	"pistol": ["g", "Pistol", "g_storm", "g_legend", "Golden Powder", "Gilded Gun", "gold flashes and powder smoke"],
	"unarmed": ["u", "Unarmed", "u_palm", "u_thousand", "Rushing Wind", "Gale Fists", "rushing wind and rings of air"],
}

static func _build_mastery() -> void:
	for tr in MASTERY.keys():
		var m: Array = MASTERY[tr]
		_tree = tr
		var p: String = m[0]
		_add(p + "_elem", m[4], "passive", m[1], _g(-1.5, 2), [m[2]], {"elem_" + tr: 1},
			"Mastery. Your %s skills awaken: %s." % [str(m[1]).to_lower(), m[6]], {"level": 8}, "", 2)
		_add(p + "_elem2", m[5], "passive", m[1], _g(-1.5, 5), [m[3]], {"elem2_" + tr: 1},
			"Mastery. The element follows every blow: your %s combo and heavy attack carry it too." % str(m[1]).to_lower(),
			{"level": 16, "node": p + "_elem"}, "", 3)


static func _build_cutlass() -> void:
	_tree = "sword"
	var R := "Cutlass"
	_add("s_root", "Cutlass", "root", R, _g(0, 0), [], {},
		"The pirate's blade: quick cuts and a lunging thrust. Fight with a cutlass to build its mastery.")
	_add("s_dash", "Running Cut", "move", R, _g(-2, 0), ["s_root"], {"mv_dash_cut": 1},
		"Attack at a sprint: one low cut driving through the target, breaking its wind-up.")
	_add("s_edge", "Keen Edge", "stat", R, _g(0, 1), ["s_root"], {"dmg_sword": 0.06}, "+6% cutlass damage.")
	_add("s_light", "Light Blade", "passive", R, _g(2, 0), ["s_root"], {"stam_sword": 0.15},
		"Cutlass attacks cost 15% less stamina.")
	# defence
	_add("s_deflect", "Arrow Cutting", "passive", R, _g(-3, 1), ["s_dash"], {"parryshot_sword": 1},
		"Parry with a cutlass and you cut gunshots out of the air too (without it, a parry only stops blades).")
	_add("s_riposte", "Riposte", "active", R, _g(-3, 2), ["s_deflect"], {}, "", {}, "riposte")
	_add("s_duelist", "Duelist", "passive", R, _g(-3, 3), ["s_riposte"], {"parry_sword": 0.06},
		"Your parry window with a cutlass is wider.")
	_add("s_return", "Return to Sender", "passive", R, _g(-3, 4), ["s_duelist"], {"deflect_sword": 1, "return_sword": 1, "deflect_cd_sword": 1.0},
		"Mastered: with a cutlass drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4})
	# skills
	_add("s_honed", "Honed Steel", "stat", R, _g(-1.5, 1), ["s_edge", "s_dash"], {"dmg_sword": 0.08}, "+8% cutlass damage.")
	_add("s_flying", "Flying Slash", "active", R, _g(0, 2), ["s_edge"], {}, "", {}, "flying_slash")
	_add("s_swordfish", "Swordfish Flurry", "active", R, _g(-1.5, 3), ["s_flying", "s_honed"], {}, "", {}, "swordfish")
	_add("s_boarding", "Boarding Blade", "stat", R, _g(0, 4), ["s_swordfish", "s_plunder"], {"dmg_sword": 0.1},
		"+10% cutlass damage.", {"level": 6})
	_add("s_captain", "Captain's Blade", "stat", R, _g(0, 5), ["s_boarding", "s_coup"], {"dmg_sword": 0.12},
		"+12% cutlass damage.", {"level": 10})
	_add("s_kraken", "Kraken's Wake", "ult", R, _g(0, 6), ["s_captain"], {}, "", {"level": 12}, "kraken_wake")
	# edge
	_add("s_rhythm", "Sea Dog's Rhythm", "passive", R, _g(1.5, 1), ["s_edge", "s_light"], {"flow_sword": 0.4},
		"Cutlass hits give 40% more energy.")
	_add("s_flourish", "Flourish", "passive", R, _g(3, 1), ["s_rhythm"], {"finisher_sword": 0.3},
		"The last cut of your combo lands 30% harder.")
	_add("s_luck", "Pirate's Luck", "passive", R, _g(1.5, 2), ["s_rhythm"], {"crit_sword": 0.1},
		"10% of your cutlass hits land 50% harder.")
	_add("s_point", "Driving Point", "passive", R, _g(3, 2), ["s_flourish"], {"heavy_sword": 0.25},
		"Your lunging thrust hits 25% harder.")
	_add("s_plunder", "Plunder", "passive", R, _g(1.5, 3), ["s_luck"], {"leech_sword": 0.06},
		"Cutlass hits heal you for 6% of their damage.")
	_add("s_swash", "Swashbuckler", "passive", R, _g(3, 3), ["s_point"], {"cdr_sword": 0.2},
		"Cutlass techniques come back 20% sooner.")
	_add("s_coup", "Coup de Grace", "passive", R, _g(2, 4), ["s_plunder", "s_swash"], {"exec_sword": 0.5},
		"A hit that leaves them under 30% health deals 50% more on top.")


static func _build_katana() -> void:
	_tree = "katana"
	var R := "Katana"
	_add("k_root", "Katana", "root", R, _g(0, 0), [], {},
		"Two hands, slow wide cuts, and iaijutsu on heavy: hold to charge, attack to draw. Fight with a katana to build its mastery.")
	_add("k_draw", "Quick Draw", "move", R, _g(-2, 0), ["k_root"], {"mv_quick_draw": 1},
		"Attack at a sprint: a quick cut straight out of the scabbard that breaks wind-ups.")
	_add("k_full", "Full Draw", "move", R, _g(0, 1), ["k_root"], {"mv_iai_full": 1},
		"Your iai charges to its second level: a gold glint, a longer dash, and everything you cut through crumples.", {}, "", 2)
	_add("k_folded", "Folded Steel", "stat", R, _g(2, 0), ["k_root"], {"dmg_katana": 0.06}, "+6% katana damage.")
	# movement and defence
	_add("k_deflect", "Cut the Shot", "passive", R, _g(-3, 1), ["k_draw"], {"parryshot_katana": 1},
		"Parry with a katana and you cut gunshots out of the air too (without it, a parry only stops blades).")
	_add("k_eye", "Mind's Eye", "passive", R, _g(-1.5, 1), ["k_draw", "k_full"], {"iai_speed": 0.3},
		"Your iai charges 30% faster.")
	_add("k_counter", "Iai Counter", "active", R, _g(-3, 2), ["k_deflect"], {}, "", {}, "iai_counter")
	_add("k_arc", "Crescent Arc", "move", R, _g(-3, 3), ["k_counter"], {"mv_air_slash": 1},
		"Attack in the air: a little lift and one big arc swept down under you (once per jump).")
	_add("k_phantom", "Phantom Step", "active", R, _g(-3, 4), ["k_arc"], {}, "", {}, "phantom_step")
	_add("k_return", "Bullet Return", "passive", R, _g(-3, 5), ["k_phantom"], {"deflect_katana": 1, "return_katana": 1, "deflect_cd_katana": 1.0},
		"Mastered: with a katana drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4})
	# skills
	_add("k_tiger", "Tiger Rush", "active", R, _g(0, 2), ["k_full"], {}, "", {"level": 4}, "tiger_rush")
	_add("k_wind", "Wind Severer", "active", R, _g(-1.5, 3), ["k_tiger", "k_eye"], {}, "", {}, "wind_sever")
	_add("k_master", "Master's Edge", "stat", R, _g(0, 4), ["k_wind", "k_final"], {"dmg_katana": 0.1},
		"+10% katana damage.", {"level": 6})
	_add("k_saint", "Sword Saint", "stat", R, _g(0, 5), ["k_master", "k_through"], {"dmg_katana": 0.12},
		"+12% katana damage.", {"level": 10})
	_add("k_petals", "Thousand Petals", "ult", R, _g(0, 6), ["k_saint"], {}, "", {"level": 12}, "petal_storm")
	# edge
	_add("k_still", "Still Water", "passive", R, _g(1.5, 1), ["k_full", "k_folded"], {"stam_katana": 0.15},
		"Katana attacks cost 15% less stamina.")
	_add("k_reading", "Blade Reading", "passive", R, _g(3, 1), ["k_still"], {"parry_katana": 0.06},
		"Your parry window with a katana is wider.")
	_add("k_clean", "Clean Line", "passive", R, _g(1.5, 2), ["k_still"], {"crit_katana": 0.15},
		"15% of your katana hits land 50% harder.")
	_add("k_deep", "Deep Cut", "passive", R, _g(3, 2), ["k_reading"], {"heavy_katana": 0.3},
		"Your iai cuts 30% deeper.")
	_add("k_final", "Final Cut", "passive", R, _g(1.5, 3), ["k_clean"], {"exec_katana": 0.5},
		"A cut that leaves them under 30% health deals 50% more on top.")
	_add("k_calm", "Empty Mind", "passive", R, _g(3, 3), ["k_deep"], {"cdr_katana": 0.2},
		"Katana techniques come back 20% sooner.")
	_add("k_through", "Through the Guard", "passive", R, _g(2, 4), ["k_final", "k_calm"], {"unblock_katana": 1},
		"Your iai can't be blocked.", {"level": 8})


static func _build_axe() -> void:
	_tree = "axe"
	var R := "Axe"
	_add("a_root", "Axe", "root", R, _g(0, 0), [], {},
		"Heavy, deliberate hacks and a whirlwind on heavy. Fight with an axe to build its mastery.")
	_add("a_sky", "Skybreaker", "move", R, _g(-2, 0), ["a_root"], {"mv_skybreaker": 1},
		"Attack in the air: spring into a somersault and split the ground in a line ahead, knocking everyone on it flat.")
	_add("a_heft", "Heft", "stat", R, _g(0, 1), ["a_root"], {"dmg_axe": 0.06}, "+6% axe damage.")
	_add("a_grip", "Iron Grip", "passive", R, _g(2, 0), ["a_root"], {"stam_axe": 0.15}, "Axe attacks cost 15% less stamina.")
	# brute force
	_add("a_cleaver", "Cleaver", "stat", R, _g(-3, 1), ["a_sky"], {"dmg_axe": 0.08}, "+8% axe damage.")
	_add("a_throw", "Hatchet Throw", "active", R, _g(-1.5, 1), ["a_heft", "a_sky"], {}, "", {}, "axe_throw")
	_add("a_split", "Earthsplitter", "active", R, _g(-3, 2), ["a_cleaver", "a_throw"], {}, "", {}, "earthsplitter")
	_add("a_brutal", "Brutal", "passive", R, _g(-2, 3), ["a_split"], {"crit_axe": 0.1}, "10% of your axe hits land 50% harder.")
	_add("a_frenzy", "Frenzy", "passive", R, _g(-3, 4), ["a_brutal"], {"cdr_axe": 0.2}, "Axe techniques come back 20% sooner.")
	# fury
	_add("a_overhead", "Overhead", "passive", R, _g(0, 2), ["a_heft"], {"heavy_axe": 0.3}, "Your whirlwind hits 30% harder.")
	_add("a_unstop", "Unstoppable", "passive", R, _g(0, 3), ["a_overhead"], {"armor_axe": 1},
		"Mid-swing with an axe, blows don't make you flinch or knock you off your feet.", {"level": 4})
	_add("a_berserk", "Berserk", "active", R, _g(0, 4), ["a_unstop", "a_exec"], {}, "", {}, "berserk")
	_add("a_warlord", "Warlord", "stat", R, _g(0, 5), ["a_berserk"], {"dmg_axe": 0.12}, "+12% axe damage.", {"level": 10})
	_add("a_maelstrom", "Maelstrom", "ult", R, _g(0, 6), ["a_warlord"], {}, "", {"level": 12}, "maelstrom")
	# blood
	_add("a_blood", "Bloodlust", "passive", R, _g(1.5, 1), ["a_heft", "a_grip"], {"flow_axe": 0.4}, "Axe hits give 40% more energy.")
	_add("a_harvest", "Red Harvest", "passive", R, _g(3, 1), ["a_blood"], {"leech_axe": 0.08}, "Axe hits heal you for 8% of their damage.")
	_add("a_sunder", "Sunder", "passive", R, _g(1.5, 2), ["a_overhead", "a_blood"], {"unblock_axe": 1}, "Your heavy attacks can't be blocked.")
	_add("a_headsman", "Headsman", "stat", R, _g(3, 2), ["a_harvest"], {"dmg_axe": 0.1}, "+10% axe damage.", {"level": 6})
	_add("a_exec", "Executioner", "passive", R, _g(1.5, 3), ["a_sunder"], {"exec_axe": 0.5},
		"A hit that leaves them under 30% health deals 50% more on top.")
	_add("a_hide", "Thick Hide", "stat", R, _g(3, 3), ["a_headsman"], {"def_axe": 8.0}, "+8 defense with an axe in hand.")


static func _build_dual() -> void:
	_tree = "dual"
	var R := "Dual Wield"
	_add("d_root", "Dual Wield", "root", R, _g(0, 0), [], {},
		"A blade in each hand: fast chained cuts and a crashing double overhead. Fight with two blades to build dual-wield mastery.")
	_add("d_spin", "Twin Spin", "move", R, _g(-2, 0), ["d_root"], {"mv_twin_spin": 1},
		"Adds a fourth hit to your combo: both blades whirled round in a spin.")
	_add("d_twin", "Twin Blades", "stat", R, _g(0, 1), ["d_root"], {"dmg_dual": 0.12}, "+12% damage while dual wielding.")
	_add("d_hands", "Light Hands", "passive", R, _g(2, 0), ["d_root"], {"stam_dual": 0.15},
		"Dual-wield attacks cost 15% less stamina.")
	# guard
	_add("d_deflect", "Twin Deflect", "passive", R, _g(-3, 1), ["d_spin"], {"parryshot_dual": 1},
		"Parry with two blades and you cut gunshots out of the air too (without it, a parry only stops blades).")
	_add("d_guard", "Crossed Guard", "passive", R, _g(-1.5, 1), ["d_twin", "d_spin"], {"parry_dual": 0.06},
		"Your parry window with two blades is wider.")
	_add("d_counter", "Crossed Counter", "active", R, _g(-3, 2), ["d_deflect"], {}, "", {}, "cross_counter")
	_add("d_fangs", "Crossed Fangs", "stat", R, _g(-3, 3), ["d_counter"], {"dmg_dual": 0.08}, "+8% damage while dual wielding.")
	_add("d_return", "Ricochet Steel", "passive", R, _g(-3, 4), ["d_fangs"], {"deflect_dual": 1, "return_dual": 1, "deflect_cd_dual": 1.0},
		"Mastered: with both blades drawn, a shot from the front is cut down by itself (once every 3 s), and every shot you cut flies back at whoever fired it, twice as hard.", {"level": 4})
	# dance
	_add("d_dance", "Blade Dance", "active", R, _g(0, 2), ["d_twin"], {}, "", {}, "blade_dance")
	_add("d_cross", "Cross Fang", "active", R, _g(-1.5, 3), ["d_dance", "d_guard"], {}, "", {}, "cross_fang")
	_add("d_storm", "Storm of Blades", "stat", R, _g(0, 4), ["d_cross", "d_tech"], {"dmg_dual": 0.1},
		"+10% damage while dual wielding.", {"level": 6})
	_add("d_master", "Twin Master", "stat", R, _g(0, 5), ["d_storm", "d_exec"], {"dmg_dual": 0.12},
		"+12% damage while dual wielding.", {"level": 10})
	_add("d_tempest", "Tempest of Steel", "ult", R, _g(0, 6), ["d_master"], {}, "", {"level": 12}, "steel_tempest")
	# edge
	_add("d_whirl", "Whirling Steel", "passive", R, _g(1.5, 1), ["d_twin", "d_hands"], {"flow_dual": 0.4},
		"Dual-wield hits give 40% more energy.")
	_add("d_crit", "Flurry of Edges", "passive", R, _g(3, 1), ["d_whirl"], {"crit_dual": 0.12},
		"12% of your dual-wield hits land 50% harder.")
	_add("d_finish", "Final Twirl", "passive", R, _g(1.5, 2), ["d_whirl"], {"finisher_dual": 0.35},
		"The last cut of your combo lands 35% harder.")
	_add("d_leech", "Drinking Steel", "passive", R, _g(3, 2), ["d_crit"], {"leech_dual": 0.06},
		"Dual-wield hits heal you for 6% of their damage.")
	_add("d_tech", "Dancer", "passive", R, _g(1.5, 3), ["d_finish"], {"cdr_dual": 0.2},
		"Dual-wield techniques come back 20% sooner.")
	_add("d_exec", "Thousand Cuts", "passive", R, _g(2, 4), ["d_tech", "d_leech"], {"exec_dual": 0.4},
		"A cut that leaves them under 30% health deals 40% more on top.")


static func _build_pistol() -> void:
	_tree = "pistol"
	var R := "Pistol"
	_add("g_root", "Pistol", "root", R, _g(0, 0), [], {},
		"Two shots, then reload. A second pistol in the off hand alternates them. Shoot to build pistol mastery.")
	_add("g_kata", "Gun Kata", "move", R, _g(-2, 0), ["g_root"], {"mv_gun_kata": 1},
		"Dual pistols' heavy: a hop into a double spin, arms crossed, shooting everyone close. (Without it: a pistol-whip.)")
	_add("g_marks", "Marksman", "stat", R, _g(0, 1), ["g_root"], {"dmg_pistol": 0.1}, "+10% damage with pistols.")
	_add("g_hands", "Quick Hands", "passive", R, _g(2, 0), ["g_root"], {"reload_pct": 0.35}, "Reload 35% faster.")
	# tricks
	_add("g_rain", "Gun Rain", "move", R, _g(-3, 1), ["g_kata"], {"mv_gun_rain": 1},
		"Dual pistols in the air: fire both guns down at once, the recoil launching you forward.")
	_add("g_smoke", "Smoke Bomb", "active", R, _g(-1.5, 1), ["g_kata", "g_marks"], {}, "", {}, "smoke_bomb")
	_add("g_hang", "Hang Time", "passive", R, _g(-3, 2), ["g_rain"], {"gun_rain_uses": 1},
		"Gun Rain can be fired twice before you land.", {"level": 6})
	_add("g_grace", "Gunslinger's Grace", "passive", R, _g(-3, 3), ["g_hang", "g_smoke"], {"cdr_pistol": 0.2},
		"Pistol techniques come back 20% sooner.")
	_add("g_money", "Blood Money", "passive", R, _g(-3, 4), ["g_grace"], {"leech_pistol": 0.05},
		"Pistol hits heal you for 5% of their damage.")
	# shots
	_add("g_storm", "Bullet Storm", "active", R, _g(0, 2), ["g_marks"], {}, "", {}, "bullet_storm")
	_add("g_dead", "Deadeye", "active", R, _g(-1.5, 3), ["g_storm", "g_smoke"], {}, "", {}, "deadeye")
	_add("g_ricochet", "Ricochet", "passive", R, _g(0, 4), ["g_dead", "g_hollow"], {"ricochet": 1},
		"Every pistol ball that hits glances off into the nearest other enemy for 60% damage.", {"level": 6})
	_add("g_legend", "Legendary Gunman", "stat", R, _g(0, 5), ["g_ricochet", "g_exec"], {"dmg_pistol": 0.12},
		"+12% damage with pistols.", {"level": 10})
	_add("g_waltz", "Death's Waltz", "ult", R, _g(0, 6), ["g_legend"], {}, "", {"level": 12}, "deaths_waltz")
	# close work
	_add("g_powder", "Extra Powder", "passive", R, _g(1.5, 1), ["g_marks", "g_hands"], {"extra_shots": 1},
		"Every pistol holds one more shot.", {"level": 4})
	_add("g_luck", "Lucky Shot", "passive", R, _g(1.5, 2), ["g_storm", "g_powder"], {"crit_pistol": 0.12},
		"12% of your shots land 50% harder.")
	_add("g_point", "Point Blank", "active", R, _g(3, 2), ["g_powder"], {}, "", {}, "point_blank")
	_add("g_hollow", "Hollow Point", "stat", R, _g(1.5, 3), ["g_luck"], {"dmg_pistol": 0.1}, "+10% damage with pistols.", {"level": 6})
	_add("g_close", "Close Quarters", "passive", R, _g(3, 3), ["g_point"], {"pointblank_pct": 0.4},
		"Shots from within 5 m hit 40% harder.")
	_add("g_exec", "Coup de Grace", "passive", R, _g(2, 4), ["g_hollow", "g_close"], {"exec_pistol": 0.4},
		"A shot that leaves them under 30% health deals 40% more on top.")


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
