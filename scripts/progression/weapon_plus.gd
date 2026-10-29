class_name WeaponPlus
extends RefCounted
## (1.26, docs/weapons_126.md) What each weapon tree gains on top of its branches: two ultimates (today's, and a second
## up the right of the split, each behind a lead-up node), a second crew technique (a variant switching which one C
## plays), three alternates (variants that come by themselves at ALT_LEVELS: the standard move or the alternate, for
## the aerial, the sprint attack and the right-click; PlusArts runs them) and four bridges between the branches (a stat
## and a passive each side of the middle; bought once you own a node they're linked to). SkillTrees._plus builds the
## nodes from TREES; a tree without an entry is as it was.
##
## TREES: tree -> {lead_a, lead_b: [id, name, effects], ult_b: [node id, skill], crew: crew technique id,
##   alts: [aerial, sprint, right-click] PlusArts move ids, bridges: [[id, name, effects] x4]: left/middle stat, its
##   passive, middle/right stat, its passive}

const ALT_SLOTS := ["air", "sprint", "heavy"]
const ALT_LEVELS := {"air": 8, "sprint": 14, "heavy": 20}
const ALT_NAMES := {"air": "Aerial", "sprint": "Sprint Attack", "heavy": "Right-Click"}
const ALT_STANDARD := {"air": "Your usual attack in the air (the tree's air move once learned, else the plunge).",
	"sprint": "Your usual attack at a sprint (the tree's sprint move once learned, else the combo's first blow).",
	"heavy": "Your usual right-click."}
## Where the split sits off the second element node (tree space): the lead-up, then the ultimate.
const LEAD_OFF := Vector2(76, -78)
const ULT_OFF := Vector2(104, -168)
## The bridges: [level, price], inner then outer.
const BRIDGE := [[6, 3], [15, 4]]
const LEAD_LEVEL := 26
const LEAD_PRICE := 3
const CREW_LEVEL := 12

## The aerial heavy (right-click in the air: the plunge until it's bought): its level.
const AIR_HEAVY_LEVEL := 10

## The second crew techniques (CrewTechniques.def): no styles (the tree's "Crew Technique" variant picks them), the tree
## whose colours they wear, a kind CrewTechniqueState plays from its DUETS ("setup", "combined", "support").
const CREW := {
	"crossed_cutlass": {"name": "Crossed Cutlasses", "styles": [], "tree": "sword", "kind": "combined", "solo": "Double Cross",
		"desc": "You and your crewmate cut across the foe ahead from opposite sides at once: an X bursts on everyone round it and throws them down.",
		"solo_desc": "Through the foe ahead and back again, a cut each way, and the X bursts."},
	"blade_sheath": {"name": "Blade and Sheath", "styles": [], "tree": "katana", "kind": "setup", "solo": "Sheath Strike",
		"desc": "The scabbard sweeps the legs of the foe ahead and pins it down; your crewmate is beside it in a blink with a drawing cut that can't be blocked.",
		"solo_desc": "The scabbard sweeps its legs, then your own drawing cut."},
	"double_course": {"name": "Double Course", "styles": [], "tree": "black_leg", "kind": "combined", "solo": "Scissor Kick",
		"desc": "You and your crewmate kick the foe ahead from opposite sides at once: an X of heat, and everyone round it is thrown up.",
		"solo_desc": "Both legs scissored through the foe ahead, and everyone round it thrown up."},
	"powder_share": {"name": "Powder Share", "styles": [], "tree": "pistol", "kind": "support", "solo": "Hot Reload",
		"desc": "Toss your crewmate a loaded pistol: you're both reloaded, they get 25 energy, and you both hit 20% harder for 8 s.",
		"solo_desc": "Reloaded at once, 12 energy, and 20% harder for 8 s."},
	"ground_pin": {"name": "Pinned", "styles": [], "tree": "polearm", "kind": "setup", "solo": "Ground Pin",
		"desc": "Sweep the foe ahead off its feet and pin it under the shaft; your crewmate vaults in and drives the finisher down like a thunderclap.",
		"solo_desc": "The sweep and the pin, then the point driven down yourself."},
	"lift_cleave": {"name": "Lift and Cleave", "styles": [], "tree": "greatsword", "kind": "setup", "solo": "Lift and Fall",
		"desc": "The flat lifts the foe ahead off its feet and holds it up; your crewmate leaps in and cleaves it back down into the ground.",
		"solo_desc": "The lift, then your own cleave down."},
}

