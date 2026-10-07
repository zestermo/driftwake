class_name SkillTree
extends RefCounted
## The skill trees, one tab each on the skill map:
##   base     Base & Haki: core stats in the middle; Mobility, Survival,
##            Armament and Observation Haki (level 10+) grow out of it
##   unarmed, sword (cutlass), katana, axe, dual, pistol
##            weapon trees, paid for with that weapon's mastery points (earned
##            by fighting with it); they hold its passives, its skills and the
##            parts of its moveset you have to unlock ("move" nodes)
##   fruit    your Devil Fruit (only once you've eaten one)
## You can learn any node linked to one you own (if you meet its requirements).
##
## Node: {id, name, kind, tree, region, pos, links, cost, effects, skill, req, desc}
##   kind: origin | root | stat | passive | move | active | ult
##   effects: stat bonuses / flags summed by Progression.stat(); a move node
##     carries a flag "mv_<move>" (Progression.has_move)
##   req: {"level": n} and/or {"fruit": id}

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
	"Armament": Color(0.6, 0.45, 0.85), "Observation": Color(0.95, 0.5, 0.75),
	"Unarmed": Color(1.0, 0.85, 0.6), "Cutlass": Color(0.85, 0.85, 0.95), "Katana": Color(0.7, 0.85, 1.0),
	"Axe": Color(1.0, 0.7, 0.45), "Dual Wield": Color(0.55, 0.85, 1.0), "Pistol": Color(0.95, 0.75, 0.4),
	"Ember": Color(1.0, 0.5, 0.15), "Wolf": Color(0.7, 0.62, 0.5), "Vine": Color(0.45, 0.85, 0.3),
}

## Direction (degrees, screen space: 90 = down) each base-tree region grows in.
const REGION_ANGLE := {"Mobility": -135.0, "Survival": -45.0, "Observation": 45.0, "Armament": 135.0}

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


static func _add(id: String, name_: String, kind: String, region: String, pos: Vector2, links: Array,
		effects: Dictionary = {}, desc: String = "", req: Dictionary = {}, skill: String = "", cost: int = -1) -> void:
	var c := cost
	if c < 0:
		c = 2 if kind in ["active", "ult"] else 1
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

	# ---- Haki (level-gated) ----
	A = REGION_ANGLE["Armament"]
	_add("h_arm", "Armament Haki", "passive", "Armament", _p(A, 185.0), ["c_spirit"], {"armament": 1, "damage_pct": 0.08},
		"Will made armor: +8% damage, and your heavy attacks can't be blocked.", {"level": 10})
	_add("h_coat", "Armament: Coat", "active", "Armament", _p(A, 265.0), ["h_arm"], {}, "", {"level": 12}, "armament_coat")
	A = REGION_ANGLE["Observation"]
	_add("h_obs", "Observation Haki", "passive", "Observation", _p(A, 185.0), ["c_toughness"], {"observation": 1},
		"Sense intent: enemies flash red the moment they start an attack, and your parry window is a little wider.", {"level": 10})
	_add("h_fore", "Foresight", "active", "Observation", _p(A, 265.0), ["h_obs"], {}, "", {"level": 12}, "foresight")


## Weapon trees share a shape for now: root in the middle, a damage line going
## up into the skills, a moveset unlock to the left, stamina/energy passives to
## the right. Generic keys: dmg_<tree> (damage with it), stam_<tree> (attack
## stamina), flow_<tree> (energy per hit).
static func _build_unarmed() -> void:
	_tree = "unarmed"
	var R := "Unarmed"
	_add("u_root", "Unarmed", "root", R, Vector2.ZERO, [], {},
		"Bare-handed brawling: jab, cross, hook and a flying kick. Fight with your fists to build unarmed mastery.")
	_add("u_knuckles", "Iron Knuckles", "stat", R, _p(-90, 75), ["u_root"], {"dmg_unarmed": 0.08}, "+8% unarmed damage.")
	_add("u_round", "Roundhouse", "move", R, _p(180, 75), ["u_root"], {"mv_roundhouse": 1},
		"Adds a fourth hit to your punch combo: a spinning roundhouse kick.")
	_add("u_breath", "Fighter's Breath", "passive", R, _p(0, 75), ["u_root"], {"stam_unarmed": 0.2},
		"Unarmed attacks cost 20% less stamina.")
	_add("u_stone", "Stone Fists", "stat", R, _p(-150, 145), ["u_knuckles", "u_round"], {"dmg_unarmed": 0.1}, "+10% unarmed damage.")
	_add("u_flow", "Flow of Combat", "passive", R, _p(-30, 145), ["u_knuckles", "u_breath"], {"flow_unarmed": 0.5},
		"Unarmed hits give 50% more energy.")
	_add("u_thousand", "Thousand Fists", "stat", R, _p(-90, 215), ["u_stone", "u_flow"], {"dmg_unarmed": 0.12},
		"+12% unarmed damage.", {"level": 6})


