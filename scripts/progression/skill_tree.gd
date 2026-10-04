class_name SkillTree
extends RefCounted
## The skill map: one constellation of nodes. You start owning the Origin and
## can learn any node linked to one you own (if you meet its requirements),
## spending skill points.
##
##   center      stats (health, damage, stamina, energy, defense...)
##   up-left     Mobility (Geppo air jumps, Soru, dodge upgrades)
##   up-right    Survival (health, Tekkai, steadfast, regen, last stand)
##   left        Sword          right   Gun
##   down-left   Armament Haki  down-right  Observation Haki  (level 10+)
##   down        your Devil Fruit (only once you've eaten one)
##
## Node: {id, name, kind, region, pos, links, cost, effects, skill, req, desc}
##   kind: origin | stat | passive | active | ult | root
##   effects: stat bonuses / flags summed by Progression.stat()
##   req: {"level": n} and/or {"fruit": id}

const REGION_COLORS := {
	"Core": Color(0.85, 0.78, 0.6), "Mobility": Color(0.45, 0.85, 0.95), "Survival": Color(0.5, 0.9, 0.45),
	"Sword": Color(0.85, 0.85, 0.95), "Gun": Color(0.95, 0.75, 0.4), "Armament": Color(0.6, 0.45, 0.85),
	"Observation": Color(0.95, 0.5, 0.75), "Ember": Color(1.0, 0.5, 0.15), "Wolf": Color(0.7, 0.62, 0.5),
	"Vine": Color(0.45, 0.85, 0.3),
}

## Direction (degrees, screen space: 90 = down) each region grows in.
const REGION_ANGLE := {"Mobility": -125.0, "Survival": -55.0, "Sword": 180.0, "Gun": 0.0,
	"Armament": 125.0, "Observation": 55.0, "Fruit": 90.0}

static var _nodes: Dictionary = {}


static func nodes() -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _nodes


static func get_node_def(id: String) -> Dictionary:
	return nodes().get(id, {})


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
	_nodes[id] = {"id": id, "name": name_, "kind": kind, "region": region, "pos": pos, "links": links,
		"effects": effects, "desc": desc, "req": req, "skill": skill, "cost": c}