## Each tree's first (1.24) crew technique, as its variant's first version shows it: [name, text].
const CREW_FIRST := {
	"sword": ["Crossed Blades", "Brace your blade at shoulder height: your crewmate vaults off it into a leaping slash."],
	"katana": ["Guardian Stance", "Stand guard over a crewmate for 8 s: whoever strikes them eats your iai counter."],
	"black_leg": ["Skyward Kick", "Your crewmate steps onto your raised foot and you kick them high along your aim; they come down with a free plunge."],
	"pistol": ["Covering Fire", "Pin down the foes ahead with a volley: crewmates in the fight take less damage and reload faster."],
	"polearm": ["Pole Vault", "Plant the polearm: your crewmate runs up it and vaults far (gaps, ledges, onto a boss)."],
	"greatsword": ["Shield Wall", "Raise the flat as a wall for 8 s: shots from the front stop at it, and a crewmate behind it takes less from blows."],
}

const TREES := {
	"sword": {
		"lead_a": ["s_call", "Kraken's Call", {"ult_charge_pct": 0.1}],
		"lead_b": ["s_deep", "Deep Current", {"skill_sword": 0.08}],
		"ult_b": ["s_undertow", "undertow"],
		"crew": "crossed_cutlass",
		"alts": ["anchor_drop", "boarding_hook", "broadside_sweep"], "air_heavy": "whirlpool_descent",
		"bridges": [["s_legs", "Sea Legs", {"def_sword": 3.0, "parry_sword": 0.03}],
			["s_current", "Counter-current", {"parry_sword": 0.04, "skill_sword": 0.06}],
			["s_salt", "Salt Edge", {"skill_sword": 0.06}],
			["s_seas", "High Seas", {"flow_sword": 0.2, "cdr_sword": 0.1}]],
	},
	"katana": {
		"lead_a": ["k_still", "Still Water", {"ult_charge_pct": 0.1}],
		"lead_b": ["k_breath", "Long Breath", {"skill_katana": 0.08}],
		"ult_b": ["k_moonlit", "moonlit_severance"],
		"crew": "blade_sheath",
		"alts": ["heron_dive", "wind_step", "mirror_draw"], "air_heavy": "blossom_cleave",
		"bridges": [["k_grip", "Settled Grip", {"def_katana": 3.0, "parry_katana": 0.03}],
			["k_water", "Clear Water", {"skill_katana": 0.06, "heavy_katana": 0.06}],
			["k_honed", "Honed", {"skill_katana": 0.06}],
			["k_drawn", "Drawn Breath", {"flow_katana": 0.2, "cdr_katana": 0.1}]],
	},
	"black_leg": {
		"lead_a": ["bl_mise", "Mise en Place", {"ult_charge_pct": 0.1}],
		"lead_b": ["bl_stove", "Hot Stove", {"skill_black_leg": 0.08}],
		"ult_b": ["bl_volcano", "volcano_course"],
		"crew": "double_course",
		"alts": ["meteor_heel", "sliding_shank", "flambe_lift"], "air_heavy": "comet_heels",
		"bridges": [["bl_callous", "Calloused", {"def_black_leg": 3.0, "parry_black_leg": 0.03}],
			["bl_simmer", "Simmer", {"skill_black_leg": 0.06, "parry_black_leg": 0.04}],
			["bl_pace", "Searing Pace", {"skill_black_leg": 0.06}],
			["bl_service", "Service", {"flow_black_leg": 0.2, "cdr_black_leg": 0.1}]],
	},
	"pistol": {
		"lead_a": ["g_card", "Dance Card", {"ult_charge_pct": 0.1}],
		"lead_b": ["g_gilt", "Gilt Rounds", {"skill_pistol": 0.08}],
		"ult_b": ["g_golden", "golden_ricochet"],
		"crew": "powder_share",
		"alts": ["spiral_shot", "slide_shot", "barrel_lift"], "air_heavy": "downward_volley",
		"bridges": [["g_hands", "Quick Hands", {"reload_pct": 0.08, "def_pistol": 3.0}],
			["g_show", "Showman", {"skill_pistol": 0.06, "flow_pistol": 0.2}],
			["g_wrist", "Steady Wrist", {"skill_pistol": 0.06}],
			["g_call", "Close Call", {"pointblank_pct": 0.12, "cdr_pistol": 0.1}]],
	},
	"polearm": {
		"lead_a": ["pl_gather", "Gathering Storm", {"ult_charge_pct": 0.1}],
		"lead_b": ["pl_rod", "Lightning Rod", {"skill_polearm": 0.08}],
		"ult_b": ["pl_pike", "heavens_pike"],
		"crew": "ground_pin",
		"alts": ["spinning_descent", "skyward_pike", "halberd_hook"], "air_heavy": "thunder_spike",
		"bridges": [["pl_shaft2", "Iron Shaft", {"def_polearm": 3.0, "parry_polearm": 0.03}],
			["pl_static", "Static", {"skill_polearm": 0.06, "parry_polearm": 0.04}],
			["pl_arm", "Long Arm", {"skill_polearm": 0.06}],
			["pl_head", "Thunderhead", {"flow_polearm": 0.2, "cdr_polearm": 0.1}]],
	},
	"greatsword": {
		"lead_a": ["gs_rising", "Rising Gale", {"ult_charge_pct": 0.1}],
		"lead_b": ["gs_front", "Stormfront", {"skill_greatsword": 0.08}],
		"ult_b": ["gs_eye", "eye_of_storm"],
		"crew": "lift_cleave",
		"alts": ["gale_glide", "wind_shear", "whirlwind_draw"], "air_heavy": "heavens_cleave",
		"bridges": [["gs_back", "Broad Back", {"def_greatsword": 3.0, "parry_greatsword": 0.03}],
			["gs_weather", "Weathered", {"skill_greatsword": 0.06, "def_greatsword": 3.0}],
			["gs_heft2", "Heft of Wind", {"skill_greatsword": 0.06}],
			["gs_breath", "Second Breath", {"flow_greatsword": 0.2, "cdr_greatsword": 0.1}]],
	},
}