static func _build_cutlass() -> void:
	_tree = "sword"
	var R := "Cutlass"
	_add("s_root", "Cutlass", "root", R, Vector2.ZERO, [], {},
		"The pirate's blade: quick cuts and a lunging thrust. Fight with a cutlass to build its mastery.")
	_add("s_edge", "Keen Edge", "stat", R, _p(-90, 75), ["s_root"], {"dmg_sword": 0.06}, "+6% cutlass damage.")
	_add("s_dash", "Running Cut", "move", R, _p(180, 75), ["s_root"], {"mv_dash_cut": 1},
		"Attack at a sprint: one low cut driving through the target, breaking its wind-up.")
	_add("s_light", "Light Blade", "passive", R, _p(0, 75), ["s_root"], {"stam_sword": 0.15},
		"Cutlass attacks cost 15% less stamina.")
	_add("s_flying", "Flying Slash", "active", R, _p(-90, 150), ["s_edge"], {}, "", {}, "flying_slash")
	_add("s_honed", "Honed Steel", "stat", R, _p(-150, 145), ["s_edge", "s_dash"], {"dmg_sword": 0.08}, "+8% cutlass damage.")
	_add("s_rhythm", "Sea Dog's Rhythm", "passive", R, _p(-30, 145), ["s_edge", "s_light"], {"flow_sword": 0.4},
		"Cutlass hits give 40% more energy.")
	_add("s_boarding", "Boarding Blade", "stat", R, _p(-90, 225), ["s_flying", "s_honed", "s_rhythm"], {"dmg_sword": 0.1},
		"+10% cutlass damage.", {"level": 6})


static func _build_katana() -> void:
	_tree = "katana"
	var R := "Katana"
	_add("k_root", "Katana", "root", R, Vector2.ZERO, [], {},
		"Two hands, slow wide cuts, and iaijutsu on heavy: hold to charge, attack to draw. Fight with a katana to build its mastery.")
	_add("k_full", "Full Draw", "move", R, _p(-90, 75), ["k_root"], {"mv_iai_full": 1},
		"Your iai charges to its second level: a gold glint, a longer dash, and everything you cut through crumples.", {}, "", 2)
	_add("k_draw", "Quick Draw", "move", R, _p(180, 75), ["k_root"], {"mv_quick_draw": 1},
		"Attack at a sprint: a quick cut straight out of the scabbard that breaks wind-ups.")
	_add("k_folded", "Folded Steel", "stat", R, _p(0, 75), ["k_root"], {"dmg_katana": 0.06}, "+6% katana damage.")
	_add("k_tiger", "Tiger Rush", "active", R, _p(-90, 150), ["k_full"], {}, "", {"level": 4}, "tiger_rush")
	_add("k_arc", "Crescent Arc", "move", R, _p(-150, 145), ["k_draw", "k_full"], {"mv_air_slash": 1},
		"Attack in the air: a little lift and one big arc swept down under you (once per jump).")
	_add("k_still", "Still Water", "passive", R, _p(-30, 145), ["k_full", "k_folded"], {"stam_katana": 0.15},
		"Katana attacks cost 15% less stamina.")
	_add("k_master", "Master's Edge", "stat", R, _p(-90, 225), ["k_tiger", "k_arc", "k_still"], {"dmg_katana": 0.1},
		"+10% katana damage.", {"level": 6})