static func _build() -> void:
	_nodes = {}
	_add("origin", "Pirate's Spirit", "origin", "Core", Vector2.ZERO, [], {}, "Where every captain starts. Learn the nodes linked to the ones you own.")
	# ---- core stats: an inner ring at each region's heading, a web between ----
	var inner := {
		"Mobility": ["c_agility", "Agility", {"move_pct": 0.04}, "+4% movement speed."],
		"Survival": ["c_vitality", "Vitality", {"max_hp": 15.0}, "+15 max health."],
		"Sword": ["c_strength", "Strength", {"damage_pct": 0.05}, "+5% damage."],
		"Gun": ["c_endurance", "Endurance", {"max_stamina": 12.0}, "+12 max stamina."],
		"Armament": ["c_spirit", "Spirit", {"max_energy": 15.0}, "+15 max energy."],
		"Observation": ["c_toughness", "Toughness", {"defense": 3.0}, "+3 defense."],
		"Fruit": ["c_focus", "Focus", {"ult_charge_pct": 0.1}, "Your ultimate charges 10% faster."],
	}
	var order := ["Gun", "Observation", "Fruit", "Armament", "Sword", "Mobility", "Survival"]  # clockwise from 0 deg
	for r in order:
		var d: Array = inner[r]
		_add(d[0], d[1], "stat", "Core", _p(REGION_ANGLE[r], 82.0), ["origin"], d[2], d[3])
	var web := [
		["c_vit2", "Vigor", {"max_hp": 20.0}, "+20 max health."],
		["c_tough2", "Thick Skin", {"defense": 4.0}, "+4 defense."],
		["c_wind", "Second Wind", {"stamina_regen_pct": 0.15}, "Stamina refills 15% faster."],
		["c_spirit2", "Inner Fire", {"energy_regen_pct": 0.12}, "Energy refills 12% faster."],
		["c_str2", "Brawn", {"damage_pct": 0.06}, "+6% damage."],
		["c_end2", "Wind", {"max_stamina": 15.0}, "+15 max stamina."],
		["c_vit3", "Heart of the Sea", {"max_hp": 20.0}, "+20 max health."],
	]
	for i in range(order.size()):
		var a: String = order[i]
		var b: String = order[(i + 1) % order.size()]
		var a1: float = REGION_ANGLE[a]
		var a2: float = REGION_ANGLE[b]
		if a2 < a1:
			a2 += 360.0
		var mid := (a1 + a2) * 0.5
		var w: Array = web[i]
		_add(w[0], w[1], "stat", "Core", _p(mid, 128.0), [inner[a][0], inner[b][0]], w[2], w[3])

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
	_add("m_shadow", "Shadow Step", "passive", "Mobility", _p(A, 420.0), ["m_skywalk", "m_fleet"], {"dodge_iframe_pct": 0.5, "dodge_dist_pct": 0.2},
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

	# ---- Sword ----
	A = REGION_ANGLE["Sword"]
	_add("w_blade", "Blade Mastery", "stat", "Sword", _p(A, 185.0), ["c_strength"], {"sword_pct": 0.1}, "+10% damage with swords.")
	_add("w_flying", "Flying Slash", "active", "Sword", _p(A, 265.0, -13.0), ["w_blade"], {}, "", {}, "flying_slash")
	_add("w_twin", "Twin Blades", "passive", "Sword", _p(A, 265.0, 13.0), ["w_blade"], {"dual_sword_pct": 0.12},
		"+12% damage while dual wielding swords.")
	_add("w_tiger", "Tiger Rush", "active", "Sword", _p(A, 345.0), ["w_flying", "w_twin"], {}, "", {"level": 4}, "tiger_rush")

	# ---- Gun ----
	A = REGION_ANGLE["Gun"]
	_add("g_marks", "Marksman", "stat", "Gun", _p(A, 185.0), ["c_endurance"], {"gun_pct": 0.1}, "+10% damage with guns.")
	_add("g_hands", "Quick Hands", "passive", "Gun", _p(A, 265.0, -13.0), ["g_marks"], {"reload_pct": 0.35}, "Reload 35% faster.")
	_add("g_storm", "Bullet Storm", "active", "Gun", _p(A, 265.0, 13.0), ["g_marks"], {}, "", {}, "bullet_storm")
	_add("g_powder", "Extra Powder", "passive", "Gun", _p(A, 345.0), ["g_hands", "g_storm"], {"extra_shots": 1},
		"Every pistol holds one more shot.", {"level": 4})

	# ---- Haki (level-gated) ----
	A = REGION_ANGLE["Armament"]
	_add("h_arm", "Armament Haki", "passive", "Armament", _p(A, 185.0), ["c_spirit"], {"armament": 1, "damage_pct": 0.08},
		"Will made armor: +8% damage, and your heavy attacks can't be blocked.", {"level": 10})
	_add("h_coat", "Armament: Coat", "active", "Armament", _p(A, 265.0), ["h_arm"], {}, "", {"level": 12}, "armament_coat")
	A = REGION_ANGLE["Observation"]
	_add("h_obs", "Observation Haki", "passive", "Observation", _p(A, 185.0), ["c_toughness"], {"observation": 1},
		"Sense intent: enemies flash red the moment they start an attack, and your parry window is a little wider.", {"level": 10})
	_add("h_fore", "Foresight", "active", "Observation", _p(A, 265.0), ["h_obs"], {}, "", {"level": 12}, "foresight")

	# ---- Devil Fruits (only the one you've eaten shows) ----
	A = REGION_ANGLE["Fruit"]
	var root := _p(A, 190.0)
	# Ember (Logia)
	_add("e_root", "Ember Fruit (Logia)", "root", "Ember", root, ["c_focus"], {},
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
	_add("z_root", "Wolf Fruit (Zoan)", "root", "Wolf", root, ["c_focus"], {},
		"Zoan: press V to shift between your human and hybrid wolf form. Hybrid: claws instead of weapons, 25% more damage and 15% faster.", {"fruit": "wolf"})
	_add("z_fang", "Rending Fang", "active", "Wolf", _p(A, 265.0, -16.0), ["z_root"], {}, "", {"fruit": "wolf"}, "rending_fang", 0)
	_add("z_pounce", "Pounce", "active", "Wolf", _p(A, 265.0, 16.0), ["z_root"], {}, "", {"fruit": "wolf"}, "pounce", 0)
	_add("z_pelt", "Thick Pelt", "passive", "Wolf", _p(A, 345.0, -10.0), ["z_fang"], {"hybrid_defense": 8.0},
		"+8 defense in hybrid form.", {"fruit": "wolf"})
	_add("z_hunt", "Predator", "passive", "Wolf", _p(A, 345.0, 10.0), ["z_pounce"], {"hybrid_speed_pct": 0.1},
		"Hybrid form is another 10% faster.", {"fruit": "wolf"})
	_add("z_howl", "Alpha Howl", "active", "Wolf", _p(A, 420.0), ["z_pelt", "z_hunt"], {}, "", {"fruit": "wolf", "level": 4}, "howl")
	# Vine (Paramecia)
	_add("p_root", "Vine Fruit (Paramecia)", "root", "Vine", root, ["c_focus"], {},
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