static func has(tree: String) -> bool:
	return TREES.has(tree)


## The PlusArts move a tree's alternate is for `slot` ("air", "sprint", "heavy"); "" if it has none.
static func alt_id(tree: String, slot: String) -> String:
	if not TREES.has(tree):
		return ""
	return str(TREES[tree]["alts"][ALT_SLOTS.find(slot)])


## A tree's aerial heavy (PlusArts move id) and the key its node sets.
static func air_heavy(tree: String) -> String:
	return str(TREES.get(tree, {}).get("air_heavy", ""))


static func air_heavy_key(tree: String) -> String:
	return "airheavy_" + tree


## The effect key that switches a tree's alternate on (its variant's second version).
static func alt_key(tree: String, slot: String) -> String:
	return "alt_%s_%s" % [slot, tree]


## The second crew technique of a weapon tree ("" for none).
static func crew_of(tree: String) -> String:
	return str(TREES.get(tree, {}).get("crew", ""))


## A node's text from its effects (bridges and lead-ups: stat nodes).
static func describe(effects: Dictionary, tree: String) -> String:
	var w := str(SkillTrees.HEADERS[tree][0]).to_lower()
	var parts: Array = []
	for k in effects.keys():
		var v := float(effects[k])
		var pct := roundi(v * 100.0)
		var pre := str(k).trim_suffix("_" + tree)
		match pre:
			"dmg":
				parts.append("+%d%% %s damage" % [pct, w])
			"skill":
				parts.append("%s techniques hit %d%% harder" % [w, pct])
			"def":
				parts.append("+%d defense with it in hand" % roundi(v))
			"parry":
				parts.append("a wider parry window")
			"crit":
				parts.append("%d%% more of your hits land 50%% harder" % pct)
			"flow":
				parts.append("%s hits give %d%% more energy" % [w, pct])
			"cdr":
				parts.append("%s techniques come back %d%% sooner" % [w, pct])
			"heavy":
				parts.append("your right-click hits %d%% harder" % pct)
			"ult_charge_pct":
				parts.append("your ultimate charges %d%% faster" % pct)
			"reload_pct":
				parts.append("you reload %d%% faster" % pct)
			"pointblank_pct":
				parts.append("shots from within 5 m hit %d%% harder" % pct)
			_:
				push_error("WeaponPlus.describe: no words for " + str(k))
	var s := ", ".join(parts.slice(0, -1)) + (" and " if parts.size() > 1 else "") + str(parts[-1])
	return s.substr(0, 1).to_upper() + s.substr(1) + "."