static func _build_axe() -> void:
	_tree = "axe"
	var R := "Axe"
	_add("a_root", "Axe", "root", R, Vector2.ZERO, [], {},
		"Heavy, deliberate hacks and a whirlwind on heavy. Fight with an axe to build its mastery.")
	_add("a_heft", "Heft", "stat", R, _p(-90, 75), ["a_root"], {"dmg_axe": 0.06}, "+6% axe damage.")
	_add("a_sky", "Skybreaker", "move", R, _p(180, 75), ["a_root"], {"mv_skybreaker": 1},
		"Attack in the air: spring into a somersault and split the ground in a line ahead, knocking everyone on it flat.")
	_add("a_grip", "Iron Grip", "passive", R, _p(0, 75), ["a_root"], {"stam_axe": 0.15}, "Axe attacks cost 15% less stamina.")
	_add("a_cleaver", "Cleaver", "stat", R, _p(-150, 145), ["a_heft", "a_sky"], {"dmg_axe": 0.08}, "+8% axe damage.")
	_add("a_blood", "Bloodlust", "passive", R, _p(-30, 145), ["a_heft", "a_grip"], {"flow_axe": 0.4}, "Axe hits give 40% more energy.")
	_add("a_headsman", "Headsman", "stat", R, _p(-90, 215), ["a_cleaver", "a_blood"], {"dmg_axe": 0.1},
		"+10% axe damage.", {"level": 6})


static func _build_dual() -> void:
	_tree = "dual"
	var R := "Dual Wield"
	_add("d_root", "Dual Wield", "root", R, Vector2.ZERO, [], {},
		"A blade in each hand: fast chained cuts and a crashing double overhead. Fight with two blades to build dual-wield mastery.")
	_add("d_twin", "Twin Blades", "stat", R, _p(-90, 75), ["d_root"], {"dmg_dual": 0.12}, "+12% damage while dual wielding.")
	_add("d_spin", "Twin Spin", "move", R, _p(180, 75), ["d_root"], {"mv_twin_spin": 1},
		"Adds a fourth hit to your combo: both blades whirled round in a spin.")
	_add("d_hands", "Light Hands", "passive", R, _p(0, 75), ["d_root"], {"stam_dual": 0.15},
		"Dual-wield attacks cost 15% less stamina.")
	_add("d_fangs", "Crossed Fangs", "stat", R, _p(-150, 145), ["d_twin", "d_spin"], {"dmg_dual": 0.08}, "+8% damage while dual wielding.")
	_add("d_whirl", "Whirling Steel", "passive", R, _p(-30, 145), ["d_twin", "d_hands"], {"flow_dual": 0.4},
		"Dual-wield hits give 40% more energy.")


static func _build_pistol() -> void:
	_tree = "pistol"
	var R := "Pistol"
	_add("g_root", "Pistol", "root", R, Vector2.ZERO, [], {},
		"Two shots, then reload. A second pistol in the off hand alternates them. Shoot to build pistol mastery.")
	_add("g_marks", "Marksman", "stat", R, _p(-90, 75), ["g_root"], {"dmg_pistol": 0.1}, "+10% damage with pistols.")
	_add("g_kata", "Gun Kata", "move", R, _p(180, 75), ["g_root"], {"mv_gun_kata": 1},
		"Dual pistols' heavy: a hop into a double spin, arms crossed, shooting everyone close. (Without it: a pistol-whip.)")
	_add("g_hands", "Quick Hands", "passive", R, _p(0, 75), ["g_root"], {"reload_pct": 0.35}, "Reload 35% faster.")
	_add("g_storm", "Bullet Storm", "active", R, _p(-90, 150), ["g_marks"], {}, "", {}, "bullet_storm")
	_add("g_rain", "Gun Rain", "move", R, _p(-150, 145), ["g_kata", "g_marks"], {"mv_gun_rain": 1},
		"Dual pistols in the air: fire both guns down at once, the recoil launching you forward.")
	_add("g_powder", "Extra Powder", "passive", R, _p(-30, 145), ["g_marks", "g_hands"], {"extra_shots": 1},
		"Every pistol holds one more shot.", {"level": 4})
	_add("g_hang", "Hang Time", "passive", R, _p(-150, 215), ["g_rain"], {"gun_rain_uses": 1},
		"Gun Rain can be fired twice before you land.", {"level": 6})


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
